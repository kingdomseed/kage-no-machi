"""Smooth sculpted Edo character archetypes with articulated hip/waist pivots."""

from __future__ import annotations

import math
from typing import Sequence

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

from common import clear_scene, export_glb, finalize_mesh, g2b, get_materials


def _c2b(x: float, y_up: float, z: float) -> Vector:
    """Proper 180-deg Y rotation before g2b so glTF export + flutter_scene Z-flip
    lands in native left-handed flutter_scene space as (-X=right, Y=up, +Z=front)."""
    return g2b(-x, y_up, -z)


def _slot_index(mat_list: list[bpy.types.Material], mat: bpy.types.Material) -> int:
    for idx, existing in enumerate(mat_list):
        if existing == mat:
            return idx
    mat_list.append(mat)
    return len(mat_list) - 1


def _assign_new_faces(
    bm: bmesh.types.BMesh,
    prev_face_count: int,
    mat_idx: int,
) -> None:
    bm.faces.ensure_lookup_table()
    for i in range(prev_face_count, len(bm.faces)):
        bm.faces[i].material_index = mat_idx


def _add_ellipsoid(
    bm: bmesh.types.BMesh,
    center: tuple[float, float, float],
    radii: tuple[float, float, float],
    mat_idx: int,
    *,
    rot_euler: tuple[float, float, float] = (0.0, 0.0, 0.0),
    u_segs: int = 16,
    v_segs: int = 12,
) -> None:
    prev = len(bm.faces)
    ret = bmesh.ops.create_uvsphere(bm, u_segments=u_segs, v_segments=v_segs, radius=1.0)
    rot_m = Euler(rot_euler, "YXZ").to_matrix()
    ctr = Vector(center)
    rx, ry, rz = radii
    for v in ret["verts"]:
        local = Vector((v.co.x * rx, v.co.y * ry, v.co.z * rz))
        gp = ctr + (rot_m @ local)
        v.co = _c2b(gp.x, gp.y, gp.z)
    _assign_new_faces(bm, prev, mat_idx)


def _add_lofted_profile(
    bm: bmesh.types.BMesh,
    stations: Sequence[tuple[float, float, float, float, float]],
    mat_idx: int,
    *,
    segments: int = 16,
    cap_bottom: bool = True,
    cap_top: bool = True,
) -> None:
    """Lofts a smooth elliptical profile from stations (cx, y, cz, rx, rz)."""
    prev = len(bm.faces)
    rings: list[list[bmesh.types.BMVert]] = []
    for cx, y, cz, rx, rz in stations:
        ring: list[bmesh.types.BMVert] = []
        for s in range(segments):
            ang = (2.0 * math.pi * s) / segments
            px = cx + math.cos(ang) * rx
            pz = cz + math.sin(ang) * rz
            ring.append(bm.verts.new(_c2b(px, y, pz)))
        rings.append(ring)

    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(segments):
            sn = (s + 1) % segments
            bm.faces.new((r0[s], r1[s], r1[sn], r0[sn]))

    if cap_bottom and len(rings[0]) >= 3:
        cx, y, cz, _, _ = stations[0]
        bot_c = bm.verts.new(_c2b(cx, y - 0.008, cz))
        for s in range(segments):
            sn = (s + 1) % segments
            bm.faces.new((bot_c, rings[0][sn], rings[0][s]))
    if cap_top and len(rings[-1]) >= 3:
        cx, y, cz, _, _ = stations[-1]
        top_c = bm.verts.new(_c2b(cx, y + 0.008, cz))
        for s in range(segments):
            sn = (s + 1) % segments
            bm.faces.new((top_c, rings[-1][s], rings[-1][sn]))

    _assign_new_faces(bm, prev, mat_idx)


def _add_swept_limb(
    bm: bmesh.types.BMesh,
    points_game: Sequence[tuple[float, float, float]],
    radii: Sequence[float],
    mat_idx: int,
    *,
    segments: int = 12,
    cap_ends: bool = True,
) -> None:
    if len(points_game) < 2:
        return
    prev = len(bm.faces)
    pts = [_c2b(p[0], p[1], p[2]) for p in points_game]
    rings: list[list[bmesh.types.BMVert]] = []
    prev_n = Vector((1.0, 0.0, 0.0))
    for i, pt in enumerate(pts):
        if i == 0:
            tangent = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            tangent = (pts[-1] - pts[-2]).normalized()
        else:
            tangent = (pts[i + 1] - pts[i - 1]).normalized()
        if tangent.length < 1e-6:
            tangent = Vector((0.0, 0.0, 1.0))
        ref = prev_n - tangent * prev_n.dot(tangent)
        if ref.length < 1e-4:
            alt = Vector((0.0, 1.0, 0.0)) if abs(tangent.z) > 0.9 else Vector((0.0, 0.0, 1.0))
            ref = alt - tangent * alt.dot(tangent)
        n_vec = ref.normalized()
        b_vec = tangent.cross(n_vec).normalized()
        prev_n = n_vec
        r = radii[i]
        ring: list[bmesh.types.BMVert] = []
        for s in range(segments):
            ang = (2.0 * math.pi * s) / segments
            v_pos = pt + (n_vec * math.cos(ang) + b_vec * math.sin(ang)) * r
            ring.append(bm.verts.new(v_pos))
        rings.append(ring)

    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(segments):
            sn = (s + 1) % segments
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    if cap_ends:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    _assign_new_faces(bm, prev, mat_idx)


def _add_woven_hat(
    bm: bmesh.types.BMesh,
    center: tuple[float, float, float],
    *,
    radius: float,
    height: float,
    bell: bool,
    mat_idx: int,
) -> None:
    cx, cy, cz = center
    rings = 7
    segs = 20
    prev = len(bm.faces)
    outer: list[list[bmesh.types.BMVert]] = []
    inner: list[list[bmesh.types.BMVert]] = []
    thick = 0.022
    for ri in range(rings + 1):
        t = ri / rings  # 0 rim -> 1 apex
        if bell:
            r = radius * math.cos(t * math.pi * 0.48) ** 0.72
            y = cy + height * math.sin(t * math.pi * 0.5)
        else:
            r = radius * (1.0 - t * 0.94)
            # Gently curved sugegasa cone
            y = cy + height * (t ** 0.88)
        row_o: list[bmesh.types.BMVert] = []
        row_i: list[bmesh.types.BMVert] = []
        for s in range(segs):
            ang = (2.0 * math.pi * s) / segs
            px = math.cos(ang) * r
            pz = math.sin(ang) * r
            row_o.append(bm.verts.new(_c2b(cx + px, y + thick * 0.5, cz + pz)))
            row_i.append(bm.verts.new(_c2b(cx + px * 0.96, y - thick * 0.5, cz + pz * 0.96)))
        outer.append(row_o)
        inner.append(row_i)

    for ri in range(rings):
        for s in range(segs):
            sn = (s + 1) % segs
            bm.faces.new((outer[ri][s], outer[ri][sn], outer[ri + 1][sn], outer[ri + 1][s]))
            bm.faces.new((inner[ri][sn], inner[ri][s], inner[ri + 1][s], inner[ri + 1][sn]))
    for s in range(segs):
        sn = (s + 1) % segs
        bm.faces.new((outer[0][sn], outer[0][s], inner[0][s], inner[0][sn]))

    top_o = bm.verts.new(_c2b(cx, cy + height + thick * 0.65, cz))
    top_i = bm.verts.new(_c2b(cx, cy + height - thick * 0.65, cz))
    for s in range(segs):
        sn = (s + 1) % segs
        bm.faces.new((top_o, outer[-1][s], outer[-1][sn]))
        bm.faces.new((top_i, inner[-1][sn], inner[-1][s]))

    _assign_new_faces(bm, prev, mat_idx)


def _finalize_multi_mat_mesh(
    name: str,
    bm: bmesh.types.BMesh,
    mat_list: list[bpy.types.Material],
    *,
    location_game: tuple[float, float, float] = (0.0, 0.0, 0.0),
    box_uv_scale: float = 1.2,
) -> bpy.types.Object | None:
    if len(bm.verts) == 0:
        bm.free()
        return None
    obj = finalize_mesh(name, bm, mat_list[0], smooth=True, box_uv_scale=box_uv_scale)
    if obj is None:
        return None
    for extra_mat in mat_list[1:]:
        obj.data.materials.append(extra_mat)
    obj.location = _c2b(*location_game)
    return obj


def _build_articulated_leg(
    name: str,
    side_x: float,
    mats: dict[str, bpy.types.Material],
    *,
    cloth_mat: bpy.types.Material,
    wide_hakama: bool = False,
) -> bpy.types.Object | None:
    """Builds a smooth sculpted leg + shin wrap + rounded sandal pivoting at hip y=0.72."""
    bm = bmesh.new()
    m_list: list[bpy.types.Material] = []
    idx_cloth = _slot_index(m_list, cloth_mat)
    idx_wrap = _slot_index(m_list, mats["PersonNavy"])
    idx_sandal = _slot_index(m_list, mats["PersonStraw"])
    idx_skin = _slot_index(m_list, mats["PersonSkin"])

    hip_y = 0.72
    if wide_hakama:
        _add_lofted_profile(
            bm,
            [
                (0.0, 0.14 - hip_y, 0.0, 0.105, 0.125),
                (0.0, 0.40 - hip_y, 0.0, 0.095, 0.110),
                (0.0, 0.68 - hip_y, 0.0, 0.088, 0.096),
            ],
            idx_cloth,
            segments=14,
        )
    else:
        _add_lofted_profile(
            bm,
            [
                (0.0, 0.30 - hip_y, 0.0, 0.068, 0.072),
                (0.0, 0.52 - hip_y, 0.0, 0.074, 0.078),
                (0.0, 0.70 - hip_y, 0.0, 0.078, 0.082),
            ],
            idx_cloth,
            segments=12,
        )
    # Gaiters / kyahan calf wrap -> ankle
    _add_lofted_profile(
        bm,
        [
            (0.0, 0.09 - hip_y, 0.0, 0.046, 0.048),
            (0.0, 0.31 - hip_y, 0.0, 0.056, 0.058),
        ],
        idx_wrap,
        segments=12,
    )
    # Rounded barefoot / tabi ankle & waraji sandal sole resting cleanly at y = 0 (i.e. -hip_y)
    _add_ellipsoid(
        bm,
        (0.0, 0.06 - hip_y, 0.035),
        (0.044, 0.036, 0.086),
        idx_skin,
        u_segs=12,
        v_segs=8,
    )
    _add_ellipsoid(
        bm,
        (0.0, 0.022 - hip_y, 0.04),
        (0.054, 0.022, 0.118),
        idx_sandal,
        u_segs=14,
        v_segs=8,
    )
    return _finalize_multi_mat_mesh(
        name,
        bm,
        m_list,
        location_game=(side_x, hip_y, 0.0),
    )


def _build_torso_base(
    bm: bmesh.types.BMesh,
    m_list: list[bpy.types.Material],
    mats: dict[str, bpy.types.Material],
    *,
    robe_mat: bpy.types.Material,
    haori_mat: bpy.types.Material,
    obi_mat: bpy.types.Material,
    skirt_y0: float,
    waist_y: float = 0.78,
    female: bool = False,
) -> None:
    """Builds smooth kimono lower skirt, obi sash knot, layered haori torso, neck & head in waist-local space."""
    i_robe = _slot_index(m_list, robe_mat)
    i_haori = _slot_index(m_list, haori_mat)
    i_obi = _slot_index(m_list, obi_mat)
    i_cream = _slot_index(m_list, mats["PersonCream"])
    i_skin = _slot_index(m_list, mats["PersonSkin"])

    def dy(world_y: float) -> float:
        return world_y - waist_y

    # Lower kimono skirt hem gently bell-flared from skirt_y0 up into obi
    hip_r_x = 0.215 if female else 0.195
    hip_r_z = 0.190 if female else 0.175
    _add_lofted_profile(
        bm,
        [
            (0.0, dy(skirt_y0), 0.0, hip_r_x * 1.06, hip_r_z * 1.08),
            (0.0, dy(skirt_y0 + 0.24), 0.0, hip_r_x * 0.96, hip_r_z * 0.98),
            (0.0, dy(0.75), 0.0, 0.165, 0.145),
        ],
        i_robe,
        segments=18,
    )
    # Soft wrapped obi sash + sculpted back musubi/taiko knot
    _add_lofted_profile(
        bm,
        [
            (0.0, dy(0.75), 0.0, 0.178, 0.156),
            (0.0, dy(0.90), 0.0, 0.174, 0.152),
        ],
        i_obi,
        segments=18,
    )
    _add_ellipsoid(
        bm,
        (0.0, dy(0.83), -0.17),
        (0.11 if female else 0.085, 0.085 if female else 0.06, 0.065),
        i_obi,
        u_segs=12,
        v_segs=10,
    )
    # Sculpted curved torso / layered haori coat
    shoulder_rx = 0.175 if female else 0.205
    _add_lofted_profile(
        bm,
        [
            (0.0, dy(0.87), 0.0, 0.195, 0.165),
            (0.0, dy(1.08), 0.0, 0.190, 0.158),
            (0.0, dy(1.27), 0.0, shoulder_rx, 0.142),
            (0.0, dy(1.36), 0.0, 0.120, 0.105),
        ],
        i_haori,
        segments=18,
    )
    # Layered kimono eri V-neck collar inset proudly at front throat
    _add_ellipsoid(
        bm,
        (0.0, dy(1.31), 0.068),
        (0.072, 0.075, 0.064),
        i_cream,
        rot_euler=(0.0, 0.35, 0.0),
        u_segs=12,
        v_segs=10,
    )
    # Neck + sculpted cranium head
    _add_lofted_profile(
        bm,
        [
            (0.0, dy(1.32), 0.01, 0.056, 0.056),
            (0.0, dy(1.42), 0.02, 0.052, 0.052),
        ],
        i_skin,
        segments=12,
    )
    _add_ellipsoid(
        bm,
        (0.0, dy(1.50), 0.022),
        (0.095, 0.118, 0.105),
        i_skin,
        u_segs=16,
        v_segs=12,
    )


def _build_sculpted_arms(
    bm: bmesh.types.BMesh,
    m_list: list[bpy.types.Material],
    mats: dict[str, bpy.types.Material],
    *,
    haori_mat: bpy.types.Material,
    robe_mat: bpy.types.Material,
    left_wrist: tuple[float, float, float],
    right_wrist: tuple[float, float, float],
    waist_y: float = 0.78,
    has_tamoto: bool = False,
) -> None:
    i_haori = _slot_index(m_list, haori_mat)
    i_robe = _slot_index(m_list, robe_mat)
    i_skin = _slot_index(m_list, mats["PersonSkin"])

    def dy(world_y: float) -> float:
        return world_y - waist_y

    for side, elbow_x, elbow_y, elbow_z, wrist in (
        (1.0, 0.25, 1.07, 0.05, left_wrist),
        (-1.0, -0.25, 1.07, 0.05, right_wrist),
    ):
        sx, sy, sz = side * 0.175, 1.27, 0.0
        wx, wy, wz = wrist
        _add_swept_limb(
            bm,
            [(sx, dy(sy), sz), (elbow_x, dy(elbow_y), elbow_z)],
            [0.072, 0.068],
            i_haori,
            segments=12,
        )
        if has_tamoto:
            _add_ellipsoid(
                bm,
                (elbow_x * 0.96, dy(elbow_y - 0.11), elbow_z + 0.02),
                (0.055, 0.125, 0.085),
                i_haori,
                u_segs=12,
                v_segs=10,
            )
        _add_swept_limb(
            bm,
            [(elbow_x, dy(elbow_y), elbow_z), (wx, dy(wy), wz)],
            [0.054, 0.040],
            i_robe,
            segments=10,
        )
        _add_ellipsoid(
            bm,
            (wx, dy(wy), wz),
            (0.038, 0.038, 0.045),
            i_skin,
            u_segs=10,
            v_segs=8,
        )


def _build_person_glb(
    filename: str,
    archetype: str,
    mats: dict[str, bpy.types.Material],
) -> None:
    clear_scene()
    mats = get_materials()

    waist_y = 0.78

    def dy(wy: float) -> float:
        return wy - waist_y

    if archetype == "merchant":
        robe, haori, obi = mats["PersonOchre"], mats["PersonIndigo"], mats["PersonCharcoal"]
        hakama = False
        skirt_y0 = 0.26
    elif archetype == "townswoman":
        robe, haori, obi = mats["PersonPlum"], mats["PersonCrimson"] if "PersonCrimson" in mats else mats["ClothCrimson"], mats["PersonCream"]
        hakama = False
        skirt_y0 = 0.22
    elif archetype == "porter":
        robe, haori, obi = mats["PersonNavy"], mats["PersonIndigo"], mats["PersonStraw"]
        hakama = False
        skirt_y0 = 0.42
    elif archetype == "watchman":
        robe, haori, obi = mats["PersonNavy"], mats["ClothCrimson"], mats["PersonCream"]
        hakama = False
        skirt_y0 = 0.28
    elif archetype == "samurai":
        robe, haori, obi = mats["PersonCharcoal"], mats["PersonNavy"], mats["PersonCream"]
        hakama = True
        skirt_y0 = 0.48
    else:  # monk
        robe, haori, obi = mats["PersonCharcoal"], mats["PersonRusset"], mats["PersonOchre"]
        hakama = False
        skirt_y0 = 0.22

    _build_articulated_leg("person_leg_l", 0.082, mats, cloth_mat=robe, wide_hakama=hakama)
    _build_articulated_leg("person_leg_r", -0.082, mats, cloth_mat=robe, wide_hakama=hakama)

    bm = bmesh.new()
    m_list: list[bpy.types.Material] = []
    _build_torso_base(
        bm,
        m_list,
        mats,
        robe_mat=robe,
        haori_mat=haori,
        obi_mat=obi,
        skirt_y0=skirt_y0,
        waist_y=waist_y,
        female=(archetype == "townswoman"),
    )

    i_hair = _slot_index(m_list, mats["PersonHair"])
    i_straw = _slot_index(m_list, mats["PersonStraw"])
    i_cedar = _slot_index(m_list, mats["CedarTimber"])
    i_lacquer = _slot_index(m_list, mats["CharredTimber"])
    i_crimson = _slot_index(m_list, mats["ClothCrimson"])
    i_cream = _slot_index(m_list, mats["PersonCream"])
    i_bronze = _slot_index(m_list, mats["GoldTrim"])

    if archetype == "merchant":
        _build_sculpted_arms(
            bm, m_list, mats, haori_mat=haori, robe_mat=robe,
            left_wrist=(0.24, 1.00, 0.14), right_wrist=(-0.22, 1.24, 0.08),
            waist_y=waist_y, has_tamoto=True,
        )
        # Sculpted conic sugegasa hat + curved carrying pole with twin woven baskets
        _add_woven_hat(bm, (0.0, dy(1.54), 0.02), radius=0.31, height=0.19, bell=False, mat_idx=i_straw)
        _add_swept_limb(bm, [(-0.46, dy(1.33), -0.44), (-0.18, dy(1.33), 0.0), (0.06, dy(1.32), 0.44)], [0.022, 0.024, 0.020], i_cedar, segments=8)
        for bx, bz, by in ((0.06, 0.44, 0.96), (-0.46, -0.44, 0.98)):
            _add_swept_limb(bm, [(bx, dy(1.32), bz), (bx, dy(by + 0.12), bz)], [0.010, 0.010], _slot_index(m_list, mats["HempRope"]), segments=6)
            _add_ellipsoid(bm, (bx, dy(by), bz), (0.14, 0.15, 0.14), i_straw, u_segs=14, v_segs=10)

    elif archetype == "townswoman":
        _build_sculpted_arms(
            bm, m_list, mats, haori_mat=haori, robe_mat=robe,
            left_wrist=(0.18, 0.98, 0.16), right_wrist=(-0.20, 1.02, 0.18),
            waist_y=waist_y, has_tamoto=True,
        )
        # Upswept Nihongami coiffure with glossy chignon & vermilion kanzashi hair ornament
        _add_ellipsoid(bm, (0.0, dy(1.52), -0.01), (0.108, 0.112, 0.115), i_hair, u_segs=14, v_segs=10)
        _add_ellipsoid(bm, (0.0, dy(1.59), -0.075), (0.065, 0.058, 0.062), i_hair, u_segs=12, v_segs=8)
        _add_ellipsoid(bm, (0.06, dy(1.60), -0.06), (0.022, 0.022, 0.036), i_crimson, u_segs=8, v_segs=6)
        # Closed oiled-paper wagasa parasol rested gently against right shoulder
        _add_swept_limb(bm, [(-0.20, dy(0.76), 0.12), (-0.21, dy(1.56), 0.25)], [0.018, 0.032], i_crimson, segments=10)

    elif archetype == "porter":
        _build_sculpted_arms(
            bm, m_list, mats, haori_mat=haori, robe_mat=robe,
            left_wrist=(0.24, 0.96, 0.12), right_wrist=(-0.18, 1.38, 0.12),
            waist_y=waist_y,
        )
        _add_lofted_profile(bm, [(0.0, dy(1.53), 0.02, 0.102, 0.110), (0.0, dy(1.57), 0.02, 0.102, 0.110)], i_cream, segments=14)
        _add_ellipsoid(bm, (0.0, dy(1.54), 0.015), (0.098, 0.098, 0.104), i_hair, u_segs=14, v_segs=10)
        # Woven straw rice bale hoisted naturally on right shoulder
        _add_ellipsoid(bm, (-0.18, dy(1.43), -0.06), (0.16, 0.14, 0.28), i_straw, rot_euler=(0.15, -0.10, 0.0), u_segs=14, v_segs=10)

    elif archetype == "watchman":
        _build_sculpted_arms(
            bm, m_list, mats, haori_mat=haori, robe_mat=robe,
            left_wrist=(0.22, 0.96, 0.14), right_wrist=(-0.23, 1.14, 0.22),
            waist_y=waist_y, has_tamoto=True,
        )
        _add_woven_hat(bm, (0.0, dy(1.54), 0.02), radius=0.25, height=0.14, bell=False, mat_idx=i_lacquer)
        _add_swept_limb(bm, [(-0.23, dy(1.13), 0.20), (-0.24, dy(1.24), 0.44)], [0.014, 0.010], i_cedar, segments=8)
        _add_swept_limb(bm, [(-0.24, dy(1.24), 0.44), (-0.24, dy(1.10), 0.44)], [0.006, 0.006], _slot_index(m_list, mats["DarkIron"]), segments=6)

    elif archetype == "samurai":
        _build_sculpted_arms(
            bm, m_list, mats, haori_mat=haori, robe_mat=robe,
            left_wrist=(0.20, 0.94, 0.18), right_wrist=(-0.22, 0.96, 0.10),
            waist_y=waist_y, has_tamoto=True,
        )
        # Sculpted samurai hair & chonmage topknot
        _add_ellipsoid(bm, (0.0, dy(1.52), 0.015), (0.102, 0.108, 0.112), i_hair, u_segs=14, v_segs=10)
        _add_swept_limb(bm, [(0.0, dy(1.59), -0.05), (0.0, dy(1.63), 0.03)], [0.032, 0.024], i_hair, segments=10)
        # Paired daisho katana & wakizashi scabbards angled cleanly clear of left hip
        _add_swept_limb(bm, [(0.20, dy(0.68), -0.34), (0.18, dy(0.92), 0.34)], [0.022, 0.022], i_lacquer, segments=8)
        _add_swept_limb(bm, [(0.19, dy(0.76), -0.18), (0.17, dy(0.90), 0.26)], [0.018, 0.018], i_bronze, segments=8)

    else:  # monk
        _build_sculpted_arms(
            bm, m_list, mats, haori_mat=haori, robe_mat=robe,
            left_wrist=(0.24, 1.00, 0.16), right_wrist=(-0.23, 1.04, 0.14),
            waist_y=waist_y, has_tamoto=True,
        )
        _add_woven_hat(bm, (0.0, dy(1.50), 0.02), radius=0.27, height=0.21, bell=True, mat_idx=i_straw)
        _add_ellipsoid(bm, (0.0, dy(1.12), -0.22), (0.15, 0.19, 0.11), i_straw, u_segs=14, v_segs=10)
        _add_swept_limb(bm, [(0.25, dy(0.04), 0.16), (0.24, dy(1.48), 0.16)], [0.018, 0.016], i_cedar, segments=8)
        _add_ellipsoid(bm, (0.24, dy(1.51), 0.16), (0.034, 0.048, 0.034), i_bronze, u_segs=10, v_segs=8)

    upper_obj = _finalize_multi_mat_mesh(
        "person_upper",
        bm,
        m_list,
        location_game=(0.0, waist_y, 0.0),
    )

    if archetype == "watchman" and upper_obj is not None:
        bm_lan = bmesh.new()
        l_mats: list[bpy.types.Material] = []
        i_glow = _slot_index(l_mats, mats["ChochinGlow"])
        i_iron = _slot_index(l_mats, mats["DarkIron"])
        _add_ellipsoid(bm_lan, (-0.24, dy(0.98), 0.44), (0.088, 0.125, 0.088), i_glow, u_segs=14, v_segs=10)
        _add_lofted_profile(bm_lan, [(-0.24, dy(1.09), 0.44, 0.05, 0.05), (-0.24, dy(1.12), 0.44, 0.04, 0.04)], i_iron, segments=10)
        _add_lofted_profile(bm_lan, [(-0.24, dy(0.84), 0.44, 0.04, 0.04), (-0.24, dy(0.87), 0.44, 0.05, 0.05)], i_iron, segments=10)
        lan_obj = _finalize_multi_mat_mesh("person_lantern_glow", bm_lan, l_mats)
        if lan_obj is not None:
            lan_obj.parent = upper_obj

    export_glb(filename)


def build_all() -> None:
    mats = {}  # loaded inside _build_person_glb after clear_scene()
    specs = (
        ("edo_person_merchant.glb", "merchant"),
        ("edo_person_townswoman.glb", "townswoman"),
        ("edo_person_porter.glb", "porter"),
        ("edo_person_watchman.glb", "watchman"),
        ("edo_person_samurai.glb", "samurai"),
        ("edo_person_monk.glb", "monk"),
    )
    for fname, archetype in specs:
        _build_person_glb(fname, archetype, mats)


if __name__ == "__main__":
    build_all()
