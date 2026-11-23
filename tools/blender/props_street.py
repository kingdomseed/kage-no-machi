"""Edo street clutter props: covered wagon, wagasa tea bench, bamboo fence, andon & nobori."""

from __future__ import annotations

import math

import bmesh
from mathutils import Vector

from common import (
    add_cambered_beam,
    add_game_box,
    add_game_cylinder,
    add_swept_tube,
    clear_scene,
    export_glb,
    finalize_mesh,
    g2b,
    get_materials,
)


def build_edo_wagon() -> None:
    """Edo horse-drawn covered wooden transport wagon with arched hoop canopy & spoked wheels."""
    clear_scene()
    mats = get_materials()
    bm_cedar = bmesh.new()
    bm_charred = bmesh.new()
    bm_cloth = bmesh.new()
    bm_iron = bmesh.new()

    # Main bed deck & side slats (spanning along Z, front shafts toward +Z)
    add_game_box(bm_cedar, 0.0, 0.56, -0.05, 1.18, 0.10, 2.25, bevel=0.015)
    for sx in (-0.56, 0.56):
        add_game_box(bm_charred, sx, 0.78, -0.05, 0.06, 0.36, 2.20, bevel=0.01)
    # Front hitch shafts
    for sx in (-0.38, 0.38):
        add_swept_tube(bm_charred, [(sx, 0.52, 0.95), (sx * 0.92, 0.62, 2.25)], [0.045, 0.036], segments=8)
    add_game_box(bm_charred, 0.0, 0.62, 2.10, 0.78, 0.06, 0.07, bevel=0.01)

    # 4 spoked wooden wheels with iron rims
    for wx, wz, rad in ((-0.68, -0.75, 0.44), (0.68, -0.75, 0.44), (-0.66, 0.72, 0.36), (0.66, 0.72, 0.36)):
        # Axle
        if wx < 0:
            add_swept_tube(bm_iron, [(-0.74, rad, wz), (0.74, rad, wz)], [0.036, 0.036], segments=8)
        # Rim torus built from 20 smooth segments in YZ plane around wheel axle
        rim_pts = []
        for s in range(21):
            ang = (s / 20.0) * math.pi * 2.0
            rim_pts.append((wx, rad + math.sin(ang) * rad, wz + math.cos(ang) * rad))
        add_swept_tube(bm_charred, rim_pts, [0.038] * len(rim_pts), segments=8, cap_ends=False)
        # Iron tire outer band (offset +0.028m radially proud)
        tire_pts = [(wx, rad + math.sin(s / 20.0 * math.pi * 2.0) * (rad + 0.025), wz + math.cos(s / 20.0 * math.pi * 2.0) * (rad + 0.025)) for s in range(21)]
        add_swept_tube(bm_iron, tire_pts, [0.022] * len(tire_pts), segments=6, cap_ends=False)
        # 8 spokes
        for sp in range(8):
            ang = (sp / 8.0) * math.pi * 2.0
            add_swept_tube(bm_cedar, [(wx, rad, wz), (wx, rad + math.sin(ang) * (rad - 0.02), wz + math.cos(ang) * (rad - 0.02))], [0.022, 0.018], segments=6)

    # Arched canvas hoop cover (12 curved cross stations x 10 arch ribs)
    arch_rows = 8
    arch_cols = 12
    grid_out: list[list[bmesh.types.BMVert]] = []
    grid_in: list[list[bmesh.types.BMVert]] = []
    for ir in range(arch_rows + 1):
        v = ir / arch_rows
        z = -1.10 + v * 2.05
        sag = 0.03 * math.sin(v * math.pi * 3.0)
        row_o: list[bmesh.types.BMVert] = []
        row_i: list[bmesh.types.BMVert] = []
        for ic in range(arch_cols + 1):
            ang = math.pi * (ic / arch_cols)  # 0 (+X) -> pi (-X)
            rx = math.cos(ang) * 0.62
            ry = 0.88 + math.sin(ang) * (0.82 - sag)
            row_o.append(bm_cloth.verts.new(g2b(rx, ry, z)))
            row_i.append(bm_cloth.verts.new(g2b(rx * 0.94, max(0.88, ry - 0.04), z)))
        grid_out.append(row_o)
        grid_in.append(row_i)
    for ir in range(arch_rows):
        for ic in range(arch_cols):
            bm_cloth.faces.new((grid_out[ir][ic], grid_out[ir + 1][ic], grid_out[ir + 1][ic + 1], grid_out[ir][ic + 1]))
            bm_cloth.faces.new((grid_in[ir][ic + 1], grid_in[ir + 1][ic + 1], grid_in[ir + 1][ic], grid_in[ir][ic]))

    finalize_mesh("wagon_cedar", bm_cedar, mats["CedarTimber"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("wagon_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("wagon_cloth", bm_cloth, mats["ClothCream"], smooth=True, box_uv_scale=0.5)
    finalize_mesh("wagon_iron", bm_iron, mats["DarkIron"], smooth=True, box_uv_scale=0.8)
    export_glb("edo_wagon.glb")


def build_edo_wagasa_bench() -> None:
    """Vermilion silk wagasa tea parasol umbrella & cedar slatted bench with red cloth (like tactical_shukuba_1)."""
    clear_scene()
    mats = get_materials()
    bm_cedar = bmesh.new()
    bm_charred = bmesh.new()
    bm_cloth = bmesh.new()
    bm_bamboo = bmesh.new()

    # Slatted cedar bench
    add_game_box(bm_charred, -0.68, 0.22, 0.0, 0.10, 0.44, 0.48, bevel=0.01)
    add_game_box(bm_charred, 0.68, 0.22, 0.0, 0.10, 0.44, 0.48, bevel=0.01)
    add_game_box(bm_cedar, 0.0, 0.45, 0.0, 1.65, 0.07, 0.54, bevel=0.012)
    # Red mosen bench runner cloth proudly seated on top & overhanging front/back (>=0.045m clear!)
    add_game_box(bm_cloth, 0.0, 0.515, 0.0, 1.54, 0.06, 0.63, bevel=0.01)

    # Tall bamboo umbrella shaft offset slightly behind bench
    ux, uz = 0.42, -0.22
    add_game_cylinder(bm_bamboo, ux, 0.0, uz, 0.034, 0.026, 2.38, segments=10)

    # Smooth 24-ribbed arched Japanese wagasa parasol dome
    segs = 24
    rings = 5
    pole_top = (ux, 2.38, uz)
    rad = 1.24
    vert_rings: list[list[bmesh.types.BMVert]] = []
    apex = bm_cloth.verts.new(g2b(pole_top[0], pole_top[1] + 0.04, pole_top[2]))
    apex_in = bm_cloth.verts.new(g2b(pole_top[0], pole_top[1] - 0.01, pole_top[2]))
    for ri in range(1, rings + 1):
        f = ri / rings
        r = rad * f
        y = pole_top[1] - 0.34 * (f ** 1.25)
        ring: list[bmesh.types.BMVert] = []
        for s in range(segs):
            ang = (s / segs) * math.pi * 2.0
            # Subtle scalloped pleat between ribs
            pleat = 0.018 * abs(math.sin(s * 0.5 * math.pi)) * f
            ring.append(bm_cloth.verts.new(g2b(ux + math.cos(ang) * r, y + pleat, uz + math.sin(ang) * r)))
        vert_rings.append(ring)

    for s in range(segs):
        sn = (s + 1) % segs
        bm_cloth.faces.new((apex, vert_rings[0][s], vert_rings[0][sn]))
        for ri in range(rings - 1):
            bm_cloth.faces.new((vert_rings[ri][s], vert_rings[ri + 1][s], vert_rings[ri + 1][sn], vert_rings[ri][sn]))
    # Bottom ring ribs radiating from hub
    for s in range(0, segs, 2):
        ang = (s / segs) * math.pi * 2.0
        add_swept_tube(bm_charred, [(ux, 2.08, uz), (ux + math.cos(ang) * 0.92, 2.08, uz + math.sin(ang) * 0.92)], [0.012, 0.010], segments=5)

    finalize_mesh("wagasa_cedar", bm_cedar, mats["CedarTimber"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("wagasa_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("wagasa_cloth", bm_cloth, mats["ClothCrimson"], smooth=True, box_uv_scale=0.5)
    finalize_mesh("wagasa_pole", bm_bamboo, mats["BambooCulm"], smooth=True, box_uv_scale=0.7)
    export_glb("edo_wagasa_bench.glb")


def build_edo_bamboo_fence() -> None:
    """Traditional lashed bamboo fence module (3.0m span) for riversides and compounds."""
    clear_scene()
    mats = get_materials()
    bm_bamboo = bmesh.new()
    bm_rope = bmesh.new()

    span = 3.0
    posts = 4
    # Main thicker support posts embedded deep
    for i in range(posts):
        x = -span * 0.5 + (i / (posts - 1)) * span
        add_game_cylinder(bm_bamboo, x, -0.35, 0.0, 0.048, 0.042, 1.48, segments=10)
        # Black/hemp lash ties at rail intersections
        for ry in (0.28, 0.62, 0.96):
            add_game_cylinder(bm_rope, x, ry - 0.025, 0.0, 0.056, 0.056, 0.05, segments=10)

    # Vertical split bamboo slats + horizontal rails slightly proud
    slat_count = 16
    for si in range(slat_count):
        x = -span * 0.48 + (si / (slat_count - 1)) * span * 0.96
        h_var = 0.98 + 0.08 * math.sin(si * 1.9)
        add_game_cylinder(bm_bamboo, x, -0.15, 0.0, 0.022, 0.020, h_var + 0.15, segments=8)
    for ry in (0.28, 0.62, 0.96):
        add_swept_tube(bm_bamboo, [(-span * 0.52, ry, 0.036), (span * 0.52, ry, 0.036)], [0.028, 0.028], segments=8)

    finalize_mesh("fence_bamboo", bm_bamboo, mats["BambooCulm"], smooth=True, box_uv_scale=0.7)
    finalize_mesh("fence_lash", bm_rope, mats["HempRope"], smooth=True, box_uv_scale=0.8)
    export_glb("edo_bamboo_fence.glb")


def build_edo_andon_lantern() -> None:
    """Standing wooden framed paper andon street lamp on granite plinth."""
    clear_scene()
    mats = get_materials()
    bm_stone = bmesh.new()
    bm_charred = bmesh.new()
    bm_glow = bmesh.new()
    bm_roof = bmesh.new()

    add_game_box(bm_stone, 0.0, -0.02, 0.0, 0.54, 0.48, 0.54, bevel=0.03)
    add_game_cylinder(bm_charred, 0.0, 0.18, 0.0, 0.075, 0.065, 1.48, segments=10)
    # Lantern cage
    for sx in (-0.18, 0.18):
        for sz in (-0.18, 0.18):
            add_game_box(bm_charred, sx, 1.78, sz, 0.04, 0.52, 0.04, bevel=0.005)
    add_game_box(bm_glow, 0.0, 1.78, 0.0, 0.30, 0.44, 0.30, bevel=0.01)
    # Gently pitched copper/tile pyramid cap
    add_game_cylinder(bm_roof, 0.0, 2.02, 0.0, 0.34, 0.04, 0.22, segments=4)

    finalize_mesh("andon_stone", bm_stone, mats["IshigakiStone"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("andon_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("andon_glow", bm_glow, mats["LanternGlow"], smooth=True, box_uv_scale=1.0)
    finalize_mesh("andon_roof", bm_roof, mats["KawaraTile"], smooth=True, box_uv_scale=0.6)
    export_glb("edo_andon_lantern.glb")


def build_edo_nobori_banner() -> None:
    """Tall wooden L-pole shop/dock banner with wind-rippled cloth."""
    clear_scene()
    mats = get_materials()
    bm_bamboo = bmesh.new()
    bm_stone = bmesh.new()
    bm_cloth = bmesh.new()

    add_game_cylinder(bm_stone, 0.0, -0.05, 0.0, 0.22, 0.18, 0.32, segments=12)
    add_game_cylinder(bm_bamboo, 0.0, 0.20, 0.0, 0.040, 0.028, 3.65, segments=10)
    add_swept_tube(bm_bamboo, [(0.0, 3.72, 0.0), (0.82, 3.72, 0.0)], [0.022, 0.016], segments=6)

    # Gently undulating hanging banner cloth with indigo/cream mon striping (zero overlap!)
    rows, cols = 10, 4
    grid: list[list[bmesh.types.BMVert]] = []
    for r in range(rows + 1):
        v = r / rows  # 0 bottom -> 1 top
        y = 1.15 + v * 2.52
        flutter = 0.065 * math.sin((1.0 - v) * 4.2) * (1.0 - v * 0.7)
        row: list[bmesh.types.BMVert] = []
        for c in range(cols + 1):
            u = c / cols
            x = 0.08 + u * 0.68
            z = flutter + 0.03 * math.sin(u * math.pi + v * 3.0) * (1.0 - v * 0.6)
            row.append(bm_cloth.verts.new(g2b(x, y, z)))
        grid.append(row)
    for r in range(rows):
        for c in range(cols):
            f = bm_cloth.faces.new((grid[r][c], grid[r][c + 1], grid[r + 1][c + 1], grid[r + 1][c]))
            # Crisp painted Edo mon cream diamond/stripe motif in rows 4..6 & borders
            if r in (1, 7) or (r in (4, 5) and c in (1, 2)):
                f.material_index = 1
            else:
                f.material_index = 0

    finalize_mesh("nobori_pole", bm_bamboo, mats["CharredTimber"], smooth=True, box_uv_scale=0.7)
    finalize_mesh("nobori_base", bm_stone, mats["IshigakiStone"], smooth=True, box_uv_scale=0.6)
    nobori_obj = finalize_mesh("nobori_cloth", bm_cloth, mats["NorenIndigo"], smooth=True, box_uv_scale=0.6)
    nobori_obj.data.materials.append(mats["ClothCream"])
    export_glb("edo_nobori_banner.glb")


def build_all() -> None:
    build_edo_wagon()
    build_edo_wagasa_bench()
    build_edo_bamboo_fence()
    build_edo_andon_lantern()
    build_edo_nobori_banner()


if __name__ == "__main__":
    build_all()
