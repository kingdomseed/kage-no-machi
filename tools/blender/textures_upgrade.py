#!/usr/bin/env python3
"""Upgrades Kage no Machi textures to crisp 1024x1024 painterly maps.

Uses clean seamless Midjourney inputs from docs/references/midjourney/, builds
fine-scale mountain_forest & dark-cedar shoji kumiko maps, removes white interior
halos from foliage cutouts with 6% border padding and RGB alpha-bleed dilation,
and regenerates wrapped tangent-space Sobel normal maps.
"""

from __future__ import annotations

import math
import os
import random
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEX_DIR = os.path.join(ROOT, "assets", "textures")
MJ_DIR = os.path.join(ROOT, "docs", "references", "midjourney")
GEN_DIR = os.path.join(ROOT, "tools", "blender", "generated_tex")
os.makedirs(GEN_DIR, exist_ok=True)

SIZE = 1024


def generate_sobel_normal_map(albedo: Image.Image, strength: float = 2.6, blur_radius: float = 0.6) -> Image.Image:
    """Computes a seamless tileable tangent-space normal map from luminance."""
    gray = albedo.convert("L")
    if blur_radius > 0:
        gray = gray.filter(ImageFilter.GaussianBlur(blur_radius))

    w, h = gray.size
    # Build cyclic 1-px border (w+2 x h+2) so Sobel gradients wrap seamlessly
    padded = Image.new("L", (w + 2, h + 2))
    padded.paste(gray, (1, 1))
    padded.paste(gray.crop((w - 1, 0, w, h)), (0, 1))
    padded.paste(gray.crop((0, 0, 1, h)), (w + 1, 1))
    padded.paste(gray.crop((0, h - 1, w, h)), (1, 0))
    padded.paste(gray.crop((0, 0, w, 1)), (1, h + 1))
    padded.putpixel((0, 0), gray.getpixel((w - 1, h - 1)))
    padded.putpixel((w + 1, 0), gray.getpixel((0, h - 1)))
    padded.putpixel((0, h + 1), gray.getpixel((w - 1, 0)))
    padded.putpixel((w + 1, h + 1), gray.getpixel((0, 0)))

    px = padded.load()
    out = Image.new("RGB", (w, h))
    opx = out.load()
    inv255 = strength / 255.0
    for y in range(h):
        yp = y + 1
        for x in range(w):
            xp = x + 1
            tl = px[xp - 1, yp - 1]
            tc = px[xp, yp - 1]
            tr = px[xp + 1, yp - 1]
            ml = px[xp - 1, yp]
            mr = px[xp + 1, yp]
            bl = px[xp - 1, yp + 1]
            bc = px[xp, yp + 1]
            br = px[xp + 1, yp + 1]

            dx = ((tr + 2 * mr + br) - (tl + 2 * ml + bl)) * 0.125 * inv255
            dy = ((bl + 2 * bc + br) - (tl + 2 * tc + tr)) * 0.125 * inv255

            nx = -dx
            ny = dy
            nz = 1.0
            inv_len = 1.0 / math.sqrt(nx * nx + ny * ny + nz * nz)
            opx[x, y] = (
                max(0, min(255, int((nx * inv_len * 0.5 + 0.5) * 255.0 + 0.5))),
                max(0, min(255, int((ny * inv_len * 0.5 + 0.5) * 255.0 + 0.5))),
                max(0, min(255, int((nz * inv_len * 0.5 + 0.5) * 255.0 + 0.5))),
            )
    return out


def save_tex_and_normal(name: str, img: Image.Image, normal_strength: float = 2.6, out_dir: str = TEX_DIR) -> None:
    rgb = img.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    rgb.save(os.path.join(out_dir, f"{name}.png"), optimize=True)
    nrm = generate_sobel_normal_map(rgb, strength=normal_strength)
    nrm.save(os.path.join(out_dir, f"{name}_normal.png"), optimize=True)
    print(f"Saved {name}.png + _normal.png ({rgb.size[0]}x{rgb.size[1]})")


def overlay_high_frequency_detail(base_rgb: Image.Image, detail_src: Image.Image, strength: float = 0.28) -> Image.Image:
    """Keeps base macro motif while injecting crisp 1024px high-frequency brush/stone grain."""
    base = base_rgb.convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    det = detail_src.convert("L").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    blurred = det.filter(ImageFilter.GaussianBlur(10))
    bpx = base.load()
    dpx = det.load()
    lpx = blurred.load()
    out = Image.new("RGB", (SIZE, SIZE))
    opx = out.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b = bpx[x, y]
            hf = (dpx[x, y] - lpx[x, y]) * strength
            opx[x, y] = (
                max(0, min(255, int(r + hf))),
                max(0, min(255, int(g + hf))),
                max(0, min(255, int(b + hf))),
            )
    return out


def build_mountain_forest() -> Image.Image:
    """Replaces blurry macro-tree tile with crisp fine-scale forested strata & dark granite crags."""
    boulder = Image.open(os.path.join(MJ_DIR, "tex_mossy_boulder_mj.png")).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    strata = Image.open(os.path.join(MJ_DIR, "tex_mossy_rock_strata_mj.png")).convert("RGB").resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    # Tile the boulder & strata at 2x2 for fine distant scale without macro features
    fine_rock = Image.new("RGB", (SIZE, SIZE))
    half = SIZE // 2
    b_half = boulder.resize((half, half), Image.Resampling.LANCZOS)
    s_half = strata.resize((half, half), Image.Resampling.LANCZOS)
    tile = Image.blend(b_half, s_half, 0.45)
    for oy in (0, half):
        for ox in (0, half):
            fine_rock.paste(tile, (ox, oy))

    # Cool forested charcoal-pine & slate-granite grading + organic cedar-canopy stipple
    fine_rock = ImageEnhance.Color(fine_rock).enhance(0.62)
    fine_rock = ImageEnhance.Contrast(fine_rock).enhance(1.12)
    stipple = Image.new("RGB", (SIZE, SIZE), (38, 52, 42))
    draw = ImageDraw.Draw(stipple)
    rng = random.Random(4217)
    palette = [
        (26, 40, 34),
        (34, 52, 40),
        (46, 62, 44),
        (28, 38, 44),
        (56, 46, 36),
        (68, 44, 32),
    ]
    for _ in range(9500):
        cx = rng.randrange(0, SIZE)
        cy = rng.randrange(0, SIZE)
        rx = rng.randint(4, 13)
        ry = rng.randint(3, 10)
        col = palette[rng.randrange(len(palette))]
        for ox in (-SIZE, 0, SIZE):
            for oy in (-SIZE, 0, SIZE):
                if -20 <= cx + ox <= SIZE + 20 and -20 <= cy + oy <= SIZE + 20:
                    draw.ellipse((cx + ox - rx, cy + oy - ry, cx + ox + rx, cy + oy + ry), fill=col)

    stipple = stipple.filter(ImageFilter.GaussianBlur(0.8))
    return Image.blend(fine_rock, stipple, 0.56)


def build_shoji_kumiko() -> None:
    """Builds 1024x1024 dark cedar kumiko lattice + warm paper albedo & paper-only emissive."""
    albedo = Image.new("RGB", (SIZE, SIZE), (242, 224, 186))
    emissive = Image.new("RGB", (SIZE, SIZE), (0, 0, 0))
    rng = random.Random(901)

    apx = albedo.load()
    epx = emissive.load()

    # Subtle hand-made kozo paper fiber tint across base paper
    for y in range(SIZE):
        vy = abs((y / SIZE) - 0.5) * 2.0
        for x in range(SIZE):
            vx = abs((x / SIZE) - 0.5) * 2.0
            fiber = ((math.sin(x * 0.21 + y * 0.05) + math.cos(y * 0.27 - x * 0.04)) * 4.5) + (rng.random() - 0.5) * 6.0
            r = max(180, min(255, int(238 + fiber - vx * 12 - vy * 14)))
            g = max(160, min(248, int(218 + fiber * 0.9 - vx * 14 - vy * 18)))
            b = max(120, min(220, int(174 + fiber * 0.8 - vx * 18 - vy * 22)))
            apx[x, y] = (r, g, b)

    # Outer cedar stile frame + 6 cols x 8 rows delicate kumiko mullions
    cols = 6
    rows = 8
    frame_w = 56
    bar_half = 8
    dark_cedar = (42, 26, 17)
    cedar_edge = (64, 42, 27)

    # Fill paper panes in emissive first (leaving outer frame & bars pure 0)
    draw_e = ImageDraw.Draw(emissive)
    cell_w = (SIZE - 2 * frame_w) / cols
    cell_h = (SIZE - 2 * frame_w) / rows
    for row in range(rows):
        for col in range(cols):
            x0 = int(frame_w + col * cell_w + bar_half)
            y0 = int(frame_w + row * cell_h + bar_half)
            x1 = int(frame_w + (col + 1) * cell_w - bar_half)
            y1 = int(frame_w + (row + 1) * cell_h - bar_half)
            cx = 0.5 * (x0 + x1)
            cy = 0.5 * (y0 + y1)
            max_r = max(1.0, math.hypot(x1 - cx, y1 - cy))
            # Soft warm gradient inside each paper pane; upper panes slightly softer than hearth bottom
            row_warm = 0.86 + 0.14 * (row / max(1, rows - 1))
            for py in range(max(0, y0), min(SIZE, y1)):
                for px in range(max(0, x0), min(SIZE, x1)):
                    d = min(1.0, math.hypot(px - cx, py - cy) / max_r)
                    falloff = (1.0 - 0.34 * (d * d)) * row_warm
                    epx[px, py] = (
                        int(248 * falloff),
                        int(176 * falloff),
                        int(88 * falloff),
                    )
            draw_e.rectangle((x0 - 2, y0 - 2, x1 + 2, y1 + 2), outline=(92, 60, 28), width=2)

    draw_a = ImageDraw.Draw(albedo)
    # Draw outer cedar frame & mullions on albedo
    draw_a.rectangle((0, 0, SIZE - 1, frame_w), fill=dark_cedar)
    draw_a.rectangle((0, SIZE - frame_w, SIZE - 1, SIZE - 1), fill=dark_cedar)
    draw_a.rectangle((0, 0, frame_w, SIZE - 1), fill=dark_cedar)
    draw_a.rectangle((SIZE - frame_w, 0, SIZE - 1, SIZE - 1), fill=dark_cedar)
    draw_a.rectangle((frame_w, frame_w, SIZE - frame_w, SIZE - frame_w), outline=cedar_edge, width=4)

    for col in range(1, cols):
        mx = int(frame_w + col * cell_w)
        draw_a.rectangle((mx - bar_half, frame_w, mx + bar_half, SIZE - frame_w), fill=dark_cedar)
    for row in range(1, rows):
        my = int(frame_w + row * cell_h)
        draw_a.rectangle((frame_w, my - bar_half, SIZE - frame_w, my + bar_half), fill=dark_cedar)

    # Clear bar bands strictly to black in emissive so kumiko grid reads razor sharp
    for col in range(1, cols):
        mx = int(frame_w + col * cell_w)
        draw_e.rectangle((mx - bar_half, 0, mx + bar_half, SIZE), fill=(0, 0, 0))
    for row in range(1, rows):
        my = int(frame_w + row * cell_h)
        draw_e.rectangle((0, my - bar_half, SIZE, my + bar_half), fill=(0, 0, 0))

    albedo.save(os.path.join(GEN_DIR, "shoji_kumiko_albedo.png"), optimize=True)
    emissive.save(os.path.join(GEN_DIR, "shoji_kumiko_emissive.png"), optimize=True)
    print("Saved shoji_kumiko_albedo.png + shoji_kumiko_emissive.png (1024x1024)")


def dilate_rgb_into_transparent(rgba: Image.Image, radius: int = 20) -> Image.Image:
    """Alpha-bleeds core opaque leaf colors outward over edge & alpha==0 pixels to kill halos."""
    rgb = rgba.convert("RGB")
    alpha = rgba.split()[3]
    # Seed dilation ONLY from solid interior leaf pixels (a >= 210) so semi-transparent white fringe is replaced!
    valid = alpha.point(lambda a: 255 if a >= 210 else 0)
    # Neutralize weak corner noise before clamping alpha
    clean_alpha = alpha.point(lambda a: 0 if a < 42 else a)
    offsets = [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)]
    for _ in range(radius):
        inv_valid = ImageChops.invert(valid)
        if not inv_valid.getbbox():
            break
        for dx, dy in offsets:
            shifted_v = ImageChops.offset(valid, dx, dy)
            mask_fill = ImageChops.multiply(shifted_v, inv_valid)
            shifted_rgb = ImageChops.offset(rgb, dx, dy)
            rgb.paste(shifted_rgb, (0, 0), mask_fill)
            valid = ImageChops.lighter(valid, shifted_v)
            inv_valid = ImageChops.invert(valid)
    r, g, b = rgb.split()
    return Image.merge("RGBA", (r, g, b, clean_alpha))


def clean_foliage_sprite(name: str, strip_white_halos: bool = False) -> None:
    path = os.path.join(TEX_DIR, f"{name}.png")
    src = Image.open(path).convert("RGBA").resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    r, g, b, a = src.split()

    if strip_white_halos:
        # Remove neutral white/silver paper gaps & perimeter boxes thoroughly
        px = src.load()
        ax = a.load()
        for y in range(SIZE):
            for x in range(SIZE):
                rv, gv, bv, av = px[x, y]
                if av < 42:
                    ax[x, y] = 0
                    continue
                hi = max(rv, gv, bv)
                lo = min(rv, gv, bv)
                chroma = hi - lo
                if name == "foliage_pine":
                    # Pine needles always have strong blue absorption vs pale white gaps
                    if (bv > 108 and (gv - bv) < 48) or (lo > 125 and chroma < 46):
                        ax[x, y] = 0
                else:
                    if lo > 168 and chroma < 42:
                        ax[x, y] = 0
        a = a.filter(ImageFilter.MinFilter(3))

    # Clear outermost 2.5% perimeter strictly before fitting into 86% center
    draw_a = ImageDraw.Draw(a)
    m = max(12, SIZE // 40)
    draw_a.rectangle((0, 0, SIZE, m), fill=0)
    draw_a.rectangle((0, SIZE - m, SIZE, SIZE), fill=0)
    draw_a.rectangle((0, 0, m, SIZE), fill=0)
    draw_a.rectangle((SIZE - m, 0, SIZE, SIZE), fill=0)
    src = Image.merge("RGBA", (r, g, b, a))

    inner = int(SIZE * 0.86)
    pad = (SIZE - inner) // 2
    padded = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    scaled = src.resize((inner, inner), Image.Resampling.LANCZOS)
    padded.paste(scaled, (pad, pad))

    cleaned = dilate_rgb_into_transparent(padded, radius=24)
    cleaned.save(path, optimize=True)
    print(f"Cleaned foliage sprite {name}.png (1024x1024, padded & RGB-dilated)")


def main() -> None:
    print("Upgrading Kage no Machi textures to 1024x1024...")

    # 1. Ground Earth (warm muted Edo packed ochre earth + pebbles from clean MJ tile)
    earth_mj = Image.open(os.path.join(MJ_DIR, "tex_earth_pebbles_mj.png")).convert("RGB")
    earth_grade = ImageEnhance.Color(earth_mj).enhance(0.86)
    earth_grade = ImageEnhance.Brightness(earth_grade).enhance(0.88)
    save_tex_and_normal("kaido_earth", earth_grade, normal_strength=2.5)

    # 2. Edo Cobblestone (crisp weathered flagstones & river cobble from clean MJ tile)
    cobble_mj = Image.open(os.path.join(MJ_DIR, "tex_cobblestone_mj.png")).convert("RGB")
    cobble_grade = ImageEnhance.Brightness(cobble_mj).enhance(0.92)
    save_tex_and_normal("cobblestone_edo", cobble_grade, normal_strength=3.0)

    # 3. Masonry Retaining Wall Stone & Castle Ashlar (1024px + high-freq stone chisel grain)
    rock_strata_mj = Image.open(os.path.join(MJ_DIR, "tex_mossy_rock_strata_mj.png")).convert("RGB")
    boulder_mj = Image.open(os.path.join(MJ_DIR, "tex_mossy_boulder_mj.png")).convert("RGB")

    ishigaki_src = Image.open(os.path.join(TEX_DIR, "ishigaki_stone.png"))
    save_tex_and_normal("ishigaki_stone", overlay_high_frequency_detail(ishigaki_src, rock_strata_mj, 0.25), normal_strength=3.0)

    castle_src = Image.open(os.path.join(TEX_DIR, "castle_ishigaki.png"))
    save_tex_and_normal("castle_ishigaki", overlay_high_frequency_detail(castle_src, boulder_mj, 0.22), normal_strength=2.9)

    # 4. Sculpted Cliff / Coastal Rock texture (used by Blender cliff/boulder/headland GLBs)
    cliff_mix = Image.blend(
        boulder_mj.resize((SIZE, SIZE), Image.Resampling.LANCZOS),
        rock_strata_mj.resize((SIZE, SIZE), Image.Resampling.LANCZOS),
        0.42,
    )
    save_tex_and_normal("cliff_rock", cliff_mix, normal_strength=3.2, out_dir=GEN_DIR)

    # 5. Upscale remaining surfaces to crisp 1024px with subtle directional grain
    for name, strength in [
        ("meadow_moss", 2.1),
        ("cedar_timber", 2.8),
        ("harbor_planks", 2.8),
        ("kawara_tile", 3.2),
        ("kayabuki_thatch", 2.9),
        ("shikkui_plaster", 1.7),
    ]:
        src = Image.open(os.path.join(TEX_DIR, f"{name}.png")).convert("RGB")
        # Apply gentle sharpening after upscale so 512->1024 has crisp brushstroke bite
        up = src.resize((SIZE, SIZE), Image.Resampling.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.5, percent=65, threshold=2))
        save_tex_and_normal(name, up, normal_strength=strength)

    # 6. Replace coarse macro-tree mountain texture with fine-scale craggy ridge & stipple canopy
    save_tex_and_normal("mountain_forest", build_mountain_forest(), normal_strength=2.4)

    # 7. Crisp dark-cedar shoji kumiko lattice + paper glow textures
    build_shoji_kumiko()

    # 8. Foliage sprite cleanup (remove white interior halos, pad margins 6%, RGB bleed)
    clean_foliage_sprite("foliage_pine", strip_white_halos=True)
    clean_foliage_sprite("foliage_willow", strip_white_halos=True)
    clean_foliage_sprite("foliage_maple", strip_white_halos=True)
    clean_foliage_sprite("foliage_maple_gold", strip_white_halos=True)
    clean_foliage_sprite("foliage_bamboo", strip_white_halos=True)

    print("Texture upgrade complete!")


if __name__ == "__main__":
    main()
