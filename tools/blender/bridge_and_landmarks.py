"""Arched vermilion Edo timber bridge with curved deck, railings & giboshi caps."""

from __future__ import annotations

import math

import bmesh
from mathutils import Vector

from common import (
    add_cambered_beam,
    add_game_box,
    add_game_cylinder,
    clear_scene,
    export_glb,
    finalize_mesh,
    g2b,
    get_materials,
)


def build_edo_arched_bridge() -> None:
    """Drop-in replacement matching [-5.66, 5.66] x [-1.96, 1.96], west y=0.40, east y=1.80."""
    clear_scene()
    mats = get_materials()

    bm_stone = bmesh.new()
    bm_charred = bmesh.new()
    bm_cedar = bmesh.new()
    bm_vermilion = bmesh.new()
    bm_bronze = bmesh.new()

    x0, y0 = -5.60, 0.40
    x1, y1 = 5.60, 1.80
    camber = 0.58
    half_w = 1.62

    def deck_y(x: float) -> float:
        t = (x - x0) / (x1 - x0)
        return y0 + (y1 - y0) * t + camber * 4.0 * t * (1.0 - t)

    # 1. Granite abutments embedded cleanly below deck grade (12cm clear of terrain y=0.40/1.80!)
    add_game_box(bm_stone, -5.22, -0.60, 0.0, 0.88, 1.76, 3.68, bevel=0.04)
    add_game_box(bm_stone, 5.22, 0.10, 0.0, 0.88, 3.16, 3.68, bevel=0.04)

    # 2. Timber pier bents reaching cleanly below riverbed (-1.85m)
    for px in (-2.95, 0.0, 2.95):
        top_y = deck_y(px) - 0.14
        bot_y = -2.05
        h = top_y - bot_y
        for pz in (-1.36, 1.36):
            add_game_cylinder(bm_charred, px, bot_y, pz, 0.13, 0.11, h, segments=12)
        # Cross cap beam & X-bracing under arch (tucked cleanly inside vermilion girders at z=+-1.42)
        add_game_box(bm_charred, px, top_y - 0.08, 0.0, 0.24, 0.20, 2.80, bevel=0.02)
        brace_y = 0.5 * (top_y + bot_y + 0.4)
        add_game_box(bm_charred, px, brace_y, 0.0, 0.12, 0.14, 2.75, bevel=0.015)

    # 3. Continuous cambered main stringers (vermilion outer girders + charred inner ribs)
    for sz in (-1.42, 1.42):
        add_cambered_beam(bm_vermilion, (x0, y0 - 0.14, sz), (x1, y1 - 0.14, sz), camber, half_width=0.11, half_thick=0.14, segments=24)
    for sz in (-0.72, 0.0, 0.72):
        add_cambered_beam(bm_charred, (x0, y0 - 0.15, sz), (x1, y1 - 0.15, sz), camber, half_width=0.08, half_thick=0.11, segments=24)

    # 4. Individual slightly proud beveled cedar planks across full cambered arch (28 stations)
    plank_count = 28
    span = x1 - x0
    plank_x_step = span / plank_count
    for i in range(plank_count):
        t = (i + 0.5) / plank_count
        px = x0 + t * span
        py = deck_y(px)
        # Slope derivative for plank tilt around game Z (pitch along X)
        dt = 0.005
        py_a = deck_y(px - dt * span)
        py_b = deck_y(px + dt * span)
        slope = math.atan2(py_b - py_a, 2.0 * dt * span)
        # Build oriented plank vertex quad slab in Blender space
        hw = half_w + 0.08
        hx = plank_x_step * 0.46
        hz = 0.055
        # Local corners in game coords tilted by slope around Z axis
        ca, sa = math.cos(slope), math.sin(slope)
        pts_l = []
        for lx in (-hx, hx):
            for ly in (-hz * 2.0, 0.0):
                for lz in (-hw, hw):
                    wx = px + lx * ca - ly * sa
                    wy = py + lx * sa + ly * ca + 0.025
                    wz = lz
                    pts_l.append(bm_cedar.verts.new(g2b(wx, wy, wz)))
        # Create cube faces for indices: (x-,x+) x (y-,y+) x (z-,z+) -> 0..7
        faces = [
            (0, 1, 3, 2),  # x-
            (4, 6, 7, 5),  # x+
            (0, 4, 5, 1),  # y-
            (2, 3, 7, 6),  # y+
            (0, 2, 6, 4),  # z-
            (1, 5, 7, 3),  # z+
        ]
        for f in faces:
            try:
                bm_cedar.faces.new([pts_l[idx] for idx in f])
            except ValueError:
                pass

    # 5. Sweeping cambered vermilion railings + mid-rails + posts + brass giboshi finials
    post_count = 11
    for side in (-1.0, 1.0):
        rz = side * 1.54
        # Top handrail + lower knee rail
        add_cambered_beam(bm_vermilion, (x0, y0 + 0.90, rz), (x1, y1 + 0.90, rz), camber, half_width=0.068, half_thick=0.055, segments=24)
        add_cambered_beam(bm_vermilion, (x0, y0 + 0.46, rz), (x1, y1 + 0.46, rz), camber, half_width=0.045, half_thick=0.040, segments=24)
        # Curbed wheel-guard timber sill proud above deck edge
        add_cambered_beam(bm_vermilion, (x0, y0 + 0.09, side * 1.46), (x1, y1 + 0.09, side * 1.46), camber, half_width=0.075, half_thick=0.075, segments=24)

        for p_idx in range(post_count):
            pt = p_idx / (post_count - 1)
            px = x0 + pt * span
            py = deck_y(px)
            is_end = p_idx in (0, post_count // 2, post_count - 1)
            post_h = 1.08 if is_end else 0.96
            add_game_box(bm_vermilion, px, py + post_h * 0.5 - 0.08, rz, 0.13 if is_end else 0.10, post_h, 0.13 if is_end else 0.10, bevel=0.015)
            # Giboshi lotus-bud finial cap (lathe-like stacked smooth cones/sphere)
            gy = py + post_h - 0.08
            r_collar = 0.082 if is_end else 0.065
            add_game_cylinder(bm_bronze, px, gy, rz, r_collar, r_collar * 0.85, 0.045, segments=14)
            add_game_cylinder(bm_bronze, px, gy + 0.045, rz, r_collar * 0.95, r_collar * 1.08, 0.055, segments=14)
            add_game_cylinder(bm_bronze, px, gy + 0.10, rz, r_collar * 1.08, 0.012, 0.095, segments=14)

    finalize_mesh("bridge_abutments", bm_stone, mats["IshigakiStone"], smooth=True, box_uv_scale=0.42)
    finalize_mesh("bridge_structure", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.50)
    finalize_mesh("bridge_planks", bm_cedar, mats["CedarTimber"], smooth=True, box_uv_scale=0.55)
    finalize_mesh("bridge_vermilion", bm_vermilion, mats["VermilionLacquer"], smooth=True, box_uv_scale=0.60)
    finalize_mesh("bridge_giboshi", bm_bronze, mats["AntiqueBronze"], smooth=True, box_uv_scale=0.80)
    export_glb("edo_arched_bridge.glb")


if __name__ == "__main__":
    build_edo_arched_bridge()
