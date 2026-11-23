"""Shared Blender 5.3.0 utilities, materials, spline sweeps, and glTF export."""

from __future__ import annotations

import math
import os
import random
from typing import Iterable, Sequence

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TEX_DIR = os.path.join(ROOT, "assets", "textures")
GEN_TEX_DIR = os.path.join(ROOT, "tools", "blender", "generated_tex")
MODELS_DIR = os.path.join(ROOT, "assets", "models")

_IMAGE_CACHE: dict[str, bpy.types.Image] = {}
_MAT_CACHE: dict[str, bpy.types.Material] = {}


def g2b(x: float, y_up: float, z: float) -> Vector:
    """Converts game/glTF coordinates (X, Y_up, Z) to Blender Z-up (X, -Z, Y_up)."""
    return Vector((x, -z, y_up))


def clear_scene() -> None:
    """Resets Blender scene objects, orphan meshes, and material/image caches."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _IMAGE_CACHE.clear()
    _MAT_CACHE.clear()


def _resolve_tex(rel: str) -> str:
    p1 = os.path.join(GEN_TEX_DIR, rel)
    if os.path.exists(p1):
        return p1
    p2 = os.path.join(TEX_DIR, rel)
    if os.path.exists(p2):
        return p2
    raise FileNotFoundError(f"Texture not found: {rel}")


def load_image(rel: str, colorspace: str = "sRGB") -> bpy.types.Image:
    key = f"{rel}:{colorspace}"
    if key in _IMAGE_CACHE and _IMAGE_CACHE[key].name in bpy.data.images:
        return _IMAGE_CACHE[key]
    path = _resolve_tex(rel)
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = colorspace
    img.pack()
    _IMAGE_CACHE[key] = img
    return img


def _make_tex_material(
    name: str,
    albedo_file: str,
    normal_file: str | None = None,
    *,
    tint: tuple[float, float, float, float] = (1.0, 1.0, 1.0, 1.0),
    roughness: float = 0.84,
    metallic: float = 0.0,
    specular: float = 0.25,
    normal_strength: float = 1.0,
    uv_scale: float = 1.0,
    emissive_file: str | None = None,
    emissive_color: tuple[float, float, float] | None = None,
    emissive_strength: float = 0.0,
    alpha_cutout: bool = False,
    double_sided: bool = False,
) -> bpy.types.Material:
    if name in _MAT_CACHE and _MAT_CACHE[name].name in bpy.data.materials:
        return _MAT_CACHE[name]
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    mat.use_backface_culling = not double_sided
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Specular IOR Level"].default_value = specular
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    tex_coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (uv_scale, uv_scale, uv_scale)
    nt.links.new(tex_coord.outputs["UV"], mapping.inputs["Vector"])

    tex_a = nt.nodes.new("ShaderNodeTexImage")
    tex_a.image = load_image(albedo_file, "sRGB")
    nt.links.new(mapping.outputs["Vector"], tex_a.inputs["Vector"])

    if tint != (1.0, 1.0, 1.0, 1.0):
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs["B"].default_value = tint
        nt.links.new(tex_a.outputs["Color"], mix.inputs["A"])
        nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    else:
        nt.links.new(tex_a.outputs["Color"], bsdf.inputs["Base Color"])

    if alpha_cutout:
        mat.blend_method = "CLIP"
        mat.alpha_threshold = 0.35
        nt.links.new(tex_a.outputs["Alpha"], bsdf.inputs["Alpha"])

    if normal_file:
        tex_n = nt.nodes.new("ShaderNodeTexImage")
        tex_n.image = load_image(normal_file, "Non-Color")
        nt.links.new(mapping.outputs["Vector"], tex_n.inputs["Vector"])
        nrm_map = nt.nodes.new("ShaderNodeNormalMap")
        nrm_map.inputs["Strength"].default_value = normal_strength
        nt.links.new(tex_n.outputs["Color"], nrm_map.inputs["Color"])
        nt.links.new(nrm_map.outputs["Normal"], bsdf.inputs["Normal"])

    if emissive_file:
        tex_e = nt.nodes.new("ShaderNodeTexImage")
        tex_e.image = load_image(emissive_file, "sRGB")
        nt.links.new(mapping.outputs["Vector"], tex_e.inputs["Vector"])
        nt.links.new(tex_e.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emissive_strength
    elif emissive_color is not None and emissive_strength > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*emissive_color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emissive_strength

    _MAT_CACHE[name] = mat
    return mat


def _make_flat_material(
    name: str,
    base_color: tuple[float, float, float, float],
    *,
    roughness: float = 0.72,
    metallic: float = 0.0,
    specular: float = 0.28,
    emissive_color: tuple[float, float, float] | None = None,
    emissive_strength: float = 0.0,
    double_sided: bool = False,
) -> bpy.types.Material:
    if name in _MAT_CACHE and _MAT_CACHE[name].name in bpy.data.materials:
        return _MAT_CACHE[name]
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    mat.use_backface_culling = not double_sided
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = base_color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Specular IOR Level"].default_value = specular
    if emissive_color is not None:
        bsdf.inputs["Emission Color"].default_value = (*emissive_color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emissive_strength
    _MAT_CACHE[name] = mat
    return mat


def get_materials() -> dict[str, bpy.types.Material]:
    """Builds and returns the standardized Kage no Machi PBR material set."""
    return {
        "CedarTimber": _make_tex_material(
            "CedarTimber", "cedar_timber.png", "cedar_timber_normal.png",
            tint=(0.76, 0.58, 0.44, 1.0), roughness=0.78, normal_strength=0.95, uv_scale=0.45,
        ),
        "CharredTimber": _make_tex_material(
            "CharredTimber", "cedar_timber.png", "cedar_timber_normal.png",
            tint=(0.24, 0.16, 0.12, 1.0), roughness=0.74, normal_strength=1.0, uv_scale=0.45,
        ),
        "HarborPlanks": _make_tex_material(
            "HarborPlanks", "harbor_planks.png", "harbor_planks_normal.png",
            tint=(0.82, 0.68, 0.56, 1.0), roughness=0.80, normal_strength=1.0, uv_scale=0.40,
        ),
        "CastleIshigaki": _make_tex_material(
            "CastleIshigaki", "castle_ishigaki.png", "castle_ishigaki_normal.png",
            tint=(0.86, 0.84, 0.80, 1.0), roughness=0.88, normal_strength=1.05, uv_scale=0.35,
        ),
        "IshigakiStone": _make_tex_material(
            "IshigakiStone", "ishigaki_stone.png", "ishigaki_stone_normal.png",
            tint=(0.82, 0.80, 0.75, 1.0), roughness=0.88, normal_strength=1.05, uv_scale=0.38,
        ),
        "CliffRock": _make_tex_material(
            "CliffRock", "cliff_rock.png", "cliff_rock_normal.png",
            tint=(0.84, 0.85, 0.80, 1.0), roughness=0.90, specular=0.14, normal_strength=1.15, uv_scale=0.32,
        ),
        "CobbleStone": _make_tex_material(
            "CobbleStone", "cobblestone_edo.png", "cobblestone_edo_normal.png",
            tint=(0.90, 0.88, 0.84, 1.0), roughness=0.84, specular=0.18, normal_strength=1.05, uv_scale=0.45,
        ),
        "KawaraTile": _make_tex_material(
            "KawaraTile", "kawara_tile.png", "kawara_tile_normal.png",
            tint=(0.56, 0.66, 0.78, 1.0), roughness=0.58, specular=0.38, normal_strength=1.1, uv_scale=0.55,
        ),
        "KawaraRust": _make_tex_material(
            "KawaraRust", "kawara_tile.png", "kawara_tile_normal.png",
            tint=(0.52, 0.34, 0.25, 1.0), roughness=0.64, specular=0.30, normal_strength=1.1, uv_scale=0.55,
        ),
        "KayabukiThatch": _make_tex_material(
            "KayabukiThatch", "kayabuki_thatch.png", "kayabuki_thatch_normal.png",
            tint=(0.86, 0.74, 0.52, 1.0), roughness=0.92, specular=0.08, normal_strength=1.05, uv_scale=0.50,
        ),
        "ShikkuiPlaster": _make_tex_material(
            "ShikkuiPlaster", "shikkui_plaster.png", "shikkui_plaster_normal.png",
            tint=(0.88, 0.84, 0.76, 1.0), roughness=0.86, specular=0.14, normal_strength=0.65, uv_scale=0.40,
        ),
        "NamakoKabe": _make_tex_material(
            "NamakoKabe", "shikkui_plaster.png", "shikkui_plaster_normal.png",
            tint=(0.30, 0.32, 0.36, 1.0), roughness=0.72, normal_strength=0.90, uv_scale=0.55,
        ),
        "VermilionLacquer": _make_flat_material(
            "VermilionLacquer", (0.52, 0.085, 0.045, 1.0), roughness=0.42, specular=0.44,
        ),
        "AntiqueBronze": _make_flat_material(
            "AntiqueBronze", (0.28, 0.34, 0.25, 1.0), roughness=0.48, metallic=0.65,
        ),
        "GoldTrim": _make_flat_material(
            "GoldTrim", (0.86, 0.64, 0.20, 1.0), roughness=0.32, metallic=0.82,
        ),
        "DarkIron": _make_flat_material(
            "DarkIron", (0.12, 0.13, 0.15, 1.0), roughness=0.46, metallic=0.72,
        ),
        "HempRope": _make_flat_material(
            "HempRope", (0.42, 0.31, 0.18, 1.0), roughness=0.90, specular=0.08,
        ),
        "NorenIndigo": _make_flat_material(
            "NorenIndigo", (0.08, 0.13, 0.26, 1.0), roughness=0.88, specular=0.08, double_sided=True,
        ),
        "ClothCrimson": _make_flat_material(
            "ClothCrimson", (0.44, 0.07, 0.05, 1.0), roughness=0.84, specular=0.10, double_sided=True,
        ),
        "ClothCream": _make_flat_material(
            "ClothCream", (0.64, 0.56, 0.43, 1.0), roughness=0.92, specular=0.06, double_sided=True,
        ),
        "SailCanvas": _make_tex_material(
            "SailCanvas", "shikkui_plaster.png", "shikkui_plaster_normal.png",
            tint=(0.82, 0.76, 0.64, 1.0), roughness=0.86, specular=0.08, normal_strength=0.45, uv_scale=0.35, double_sided=True,
        ),
        "StrawBale": _make_tex_material(
            "StrawBale", "kayabuki_thatch.png", "kayabuki_thatch_normal.png",
            tint=(0.78, 0.66, 0.42, 1.0), roughness=0.94, specular=0.06, uv_scale=0.6,
        ),
        "ShojiGlow": _make_tex_material(
            "ShojiGlow", "shoji_kumiko_albedo.png", None,
            roughness=0.85, specular=0.05, uv_scale=1.0,
            emissive_file="shoji_kumiko_emissive.png", emissive_strength=0.85,
        ),
        "ChochinGlow": _make_flat_material(
            "ChochinGlow", (0.94, 0.28, 0.06, 1.0), roughness=0.72,
            emissive_color=(1.0, 0.30, 0.05), emissive_strength=2.6,
        ),
        "LanternGlow": _make_flat_material(
            "LanternGlow", (0.98, 0.64, 0.22, 1.0), roughness=0.75,
            emissive_color=(1.0, 0.62, 0.18), emissive_strength=2.8,
        ),
        "BeaconGlow": _make_flat_material(
            "BeaconGlow", (1.0, 0.68, 0.20, 1.0), roughness=0.65,
            emissive_color=(1.0, 0.58, 0.12), emissive_strength=3.6,
        ),
        "PineFoliage": _make_tex_material(
            "PineFoliage", "foliage_pine.png", None,
            tint=(0.76, 0.86, 0.70, 1.0), roughness=0.92, specular=0.06, uv_scale=1.0,
            alpha_cutout=True, double_sided=True,
        ),
        "MapleCrimsonFoliage": _make_tex_material(
            "MapleCrimsonFoliage", "foliage_maple.png", None,
            tint=(0.94, 0.84, 0.82, 1.0), roughness=0.90, specular=0.06, uv_scale=1.0,
            alpha_cutout=True, double_sided=True,
        ),
        "MapleGoldFoliage": _make_tex_material(
            "MapleGoldFoliage", "foliage_maple_gold.png", None,
            tint=(0.98, 0.90, 0.78, 1.0), roughness=0.90, specular=0.06, uv_scale=1.0,
            alpha_cutout=True, double_sided=True,
        ),
        "WillowFoliage": _make_tex_material(
            "WillowFoliage", "foliage_willow.png", None,
            tint=(0.86, 0.92, 0.76, 1.0), roughness=0.92, specular=0.06, uv_scale=1.0,
            alpha_cutout=True, double_sided=True,
        ),
        "BambooFoliage": _make_tex_material(
            "BambooFoliage", "foliage_bamboo.png", None,
            tint=(0.84, 0.92, 0.78, 1.0), roughness=0.90, specular=0.06, uv_scale=1.0,
            alpha_cutout=True, double_sided=True,
        ),
        "MapleBark": _make_tex_material(
            "MapleBark", "cedar_timber.png", "cedar_timber_normal.png",
            tint=(0.24, 0.18, 0.14, 1.0), roughness=0.92, specular=0.08, uv_scale=0.65,
        ),
        "PineBark": _make_tex_material(
            "PineBark", "cedar_timber.png", "cedar_timber_normal.png",
            tint=(0.28, 0.19, 0.13, 1.0), roughness=0.92, specular=0.08, uv_scale=0.65,
        ),
        "WillowBark": _make_tex_material(
            "WillowBark", "cedar_timber.png", "cedar_timber_normal.png",
            tint=(0.26, 0.22, 0.16, 1.0), roughness=0.92, specular=0.08, uv_scale=0.65,
        ),
        "BambooCulm": _make_flat_material(
            "BambooCulm", (0.33, 0.37, 0.21, 1.0), roughness=0.86, specular=0.08,
        ),
        "MountainVistaMat": _make_tex_material(
            "MountainVistaMat", "mountain_forest.png", "mountain_forest_normal.png",
            tint=(0.88, 0.90, 0.92, 1.0), roughness=1.0, specular=0.0, uv_scale=1.0,
        ),
    }


def apply_box_uv(bm: bmesh.types.BMesh, scale: float = 1.0) -> None:
    """Applies world-space cubic box UVs directly to every face corner of bm."""
    uv_layer = bm.loops.layers.uv.verify()
    for face in bm.faces:
        n = face.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in face.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                u, v = co.x * scale, co.y * scale
            elif ax >= ay:
                u, v = co.y * scale, co.z * scale
            else:
                u, v = co.x * scale, co.z * scale
            loop[uv_layer].uv = (u, v)


def set_face_uv_quad(face: bmesh.types.BMFace, uv_layer, u0: float = 0.0, v0: float = 0.0, u1: float = 1.0, v1: float = 1.0) -> None:
    """Maps 4 corners of a quad cleanly to [u0..u1] x [v0..v1]."""
    uvs = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
    for loop, uv in zip(face.loops, uvs):
        loop[uv_layer].uv = uv


def finalize_mesh(
    name: str,
    bm: bmesh.types.BMesh,
    material: bpy.types.Material,
    *,
    smooth: bool = True,
    box_uv_scale: float | None = 1.0,
    recalc_normals: bool = True,
) -> bpy.types.Object | None:
    """Finalizes a non-empty BMesh into a scene Object with optional box UVs and smooth shading."""
    if len(bm.verts) == 0:
        bm.free()
        return None
    if recalc_normals:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    else:
        bm.normal_update()
    if box_uv_scale is not None:
        apply_box_uv(bm, scale=box_uv_scale)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def add_game_box(
    bm: bmesh.types.BMesh,
    cx: float,
    cy_up: float,
    cz: float,
    sx: float,
    sy_up: float,
    sz: float,
    yaw: float = 0.0,
    bevel: float = 0.0,
) -> list[bmesh.types.BMVert]:
    """Adds a box specified in game coordinates (center + full dimensions)."""
    mat = Matrix.Translation(g2b(cx, cy_up, cz)) @ Euler((0.0, 0.0, yaw), "XYZ").to_matrix().to_4x4()
    scale_m = Matrix.Diagonal((sx, sz, sy_up, 1.0))
    ret = bmesh.ops.create_cube(bm, size=1.0, matrix=mat @ scale_m)
    verts = ret["verts"]
    if bevel > 0.0:
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=2, affect="EDGES", clamp_overlap=True)
    return verts


def add_game_cylinder(
    bm: bmesh.types.BMesh,
    cx: float,
    y_bot: float,
    cz: float,
    r_bot: float,
    r_top: float,
    height: float,
    segments: int = 16,
    cap_ends: bool = True,
) -> list[bmesh.types.BMVert]:
    """Adds a vertical cylinder/frustum in game space."""
    center = g2b(cx, y_bot + height * 0.5, cz)
    ret = bmesh.ops.create_cone(
        bm,
        cap_ends=cap_ends,
        cap_tris=False,
        segments=segments,
        radius1=r_bot,
        radius2=r_top,
        depth=height,
        matrix=Matrix.Translation(center),
    )
    return ret["verts"]


def add_swept_tube(
    bm: bmesh.types.BMesh,
    points_game: Sequence[tuple[float, float, float]],
    radii: Sequence[float],
    segments: int = 10,
    cap_ends: bool = True,
) -> None:
    """Sweeps a smooth circular cross-section along game-space points."""
    if len(points_game) < 2:
        return
    pts = [g2b(p[0], p[1], p[2]) for p in points_game]
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
        # Parallel-transport orthonormal frame without sudden twist
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
            s_next = (s + 1) % segments
            bm.faces.new((r0[s], r0[s_next], r1[s_next], r1[s]))
    if cap_ends:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])


def add_cambered_beam(
    bm: bmesh.types.BMesh,
    p0: tuple[float, float, float],
    p1: tuple[float, float, float],
    camber_y: float,
    half_width: float,
    half_thick: float,
    segments: int = 16,
) -> None:
    """Adds a smoothly curved rectangular arch beam between two game points."""
    p0v = Vector(p0)
    p1v = Vector(p1)
    dx = p1v.x - p0v.x
    dz = p1v.z - p0v.z
    horiz = math.hypot(dx, dz) or 1.0
    # Horizontal side perpendicular to span in game XZ -> Blender XY
    perp_b = g2b(-dz / horiz, 0.0, dx / horiz).normalized()
    up_b = Vector((0.0, 0.0, 1.0))

    rings: list[list[bmesh.types.BMVert]] = []
    for i in range(segments + 1):
        t = i / segments
        arch = camber_y * 4.0 * t * (1.0 - t)
        gp = p0v.lerp(p1v, t)
        center = g2b(gp.x, gp.y + arch, gp.z)
        c0 = bm.verts.new(center - perp_b * half_width - up_b * half_thick)
        c1 = bm.verts.new(center + perp_b * half_width - up_b * half_thick)
        c2 = bm.verts.new(center + perp_b * half_width + up_b * half_thick)
        c3 = bm.verts.new(center - perp_b * half_width + up_b * half_thick)
        rings.append([c0, c1, c2, c3])

    for i in range(segments):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(4):
            sn = (s + 1) % 4
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])


def export_glb(filename: str, *, has_alpha: bool = False) -> str:
    """Exports all objects currently in the scene to assets/models/<filename>."""
    out_path = os.path.join(MODELS_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_vertex_color="ACTIVE",
        export_image_format="AUTO" if has_alpha else "JPEG",
        export_jpeg_quality=90,
        use_selection=False,
    )
    print(f"Exported {filename} ({os.path.getsize(out_path) // 1024} KB)")
    return out_path
