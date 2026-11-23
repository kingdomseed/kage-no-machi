"""Sculpted non-polygonal rocks, coastal cliffs, headland stacks & river stairs."""

from __future__ import annotations

import math
import random

import bmesh
from mathutils import Vector

from common import (
    add_game_box,
    clear_scene,
    export_glb,
    finalize_mesh,
    g2b,
    get_materials,
)


def _sculpted_rock_lobe(
    bm: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radii: tuple[float, float, float],
    *,
    seed: int,
    subdivisions: int = 3,
    strata_steps: float = 0.0,
    flatten_bottom: bool = True,
) -> None:
    """Builds an organic smooth-shaded sculpted granite boulder / cliff mass."""
    ret = bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    verts = ret["verts"]
    rng = random.Random(seed)
    p1 = rng.uniform(0.0, 6.28)
    p2 = rng.uniform(0.0, 6.28)
    p3 = rng.uniform(0.0, 6.28)
    rx, ry, rz = radii
    cx, cy, cz = center

    for v in verts:
        x, y, z = v.co.x, v.co.y, v.co.z
        # Multi-frequency organic rock fissure & strata deformation
        d = (
            0.18 * math.sin(x * 2.4 + p1) * math.cos(y * 2.1 + p2)
            + 0.12 * math.sin(z * 3.3 + x * 1.9 + p2)
            + 0.07 * math.cos(y * 4.8 - z * 2.7 + p3)
            + 0.04 * math.sin((x + y + z) * 6.5 + p1)
        )
        # Optional horizontal sedimentary strata shelves along height z (Blender up)
        if strata_steps > 0.0:
            shelf = math.sin(z * strata_steps + x * 1.4 + p3) * 0.085
            d += shelf
        # Slight granite angular ridge sharpening via smooth abs crease
        crevice = abs(math.sin(x * 2.7 + y * 2.2 + p1))
        scale = 1.0 + d - 0.09 * (1.0 - crevice)

        gx = x * rx * scale
        gy_up = z * ry * scale
        gz = -y * rz * scale
        if flatten_bottom and gy_up < -ry * 0.52:
            gy_up = -ry * 0.52 + (gy_up + ry * 0.52) * 0.25
        v.co = g2b(cx + gx, cy + gy_up, cz + gz)


def build_rock_river_boulder() -> None:
    clear_scene()
    mats = get_materials()
    bm = bmesh.new()
    _sculpted_rock_lobe(bm, (0.0, 0.10, 0.0), (1.15, 0.72, 0.92), seed=101, subdivisions=3, strata_steps=4.2)
    _sculpted_rock_lobe(bm, (0.78, -0.04, 0.44), (0.62, 0.44, 0.56), seed=102, subdivisions=3, strata_steps=5.0)
    _sculpted_rock_lobe(bm, (-0.72, -0.08, -0.36), (0.55, 0.36, 0.48), seed=103, subdivisions=2, strata_steps=4.8)
    finalize_mesh("rock_river_boulder", bm, mats["CliffRock"], smooth=True, box_uv_scale=0.45)
    export_glb("rock_river_boulder.glb")


def build_rock_shore_riprap() -> None:
    clear_scene()
    mats = get_materials()
    bm = bmesh.new()
    specs = [
        ((0.0, 0.02, 0.0), (1.05, 0.58, 0.84), 201),
        ((-0.88, -0.06, -0.45), (0.72, 0.42, 0.64), 202),
        ((0.92, -0.05, 0.38), (0.78, 0.45, 0.62), 203),
        ((0.18, 0.14, 0.62), (0.56, 0.36, 0.50), 204),
        ((-0.34, -0.10, 0.68), (0.48, 0.30, 0.44), 205),
    ]
    for ctr, rad, sd in specs:
        _sculpted_rock_lobe(bm, ctr, rad, seed=sd, subdivisions=3, strata_steps=3.5)
    finalize_mesh("rock_shore_riprap", bm, mats["CliffRock"], smooth=True, box_uv_scale=0.48)
    export_glb("rock_shore_riprap.glb")


def build_rock_cliff_a() -> None:
    """Vertical rugged granite cliff buttress (for river gorges, hillsides & Minato castle slopes)."""
    clear_scene()
    mats = get_materials()
    bm = bmesh.new()
    _sculpted_rock_lobe(bm, (0.0, 0.75, 0.0), (1.75, 1.55, 1.45), seed=301, subdivisions=3, strata_steps=6.2)
    _sculpted_rock_lobe(bm, (1.10, 0.32, 0.55), (1.05, 0.92, 0.98), seed=302, subdivisions=3, strata_steps=6.8)
    _sculpted_rock_lobe(bm, (-0.98, 0.25, -0.48), (1.12, 0.85, 0.95), seed=303, subdivisions=3, strata_steps=5.8)
    _sculpted_rock_lobe(bm, (0.15, -0.15, 0.95), (0.85, 0.54, 0.72), seed=304, subdivisions=2, strata_steps=5.2)
    finalize_mesh("rock_cliff_a", bm, mats["CliffRock"], smooth=True, box_uv_scale=0.34)
    export_glb("rock_cliff_a.glb")


def build_rock_cliff_b() -> None:
    """Broader terraced rocky ridge crag variant."""
    clear_scene()
    mats = get_materials()
    bm = bmesh.new()
    _sculpted_rock_lobe(bm, (-0.25, 0.62, 0.10), (1.95, 1.28, 1.38), seed=401, subdivisions=3, strata_steps=5.6)
    _sculpted_rock_lobe(bm, (1.28, 0.22, -0.25), (1.18, 0.78, 1.04), seed=402, subdivisions=3, strata_steps=6.0)
    _sculpted_rock_lobe(bm, (-1.20, 0.14, 0.68), (0.94, 0.64, 0.82), seed=403, subdivisions=3, strata_steps=5.0)
    finalize_mesh("rock_cliff_b", bm, mats["CliffRock"], smooth=True, box_uv_scale=0.34)
    export_glb("rock_cliff_b.glb")


def build_rock_coastal_headland() -> None:
    """Large layered sea-cliff headland for wrapping Minato-jo promontory and breakwater."""
    clear_scene()
    mats = get_materials()
    bm = bmesh.new()
    _sculpted_rock_lobe(bm, (0.0, 0.45, 0.0), (2.75, 2.25, 2.35), seed=501, subdivisions=3, strata_steps=6.4, flatten_bottom=False)
    _sculpted_rock_lobe(bm, (1.85, -0.25, 0.85), (1.55, 1.35, 1.45), seed=502, subdivisions=3, strata_steps=6.0, flatten_bottom=False)
    _sculpted_rock_lobe(bm, (-1.65, -0.18, -0.95), (1.65, 1.22, 1.50), seed=503, subdivisions=3, strata_steps=5.8, flatten_bottom=False)
    _sculpted_rock_lobe(bm, (0.55, -0.65, -1.75), (1.28, 0.96, 1.15), seed=504, subdivisions=2, strata_steps=5.0, flatten_bottom=False)
    finalize_mesh("rock_coastal_headland", bm, mats["CliffRock"], smooth=True, box_uv_scale=0.28)
    export_glb("rock_coastal_headland.glb")


def build_edo_river_stairs() -> None:
    """Curved stone water-stairs descending gently from bank promenade to shallow river edge."""
    clear_scene()
    mats = get_materials()
    bm_stone = bmesh.new()
    bm_cheeks = bmesh.new()

    steps = 7
    total_run = 2.45
    total_rise = 1.24
    width = 1.92
    step_d = total_run / steps
    step_h = total_rise / steps
    for i in range(steps):
        # Top tread starts at y=+0.06 at -X bank, descending to y=-1.00 into river edge at +X
        x = -total_run * 0.5 + (i + 0.5) * step_d
        y_top = 0.06 - i * step_h
        tread_h = step_h + 0.72
        add_game_box(
            bm_stone,
            x,
            y_top - tread_h * 0.5,
            0.0,
            step_d + 0.06,
            tread_h,
            width - 0.14,
            bevel=0.025,
        )
    # Low granite curb stones framing steps cleanly without jutting boxes
    for side in (-1.0, 1.0):
        z = side * (width * 0.5 + 0.07)
        add_game_box(bm_cheeks, -0.58, -0.50, z, 1.38, 0.72, 0.22, bevel=0.03)
        add_game_box(bm_cheeks, 0.62, -0.92, z, 1.32, 0.74, 0.22, bevel=0.03)

    finalize_mesh("river_stairs_treads", bm_stone, mats["CobbleStone"], smooth=True, box_uv_scale=0.55)
    finalize_mesh("river_stairs_cheeks", bm_cheeks, mats["IshigakiStone"], smooth=True, box_uv_scale=0.45)
    export_glb("edo_river_stairs.glb")


def build_rock_coastal_shelf() -> None:
    """Wide, low tiered granite shelf & pebble-bank rocks straddling ocean waterlines organically."""
    clear_scene()
    mats = get_materials()
    bm = bmesh.new()
    specs = [
        ((0.0, -0.08, 0.0), (2.85, 0.86, 2.15), 601),
        ((-2.05, 0.14, -0.85), (1.75, 0.92, 1.55), 602),
        ((1.85, -0.34, 0.72), (1.55, 0.58, 1.48), 603),
        ((-0.65, -0.28, 1.65), (1.35, 0.48, 1.15), 604),
        ((0.95, 0.10, -1.35), (1.42, 0.66, 1.24), 605),
        ((2.55, -0.52, -0.35), (1.15, 0.40, 1.05), 606),
    ]
    for ctr, rad, sd in specs:
        _sculpted_rock_lobe(
            bm,
            ctr,
            rad,
            seed=sd,
            subdivisions=3,
            strata_steps=4.8,
            flatten_bottom=False,
        )
    finalize_mesh("rock_coastal_shelf", bm, mats["CliffRock"], smooth=True, box_uv_scale=0.34)
    export_glb("rock_coastal_shelf.glb")


def build_rock_river_cobble_bar() -> None:
    """Wide low cluster of river anchor boulders & water-tumbled cobbles straddling shallow margins."""
    clear_scene()
    mats = get_materials()
    bm_anchor = bmesh.new()
    bm_cobbles = bmesh.new()

    anchor_specs = [
        ((-0.12, 0.00, 0.10), (0.68, 0.24, 0.74), 701, 1.8),
        ((0.36, -0.04, -0.82), (0.56, 0.21, 0.64), 702, 2.0),
        ((-0.38, 0.02, 1.02), (0.52, 0.20, 0.58), 703, 1.7),
        ((0.46, -0.06, 0.86), (0.48, 0.19, 0.54), 704, 2.2),
        ((-0.44, -0.04, -1.04), (0.48, 0.19, 0.52), 705, 1.6),
    ]
    for ctr, rad, sd, strata in anchor_specs:
        _sculpted_rock_lobe(
            bm_anchor,
            ctr,
            rad,
            seed=sd,
            subdivisions=3,
            strata_steps=strata,
            flatten_bottom=False,
        )

    cobble_specs = [
        ((-0.78, -0.05, 0.34), (0.34, 0.14, 0.38), 711, 1.0),
        ((0.76, -0.08, -0.18), (0.36, 0.15, 0.40), 712, 1.2),
        ((-0.08, -0.03, -1.36), (0.38, 0.14, 0.32), 713, 0.9),
        ((0.12, -0.04, 1.38), (0.34, 0.14, 0.30), 714, 1.1),
        ((-0.76, -0.07, -0.58), (0.30, 0.13, 0.34), 715, 1.3),
        ((0.78, -0.08, 0.44), (0.28, 0.12, 0.32), 716, 0.8),
        ((-0.14, 0.03, -0.54), (0.30, 0.12, 0.28), 717, 1.4),
        ((0.22, 0.02, 0.42), (0.28, 0.12, 0.28), 718, 1.1),
        ((-0.64, -0.06, 1.24), (0.26, 0.11, 0.28), 719, 1.0),
    ]
    for ctr, rad, sd, strata in cobble_specs:
        _sculpted_rock_lobe(
            bm_cobbles,
            ctr,
            rad,
            seed=sd,
            subdivisions=2,
            strata_steps=strata,
            flatten_bottom=False,
        )

    finalize_mesh("river_cobble_anchors", bm_anchor, mats["CliffRock"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("river_cobble_stones", bm_cobbles, mats["CobbleStone"], smooth=True, box_uv_scale=0.60)
    export_glb("rock_river_cobble_bar.glb")


def build_rock_bank_ledge() -> None:
    """Stepped mossy granite bank outcrop (~3.2m along Z x ~2.1m along X x ~1.15m high)."""
    clear_scene()
    mats = get_materials()
    bm = bmesh.new()

    ledge_specs = [
        ((-0.24, 0.18, 0.05), (0.78, 0.38, 1.08), 801, 5.6),
        ((-0.18, 0.26, -0.96), (0.68, 0.34, 0.64), 802, 5.2),
        ((-0.14, 0.12, 1.02), (0.64, 0.30, 0.60), 803, 6.0),
        ((0.46, -0.06, -0.28), (0.58, 0.28, 0.84), 804, 5.8),
        ((0.52, -0.14, 0.68), (0.52, 0.24, 0.68), 805, 6.2),
    ]
    for ctr, rad, sd, strata in ledge_specs:
        _sculpted_rock_lobe(
            bm,
            ctr,
            rad,
            seed=sd,
            subdivisions=3,
            strata_steps=strata,
            flatten_bottom=False,
        )

    finalize_mesh("rock_bank_ledge", bm, mats["CliffRock"], smooth=True, box_uv_scale=0.36)
    export_glb("rock_bank_ledge.glb")


def build_all() -> None:
    build_rock_river_boulder()
    build_rock_shore_riprap()
    build_rock_cliff_a()
    build_rock_cliff_b()
    build_rock_coastal_headland()
    build_rock_coastal_shelf()
    build_rock_river_cobble_bar()
    build_rock_bank_ledge()
    build_edo_river_stairs()


if __name__ == "__main__":
    build_all()
