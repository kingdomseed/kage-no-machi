"""Edo buildings & market stalls: multi-variant machiya, chaya, kura, minka & yatai."""

from __future__ import annotations

import math

import bmesh
from mathutils import Vector

from common import (
    add_game_box,
    add_game_cylinder,
    clear_scene,
    export_glb,
    finalize_mesh,
    g2b,
    get_materials,
    set_face_uv_quad,
)


def _add_curved_roof(
    bm: bmesh.types.BMesh,
    cx: float,
    y_eave: float,
    cz: float,
    width_x: float,
    depth_z: float,
    rise_y: float,
    *,
    ridge_axis: str = "x",
    hipped: bool = False,
    thickness: float = 0.11,
    curve_segs: int = 8,
    eave_flare: float = 0.24,
) -> None:
    """Adds a smooth concave terimukuri Edo roof shell with flipped curved eaves."""
    # Parametric grid over roof slope half-sections mirrored around ridge
    hx = width_x * 0.5
    hz = depth_z * 0.5

    def add_half_slope(sign: float) -> None:
        rows = curve_segs + 1
        cols = 6
        verts_top: list[list[bmesh.types.BMVert]] = []
        verts_bot: list[list[bmesh.types.BMVert]] = []
        for r in range(rows):
            t = r / curve_segs  # 0 at ridge -> 1 at outer eave
            # Concave Edo slope + gentle upturned eave tip
            profile = (1.0 - t) ** 1.45
            # Slight subtle lip flare right at outer eave tip
            flare = eave_flare * (t ** 3.2) * (1.0 - t * 0.35)
            row_top: list[bmesh.types.BMVert] = []
            row_bot: list[bmesh.types.BMVert] = []
            for c in range(cols):
                u = (c / (cols - 1)) * 2.0 - 1.0  # -1..+1 along ridge
                # Upward terimukuri flare toward gable corners
                corner_lift = 0.14 * (u * u) * (t ** 0.7)
                y_surf = y_eave + rise_y * profile + flare + corner_lift
                if hipped:
                    span_r = (1.0 - 0.52 * (1.0 - t)) if abs(u) > 0.0 else 1.0
                else:
                    span_r = 1.0
                if ridge_axis == "x":
                    wx = cx + u * hx * span_r
                    wz = cz + sign * t * hz
                else:
                    wx = cx + sign * t * hx
                    wz = cz + u * hz * span_r
                row_top.append(bm.verts.new(g2b(wx, y_surf, wz)))
                row_bot.append(bm.verts.new(g2b(wx, y_surf - thickness, wz)))
            verts_top.append(row_top)
            verts_bot.append(row_bot)

        for r in range(rows - 1):
            for c in range(cols - 1):
                a, b, d, e = verts_top[r][c], verts_top[r][c + 1], verts_top[r + 1][c + 1], verts_top[r + 1][c]
                bm.faces.new((a, b, d, e) if sign > 0 else (e, d, b, a))
                a2, b2, d2, e2 = verts_bot[r][c], verts_bot[r][c + 1], verts_bot[r + 1][c + 1], verts_bot[r + 1][c]
                bm.faces.new((e2, d2, b2, a2) if sign > 0 else (a2, b2, d2, e2))

        # Eave rim closure
        re = rows - 1
        for c in range(cols - 1):
            t0, t1, b1, b0 = verts_top[re][c], verts_top[re][c + 1], verts_bot[re][c + 1], verts_bot[re][c]
            bm.faces.new((t0, t1, b1, b0) if sign < 0 else (b0, b1, t1, t0))
        # Gable/side rims
        for r in range(rows - 1):
            for c_idx, rev in ((0, True), (cols - 1, False)):
                t0, t1, b1, b0 = verts_top[r][c_idx], verts_top[r + 1][c_idx], verts_bot[r + 1][c_idx], verts_bot[r][c_idx]
                bm.faces.new((b0, b1, t1, t0) if (rev ^ (sign > 0)) else (t0, t1, b1, b0))

    add_half_slope(1.0)
    add_half_slope(-1.0)


def _add_shoji_panel(
    bm: bmesh.types.BMesh,
    cx: float,
    cy: float,
    cz: float,
    w: float,
    h: float,
    normal_dir: str,
) -> None:
    """Adds a UV-mapped shoji window quad sitting cleanly >=0.025m proud of wall plane."""
    uv_layer = bm.loops.layers.uv.verify()
    hw, hh = w * 0.5, h * 0.5
    if normal_dir == "+z":
        pts = [(cx - hw, cy - hh, cz), (cx + hw, cy - hh, cz), (cx + hw, cy + hh, cz), (cx - hw, cy + hh, cz)]
    elif normal_dir == "-z":
        pts = [(cx + hw, cy - hh, cz), (cx - hw, cy - hh, cz), (cx - hw, cy + hh, cz), (cx + hw, cy + hh, cz)]
    elif normal_dir == "+x":
        pts = [(cx, cy - hh, cz + hw), (cx, cy - hh, cz - hw), (cx, cy + hh, cz - hw), (cx, cy + hh, cz + hw)]
    else:  # "-x"
        pts = [(cx, cy - hh, cz - hw), (cx, cy - hh, cz + hw), (cx, cy + hh, cz + hw), (cx, cy + hh, cz - hw)]
    verts = [bm.verts.new(g2b(*p)) for p in pts]
    face = bm.faces.new(verts)
    set_face_uv_quad(face, uv_layer, 0.0, 0.0, 1.0, 1.0)


def _add_chochin(bm_glow: bmesh.types.BMesh, bm_trim: bmesh.types.BMesh, x: float, y: float, z: float, radius: float = 0.14, h: float = 0.34) -> None:
    """Adds a smooth ellipsoid hanging paper chochin lantern with dark iron top/bottom rings."""
    ret = bmesh.ops.create_uvsphere(bm_glow, u_segments=14, v_segments=10, radius=1.0)
    for v in ret["verts"]:
        v.co = g2b(x + v.co.x * radius, y + v.co.z * h * 0.5, z - v.co.y * radius)
    add_game_cylinder(bm_trim, x, y + h * 0.45, z, radius * 0.65, radius * 0.45, 0.05, segments=12)
    add_game_cylinder(bm_trim, x, y - h * 0.50, z, radius * 0.45, radius * 0.62, 0.05, segments=12)
    add_game_cylinder(bm_trim, x, y + h * 0.50, z, 0.014, 0.014, 0.16, segments=6)


def _add_timber_frame_and_koshi(
    bm_timber: bmesh.types.BMesh,
    bx: float,
    bz: float,
    y0: float,
    y1: float,
    *,
    include_sill: bool = True,
) -> None:
    """Adds corner posts & hollow exterior belt rails >=4.5cm clear on all faces."""
    hx, hz = bx * 0.5, bz * 0.5
    h = y1 - y0
    ym = 0.5 * (y0 + y1)
    # Corner posts span [y0-0.05..y1+0.05] & X/Z span [hx-0.075..hx+0.125] (no bevel/face within 4.5cm!)
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            add_game_box(bm_timber, sx * (hx + 0.025), ym, sz * (hz + 0.025), 0.20, h + 0.10, 0.20, bevel=0.012)
    # Hollow exterior sill & top-plate perimeter beams >=4.5cm clear of y0/y1 and >=5.5cm of wall/wainscot
    rail_h = 0.09
    rail_d = 0.20
    rail_ys = (y0 + 0.18, y1 - 0.18) if include_sill else (y1 - 0.18,)
    for ry in rail_ys:
        for sz in (-1.0, 1.0):
            add_game_box(bm_timber, 0.0, ry, sz * (hz + 0.025), bx + 0.18, rail_h, rail_d, bevel=0.012)
        for sx in (-1.0, 1.0):
            add_game_box(bm_timber, sx * (hx + 0.025), ry, 0.0, rail_d, rail_h, bz - 0.10, bevel=0.012)


def _add_framed_wall_bays(
    bm: bmesh.types.BMesh,
    bx: float,
    bz: float,
    y_bot: float,
    y_top: float,
    *,
    post_inset: float = 0.06,
) -> None:
    """Adds 4 outward wall infill quads strictly between corner posts & sills."""
    hx, hz = bx * 0.5, bz * 0.5
    x0, x1 = -(hx - post_inset), (hx - post_inset)
    z0, z1 = -(hz - post_inset), (hz - post_inset)
    quads = (
        [(x0, y_bot, hz), (x1, y_bot, hz), (x1, y_top, hz), (x0, y_top, hz)],
        [(x1, y_bot, -hz), (x0, y_bot, -hz), (x0, y_top, -hz), (x1, y_top, -hz)],
        [(hx, y_bot, z1), (hx, y_bot, z0), (hx, y_top, z0), (hx, y_top, z1)],
        [(-hx, y_bot, z0), (-hx, y_bot, z1), (-hx, y_top, z1), (-hx, y_top, z0)],
    )
    for pts in quads:
        bm.faces.new([bm.verts.new(g2b(*p)) for p in pts])


def _add_machiya_timber_frame(
    bm_timber: bmesh.types.BMesh,
    bx: float,
    bz: float,
    y_sill_top: float,
    y_plate_bot: float,
    *,
    plate_h: float = 0.16,
    sill_bot: float | None = None,
    post_inset: float = 0.06,
    post_out: float = 0.11,
) -> None:
    """Adds non-intersecting corner posts, sill plate, and cornice plate."""
    hx, hz = bx * 0.5, bz * 0.5
    pw = post_inset + post_out
    pc_off = (post_out - post_inset) * 0.5
    if sill_bot is not None:
        sill_h = y_sill_top - sill_bot
        add_game_box(
            bm_timber,
            0.0,
            sill_bot + sill_h * 0.5,
            0.0,
            bx + 0.20,
            sill_h,
            bz + 0.20,
        )
    add_game_box(
        bm_timber,
        0.0,
        y_plate_bot + plate_h * 0.5,
        0.0,
        bx + 0.20,
        plate_h,
        bz + 0.20,
    )
    post_h = y_plate_bot - y_sill_top
    ym = y_sill_top + post_h * 0.5
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            add_game_box(
                bm_timber,
                sx * (hx + pc_off),
                ym,
                sz * (hz + pc_off),
                pw,
                post_h,
                pw,
            )


def build_machiya_variant(variant: int, filename: str) -> None:
    """4 distinct machiya merchant townhouses preserving [-2.43, 2.43] x [-1.30, 5.54] x [-2.62, 2.80]."""
    clear_scene()
    mats = get_materials()

    bm_stone = bmesh.new()
    bm_charred = bmesh.new()
    bm_cedar = bmesh.new()
    bm_plaster = bmesh.new()
    bm_roof = bmesh.new()
    bm_shoji = bmesh.new()
    bm_noren = bmesh.new()
    bm_lantern = bmesh.new()
    bm_iron = bmesh.new()

    bx = (3.22, 4.05, 3.68, 3.55)[variant]
    bz = (4.35, 3.85, 4.05, 4.25)[variant]

    # Stone foundation skirt reaching deep into terrain (top +0.26m frames bx+0.20 sill plate)
    add_game_box(bm_stone, 0.0, -0.44, 0.0, bx + 0.30, 1.40, bz + 0.30, bevel=0.03)

    # First story framed wall bays cleanly seated between charred timber frame & plates
    y_sill_top = 0.38
    y_plate_bot = 2.19
    y1_top = 2.35
    _add_machiya_timber_frame(
        bm_charred,
        bx,
        bz,
        y_sill_top,
        y_plate_bot,
        plate_h=0.16,
        sill_bot=0.20,
    )
    if variant in (1, 3):
        _add_framed_wall_bays(bm_cedar, bx, bz, y_sill_top, 1.24)
        add_game_box(bm_charred, 0.0, 1.31, 0.0, bx + 0.16, 0.14, bz + 0.16)
        _add_framed_wall_bays(bm_plaster, bx, bz, 1.38, y_plate_bot)
    else:
        _add_framed_wall_bays(bm_cedar, bx, bz, y_sill_top, y_plate_bot)

    # Vertical wooden merchant signboard on v0 & v3
    if variant in (0, 3):
        add_game_box(
            bm_charred,
            -bx * 0.5 - 0.15,
            1.48,
            bz * 0.5 + 0.16,
            0.22,
            0.74,
            0.06,
            bevel=0.01,
        )

    # Shoji window bays (strictly >=0.05m proud of waist rail & wall!)
    win_w, win_h = 0.88, 1.12
    for z_side, ndir in ((bz * 0.5 + 0.13, "+z"), (-bz * 0.5 - 0.13, "-z")):
        for wx in (-0.78, 0.78):
            _add_shoji_panel(bm_shoji, wx, 1.26, z_side, win_w, win_h, ndir)
            add_game_box(bm_charred, wx, 0.70, z_side + (0.02 if ndir == "+z" else -0.02), win_w + 0.08, 0.06, 0.06)
    for x_side, ndir in ((bx * 0.5 + 0.13, "+x"), (-bx * 0.5 - 0.13, "-x")):
        for wz in (-0.90, 0.90):
            _add_shoji_panel(bm_shoji, x_side, 1.26, wz, win_w * 0.85, win_h, ndir)

    # Noren-kake curtain beam above entrance supporting noren cleanly clear of mullions & top-plate beam
    add_game_box(bm_charred, 0.0, 2.04, bz * 0.5 + 0.23, 1.28, 0.08, 0.08, bevel=0.012)
    # Entrance Noren cloth panels hanging gracefully at front
    noren_y = 1.70
    for nx in (-0.36, 0.0, 0.36):
        add_game_box(bm_noren, nx, noren_y, bz * 0.5 + 0.22, 0.30, 0.68, 0.025, bevel=0.004)
    # Lower tiled rain awning (hisashi) curving outward on +Z (and on +X for corner v3)
    _add_curved_roof(
        bm_roof,
        0.0,
        y1_top - 0.06,
        bz * 0.5 + 0.28,
        bx + 0.56,
        0.92,
        0.38,
        ridge_axis="x",
        thickness=0.08,
        curve_segs=5,
        eave_flare=0.14,
    )
    if variant == 3:
        _add_curved_roof(
            bm_roof,
            bx * 0.5 + 0.26,
            y1_top - 0.08,
            0.0,
            0.86,
            bz + 0.42,
            0.36,
            ridge_axis="z",
            thickness=0.08,
            curve_segs=5,
            eave_flare=0.14,
        )

    # Varied hanging entrance lanterns (no identical symmetrical clone rhythm down the block)
    if variant == 0:
        for lx in (-1.08, 1.08):
            _add_chochin(bm_lantern, bm_iron, lx, y1_top - 0.36, bz * 0.5 + 0.48, radius=0.12, h=0.28)
    elif variant == 1:
        _add_chochin(bm_lantern, bm_iron, 1.32, y1_top - 0.34, bz * 0.5 + 0.48, radius=0.14, h=0.34)
    elif variant == 3:
        _add_chochin(bm_lantern, bm_iron, -1.24, y1_top - 0.36, bz * 0.5 + 0.50, radius=0.16, h=0.38)

    # Upper second story seated cleanly atop the 1st-story cornice [2.19, 2.35]
    ubx = bx - (0.36 if variant in (0, 3) else 0.44)
    ubz = bz - (0.40 if variant in (0, 3) else 0.48)
    h2 = (1.88, 1.66, 1.06, 1.68)[variant]
    y2_bot = y1_top
    y2_top = y2_bot + h2
    y2_plate_bot = y2_top - 0.16
    _add_machiya_timber_frame(
        bm_charred,
        ubx,
        ubz,
        y2_bot,
        y2_plate_bot,
        plate_h=0.16,
        sill_bot=None,
    )
    upper_wall_bm = bm_plaster if variant in (1, 3) else bm_cedar
    _add_framed_wall_bays(
        upper_wall_bm,
        ubx,
        ubz,
        y2_bot,
        y2_plate_bot,
    )

    # Upper Engawa wooden veranda rail + proud udatsu fire-wall wing on v1
    if variant == 1:
        ry = y1_top + 0.58
        add_game_box(bm_charred, 0.0, ry, ubz * 0.5 + 0.28, ubx + 0.12, 0.06, 0.07)
        for px in (-1.35, -0.45, 0.45, 1.35):
            add_game_box(bm_charred, px, ry - 0.22, ubz * 0.5 + 0.28, 0.06, 0.48, 0.06)
        # Udatsu wing wall rising cleanly beside roof eave on -X flank
        ux = -(ubx * 0.5 + 0.26)
        add_game_box(bm_plaster, ux, y2_top + 0.22, 0.25, 0.20, 1.35, ubz * 0.65, bevel=0.02)
        add_game_box(bm_roof, ux, y2_top + 0.96, 0.25, 0.34, 0.12, ubz * 0.72, bevel=0.015)

    y_shoji_2 = y2_bot + (y2_plate_bot - y2_bot) * 0.50
    shoji2_h = 0.58 if variant == 2 else 0.86
    for z_side, ndir in ((ubz * 0.5 + 0.11, "+z"), (-ubz * 0.5 - 0.11, "-z")):
        for wx in (-0.70, 0.70):
            _add_shoji_panel(bm_shoji, wx, y_shoji_2, z_side, 0.76, shoji2_h, ndir)
    for x_side, ndir in ((ubx * 0.5 + 0.11, "+x"), (-ubx * 0.5 - 0.11, "-x")):
        _add_shoji_panel(bm_shoji, x_side, y_shoji_2, 0.0, 0.80, shoji2_h, ndir)

    # Sweeping main roof (eaves sit +0.05m above y2_top with 0.11m thickness so wall top embeds cleanly)
    ridge_ax = "z" if variant in (2, 3) else "x"
    hipped = variant == 1
    roof_rise = (1.36, 1.24, 1.48, 1.32)[variant]
    _add_curved_roof(
        bm_roof,
        0.0,
        y2_top + 0.05,
        0.0,
        ubx + 1.02,
        ubz + 1.12,
        roof_rise,
        ridge_axis=ridge_ax,
        hipped=hipped,
        thickness=0.11,
        curve_segs=8,
        eave_flare=0.22,
    )
    # Closed gable tympanum walls cleanly inset above cornice without grazing roof slope
    if not hipped:
        if ridge_ax == "x":
            for sx in (-1.0, 1.0):
                gx = sx * (ubx * 0.5 - 0.12)
                add_game_box(bm_cedar if variant != 1 else bm_plaster, gx, y2_top + 0.06 + roof_rise * 0.32, 0.0, 0.08, roof_rise * 0.64, ubz * 0.62)
        else:
            for sz in (-1.0, 1.0):
                gz = sz * (ubz * 0.5 - 0.12)
                add_game_box(upper_wall_bm, 0.0, y2_top + 0.06 + roof_rise * 0.32, gz, ubx * 0.62, roof_rise * 0.64, 0.08)

    # Ornate ridge beam & end tile finials (onigawara)
    if ridge_ax == "x":
        r_len = (ubx + 0.65) if not hipped else (ubx * 0.55)
        add_game_box(bm_roof, 0.0, y2_top + roof_rise + 0.08, 0.0, r_len, 0.16, 0.18, bevel=0.02)
    else:
        r_len = ubz + 0.65
        add_game_box(bm_roof, 0.0, y2_top + roof_rise + 0.08, 0.0, 0.18, 0.16, r_len, bevel=0.02)

    # Rooftop hoshidai timber drying platform perched cleanly on v2 workshop roof
    if variant == 2:
        deck_y = y2_top + roof_rise + 0.24
        for lx in (-0.52, 0.52):
            for lz in (-0.42, 0.42):
                add_game_box(bm_charred, lx, deck_y - 0.38, lz - 0.15, 0.07, 0.78, 0.07)
        add_game_box(bm_cedar, 0.0, deck_y + 0.04, -0.15, 1.32, 0.08, 1.08, bevel=0.01)
        add_game_box(bm_charred, 0.0, deck_y + 0.44, 0.36, 1.30, 0.06, 0.06)

    roof_mat = mats["KawaraRust"] if variant == 2 else (mats["KawaraMossGreen"] if variant == 3 else mats["KawaraTile"])
    noren_mat = (
        mats["NorenIndigo"],
        mats["ClothCrimson"],
        mats["OchreCloth"],
        mats["ClothCrimson"],
    )[variant]

    finalize_mesh("machiya_stone", bm_stone, mats["CastleIshigaki"], smooth=True, box_uv_scale=0.38)
    finalize_mesh("machiya_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("machiya_cedar", bm_cedar, mats["CedarTimber"], smooth=False, box_uv_scale=0.45, recalc_normals=False)
    finalize_mesh("machiya_plaster", bm_plaster, mats["ShikkuiPlaster"], smooth=False, box_uv_scale=0.40, recalc_normals=False)
    finalize_mesh("machiya_kawara", bm_roof, roof_mat, smooth=True, box_uv_scale=0.55)
    finalize_mesh("machiya_shoji", bm_shoji, mats["ShojiGlow"], smooth=False, box_uv_scale=None)
    finalize_mesh("machiya_noren", bm_noren, noren_mat, smooth=True, box_uv_scale=0.5)
    finalize_mesh("machiya_chochin", bm_lantern, mats["ChochinGlow"], smooth=True, box_uv_scale=0.5)
    finalize_mesh("machiya_iron", bm_iron, mats["DarkIron"], smooth=True, box_uv_scale=0.6)
    export_glb(filename)


def build_teahouse_variant(variant: int, filename: str) -> None:
    """3 multi-variant riverside & alley teahouses preserving ~[-2.54, 2.54] bounds."""
    clear_scene()
    mats = get_materials()

    bm_stone = bmesh.new()
    bm_charred = bmesh.new()
    bm_cedar = bmesh.new()
    bm_plaster = bmesh.new()
    bm_roof = bmesh.new()
    bm_shoji = bmesh.new()
    bm_noren = bmesh.new()
    bm_lantern = bmesh.new()
    bm_iron = bmesh.new()

    bx, bz = 3.85, 3.85
    add_game_box(bm_stone, 0.0, -0.44, 0.0, bx + 0.25, 1.40, bz + 0.25, bevel=0.03)
    # Wrap-around raised wooden veranda deck (engawa: top at 0.38m)
    add_game_box(bm_cedar, 0.0, 0.30, 0.0, bx + 0.72, 0.16, bz + 0.72, bevel=0.02)

    h1 = 2.08
    y1_bot = 0.32
    y1_top = y1_bot + h1
    add_game_box(bm_cedar if variant != 1 else bm_plaster, 0.0, y1_bot + h1 * 0.5, 0.0, bx - 0.15, h1, bz - 0.15)
    _add_timber_frame_and_koshi(bm_charred, bx - 0.15, bz - 0.15, y1_bot, y1_top)

    # Prominent shoji gallery panels all around ground floor
    for z_s, nd in (((bz - 0.15) * 0.5 + 0.11, "+z"), (-(bz - 0.15) * 0.5 - 0.11, "-z")):
        for wx in (-0.90, 0.0, 0.90):
            _add_shoji_panel(bm_shoji, wx, 1.38, z_s, 0.76, 1.24, nd)
    for x_s, nd in (((bx - 0.15) * 0.5 + 0.11, "+x"), (-(bx - 0.15) * 0.5 - 0.11, "-x")):
        for wz in (-0.85, 0.85):
            _add_shoji_panel(bm_shoji, x_s, 1.38, wz, 0.86, 1.24, nd)

    # Lower sweeping pagoda skirt roof (rise 0.42 cuts crisply into upper wall without grazing parallel)
    _add_curved_roof(bm_roof, 0.0, y1_top - 0.06, 0.0, bx + 1.04, bz + 1.04, 0.42, hipped=True, thickness=0.10, curve_segs=6, eave_flare=0.22)

    # Second floor pavilion lantern tower
    ubx, ubz = bx * 0.68, bz * 0.68
    h2 = 1.48 if variant != 2 else 1.62
    y2_bot = y1_top + 0.25
    y2_top = y2_bot + h2
    add_game_box(bm_plaster, 0.0, y2_bot + h2 * 0.5, 0.0, ubx, h2, ubz)
    _add_timber_frame_and_koshi(bm_charred, ubx, ubz, y2_bot, y2_top)
    for z_s, nd in ((ubz * 0.5 + 0.11, "+z"), (-ubz * 0.5 - 0.11, "-z")):
        _add_shoji_panel(bm_shoji, 0.0, y2_bot + h2 * 0.52, z_s, 1.28, 0.84, nd)
    for x_s, nd in ((ubx * 0.5 + 0.11, "+x"), (-ubx * 0.5 - 0.11, "-x")):
        _add_shoji_panel(bm_shoji, x_s, y2_bot + h2 * 0.52, 0.0, 1.12, 0.84, nd)

    _add_curved_roof(bm_roof, 0.0, y2_top + 0.05, 0.0, ubx + 1.15, ubz + 1.15, 1.18, hipped=(variant != 1), thickness=0.11, curve_segs=8, eave_flare=0.24)
    add_game_box(bm_roof, 0.0, y2_top + 1.25, 0.0, 0.88 if variant != 1 else ubx + 0.6, 0.16, 0.16, bevel=0.02)

    # Festive veranda lanterns & cloth banners
    for sx in (-1.85, 1.85):
        _add_chochin(bm_lantern, bm_iron, sx, y1_top - 0.35, bz * 0.5 + 0.42, radius=0.14, h=0.32)
    for nx in (-0.42, 0.42):
        add_game_box(bm_noren, nx, 1.62, bz * 0.5 + 0.32, 0.38, 0.72, 0.03, bevel=0.004)

    roof_mat = (
        mats["KawaraTile"]
        if variant == 0
        else (mats["KawaraRust"] if variant == 1 else mats["KawaraMossGreen"])
    )
    finalize_mesh("teahouse_stone", bm_stone, mats["CastleIshigaki"], smooth=True, box_uv_scale=0.38)
    finalize_mesh("teahouse_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("teahouse_cedar", bm_cedar, mats["CedarTimber"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("teahouse_plaster", bm_plaster, mats["ShikkuiPlaster"], smooth=True, box_uv_scale=0.40)
    finalize_mesh("teahouse_kawara", bm_roof, roof_mat, smooth=True, box_uv_scale=0.55)
    finalize_mesh("teahouse_shoji", bm_shoji, mats["ShojiGlow"], smooth=False, box_uv_scale=None)
    finalize_mesh("teahouse_noren", bm_noren, mats["ClothCrimson"] if variant != 2 else mats["NorenIndigo"], smooth=True, box_uv_scale=0.5)
    finalize_mesh("teahouse_chochin", bm_lantern, mats["ChochinGlow"], smooth=True, box_uv_scale=0.5)
    finalize_mesh("teahouse_iron", bm_iron, mats["DarkIron"], smooth=True, box_uv_scale=0.6)
    export_glb(filename)


def build_kura_variant(variant: int, filename: str) -> None:
    """2 fireproof mud-plaster & namako-kabe merchant kura storehouses."""
    clear_scene()
    mats = get_materials()
    bm_stone = bmesh.new()
    bm_plaster = bmesh.new()
    bm_namako = bmesh.new()
    bm_charred = bmesh.new()
    bm_iron = bmesh.new()
    bm_roof = bmesh.new()
    bm_shoji = bmesh.new()

    bx, bz = (3.45, 4.10) if variant == 0 else (3.70, 3.80)
    # Stone top at +0.30; split namako-kabe lower skirt and upper plaster cleanly with proud charred waist belt
    add_game_box(bm_stone, 0.0, -0.40, 0.0, bx + 0.32, 1.40, bz + 0.32, bevel=0.04)
    h_wall = 3.61
    add_game_box(bm_namako, 0.0, 0.24 + 0.64, 0.0, bx + 0.08, 1.28, bz + 0.08, bevel=0.02)
    add_game_box(bm_charred, 0.0, 1.56, 0.0, bx + 0.18, 0.16, bz + 0.18, bevel=0.012)
    pl_h = (0.24 + h_wall) - 1.60
    add_game_box(bm_plaster, 0.0, 1.60 + pl_h * 0.5, 0.0, bx, pl_h, bz, bevel=0.03)
    # Heavy fireproof recessed door frame + iron-studded doors
    add_game_box(bm_charred, 0.0, 1.33, bz * 0.5 + 0.09, 1.15, 1.90, 0.14, bevel=0.015)
    add_game_box(bm_iron, -0.25, 1.30, bz * 0.5 + 0.17, 0.44, 1.72, 0.06, bevel=0.008)
    add_game_box(bm_iron, 0.25, 1.30, bz * 0.5 + 0.17, 0.44, 1.72, 0.06, bevel=0.008)
    # Small high fortified upper louver/shoji vent
    _add_shoji_panel(bm_shoji, 0.0, 3.10, bz * 0.5 + 0.11, 0.72, 0.46, "+z")
    _add_shoji_panel(bm_shoji, 0.0, 3.10, -bz * 0.5 - 0.11, 0.72, 0.46, "-z")

    _add_curved_roof(bm_roof, 0.0, 0.24 + h_wall + 0.05, 0.0, bx + 1.05, bz + 0.92, 1.32, ridge_axis="z" if variant == 0 else "x", hipped=(variant == 1), thickness=0.14, curve_segs=8, eave_flare=0.22)
    add_game_box(bm_roof, 0.0, 0.24 + h_wall + 1.39, 0.0, 0.20 if variant == 0 else 1.85, 0.18, (bz + 0.70) if variant == 0 else 0.20, bevel=0.02)
    if variant == 1:
        # Harbor timber loading canopy overhanging front iron doors
        _add_curved_roof(bm_roof, 0.0, 2.38, bz * 0.5 + 0.42, bx * 0.72, 0.88, 0.34, ridge_axis="x", thickness=0.09, curve_segs=5, eave_flare=0.14)

    plaster_mat = mats["PlasterBlack"] if variant == 1 else mats["ShikkuiPlaster"]
    kura_roof_mat = mats["KawaraRust"] if variant == 1 else mats["KawaraTile"]
    finalize_mesh("kura_stone", bm_stone, mats["CastleIshigaki"], smooth=True, box_uv_scale=0.38)
    finalize_mesh("kura_plaster", bm_plaster, plaster_mat, smooth=True, box_uv_scale=0.38)
    finalize_mesh("kura_namako", bm_namako, mats["NamakoKabe"], smooth=True, box_uv_scale=0.55)
    finalize_mesh("kura_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("kura_iron", bm_iron, mats["DarkIron"], smooth=True, box_uv_scale=0.60)
    finalize_mesh("kura_kawara", bm_roof, kura_roof_mat, smooth=True, box_uv_scale=0.55)
    finalize_mesh("kura_shoji", bm_shoji, mats["ShojiGlow"], smooth=False, box_uv_scale=None)
    export_glb(filename)


def build_minka_variant(variant: int, filename: str) -> None:
    """Thick curved kayabuki thatched countryside farmhouses."""
    clear_scene()
    mats = get_materials()
    bm_stone = bmesh.new()
    bm_cedar = bmesh.new()
    bm_charred = bmesh.new()
    bm_thatch = bmesh.new()
    bm_kawara = bmesh.new()
    bm_shoji = bmesh.new()

    bx, bz = (3.65, 3.30) if variant == 0 else (3.35, 3.85)
    add_game_box(bm_stone, 0.0, -0.40, 0.0, bx + 0.24, 1.24, bz + 0.24, bevel=0.04)
    add_game_box(bm_cedar, 0.0, 0.16 + 0.94, 0.0, bx, 1.88, bz)
    _add_timber_frame_and_koshi(bm_charred, bx, bz, 0.16, 2.04)

    for z_s, nd in ((bz * 0.5 + 0.11, "+z"), (-bz * 0.5 - 0.11, "-z")):
        for wx in (-0.82, 0.82):
            _add_shoji_panel(bm_shoji, wx, 1.13, z_s, 0.82, 1.02, nd)

    # Thick steep bell-curved kayabuki thatch roof (Suganuma st-25 silhouette!)
    _add_curved_roof(bm_thatch, 0.0, 2.10, 0.0, bx + 1.02, bz + 0.96, 2.15, ridge_axis="x" if variant == 0 else "z", hipped=True, thickness=0.34, curve_segs=9, eave_flare=0.12)
    # Timber chigi ridge cap pole & crossbars on top of thatch
    r_len = 2.05
    add_game_box(bm_charred, 0.0, 4.28, 0.0, r_len if variant == 0 else 0.24, 0.24, 0.24 if variant == 0 else r_len, bevel=0.02)
    # Lower wooden lean-to rain eave at side entrance
    _add_curved_roof(bm_kawara, 0.0, 1.64, bz * 0.5 + 0.30, bx * 0.72, 0.76, 0.34, thickness=0.07, curve_segs=5, eave_flare=0.10)

    finalize_mesh("minka_stone", bm_stone, mats["IshigakiStone"], smooth=True, box_uv_scale=0.40)
    finalize_mesh("minka_cedar", bm_cedar, mats["CedarTimber"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("minka_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.45)
    finalize_mesh("minka_thatch", bm_thatch, mats["KayabukiThatch"], smooth=True, box_uv_scale=0.52)
    finalize_mesh("minka_hisashi", bm_kawara, mats["CedarTimber"], smooth=True, box_uv_scale=0.55)
    finalize_mesh("minka_shoji", bm_shoji, mats["ShojiGlow"], smooth=False, box_uv_scale=None)
    export_glb(filename)


def build_yatai_variant(variant: int, filename: str) -> None:
    """4 crisp street yatai market booths / noodle carts."""
    clear_scene()
    mats = get_materials()
    bm_cedar = bmesh.new()
    bm_charred = bmesh.new()
    bm_cloth = bmesh.new()
    bm_lantern = bmesh.new()
    bm_iron = bmesh.new()

    w, d = 1.80, 1.24
    # Timber counter base & top strictly inset/clear of exterior corner posts (ZERO shared X/Z/Y faces!)
    add_game_box(bm_cedar, 0.0, 0.48, 0.0, w - 0.08, 0.80, 0.92, bevel=0.015)
    add_game_box(bm_charred, 0.0, 0.94, 0.0, w + 0.26, 0.08, d + 0.14, bevel=0.01)
    for sx in (-w * 0.50 - 0.03, w * 0.50 + 0.03):
        for sz in (-0.54, 0.54):
            add_game_box(bm_charred, sx, 1.14, sz, 0.08, 2.28, 0.08, bevel=0.008)

    # Variant roof vs fabric awning + carts wheels on v0/v2
    if variant in (0, 2):
        # Cart wheels on ends
        for side in (-1.0, 1.0):
            add_game_cylinder(bm_charred, side * (w * 0.54 + 0.05), 0.0, 0.0, 0.34, 0.34, 0.07, segments=16)
        _add_curved_roof(bm_cloth, 0.0, 2.24, 0.0, w + 0.48, d + 0.56, 0.46, ridge_axis="x", thickness=0.05, curve_segs=6, eave_flare=0.12)
    else:
        _add_curved_roof(bm_cedar, 0.0, 2.26, 0.0, w + 0.54, d + 0.60, 0.54, ridge_axis="x", thickness=0.08, curve_segs=6, eave_flare=0.14)
        # Hanging front noren curtain strip
        for nx in (-0.48, 0.0, 0.48):
            add_game_box(bm_cloth, nx, 1.88, d * 0.5 + 0.16, 0.38, 0.42, 0.02, bevel=0.004)

    if variant in (0, 2):
        _add_chochin(bm_lantern, bm_iron, -w * 0.48, 1.86, d * 0.5 + 0.24, radius=0.11, h=0.25)
    else:
        _add_chochin(bm_lantern, bm_iron, w * 0.48, 1.86, d * 0.5 + 0.24, radius=0.11, h=0.25)
    # Market wares cleanly perched >=5cm proud of counter top (y=0.98)
    bm_wares = bmesh.new()
    if variant in (0, 3):
        for wx, wz in ((-0.42, 0.0), (0.04, 0.08)):
            add_game_cylinder(bm_wares, wx, 1.03, wz, 0.17, 0.18, 0.32, segments=12)
    else:
        add_game_box(bm_wares, -0.35, 1.15, 0.0, 0.46, 0.26, 0.42, yaw=0.15, bevel=0.015)
        add_game_box(bm_wares, 0.36, 1.13, -0.04, 0.38, 0.22, 0.38, yaw=-0.22, bevel=0.015)

    cloth_mat = (
        mats["NorenIndigo"],
        mats["ClothCrimson"],
        mats["OchreCloth"],
        mats["ClothCream"],
    )[variant]
    finalize_mesh("yatai_cedar", bm_cedar, mats["CedarTimber"], smooth=True, box_uv_scale=0.55)
    finalize_mesh("yatai_charred", bm_charred, mats["CharredTimber"], smooth=True, box_uv_scale=0.55)
    finalize_mesh("yatai_cloth", bm_cloth, cloth_mat, smooth=True, box_uv_scale=0.5)
    finalize_mesh("yatai_wares", bm_wares, mats["KayabukiThatch"] if variant in (0, 3) else mats["CedarTimber"], smooth=True, box_uv_scale=0.6)
    finalize_mesh("yatai_chochin", bm_lantern, mats["ChochinGlow"], smooth=True, box_uv_scale=0.5)
    finalize_mesh("yatai_iron", bm_iron, mats["DarkIron"], smooth=True, box_uv_scale=0.6)
    export_glb(filename)


def build_all() -> None:
    build_machiya_variant(0, "machiya_hero.glb")
    build_machiya_variant(1, "machiya_hero_v1.glb")
    build_machiya_variant(2, "machiya_hero_v2.glb")
    build_machiya_variant(3, "machiya_hero_v3.glb")

    build_teahouse_variant(0, "teahouse_hero.glb")
    build_teahouse_variant(1, "teahouse_hero_v1.glb")
    build_teahouse_variant(2, "teahouse_hero_v2.glb")

    build_kura_variant(0, "kura_warehouse_hero.glb")
    build_kura_variant(1, "kura_warehouse_hero_v1.glb")

    build_minka_variant(0, "minka_hero_v0.glb")
    build_minka_variant(1, "minka_hero_v1.glb")

    for i in range(4):
        build_yatai_variant(i, f"yatai_stall_v{i}.glb")


if __name__ == "__main__":
    build_all()
