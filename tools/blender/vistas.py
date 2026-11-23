"""High-res ridged horizon mountains & pine-crowned rocky Minato sea-stack islands."""

from __future__ import annotations

import math
import random

import bmesh
from mathutils import Vector

from common import (
    add_swept_tube,
    clear_scene,
    export_glb,
    finalize_mesh,
    g2b,
    get_materials,
)
from nature_trees import _add_crossed_foliage_cluster


def _ridged_fbm(x: float, z: float, seed: float) -> tuple[float, float]:
    """Returns natural multi-peak undulating alpine massif elevation & valley AO."""
    acc = 0.0
    amp = 0.56
    freq = 1.0
    gully = 1.0
    for oct_i in range(4):
        px = x * freq + seed * (oct_i + 1) * 1.9
        pz = z * freq - seed * (oct_i + 1) * 1.4
        # Smooth warped sinusoidal massif + complementary secondary peak harmonics
        w1 = math.sin(px * 0.022 + math.cos(pz * 0.019) * 1.45)
        w2 = math.cos(pz * 0.025 - math.sin(px * 0.021) * 1.35)
        billow = 0.5 + 0.5 * math.sin(0.55 * (w1 + w2) * 1.25)
        s_sq = (0.5 * (w1 + w2)) ** 2
        rounded_crest = 1.0 - math.sqrt(s_sq + 0.04) * 0.92
        primary_massif = 0.62 * billow + 0.38 * max(0.0, rounded_crest)

        p2x = x * freq * 1.55 + seed * (oct_i + 2) * 2.3
        p2z = z * freq * 1.48 - seed * (oct_i + 1) * 2.1
        m1 = math.sin(p2x * 0.029 - math.cos(p2z * 0.024) * 1.3)
        m2 = math.cos(p2z * 0.031 + math.sin(p2x * 0.027) * 1.2)
        multi_peak_ridges = 0.5 + 0.5 * math.sin((m1 - m2) * 0.85)
        val = 0.52 * primary_massif + 0.48 * multi_peak_ridges

        acc += val * amp
        if oct_i < 2:
            gully = min(gully, 0.36 + 0.64 * val)
        freq *= 1.92
        amp *= 0.44
    return min(1.0, max(0.0, acc)), min(1.0, max(0.35, gully))


def _set_vista_vertex_colors(
    bm: bmesh.types.BMesh,
    heights_01: dict[bmesh.types.BMVert, tuple[float, float, float]],
    outer_tier: float,
) -> None:
    """Packs (normElev, gullyAo, sunRim, outerTier) into CORNER color layer for MountainVista shader."""
    col_layer = bm.loops.layers.color.verify()
    for face in bm.faces:
        for loop in face.loops:
            norm_e, gully_ao, sun_rim = heights_01[loop.vert]
            loop[col_layer] = (norm_e, gully_ao, sun_rim, outer_tier)


def _build_mountain_arc(
    name: str,
    r_inner: float,
    r_outer: float,
    theta0: float,
    theta1: float,
    max_height: float,
    y_floor: float,
    outer_tier: float,
    seed: float,
    mats: dict,
    *,
    rad_segs: int = 24,
    ang_segs: int = 28,
) -> None:
    """Sculpts a high-resolution ridged mountain range sector preserving outer boundary continuity."""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.verify()
    vdata: dict[bmesh.types.BMVert, tuple[float, float, float]] = {}
    grid: list[list[bmesh.types.BMVert]] = []

    for ir in range(rad_segs + 1):
        u = ir / rad_segs  # 0 inner skirt -> 1 outer base
        r = r_inner + (r_outer - r_inner) * u
        # Smooth arch profile fading to floor at both inner edge (u=0) and outer edge (u=1)
        envelope = math.sin(u * math.pi) ** 1.15
        row: list[bmesh.types.BMVert] = []
        for ia in range(ang_segs + 1):
            v = ia / ang_segs
            th = theta0 + (theta1 - theta0) * v
            x = math.cos(th) * r
            z = math.sin(th) * r
            ang_fade = math.sin(v * math.pi) ** 0.35
            ridge, gully = _ridged_fbm(x, z, seed)
            norm_e = min(1.0, ridge * envelope * (0.45 + 0.55 * ang_fade) * 1.15)
            y = y_floor + norm_e * (max_height - y_floor)
            vert = bm.verts.new(g2b(x, y, z))
            # Sunward rim estimate toward golden dusk azimuth (+X, -Z)
            sun_rim = max(0.0, min(1.0, (0.85 * math.cos(th) - 0.44 * math.sin(th)) * 0.5 + 0.5)) * norm_e
            vdata[vert] = (norm_e, gully, sun_rim)
            row.append(vert)
        grid.append(row)

    for ir in range(rad_segs):
        for ia in range(ang_segs):
            f = bm.faces.new((grid[ir][ia], grid[ir][ia + 1], grid[ir + 1][ia + 1], grid[ir + 1][ia]))
            # Smooth continuous world-scaled UV (approx 16m per tile -> fine crisp strata)
            uvs = [
                (ir / rad_segs * 3.5, ia / ang_segs * 4.5),
                (ir / rad_segs * 3.5, (ia + 1) / ang_segs * 4.5),
                ((ir + 1) / rad_segs * 3.5, (ia + 1) / ang_segs * 4.5),
                ((ir + 1) / rad_segs * 3.5, ia / ang_segs * 4.5),
            ]
            for loop, uv in zip(f.loops, uvs):
                loop[uv_layer].uv = uv

    _set_vista_vertex_colors(bm, vdata, outer_tier)
    finalize_mesh(name, bm, mats["MountainVistaMat"], smooth=True, box_uv_scale=None)


def build_vista_mountains() -> None:
    """High-res ridged horizon mountain ring matching Shukuba Valley [-290, 290] bounds."""
    clear_scene()
    mats = get_materials()
    # Keep western & northern high ranges towering cleanly (34..61m), lower golden eastern pass
    inner_heights = [22.0, 21.5, 20.0, 34.4, 24.0, 23.5, 11.5, 18.5]
    outer_heights = [56.5, 54.0, 44.5, 61.5, 50.5, 34.0, 26.0, 31.0]
    for s in range(8):
        th0 = s * (math.pi / 4.0)
        th1 = (s + 1) * (math.pi / 4.0)
        _build_mountain_arc(
            f"vista_foothills_s{s}",
            r_inner=84.0, r_outer=198.0, theta0=th0, theta1=th1,
            max_height=inner_heights[s], y_floor=-6.0, outer_tier=0.0,
            seed=12.3 + s * 3.7, mats=mats, rad_segs=30, ang_segs=48,
        )
        _build_mountain_arc(
            f"vista_outer_peaks_s{s}",
            r_inner=126.0, r_outer=290.0, theta0=th0, theta1=th1,
            max_height=outer_heights[s], y_floor=-10.0, outer_tier=1.0,
            seed=41.9 + s * 5.3, mats=mats, rad_segs=36, ang_segs=64,
        )
    export_glb("vista_mountains.glb")


def _build_rocky_bay_island(
    name: str,
    pine_name: str,
    cx: float,
    cz: float,
    rad_x: float,
    rad_z: float,
    height: float,
    yaw: float,
    seed: int,
    mats: dict,
    bm_pine_bark: bmesh.types.BMesh,
    bm_pine_leaf: bmesh.types.BMesh,
) -> None:
    """Sculpts a terraced craggy sea-stack islet & adds natural pines crowning its ridge."""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.verify()
    vdata: dict[bmesh.types.BMVert, tuple[float, float, float]] = {}

    rings = 24
    segs = 44
    grid: list[list[bmesh.types.BMVert]] = []
    ca, sa = math.cos(yaw), math.sin(yaw)

    for ir in range(rings + 1):
        u = ir / rings  # 0 summit -> 1 underwater skirt (-7.5m)
        row: list[bmesh.types.BMVert] = []
        for ia in range(segs + 1):
            th = (ia / segs) * math.pi * 2.0
            # Irregular rocky peninsula coastline lobes (non-circular!)
            coast_lobe = (
                1.0
                + 0.24 * math.sin(th * 3.0 + seed)
                + 0.14 * math.cos(th * 5.0 - seed * 0.7)
                + 0.08 * math.sin(th * 7.0 + seed * 1.4)
            )
            r_norm = u * coast_lobe
            lx = math.cos(th) * rad_x * r_norm
            lz = math.sin(th) * rad_z * r_norm
            wx = cx + lx * ca - lz * sa
            wz = cz + lx * sa + lz * ca

            ridge, gully = _ridged_fbm(wx * 2.6, wz * 2.6, float(seed))
            # Steep terraced coastal sea-stack cliffs + secondary rocky spur lobes
            cliff_profile = max(0.0, (1.0 - (u ** 1.65)))
            strata = 0.09 * math.sin(u * 16.0 + ridge * 3.2) * (1.0 - u)
            terraced = cliff_profile * (0.52 + 0.48 * ridge) + max(0.0, strata) * cliff_profile
            shoulder = 0.34 * math.exp(-((u - 0.36) ** 2) * 16.0) * max(0.0, math.sin(th * 2.0 + seed))
            spur = 0.22 * math.exp(-((u - 0.56) ** 2) * 20.0) * max(0.0, math.cos(th * 3.0 - seed * 0.8))
            raw_e = terraced * 0.74 + shoulder * 0.80 + spur * 0.72
            norm_e = raw_e / (1.0 + max(0.0, raw_e - 0.72) * 0.85)
            y = -7.4 + norm_e * (height + 7.4)

            vert = bm.verts.new(g2b(wx, y, wz))
            sun_rim = max(0.0, min(1.0, (0.85 * math.cos(th) - 0.44 * math.sin(th)) * 0.5 + 0.5)) * norm_e
            vdata[vert] = (norm_e, gully, sun_rim)
            row.append(vert)
        grid.append(row)

    for ir in range(rings):
        for ia in range(segs):
            f = bm.faces.new((grid[ir][ia], grid[ir + 1][ia], grid[ir + 1][ia + 1], grid[ir][ia + 1]))
            uvs = [
                (ir / rings * 10.0, ia / segs * 18.0),
                ((ir + 1) / rings * 10.0, ia / segs * 18.0),
                ((ir + 1) / rings * 10.0, (ia + 1) / segs * 18.0),
                (ir / rings * 10.0, (ia + 1) / segs * 18.0),
            ]
            for loop, uv in zip(f.loops, uvs):
                loop[uv_layer].uv = uv

    _set_vista_vertex_colors(bm, vdata, 0.25)
    finalize_mesh(name, bm, mats["CliffRock"], smooth=True, box_uv_scale=None)

    # Crown rugged summit & shoulders with windswept 3D pine clusters cleanly anchored into rock!
    rng = random.Random(seed)
    tree_count = 6
    for ti in range(tree_count):
        ang = rng.uniform(0.0, math.pi * 2.0)
        frac = 0.08 + 0.26 * (ti / tree_count)
        lx = math.cos(ang) * rad_x * frac
        lz = math.sin(ang) * rad_z * frac
        wx = cx + lx * ca - lz * sa
        wz = cz + lx * sa + lz * ca
        base_y = max(1.6, height * (1.0 - frac * 1.45) - 0.6)
        th = rng.uniform(2.5, 4.2)
        lean_x = rng.uniform(-0.8, 0.8)
        lean_z = rng.uniform(-0.8, 0.8)
        add_swept_tube(
            bm_pine_bark,
            [(wx, base_y - 1.2, wz), (wx + lean_x * 0.4, base_y + th * 0.5, wz + lean_z * 0.4), (wx + lean_x, base_y + th, wz + lean_z)],
            [0.38, 0.26, 0.14],
            segments=7,
        )
        sz_crown = rng.uniform(2.4, 3.4)
        h_crown = rng.uniform(1.6, 2.3)
        _add_crossed_foliage_cluster(bm_pine_leaf, (wx + lean_x, base_y + th + 0.35, wz + lean_z), sz_crown, h_crown, seed=seed * 31 + ti)
        _add_crossed_foliage_cluster(bm_pine_leaf, (wx + lean_x * 0.5 + 0.6, base_y + th * 0.72, wz + lean_z * 0.5 - 0.5), sz_crown * 0.78, h_crown * 0.82, seed=seed * 47 + ti)


def build_minato_coastal_islands() -> None:
    """Craggy Minato landward headlands + pine-crowned bay rocky sea-stack islands."""
    clear_scene()
    mats = get_materials()

    # Landward coastal mountain ranges (West, Northwest, Southwest)
    landward_sectors = [
        ("minato_landward_inner_0", 88.0, 215.0, 1.38, 2.38, 26.5, -6.2, 0.0, 71.1),
        ("minato_landward_inner_1", 86.0, 216.0, 2.38, 3.72, 27.2, -6.2, 0.0, 82.4),
        ("minato_landward_inner_2", 86.0, 215.0, 3.72, 4.92, 24.2, -6.2, 0.0, 93.7),
        ("minato_landward_outer_0", 136.0, 277.0, 1.36, 2.38, 38.0, -9.6, 1.0, 104.2),
        ("minato_landward_outer_1", 136.0, 278.0, 2.38, 3.74, 38.2, -9.6, 1.0, 115.6),
        ("minato_landward_outer_2", 136.0, 277.0, 3.74, 4.94, 39.4, -9.6, 1.0, 127.3),
    ]
    for nm, ri, ro, t0, t1, mh, yf, ot, sd in landward_sectors:
        _build_mountain_arc(nm, ri, ro, t0, t1, mh, yf, ot, sd, mats, rad_segs=30, ang_segs=52)

    # Bay sea-stack islands (dramatic pine-crested craggy coastal islands in East/NE/SE harbor waters)
    bm_pine_bark = bmesh.new()
    bm_pine_leaf = bmesh.new()
    bay_islands = [
        ("minato_bay_islands_0", "IslandPine_0", 112.0, -108.0, 28.0, 22.0, 13.5, 0.42, 301),
        ("minato_bay_islands_0b", "IslandPine_0b", 168.0, -142.0, 36.0, 26.0, 15.8, -0.35, 302),
        ("minato_bay_islands_1", "IslandPine_1", 164.0, 48.0, 32.0, 25.0, 14.2, 0.78, 303),
        ("minato_bay_islands_2", "IslandPine_2", 78.0, 136.0, 26.0, 20.0, 11.2, -0.62, 304),
    ]
    for nm, pnm, cx, cz, rx, rz, h, yw, sd in bay_islands:
        _build_rocky_bay_island(nm, pnm, cx, cz, rx, rz, h, yw, sd, mats, bm_pine_bark, bm_pine_leaf)

    finalize_mesh("IslandPine_Bark", bm_pine_bark, mats["PineBark"], smooth=True, box_uv_scale=0.5)
    finalize_mesh("IslandPine_Canopy", bm_pine_leaf, mats["PineFoliage"], smooth=True, box_uv_scale=None)
    export_glb("minato_coastal_islands.glb", has_alpha=True)


def build_all() -> None:
    build_vista_mountains()
    build_minato_coastal_islands()


if __name__ == "__main__":
    build_all()
