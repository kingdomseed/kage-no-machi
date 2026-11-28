"""Shared cutaway Edo house interior builder (strictly non-coplanar, inset-safe).

Used by both tools/blender/buildings.py and tools/asset_pipeline/blender_postprocess.py
so every peekable house (Blender-authored or Tripo-generated) shares the exact canonical
node hierarchy:
  - interior_room_*   (floor slab, tatami mats, interior plaster walls, corner posts)
  - interior_props_*  (archetype furniture: irori hearth, chabudai, tansu, counter, casks, andon)
"""

from __future__ import annotations

import os
from pathlib import Path

import bmesh
import bpy

from common import (
    MODELS_DIR,
    add_game_box,
    add_game_cylinder,
    finalize_mesh,
    g2b,
)


def _try_mount_tripo_prop(
    prop_filename: str,
    node_name: str,
    pos_game: tuple[float, float, float],
    yaw: float = 0.0,
) -> bool:
    """Mounts a Tripo-generated interior prop GLB if installed in assets/models/."""
    path = os.path.join(MODELS_DIR, prop_filename)
    if not os.path.exists(path):
        return False
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    added = [o for o in bpy.data.objects if o not in before]
    if not added:
        return False
    pivot = bpy.data.objects.new(node_name, None)
    bpy.context.scene.collection.objects.link(pivot)
    pivot.location = g2b(*pos_game)
    pivot.rotation_euler = (0.0, 0.0, yaw)
    for idx, obj in enumerate(added):
        if obj.parent is None:
            obj.parent = pivot
        if not obj.name.lower().startswith("interior_"):
            obj.name = f"{node_name}_{idx}"
    return True


def _add_tatami_grid(
    bm_tatami: bmesh.types.BMesh,
    bm_border: bmesh.types.BMesh,
    cx: float,
    cz: float,
    span_x: float,
    span_z: float,
    floor_top_y: float,
    *,
    cols: int = 2,
    rows: int = 2,
) -> None:
    """Adds non-overlapping tatami mats proud of floor_top_y with recessed border strips."""
    gap = 0.055
    mat_h = 0.032
    mat_cy = floor_top_y + 0.015 + mat_h * 0.5
    cell_x = (span_x - gap * (cols + 1)) / cols
    cell_z = (span_z - gap * (rows + 1)) / rows
    if cell_x <= 0.25 or cell_z <= 0.25:
        return

    # Dark indigo border strips running strictly in the gaps between mats (never coplanar with mats)
    border_h = 0.018
    border_cy = floor_top_y + 0.012 + border_h * 0.5
    for c in range(1, cols):
        bx_pos = cx - span_x * 0.5 + gap * (c + 0.5) + cell_x * c
        add_game_box(bm_border, bx_pos, border_cy, cz, gap * 0.62, border_h, span_z - gap * 1.4)
    for r in range(1, rows):
        bz_pos = cz - span_z * 0.5 + gap * (r + 0.5) + cell_z * r
        add_game_box(bm_border, cx, border_cy, bz_pos, span_x - gap * 1.4, border_h, gap * 0.62)

    for c in range(cols):
        mx = cx - span_x * 0.5 + gap * (c + 1) + cell_x * (c + 0.5)
        for r in range(rows):
            mz = cz - span_z * 0.5 + gap * (r + 1) + cell_z * (r + 0.5)
            add_game_box(bm_tatami, mx, mat_cy, mz, cell_x, mat_h, cell_z, bevel=0.005)


def _add_andon_lamp(
    bm_wood: bmesh.types.BMesh,
    bm_glow: bmesh.types.BMesh,
    x: float,
    floor_y: float,
    z: float,
) -> None:
    """Adds a cozy Edo indoor square paper andon floor lamp resting clear of floor_y."""
    base_y = floor_y + 0.008
    add_game_box(bm_wood, x, base_y + 0.025, z, 0.30, 0.05, 0.30, bevel=0.006)
    for sx in (-0.11, 0.11):
        for sz in (-0.11, 0.11):
            add_game_box(bm_wood, x + sx, base_y + 0.34, z + sz, 0.026, 0.58, 0.026)
    add_game_box(bm_wood, x, base_y + 0.64, z, 0.28, 0.03, 0.28, bevel=0.004)
    # Glowing washi lamp core strictly inset inside frame posts
    add_game_box(bm_glow, x, base_y + 0.36, z, 0.17, 0.42, 0.17)


def _add_zabuton(
    bm_cloth: bmesh.types.BMesh,
    x: float,
    surface_y: float,
    z: float,
    yaw: float = 0.0,
) -> None:
    add_game_box(bm_cloth, x, surface_y + 0.036, z, 0.46, 0.058, 0.46, yaw=yaw, bevel=0.018)


def _add_chabudai_and_tea(
    bm_lacquer: bmesh.types.BMesh,
    bm_ceramic: bmesh.types.BMesh,
    x: float,
    surface_y: float,
    z: float,
    *,
    w: float = 0.88,
    d: float = 0.62,
    h: float = 0.32,
) -> None:
    y0 = surface_y + 0.008
    # Four corner legs strictly beneath tabletop
    leg_h = h - 0.05
    for sx in (-w * 0.40, w * 0.40):
        for sz in (-d * 0.38, d * 0.38):
            add_game_box(bm_lacquer, x + sx, y0 + leg_h * 0.5, z + sz, 0.055, leg_h, 0.055)
    add_game_box(bm_lacquer, x, y0 + leg_h + 0.028, z, w, 0.048, d, bevel=0.008)
    top_y = y0 + leg_h + 0.056
    # Kyusu teapot + two teacups resting proud of tabletop
    add_game_cylinder(bm_ceramic, x - 0.10, top_y, z, 0.068, 0.055, 0.095, segments=12)
    add_game_cylinder(bm_ceramic, x + 0.14, top_y, z + 0.08, 0.036, 0.042, 0.058, segments=10)
    add_game_cylinder(bm_ceramic, x + 0.12, top_y, z - 0.10, 0.036, 0.042, 0.058, segments=10)


def build_house_interior(
    *,
    archetype: str,
    inner_bx: float,
    inner_bz: float,
    floor_y: float,
    wall_top_y: float,
    mats: dict[str, bpy.types.Material],
) -> None:
    """Emits canonical interior_room_* and interior_props_* meshes strictly inside hollow walls."""
    # Strict inset from inner face of exterior walls so zero coplanar faces exist
    room_w = max(1.60, inner_bx - 0.14)
    room_d = max(1.60, inner_bz - 0.14)
    hw = room_w * 0.5
    hd = room_d * 0.5

    bm_floor = bmesh.new()
    bm_tatami = bmesh.new()
    bm_border = bmesh.new()
    bm_int_wall = bmesh.new()
    bm_int_timber = bmesh.new()

    bm_prop_wood = bmesh.new()
    bm_prop_lacquer = bmesh.new()
    bm_prop_cloth = bmesh.new()
    bm_prop_iron = bmesh.new()
    bm_prop_gold = bmesh.new()
    bm_prop_straw = bmesh.new()
    bm_prop_glow = bmesh.new()
    bm_prop_hearth = bmesh.new()

    # 1. Base wooden interior floor slab (top at floor_y, thickness 0.10m)
    floor_thick = 0.10
    add_game_box(bm_floor, 0.0, floor_y - floor_thick * 0.5, 0.0, room_w, floor_thick, room_d)

    # 2. Recessed interior plaster wall linings strictly clear of corner posts
    wall_h = max(0.80, wall_top_y - floor_y - 0.10)
    wall_cy = floor_y + 0.03 + wall_h * 0.5
    liner_t = 0.04
    # Corner posts stand 5cm taller than wall liners (zero coplanar top cap) and clear in X/Z
    post_h = wall_h + 0.05
    post_cy = floor_y + 0.03 + post_h * 0.5
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            add_game_box(bm_int_timber, sx * (hw - 0.055), post_cy, sz * (hd - 0.055), 0.08, post_h, 0.08)
    # Rear interior plaster wall (-Z), >=2.5cm clear of corner posts in X
    add_game_box(bm_int_wall, 0.0, wall_cy, -hd + 0.045, room_w - 0.24, wall_h, liner_t)
    # Side interior plaster walls (-X, +X), >=2.5cm clear of corner posts in Z
    side_d = room_d - 0.24
    add_game_box(bm_int_wall, -hw + 0.045, wall_cy, 0.0, liner_t, wall_h, side_d)
    add_game_box(bm_int_wall, hw - 0.045, wall_cy, 0.0, liner_t, wall_h, side_d)
    # Upper rear lintel trim strictly proud inward (>=2.5cm clear of rear plaster wall & posts)
    add_game_box(bm_int_timber, 0.0, floor_y + 0.03 + wall_h - 0.06, -hd + 0.11, room_w - 0.25, 0.055, 0.04)

    # 3. Archetype room layout & furnishings
    if archetype == "machiya":
        # Rear raised tatami shop platform + front packed-earth/wood doma entry
        tatami_d = room_d * 0.56
        tatami_cz = -hd + tatami_d * 0.5 + 0.14
        _add_tatami_grid(bm_tatami, bm_border, 0.0, tatami_cz, room_w - 0.24, tatami_d, floor_y, cols=2, rows=2)
        tatami_top = floor_y + 0.052

        # Merchant shop cedar counter dividing doma from tatami shop floor
        if not _try_mount_tripo_prop("interior_shop_counter.glb", "interior_props_counter", (-0.15, floor_y + 0.01, 0.36)):
            c_w = min(1.55, room_w * 0.54)
            add_game_box(bm_prop_wood, -0.15, floor_y + 0.42, 0.36, c_w, 0.80, 0.48, bevel=0.012)
            add_game_box(bm_prop_lacquer, -0.15, floor_y + 0.85, 0.36, c_w + 0.08, 0.055, 0.56, bevel=0.008)
            # Ledger book & abacus box on counter
            add_game_box(bm_prop_cloth, -0.35, floor_y + 0.91, 0.34, 0.26, 0.045, 0.20, yaw=0.14)
            add_game_box(bm_prop_wood, 0.22, floor_y + 0.905, 0.38, 0.24, 0.035, 0.14, yaw=-0.18)

        # Rear merchant tansu drawer chest against -Z wall
        if not _try_mount_tripo_prop("interior_tansu_chest.glb", "interior_props_tansu", (0.0, tatami_top, -hd + 0.42)):
            tw = min(1.26, room_w * 0.46)
            add_game_box(bm_prop_lacquer, 0.0, tatami_top + 0.52, -hd + 0.42, tw, 1.02, 0.42, bevel=0.014)
            for dx in (-tw * 0.25, tw * 0.25):
                for dy in (0.28, 0.62, 0.86):
                    add_game_box(bm_prop_iron, dx, tatami_top + dy, -hd + 0.645, 0.12, 0.04, 0.025)

        # Stacked ceramic/sake jars near side wall
        for jx, jz in ((hw - 0.42, 0.46), (hw - 0.44, 0.04)):
            add_game_cylinder(bm_prop_straw, jx, floor_y + 0.01, jz, 0.16, 0.17, 0.44, segments=12)

        # Warm glowing floor andon lamp
        if not _try_mount_tripo_prop("interior_andon_lamp.glb", "interior_props_andon", (-hw + 0.42, tatami_top, -hd + 0.52)):
            _add_andon_lamp(bm_prop_wood, bm_prop_glow, -hw + 0.42, tatami_top, -hd + 0.52)

    elif archetype == "minka":
        # Full rustic tatami room around a glowing sunken central irori hearth
        _add_tatami_grid(bm_tatami, bm_border, 0.0, 0.0, room_w - 0.24, room_d - 0.24, floor_y, cols=2, rows=2)
        tatami_top = floor_y + 0.052

        if not _try_mount_tripo_prop("interior_irori_hearth.glb", "interior_props_irori", (0.0, tatami_top, 0.0)):
            # Square dark-cedar hearth surround
            h_span = 0.92
            rim = 0.11
            hy = tatami_top + 0.065
            add_game_box(bm_prop_wood, 0.0, hy, h_span * 0.5, h_span + rim, 0.11, rim, bevel=0.008)
            add_game_box(bm_prop_wood, 0.0, hy, -h_span * 0.5, h_span + rim, 0.11, rim, bevel=0.008)
            add_game_box(bm_prop_wood, -h_span * 0.5, hy, 0.0, rim, 0.11, h_span - rim - 0.02, bevel=0.008)
            add_game_box(bm_prop_wood, h_span * 0.5, hy, 0.0, rim, 0.11, h_span - rim - 0.02, bevel=0.008)
            # Glowing charcoal ember bed & cast-iron tetsubin kettle
            add_game_box(bm_prop_hearth, 0.0, tatami_top + 0.055, 0.0, 0.58, 0.07, 0.58, bevel=0.01)
            add_game_cylinder(bm_prop_iron, 0.0, tatami_top + 0.14, 0.0, 0.15, 0.12, 0.22, segments=14)
            add_game_cylinder(bm_prop_iron, 0.0, tatami_top + 0.36, 0.0, 0.018, 0.018, 0.42, segments=8)

        # Floor cushions around hearth & straw storage baskets
        _add_zabuton(bm_prop_cloth, 0.0, tatami_top, -0.82, yaw=0.06)
        _add_zabuton(bm_prop_cloth, -0.84, tatami_top, 0.08, yaw=-0.12)
        _add_zabuton(bm_prop_cloth, 0.84, tatami_top, -0.04, yaw=0.10)
        add_game_cylinder(bm_prop_straw, -hw + 0.44, tatami_top, -hd + 0.44, 0.20, 0.22, 0.42, segments=12)
        add_game_cylinder(bm_prop_straw, hw - 0.44, tatami_top, -hd + 0.44, 0.18, 0.20, 0.36, segments=12)

    elif archetype == "chaya":
        # Elegant tatami tea salon with twin lacquer chabudai tables & tokonoma shelf
        _add_tatami_grid(bm_tatami, bm_border, 0.0, 0.0, room_w - 0.24, room_d - 0.24, floor_y, cols=2, rows=2)
        tatami_top = floor_y + 0.052

        if not _try_mount_tripo_prop("interior_chabudai_set.glb", "interior_props_chabudai_l", (-0.64, tatami_top, 0.12)):
            _add_chabudai_and_tea(bm_prop_lacquer, bm_prop_iron, -0.64, tatami_top, 0.12, w=0.82, d=0.58)
            _add_zabuton(bm_prop_cloth, -0.64, tatami_top, -0.46, yaw=0.05)
            _add_zabuton(bm_prop_cloth, -0.64, tatami_top, 0.68, yaw=-0.04)

        _add_chabudai_and_tea(bm_prop_lacquer, bm_prop_iron, 0.66, tatami_top, -0.08, w=0.82, d=0.58)
        _add_zabuton(bm_prop_cloth, 0.66, tatami_top, -0.64, yaw=-0.08)
        _add_zabuton(bm_prop_cloth, 0.66, tatami_top, 0.50, yaw=0.06)

        # Rear tokonoma lacquer display dais + warm andon floor lamp
        add_game_box(bm_prop_lacquer, 0.0, tatami_top + 0.075, -hd + 0.38, 1.10, 0.14, 0.42, bevel=0.01)
        add_game_cylinder(bm_prop_gold, 0.0, tatami_top + 0.16, -hd + 0.38, 0.09, 0.06, 0.28, segments=12)
        _add_andon_lamp(bm_prop_wood, bm_prop_glow, -hw + 0.44, tatami_top, -hd + 0.46)
        _add_andon_lamp(bm_prop_wood, bm_prop_glow, hw - 0.44, tatami_top, hd - 0.46)

    else:  # kura storehouse
        # Plank storehouse floor with stacked sake casks, timber shelves & brass-clasped treasure chest
        shelf_y = floor_y + 0.01
        # Rear timber storage rack
        rw = min(2.15, room_w - 0.46)
        for sx in (-rw * 0.45, 0.0, rw * 0.45):
            add_game_box(bm_prop_wood, sx, shelf_y + 0.66, -hd + 0.42, 0.08, 1.30, 0.46)
        add_game_box(bm_prop_wood, 0.0, shelf_y + 0.62, -hd + 0.42, rw, 0.06, 0.50)
        add_game_box(bm_prop_wood, 0.0, shelf_y + 1.24, -hd + 0.42, rw, 0.06, 0.50)
        # Stacked komodaru sake casks along left wall
        for cz in (-0.35, 0.22, 0.78):
            add_game_cylinder(bm_prop_straw, -hw + 0.48, shelf_y, cz, 0.23, 0.24, 0.54, segments=14)
        add_game_cylinder(bm_prop_straw, -hw + 0.48, shelf_y + 0.56, -0.06, 0.22, 0.23, 0.52, segments=14)
        # Heavy lacquered nagamochi strongbox with gold brass clasps on right
        add_game_box(bm_prop_lacquer, hw - 0.68, shelf_y + 0.32, 0.26, 0.84, 0.62, 0.54, bevel=0.015)
        add_game_box(bm_prop_gold, hw - 0.68, shelf_y + 0.36, 0.55, 0.18, 0.14, 0.03)
        add_game_box(bm_prop_gold, hw - 1.05, shelf_y + 0.32, 0.55, 0.08, 0.54, 0.025)
        add_game_box(bm_prop_gold, hw - 0.31, shelf_y + 0.32, 0.55, 0.08, 0.54, 0.025)
        # Warm storehouse lantern
        _add_andon_lamp(bm_prop_wood, bm_prop_glow, 0.15, shelf_y, -0.15)

    finalize_mesh("interior_room_floor", bm_floor, mats["InteriorCedarFloor"], smooth=False, box_uv_scale=0.55)
    finalize_mesh("interior_room_tatami", bm_tatami, mats["TatamiMat"], smooth=False, box_uv_scale=0.85)
    finalize_mesh("interior_room_border", bm_border, mats["TatamiBorder"], smooth=False, box_uv_scale=0.8)
    finalize_mesh("interior_room_walls", bm_int_wall, mats["InteriorPlaster"], smooth=False, box_uv_scale=0.45)
    finalize_mesh("interior_room_timber", bm_int_timber, mats["CharredTimber"], smooth=False, box_uv_scale=0.50)

    finalize_mesh("interior_props_wood", bm_prop_wood, mats["CedarTimber"], smooth=True, box_uv_scale=0.60)
    finalize_mesh("interior_props_lacquer", bm_prop_lacquer, mats["LacquerWood"], smooth=True, box_uv_scale=0.60)
    finalize_mesh("interior_props_cloth", bm_prop_cloth, mats["ClothCrimson"], smooth=True, box_uv_scale=0.65)
    finalize_mesh("interior_props_iron", bm_prop_iron, mats["DarkIron"], smooth=True, box_uv_scale=0.70)
    finalize_mesh("interior_props_gold", bm_prop_gold, mats["GoldTrim"], smooth=True, box_uv_scale=0.70)
    finalize_mesh("interior_props_straw", bm_prop_straw, mats["StrawBale"], smooth=True, box_uv_scale=0.75)
    finalize_mesh("interior_props_glow", bm_prop_glow, mats["LanternGlow"], smooth=False, box_uv_scale=0.60)
    finalize_mesh("interior_props_hearth", bm_prop_hearth, mats["HearthEmber"], smooth=True, box_uv_scale=0.80)
