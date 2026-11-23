"""Organic Edo botanical trees: curved Bezier trunks, draped willow curtains & layered leaf domes."""

from __future__ import annotations

import math
import random

import bmesh
from mathutils import Euler, Matrix, Vector

from common import (
    add_game_cylinder,
    add_swept_tube,
    clear_scene,
    export_glb,
    finalize_mesh,
    g2b,
    get_materials,
    set_face_uv_quad,
)


def _add_curved_foliage_dome(
    bm: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radius_x: float,
    radius_z: float,
    arch_y: float,
    *,
    yaw: float = 0.0,
    tilt_x: float = 0.0,
    tilt_z: float = 0.0,
    segs_u: int = 5,
    segs_v: int = 5,
) -> None:
    """Adds a gently arched botanical leaf-pad dome mapped cleanly over UV [0..1]^2 (no flat boxes!)."""
    uv_layer = bm.loops.layers.uv.verify()
    rot = Euler((tilt_x, yaw, tilt_z), "YXZ").to_matrix()
    ctr = Vector(center)
    grid: list[list[bmesh.types.BMVert]] = []
    for iv in range(segs_v + 1):
        v = iv / segs_v
        lz = (v * 2.0 - 1.0) * radius_z
        row: list[bmesh.types.BMVert] = []
        for iu in range(segs_u + 1):
            u = iu / segs_u
            lx = (u * 2.0 - 1.0) * radius_x
            r2 = min(1.3, ((u * 2.0 - 1.0) ** 2 + (v * 2.0 - 1.0) ** 2) * 0.62)
            ly = arch_y * (1.0 - r2)
            local_g = rot @ Vector((lx, ly, lz)) + ctr
            row.append(bm.verts.new(g2b(local_g.x, local_g.y, local_g.z)))
        grid.append(row)

    for iv in range(segs_v):
        for iu in range(segs_u):
            f = bm.faces.new((grid[iv][iu], grid[iv][iu + 1], grid[iv + 1][iu + 1], grid[iv + 1][iu]))
            set_face_uv_quad(f, uv_layer, iu / segs_u, iv / segs_v, (iu + 1) / segs_u, (iv + 1) / segs_v)


def _add_crossed_foliage_cluster(
    bm: bmesh.types.BMesh,
    center: tuple[float, float, float],
    size: float,
    height: float,
    seed: int,
) -> None:
    """Organic 4-shell layered branch cluster (top dome + 3 steeper crossed silhouette tufts)."""
    rng = random.Random(seed)
    yaw0 = rng.uniform(0.0, 6.28)
    _add_curved_foliage_dome(bm, center, size * 0.85, size * 0.78, height * 0.36, yaw=yaw0, tilt_x=0.14)
    _add_curved_foliage_dome(bm, (center[0] + size * 0.14, center[1] - height * 0.12, center[2] - size * 0.10), size * 0.75, size * 0.70, height * 0.32, yaw=yaw0 + 1.05, tilt_x=-0.38, tilt_z=0.28)
    _add_curved_foliage_dome(bm, (center[0] - size * 0.14, center[1] - height * 0.10, center[2] + size * 0.12), size * 0.72, size * 0.68, height * 0.30, yaw=yaw0 - 1.15, tilt_x=0.35, tilt_z=-0.30)
    _add_curved_foliage_dome(bm, (center[0] + size * 0.04, center[1] - height * 0.08, center[2] + size * 0.05), size * 0.70, size * 0.66, height * 0.42, yaw=yaw0 + 2.15, tilt_x=0.58, tilt_z=0.42)


def build_tree_pine_bonsai() -> None:
    """Sculpted windswept Edo kuromatsu pine with gnarly limbs & crisp layered cloud pads."""
    clear_scene()
    mats = get_materials()
    bm_bark = bmesh.new()
    bm_leaf = bmesh.new()

    # Sinuous main trunk anchored down to y=-0.52
    trunk_pts = [(0.0, -0.52, 0.0), (0.14, 0.45, -0.08), (0.38, 1.85, -0.20), (-0.12, 3.25, 0.18), (0.28, 4.75, -0.15), (0.05, 5.75, 0.05)]
    trunk_rad = [0.34, 0.25, 0.20, 0.16, 0.12, 0.07]
    add_swept_tube(bm_bark, trunk_pts, trunk_rad, segments=12)

    # Flared surface roots gripping soil cleanly
    for ang, reach in ((0.2, 0.85), (2.2, 0.78), (4.3, 0.82)):
        rx, rz = math.cos(ang) * reach, math.sin(ang) * reach
        add_swept_tube(bm_bark, [(0.0, 0.08, 0.0), (rx * 0.55, -0.18, rz * 0.55), (rx, -0.48, rz)], [0.16, 0.10, 0.05], segments=8)

    # Asymmetric sculpted cloud-pruned limbs + 3D volumetric niwaki cloud tufts (no thin flat plates!)
    limbs = [
        ([(0.24, 2.25, -0.12), (1.35, 2.65, -0.45), (2.35, 2.92, -0.68)], (2.38, 3.12, -0.72), 1.62, 11),
        ([(0.05, 3.00, 0.12), (-1.15, 3.45, 0.62), (-2.15, 3.72, 0.95)], (-2.22, 3.92, 1.00), 1.70, 12),
        ([(0.10, 3.85, 0.02), (0.65, 4.28, 1.25), (1.15, 4.56, 2.02)], (1.20, 4.78, 2.08), 1.52, 13),
        ([(0.18, 4.45, -0.10), (-0.88, 4.82, -1.20), (-1.52, 5.08, -1.78)], (-1.55, 5.28, -1.82), 1.44, 14),
        ([(0.12, 5.15, 0.00), (0.05, 5.75, 0.05)], (0.08, 6.12, 0.06), 1.90, 15),
    ]
    for pts, pad_ctr, pad_sz, sd in limbs:
        add_swept_tube(bm_bark, pts, [0.12 - 0.02 * i for i in range(len(pts))], segments=8)
        _add_crossed_foliage_cluster(bm_leaf, pad_ctr, pad_sz * 0.92, pad_sz * 0.65, seed=sd)
        _add_curved_foliage_dome(bm_leaf, (pad_ctr[0], pad_ctr[1] + 0.16, pad_ctr[2]), pad_sz * 0.84, pad_sz * 0.78, 0.68, yaw=sd * 0.9, segs_u=6, segs_v=6)
    # Extra inner shoulder cloud tuft near fork so crown reads full from eye-level angles
    _add_crossed_foliage_cluster(bm_leaf, (-0.15, 4.85, 0.12), 1.38, 0.95, seed=19)
    _add_crossed_foliage_cluster(bm_leaf, (0.72, 3.62, 0.45), 1.48, 0.92, seed=23)
    _add_crossed_foliage_cluster(bm_leaf, (-0.82, 4.35, -0.32), 1.42, 0.88, seed=29)

    finalize_mesh("pine_trunk", bm_bark, mats["PineBark"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("pine_canopy", bm_leaf, mats["PineFoliage"], smooth=True, box_uv_scale=None)
    export_glb("tree_pine_bonsai.glb", has_alpha=True)


def build_tree_maple(is_gold: bool, filename: str) -> None:
    """Open asymmetric Japanese momiji maple with bifurcated boughs & natural spray fans (no spherical pom-poms!)."""
    clear_scene()
    mats = get_materials()
    bm_bark = bmesh.new()
    bm_leaf = bmesh.new()

    trunk = [(0.0, -0.46, 0.0), (-0.08, 0.55, 0.06), (0.12, 1.55, -0.08), (0.02, 2.35, 0.05)]
    add_swept_tube(bm_bark, trunk, [0.28, 0.21, 0.17, 0.13], segments=10)
    for ang, reach in ((0.6, 0.68), (2.7, 0.72), (4.8, 0.65)):
        add_swept_tube(bm_bark, [(0.0, 0.05, 0.0), (math.cos(ang) * reach, -0.44, math.sin(ang) * reach)], [0.14, 0.04], segments=6)

    boughs = [
        ([(0.05, 1.85, 0.00), (1.05, 2.65, 0.45), (1.85, 3.15, 0.85)], (1.95, 3.30, 0.92), 1.48, 201),
        ([(0.02, 2.05, 0.02), (-1.15, 2.85, 0.35), (-1.95, 3.38, 0.52)], (-2.05, 3.55, 0.55), 1.52, 202),
        ([(0.00, 2.20, 0.05), (0.35, 3.15, -1.15), (0.65, 3.72, -1.85)], (0.68, 3.88, -1.92), 1.45, 203),
        ([(0.02, 2.25, 0.04), (-0.42, 3.25, -1.05), (-0.78, 3.82, -1.62)], (-0.82, 4.02, -1.70), 1.38, 204),
        ([(0.02, 2.35, 0.05), (0.12, 3.65, 0.18), (0.18, 4.42, 0.28)], (0.18, 4.55, 0.30), 1.56, 205),
    ]
    for pts, ctr, sz, sd in boughs:
        add_swept_tube(bm_bark, pts, [0.11, 0.08, 0.05], segments=8)
        _add_crossed_foliage_cluster(bm_leaf, ctr, sz, 0.92, seed=sd)
    # Central mid-canopy fill tufts so maples silhouette organically from steep aerial cameras
    _add_crossed_foliage_cluster(bm_leaf, (-0.45, 3.65, 0.42), 1.46, 0.95, seed=211)
    _add_crossed_foliage_cluster(bm_leaf, (0.55, 3.88, -0.35), 1.42, 0.90, seed=217)

    leaf_mat = mats["MapleGoldFoliage"] if is_gold else mats["MapleCrimsonFoliage"]
    finalize_mesh("maple_trunk", bm_bark, mats["MapleBark"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("maple_canopy", bm_leaf, leaf_mat, smooth=True, box_uv_scale=None)
    export_glb(filename, has_alpha=True)


def _add_curved_willow_curtain(
    bm: bmesh.types.BMesh,
    cx: float,
    cy_top: float,
    cz: float,
    arc_radius: float,
    drop_height: float,
    yaw: float,
    arc_span: float = 1.65,
) -> None:
    """Draps a smoothly curved cylindrical curtain ribbon of willow fronds without flat sharp card corners."""
    uv_layer = bm.loops.layers.uv.verify()
    u_segs = 8
    v_segs = 7
    grid: list[list[bmesh.types.BMVert]] = []
    for iv in range(v_segs + 1):
        v = iv / v_segs  # 0 bottom tip -> 1 top arch crown
        # Slight inward bell curve at top crown + outward gentle breeze flare below
        r = arc_radius * (0.55 + 0.45 * math.sin((1.0 - v * 0.72) * math.pi * 0.5))
        y = cy_top - (1.0 - v) * drop_height
        row: list[bmesh.types.BMVert] = []
        for iu in range(u_segs + 1):
            u = iu / u_segs
            ang = yaw + (u - 0.5) * arc_span
            x = cx + math.cos(ang) * r
            z = cz + math.sin(ang) * r
            row.append(bm.verts.new(g2b(x, y, z)))
        grid.append(row)

    for iv in range(v_segs):
        for iu in range(u_segs):
            f = bm.faces.new((grid[iv][iu], grid[iv][iu + 1], grid[iv + 1][iu + 1], grid[iv + 1][iu]))
            set_face_uv_quad(f, uv_layer, iu / u_segs, iv / v_segs, (iu + 1) / u_segs, (iv + 1) / v_segs)


def build_tree_willow_weeping() -> None:
    """Leaning riverside willow with swept overarching branches & curved cylindrical frond curtains."""
    clear_scene()
    mats = get_materials()
    bm_bark = bmesh.new()
    bm_leaf = bmesh.new()

    trunk = [(0.0, -0.50, 0.0), (0.34, 0.95, 0.16), (0.72, 2.65, 0.28), (0.52, 4.15, 0.14)]
    add_swept_tube(bm_bark, trunk, [0.32, 0.25, 0.19, 0.13], segments=10)
    # 5 overarching weeping boughs + smooth cylindrical curtains hanging cleanly down
    bough_angles = [0.0, 1.25, 2.48, 3.72, 5.02]
    for idx, ang in enumerate(bough_angles):
        bx = 0.52 + math.cos(ang) * 1.85
        bz = 0.18 + math.sin(ang) * 1.85
        add_swept_tube(bm_bark, [(0.52, 3.65, 0.18), (0.52 + math.cos(ang) * 0.95, 4.68, 0.18 + math.sin(ang) * 0.95), (bx, 4.25, bz)], [0.11, 0.075, 0.04], segments=8)
        _add_curved_willow_curtain(bm_leaf, 0.52, 5.05 + (idx % 2) * 0.25, 0.18, arc_radius=1.95 + (idx % 2) * 0.25, drop_height=3.95, yaw=ang, arc_span=1.65)
        _add_curved_willow_curtain(bm_leaf, 0.52, 5.38, 0.18, arc_radius=1.18, drop_height=3.35, yaw=ang + 0.52, arc_span=1.80)

    finalize_mesh("willow_trunk", bm_bark, mats["WillowBark"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("willow_canopy", bm_leaf, mats["WillowFoliage"], smooth=True, box_uv_scale=None)
    export_glb("tree_willow_weeping.glb", has_alpha=True)


def build_tree_bamboo_clump() -> None:
    """Cluster of 16 jointed tapering bamboo culms with delicate top leaf fans."""
    clear_scene()
    mats = get_materials()
    bm_culm = bmesh.new()
    bm_leaf = bmesh.new()
    rng = random.Random(719)

    for i in range(16):
        ang = (i / 16.0) * math.pi * 2.0 + rng.uniform(-0.18, 0.18)
        dist = 0.22 + (i % 4) * 0.34
        bx = math.cos(ang) * dist
        bz = math.sin(ang) * dist
        h = 7.4 + rng.uniform(-0.8, 2.8)
        lean_x = math.cos(ang) * rng.uniform(0.35, 1.15)
        lean_z = math.sin(ang) * rng.uniform(0.35, 1.15)
        pts = [
            (bx, -0.22, bz),
            (bx + lean_x * 0.18, h * 0.32, bz + lean_z * 0.18),
            (bx + lean_x * 0.54, h * 0.68, bz + lean_z * 0.54),
            (bx + lean_x, h, bz + lean_z),
        ]
        add_swept_tube(bm_culm, pts, [0.085, 0.072, 0.058, 0.044], segments=8)
        # Jointed node collar rings along lower 2/3
        for frac in (0.14, 0.28, 0.44, 0.60):
            nx = bx + lean_x * (frac * frac)
            nz = bz + lean_z * (frac * frac)
            add_game_cylinder(bm_culm, nx, h * frac, nz, 0.092 - 0.02 * frac, 0.092 - 0.02 * frac, 0.055, segments=8)
        # Leaf fans in upper crown (shielding upper culms against horizon peaks)
        top_ctr = (bx + lean_x * 0.92, h * 0.90, bz + lean_z * 0.92)
        mid_ctr = (bx + lean_x * 0.76, h * 0.78, bz + lean_z * 0.76)
        _add_crossed_foliage_cluster(bm_leaf, top_ctr, 1.32, 0.80, seed=800 + i)
        _add_crossed_foliage_cluster(bm_leaf, mid_ctr, 1.14, 0.68, seed=900 + i)

    finalize_mesh("bamboo_culms", bm_culm, mats["BambooCulm"], smooth=True, box_uv_scale=0.8)
    finalize_mesh("bamboo_canopy", bm_leaf, mats["BambooFoliage"], smooth=True, box_uv_scale=None)
    export_glb("tree_bamboo_clump.glb", has_alpha=True)


def build_tree_shrub_cluster() -> None:
    """Lush multi-mound woody Japanese hillside & courtyard shrub cluster (has_alpha=True)."""
    clear_scene()
    mats = get_materials()
    bm_bark = bmesh.new()
    bm_leaf = bmesh.new()
    rng = random.Random(509)

    mounds = [
        ((0.0, 0.65, 0.0), 1.18, 0.92, 51),
        ((-0.82, 0.48, 0.45), 0.92, 0.74, 52),
        ((0.86, 0.52, -0.38), 0.96, 0.78, 53),
        ((0.28, 0.44, 0.78), 0.85, 0.68, 54),
        ((-0.42, 0.46, -0.74), 0.88, 0.70, 55),
    ]
    for (cx, cy, cz), sz, ht, sd in mounds:
        add_swept_tube(
            bm_bark,
            [(cx * 0.25, -0.25, cz * 0.25), (cx * 0.68, cy * 0.45, cz * 0.68), (cx, cy * 0.88, cz)],
            [0.09, 0.06, 0.035],
            segments=6,
        )
        _add_crossed_foliage_cluster(bm_leaf, (cx, cy, cz), sz, ht, seed=sd + rng.randint(0, 10))
        _add_curved_foliage_dome(
            bm_leaf,
            (cx, cy + ht * 0.14, cz),
            sz * 0.84,
            sz * 0.78,
            ht * 0.42,
            yaw=sd * 0.7,
            segs_u=5,
            segs_v=5,
        )

    finalize_mesh("shrub_twigs", bm_bark, mats["WillowBark"], smooth=True, box_uv_scale=0.7)
    finalize_mesh("shrub_canopy", bm_leaf, mats["PineFoliage"], smooth=True, box_uv_scale=None)
    export_glb("tree_shrub_cluster.glb", has_alpha=True)


def build_all() -> None:
    build_tree_pine_bonsai()
    build_tree_maple(False, "tree_maple_hero.glb")
    build_tree_maple(True, "tree_maple_gold.glb")
    build_tree_willow_weeping()
    build_tree_bamboo_clump()
    build_tree_shrub_cluster()


if __name__ == "__main__":
    build_all()
