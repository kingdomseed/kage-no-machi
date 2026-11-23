"""Minato-jo curved oginokobai ishigaki walls, sengokubune ships, boats, crane & castle shoji patch."""

from __future__ import annotations

import math
import os

import bmesh
import bpy
from mathutils import Vector

from common import (
    MODELS_DIR,
    add_cambered_beam,
    add_game_box,
    add_game_cylinder,
    add_swept_tube,
    clear_scene,
    export_glb,
    finalize_mesh,
    g2b,
    get_materials,
    load_image,
    set_face_uv_quad,
)


def _kobai_curve(t: float) -> float:
    """Classic Edo oginokobai concave fan slope: t=0 base toe -> t=1 top crest."""
    return (1.0 - t) ** 1.75


def build_castle_ishigaki_wall() -> None:
    """Drop-in replacement matching [-6.02, 6.02] x [-3.40, 6.56] x [-2.75, 2.75]."""
    clear_scene()
    mats = get_materials()
    bm = bmesh.new()

    hx = 6.02
    y_bot = -3.40
    y_top = 6.56
    z_top_half = 1.15
    z_bot_half = 2.75
    v_segs = 12
    x_segs = 8

    # Loft continuous concave battered cross-section rings from base to top crest
    rings: list[list[bmesh.types.BMVert]] = []
    for vi in range(v_segs + 1):
        t = vi / v_segs
        y = y_bot + (y_top - y_bot) * t
        hz = z_top_half + (z_bot_half - z_top_half) * _kobai_curve(t)
        ring: list[bmesh.types.BMVert] = []
        # Walk perimeter CCW around rectangle (front +Z -> right +X -> back -Z -> left -X)
        # Front edge -hx -> +hx at +hz
        for xi in range(x_segs):
            u = xi / x_segs
            x = -hx + 2.0 * hx * u
            # Subtle organic masonry course bulge on lower courses
            wobble = 0.035 * math.sin(t * 7.0 + u * 9.0) * (1.0 - t * 0.5)
            ring.append(bm.verts.new(g2b(x, y, hz + wobble)))
        # Right edge +hx from +hz -> -hz (single span or 4 substeps)
        for zi in range(4):
            u = zi / 4.0
            ring.append(bm.verts.new(g2b(hx, y, hz * (1.0 - 2.0 * u))))
        # Back edge +hx -> -hx at -hz
        for xi in range(x_segs):
            u = xi / x_segs
            x = hx - 2.0 * hx * u
            wobble = 0.035 * math.cos(t * 7.0 + u * 8.0) * (1.0 - t * 0.5)
            ring.append(bm.verts.new(g2b(x, y, -hz - wobble)))
        # Left edge -hx from -hz -> +hz
        for zi in range(4):
            u = zi / 4.0
            ring.append(bm.verts.new(g2b(-hx, y, -hz * (1.0 - 2.0 * u))))
        rings.append(ring)

    n_ring = len(rings[0])
    for vi in range(v_segs):
        r0, r1 = rings[vi], rings[vi + 1]
        for s in range(n_ring):
            sn = (s + 1) % n_ring
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    # Top plateau & bottom cap
    bm.faces.new(rings[-1])
    bm.faces.new(list(reversed(rings[0])))

    finalize_mesh("ishigaki_wall_castle_stone", bm, mats["CastleIshigaki"], smooth=True, box_uv_scale=0.35)
    export_glb("castle_ishigaki_wall.glb")


def build_castle_ishigaki_corner() -> None:
    """Drop-in replacement matching [-4.05, 4.05] x [-3.40, 6.56] x [-4.05, 4.05]."""
    clear_scene()
    mats = get_materials()
    bm = bmesh.new()

    y_bot = -3.40
    y_top = 6.56
    h_top = 2.15
    h_bot = 4.05
    v_segs = 12
    sub_side = 5

    rings: list[list[bmesh.types.BMVert]] = []
    for vi in range(v_segs + 1):
        t = vi / v_segs
        y = y_bot + (y_top - y_bot) * t
        h = h_top + (h_bot - h_top) * _kobai_curve(t)
        # Round outer chamfer slightly so corner pier has organic chamfered sangizumi ribs
        cham = 0.24 * _kobai_curve(t) + 0.08
        ring: list[bmesh.types.BMVert] = []
        corners = [(h, h), (-h, h), (-h, -h), (h, -h)]
        # Walk CCW in game XZ (+Z -> -X -> -Z -> +X edges) -> use (-h,+h)->(+h,+h)->(+h,-h)->(-h,-h)
        edges_pts = [
            ((-h + cham, h), (h - cham, h)),
            ((h, h - cham), (h, -h + cham)),
            ((h - cham, -h), (-h + cham, -h)),
            ((-h, -h + cham), (-h, h - cham)),
        ]
        for (x0, z0), (x1, z1) in edges_pts:
            for k in range(sub_side):
                u = k / sub_side
                px = x0 + (x1 - x0) * u
                pz = z0 + (z1 - z0) * u
                ring.append(bm.verts.new(g2b(px, y, pz)))
        rings.append(ring)

    n_ring = len(rings[0])
    for vi in range(v_segs):
        r0, r1 = rings[vi], rings[vi + 1]
        for s in range(n_ring):
            sn = (s + 1) % n_ring
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    bm.faces.new(rings[-1])
    bm.faces.new(list(reversed(rings[0])))

    finalize_mesh("ishigaki_corner_castle_stone", bm, mats["CastleIshigaki"], smooth=True, box_uv_scale=0.35)
    export_glb("castle_ishigaki_corner.glb")


def _add_lofted_hull(
    bm_hull: bmesh.types.BMesh,
    bm_deck: bmesh.types.BMesh,
    *,
    z_min: float,
    z_max: float,
    max_half_w: float,
    keel_y: float,
    deck_y: float,
    sheer_lift: float,
    stations: int,
    transom_w: float = 0.45,
) -> None:
    """Lofts a smooth curved double-ended / transom Edo wooden ship hull + curved planked deck."""
    prof_pts = 9  # cross-section port gunwale -> keel -> starboard gunwale
    hull_rings: list[list[bmesh.types.BMVert]] = []
    deck_left: list[bmesh.types.BMVert] = []
    deck_right: list[bmesh.types.BMVert] = []

    for si in range(stations + 1):
        t = si / stations  # 0 stern (-Z) -> 1 bow (+Z)
        z = z_min + (z_max - z_min) * t
        # Beam width curve: sleek tapered bow, proud wider mid-body, semi-square Edo stern transom
        if t < 0.72:
            beam_t = transom_w + (1.0 - transom_w) * math.sin((t / 0.72) * math.pi * 0.5)
        else:
            bt = (t - 0.72) / 0.28
            beam_t = math.cos(bt * math.pi * 0.5) ** 0.85
        hw = max(0.05, max_half_w * beam_t)
        # Elegant rising sheer toward stern & prow
        sheer = sheer_lift * ((t - 0.42) * 1.9) ** 2
        gunwale_y = deck_y + 0.36 + sheer
        dk_y = deck_y + sheer * 0.65
        local_keel = keel_y + sheer * 0.25 + (0.35 * ((1.0 - beam_t) ** 1.6))

        ring: list[bmesh.types.BMVert] = []
        for pi in range(prof_pts):
            u = (pi / (prof_pts - 1)) * 2.0 - 1.0  # -1 (port) .. 0 (keel) .. +1 (starboard)
            abs_u = abs(u)
            # Flared curved hull cross-section
            px = math.copysign(hw * (abs_u ** 0.58), u)
            py = local_keel + (gunwale_y - local_keel) * (abs_u ** 1.35)
            ring.append(bm_hull.verts.new(g2b(px, py, z)))
        hull_rings.append(ring)

        # Deck strips slightly recessed inside gunwales
        deck_left.append(bm_deck.verts.new(g2b(-hw * 0.90, dk_y, z)))
        deck_right.append(bm_deck.verts.new(g2b(hw * 0.90, dk_y, z)))

    for si in range(stations):
        r0, r1 = hull_rings[si], hull_rings[si + 1]
        for pi in range(prof_pts - 1):
            bm_hull.faces.new((r0[pi], r1[pi], r1[pi + 1], r0[pi + 1]))
        # Deck strip faces
        bm_deck.faces.new((deck_left[si], deck_right[si], deck_right[si + 1], deck_left[si + 1]))
    # Close transom & inner bulwark top edges on hull
    bm_hull.faces.new(hull_rings[0])


def _add_curved_sail_with_ribs(
    bm_sail: bmesh.types.BMesh,
    bm_ribs: bmesh.types.BMesh,
    cx: float,
    y_bot: float,
    y_top: float,
    cz: float,
    width: float,
    belly: float,
    rib_count: int = 8,
) -> None:
    """Adds a deeply billowed 16x12 curved Edo square sail with proud horizontal bamboo battens."""
    rows = 12
    cols = 16
    grid: list[list[bmesh.types.BMVert]] = []
    uv_layer = bm_sail.loops.layers.uv.verify()

    for r in range(rows + 1):
        v = r / rows  # 0 bottom -> 1 yardarm top
        y = y_bot + (y_top - y_bot) * v
        # Slight upward camber at yardarm & foot, narrow slightly at top yard
        taper = 0.86 + 0.14 * (1.0 - v * 0.65)
        w = width * taper
        billow_v = math.sin(v * math.pi)
        row_v: list[bmesh.types.BMVert] = []
        for c in range(cols + 1):
            u = (c / cols) * 2.0 - 1.0  # -1..+1
            x = cx + u * w * 0.5
            # Deep organic wind-billowed curvature bulging toward +Z
            billow = belly * billow_v * (0.28 + 0.72 * math.cos(u * math.pi * 0.5))
            # Subtle horizontal pleating ripples between bamboo battens
            pleat = 0.045 * abs(math.sin(v * rib_count * math.pi)) * billow_v
            z = cz + billow + pleat
            row_v.append(bm_sail.verts.new(g2b(x, y, z)))
        grid.append(row_v)

    for r in range(rows):
        for c in range(cols):
            f = bm_sail.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
            set_face_uv_quad(f, uv_layer, c / cols, r / rows, (c + 1) / cols, (r + 1) / rows)

    # Proud horizontal bamboo batten ribs along front curve of sail
    for ri in range(rib_count):
        v = (ri + 0.5) / rib_count
        y = y_bot + (y_top - y_bot) * v
        taper = 0.86 + 0.14 * (1.0 - v * 0.65)
        w = width * taper * 1.02
        billow_v = math.sin(v * math.pi)
        pts = []
        radii = []
        for c in range(9):
            u = (c / 8.0) * 2.0 - 1.0
            x = cx + u * w * 0.5
            z = cz + belly * billow_v * (0.28 + 0.72 * math.cos(u * math.pi * 0.5)) + 0.032
            pts.append((x, y, z))
            radii.append(0.026)
        add_swept_tube(bm_ribs, pts, radii, segments=6)


def build_ship_sengokubune() -> None:
    """High-craft curved Edo coastal transport/warship matching [-2.6, 2.6] x [-1.12, 12.6] x [-7.85, 9.64]."""
    clear_scene()
    mats = get_materials()

    bm_cedar = bmesh.new()
    bm_charred = bmesh.new()
    bm_planks = bmesh.new()
    bm_sail = bmesh.new()
    bm_rope = bmesh.new()
    bm_gold = bmesh.new()
    bm_iron = bmesh.new()
    bm_shoji = bmesh.new()
    bm_lantern = bmesh.new()
    bm_vermilion = bmesh.new()

    _add_lofted_hull(
        bm_cedar, bm_planks,
        z_min=-7.20, z_max=8.25, max_half_w=2.42,
        keel_y=-1.05, deck_y=0.95, sheer_lift=0.68, stations=24, transom_w=0.46,
    )

    # Bowstem timber dragon prow extending smoothly toward +Z
    add_swept_tube(bm_charred, [(0.0, 0.2, 7.6), (0.0, 1.35, 8.65), (0.0, 2.35, 9.52)], [0.22, 0.17, 0.11], segments=10)
    add_game_box(bm_gold, 0.0, 2.42, 9.55, 0.20, 0.20, 0.22, bevel=0.02)

    # Stern yakata captain's deckhouse & vermilion balustrade
    add_game_box(bm_charred, 0.0, 2.15, -4.60, 2.60, 1.85, 3.85, bevel=0.03)
    add_game_box(bm_vermilion, 0.0, 3.12, -4.60, 3.15, 0.16, 4.25, bevel=0.025)
    # Crisp kumiko shoji cabin windows (soft glow via emissive map)
    uv_layer = bm_shoji.loops.layers.uv.verify()
    for sx in (-1.42, 1.42):
        for wz in (-5.65, -4.55, -3.45):
            # Side cabin windows facing outward +-X
            hw, hh = 0.42, 0.56
            if sx > 0:
                pts = [(sx, 2.15 - hh, wz + hw), (sx, 2.15 - hh, wz - hw), (sx, 2.15 + hh, wz - hw), (sx, 2.15 + hh, wz + hw)]
            else:
                pts = [(sx, 2.15 - hh, wz - hw), (sx, 2.15 - hh, wz + hw), (sx, 2.15 + hh, wz + hw), (sx, 2.15 + hh, wz - hw)]
            f = bm_shoji.faces.new([bm_shoji.verts.new(g2b(*p)) for p in pts])
            set_face_uv_quad(f, uv_layer, 0.0, 0.0, 1.0, 1.0)

    # Foremast & tall mainmast + yards
    add_game_cylinder(bm_charred, 0.0, 0.95, 0.45, 0.22, 0.12, 11.45, segments=14)
    add_game_cylinder(bm_charred, 0.0, 1.15, 4.75, 0.17, 0.10, 8.20, segments=12)
    # Main yardarm & fore yardarm
    add_cambered_beam(bm_cedar, (-2.52, 11.15, 0.65), (2.52, 11.15, 0.65), -0.18, half_width=0.08, half_thick=0.08, segments=12)
    add_cambered_beam(bm_cedar, (-1.92, 8.45, 4.92), (1.92, 8.45, 4.92), -0.14, half_width=0.07, half_thick=0.07, segments=12)

    # Billowing multi-segment bamboo-ribbed sails
    _add_curved_sail_with_ribs(bm_sail, bm_charred, 0.0, 3.25, 11.05, 0.72, 4.72, belly=0.92, rib_count=8)
    _add_curved_sail_with_ribs(bm_sail, bm_charred, 0.0, 2.85, 8.38, 4.96, 3.55, belly=0.72, rib_count=6)

    # Hemp standing shrouds & stays (sturdy cables terminated strictly outside mast surfaces)
    for sx in (-2.15, 2.15):
        for sz in (-0.35, 1.25):
            add_swept_tube(bm_rope, [(sx, 1.38, sz), (sx * 0.14, 11.55, 0.45)], [0.072, 0.064], segments=6)
    add_swept_tube(bm_rope, [(0.0, 2.40, 9.40), (0.0, 8.85, 4.98)], [0.074, 0.068], segments=6)
    add_swept_tube(bm_rope, [(0.0, 8.85, 4.52), (0.0, 11.85, 0.68)], [0.074, 0.068], segments=6)
    add_swept_tube(bm_rope, [(0.0, 11.85, 0.22), (0.0, 3.15, -6.20)], [0.074, 0.068], segments=6)

    # Stern & bow lanterns + anchor iron hooks
    for sx in (-1.42, 1.42):
        ret = bmesh.ops.create_uvsphere(bm_lantern, u_segments=12, v_segments=8, radius=0.14)
        for v in ret["verts"]:
            v.co = g2b(sx + v.co.x, 3.38 + v.co.z, -2.55 - v.co.y)
    add_game_box(bm_iron, 2.25, 1.15, 6.20, 0.18, 0.48, 0.42, bevel=0.02)

    finalize_mesh("ship_cedar", bm_cedar, mats["CedarTimber"], smooth=True, box_uv_scale=0.40)
    finalize_mesh("ship_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("ship_planks", bm_planks, mats["HarborPlanks"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("ship_sails", bm_sail, mats["SailCanvas"], smooth=True, box_uv_scale=None)
    finalize_mesh("ship_rope", bm_rope, mats["HempRope"], smooth=True, box_uv_scale=0.8)
    finalize_mesh("ship_gold", bm_gold, mats["GoldTrim"], smooth=True, box_uv_scale=0.8)
    finalize_mesh("ship_iron", bm_iron, mats["DarkIron"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("ship_shoji", bm_shoji, mats["ShojiGlow"], smooth=False, box_uv_scale=None)
    finalize_mesh("ship_chochin_glow", bm_lantern, mats["ChochinGlow"], smooth=True, box_uv_scale=0.5)
    finalize_mesh("ship_vermilion", bm_vermilion, mats["VermilionLacquer"], smooth=True, box_uv_scale=0.5)
    export_glb("ship_sengokubune.glb")


def build_boat_wasen() -> None:
    """Smooth curved traditional wooden wasen skiff matching [-0.74, 0.74] x [-0.22, 1.35] x [-2.66, 2.74]."""
    clear_scene()
    mats = get_materials()
    bm_cedar = bmesh.new()
    bm_charred = bmesh.new()
    bm_lantern = bmesh.new()
    bm_iron = bmesh.new()

    _add_lofted_hull(
        bm_cedar, bm_charred,
        z_min=-2.55, z_max=2.62, max_half_w=0.72,
        keel_y=-0.20, deck_y=0.14, sheer_lift=0.22, stations=16, transom_w=0.38,
    )
    # Thwart benches & sculling oar (ro)
    for tz in (-1.15, 0.05, 1.25):
        add_game_box(bm_cedar, 0.0, 0.24, tz, 1.02, 0.06, 0.26, bevel=0.01)
    add_swept_tube(bm_charred, [(0.18, 0.34, -2.50), (0.04, 0.26, 0.15)], [0.032, 0.024], segments=8)
    # Lantern pole at bow
    add_game_cylinder(bm_charred, 0.0, 0.25, 2.28, 0.025, 0.020, 1.02, segments=8)
    ret = bmesh.ops.create_uvsphere(bm_lantern, u_segments=12, v_segments=8, radius=0.11)
    for v in ret["verts"]:
        v.co = g2b(v.co.x, 1.15 + v.co.z, 2.40 - v.co.y)
    add_game_cylinder(bm_iron, 0.0, 1.24, 2.40, 0.07, 0.05, 0.04, segments=10)

    finalize_mesh("wasen_cedar", bm_cedar, mats["CedarTimber"], smooth=True, box_uv_scale=0.55)
    finalize_mesh("wasen_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.55)
    finalize_mesh("wasen_chochin_glow", bm_lantern, mats["ChochinGlow"], smooth=True, box_uv_scale=0.5)
    finalize_mesh("wasen_dark_iron", bm_iron, mats["DarkIron"], smooth=True, box_uv_scale=0.6)
    export_glb("boat_wasen.glb")


def build_harbor_crane() -> None:
    """Edo A-frame timber dock cargo crane with jib boom, windlass barrel & hanging crate."""
    clear_scene()
    mats = get_materials()
    bm_charred = bmesh.new()
    bm_cedar = bmesh.new()
    bm_rope = bmesh.new()
    bm_iron = bmesh.new()

    # Heavy timber sill X-base anchored solidly below dock deck (y = -0.10..0.12)
    add_game_box(bm_charred, 0.0, 0.06, 0.0, 2.15, 0.22, 0.28, bevel=0.02)
    add_game_box(bm_charred, 0.0, 0.06, 0.0, 0.28, 0.22, 2.15, bevel=0.02)
    # Vertical king-post + angled twin A-frame struts meeting at top pivot (y=3.15)
    add_game_cylinder(bm_charred, 0.0, 0.14, 0.0, 0.14, 0.11, 3.25, segments=12)
    for sx in (-0.82, 0.82):
        add_swept_tube(bm_charred, [(sx, 0.12, -0.58), (0.0, 3.05, 0.0)], [0.09, 0.075], segments=8)
    # Diagonal jib boom reaching outward over +Z (waterfront side) to (0.0, 4.35, 2.65)
    add_swept_tube(bm_cedar, [(0.0, 0.85, -0.05), (0.0, 4.35, 2.65)], [0.11, 0.075], segments=10)
    # Windlass drum & spokes
    drum_pts = [(-0.55, 1.05, -0.35), (0.55, 1.05, -0.35)]
    add_swept_tube(bm_cedar, drum_pts, [0.16, 0.16], segments=14)
    add_game_box(bm_iron, 0.0, 3.05, 0.0, 0.26, 0.24, 0.24, bevel=0.02)
    # Taut hemp tackle line from king-post -> boom tip -> dangling suspended cargo crate
    add_swept_tube(bm_rope, [(0.0, 3.12, 0.0), (0.0, 4.35, 2.65), (0.0, 2.05, 2.65)], [0.028, 0.028, 0.024], segments=6)
    add_swept_tube(bm_rope, [(0.0, 1.15, -0.35), (0.0, 4.32, 2.62)], [0.024, 0.024], segments=6)
    add_game_box(bm_cedar, 0.0, 1.62, 2.65, 0.88, 0.78, 0.88, yaw=0.25, bevel=0.02)
    add_game_box(bm_iron, 0.0, 2.04, 2.65, 0.18, 0.14, 0.18, bevel=0.015)

    finalize_mesh("crane_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("crane_cedar", bm_cedar, mats["CedarTimber"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("crane_rope", bm_rope, mats["HempRope"], smooth=True, box_uv_scale=0.7)
    finalize_mesh("crane_iron", bm_iron, mats["DarkIron"], smooth=True, box_uv_scale=0.6)
    export_glb("harbor_crane.glb")


def patch_castle_shoji_materials() -> None:
    """Re-skins ShojiGlow in existing castle/lighthouse GLBs to dark-cedar kumiko lattice (0.85 strength)."""
    targets = [
        "castle_tenshukaku.glb",
        "castle_yagura.glb",
        "castle_otemon_gate.glb",
        "harbor_todai.glb",
    ]
    for fname in targets:
        path = os.path.join(MODELS_DIR, fname)
        if not os.path.exists(path):
            continue
        clear_scene()
        bpy.ops.import_scene.gltf(filepath=path)
        shoji_a = load_image("shoji_kumiko_albedo.png", "sRGB")
        shoji_e = load_image("shoji_kumiko_emissive.png", "sRGB")
        patched = False
        for mat in bpy.data.materials:
            if not mat.use_nodes:
                continue
            nt = mat.node_tree
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if not bsdf:
                continue
            if "ShojiGlow" in mat.name:
                nt.nodes.clear()
                out = nt.nodes.new("ShaderNodeOutputMaterial")
                new_bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
                new_bsdf.inputs["Roughness"].default_value = 0.85
                new_bsdf.inputs["Specular IOR Level"].default_value = 0.05
                new_bsdf.inputs["Emission Strength"].default_value = 0.85
                ta = nt.nodes.new("ShaderNodeTexImage")
                ta.image = shoji_a
                te = nt.nodes.new("ShaderNodeTexImage")
                te.image = shoji_e
                nt.links.new(ta.outputs["Color"], new_bsdf.inputs["Base Color"])
                nt.links.new(te.outputs["Color"], new_bsdf.inputs["Emission Color"])
                nt.links.new(new_bsdf.outputs["BSDF"], out.inputs["Surface"])
                patched = True
            elif "ChochinGlow" in mat.name or "BeaconGlow" in mat.name:
                bsdf.inputs["Emission Strength"].default_value = 2.6 if "Chochin" in mat.name else 3.2
                patched = True
        if patched:
            # Blender glTF importer creates an empty root armature/group wrapper if scaled cleanly; export_apply=True preserves transforms
            bpy.ops.export_scene.gltf(
                filepath=path,
                export_format="GLB",
                export_yup=True,
                export_apply=True,
                export_texcoords=True,
                export_normals=True,
                export_tangents=True,
                export_materials="EXPORT",
                export_vertex_color="ACTIVE",
                export_image_format="JPEG",
                export_jpeg_quality=90,
                use_selection=False,
            )
            print(f"Patched shoji/emissives in {fname}")


def build_all() -> None:
    build_castle_ishigaki_wall()
    build_castle_ishigaki_corner()
    build_ship_sengokubune()
    build_boat_wasen()
    build_harbor_crane()
    patch_castle_shoji_materials()


if __name__ == "__main__":
    build_all()
