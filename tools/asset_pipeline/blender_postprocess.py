#!/usr/bin/env python3
"""Headless Blender 5.3.0 post-processor for Tripo MCP & custom Kage no Machi GLBs.

Performs:
  1. glTF import (mesh, armature, animations, materials).
  2. World-scale normalization to catalog.json dimensions_m (ground pivot y=0, +Z forward).
  3. Dual-path Stage 3 texturing:
       - tripo_keep:      keep Tripo textures, clamp non-metal roughness >= 0.45,
                          harmonize gouache tone, and downsample to max_tex_size.
       - tripo_hybrid:    keep Tripo textures on hero parts, assign Kage no Machi
                          emissives (ShojiGlow/ChochinGlow/LanternGlow) and seamless
                          gouache PBR on structural/interior parts.
       - blender_gouache: replace materials with Kage no Machi seamless Midjourney
                          gouache PBR materials from tools/blender/common.py.
  4. Cutaway house componentization (peek_roof_*, peek_upper_*, exterior_*) + recessed
     non-coplanar interior room & furnishings via tools/blender/interiors.py.
  5. Multi-clip skeletal animation merge onto primary Armature NLA tracks (idle, walk, ...).
  6. Optional 4-corner (+ cutaway roof-off) contact sheet render.
  7. Clean Y-up GLB export compatible with flutter_scene loadScene.
"""

from __future__ import annotations

import argparse
import io
import json
import math
import os
import sys
import tempfile
from pathlib import Path
from typing import Any

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
BLENDER_TOOLS_DIR = REPO_ROOT / "tools" / "blender"
if str(BLENDER_TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(BLENDER_TOOLS_DIR))

import common  # noqa: E402
import interiors  # noqa: E402


def _parse_cli() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []
    p = argparse.ArgumentParser(description="Blender post-processor for Kage no Machi GLBs")
    p.add_argument("--catalog", required=True)
    p.add_argument("--asset-id", required=True)
    p.add_argument("--input", required=True)
    p.add_argument("--output", required=True)
    p.add_argument(
        "--texture-strategy",
        default="tripo_keep",
        choices=["tripo_keep", "tripo_hybrid", "blender_gouache"],
    )
    p.add_argument("--extra-clips", default=None)
    p.add_argument("--preview-out", default=None)
    return p.parse_args(argv)


def _world_mesh_bounds(objects: list[bpy.types.Object]) -> tuple[Vector, Vector]:
    bmin = Vector((1e9, 1e9, 1e9))
    bmax = Vector((-1e9, -1e9, -1e9))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for obj in objects:
        if obj.type != "MESH":
            continue
        eval_obj = obj.evaluated_get(depsgraph)
        for corner in eval_obj.bound_box:
            wc = eval_obj.matrix_world @ Vector(corner)
            bmin.x = min(bmin.x, wc.x)
            bmin.y = min(bmin.y, wc.y)
            bmin.z = min(bmin.z, wc.z)
            bmax.x = max(bmax.x, wc.x)
            bmax.y = max(bmax.y, wc.y)
            bmax.z = max(bmax.z, wc.z)
    return bmin, bmax


def _normalize_scene_scale_and_pivot(
    root_objs: list[bpy.types.Object],
    mesh_objs: list[bpy.types.Object],
    dims_m: dict[str, float],
) -> tuple[float, float, float]:
    """Uniformly scales imported assets to target height (or max span) and seats base at Z=0 (Blender up)."""
    if not mesh_objs:
        return (dims_m["width"], dims_m["depth"], dims_m["height"])

    bmin, bmax = _world_mesh_bounds(mesh_objs)
    cur_w = max(1e-4, bmax.x - bmin.x)
    cur_d = max(1e-4, bmax.y - bmin.y)
    cur_h = max(1e-4, bmax.z - bmin.z)

    target_h = float(dims_m["height"])
    target_w = float(dims_m["width"])
    target_d = float(dims_m["depth"])
    scale_factor = target_h / cur_h
    # Guard against wildly disproportionate meshes by keeping footprint reasonable
    if cur_w * scale_factor > target_w * 1.45:
        scale_factor = min(scale_factor, (target_w * 1.15) / cur_w)
    if cur_d * scale_factor > target_d * 1.45:
        scale_factor = min(scale_factor, (target_d * 1.15) / cur_d)

    center_x = 0.5 * (bmin.x + bmax.x)
    center_y = 0.5 * (bmin.y + bmax.y)
    base_z = bmin.z

    norm_empty = bpy.data.objects.new("__norm_pivot", None)
    bpy.context.scene.collection.objects.link(norm_empty)
    for obj in root_objs:
        if obj.parent is None:
            obj.parent = norm_empty

    norm_empty.location = (-center_x * scale_factor, -center_y * scale_factor, -base_z * scale_factor)
    norm_empty.scale = (scale_factor, scale_factor, scale_factor)
    bpy.context.view_layer.update()

    # Unparent while preserving world transform; bake scale cleanly on unrigged meshes
    has_armature = any(o.type == "ARMATURE" for o in bpy.data.objects)
    for obj in list(norm_empty.children):
        world_m = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = world_m
    bpy.data.objects.remove(norm_empty, do_unlink=True)
    bpy.context.view_layer.update()

    if not has_armature:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in mesh_objs:
            obj.select_set(True)
        if mesh_objs:
            bpy.context.view_layer.objects.active = mesh_objs[0]
            bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    bmin2, bmax2 = _world_mesh_bounds(mesh_objs)
    return (bmax2.x - bmin2.x, bmax2.y - bmin2.y, bmax2.z - bmin2.z)


def _clamp_roughness_and_downsample(max_tex_size: int) -> None:
    """Removes Tripo plastic sheen and resizes embedded images to asset budget."""
    for mat in bpy.data.materials:
        if not mat.use_nodes or mat.node_tree is None:
            continue
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None:
            continue
        metallic = bsdf.inputs["Metallic"].default_value
        rough_in = bsdf.inputs["Roughness"]
        if metallic < 0.35 and not rough_in.is_linked:
            rough_in.default_value = max(0.52, float(rough_in.default_value))
        spec_in = bsdf.inputs.get("Specular IOR Level")
        if spec_in is not None and not spec_in.is_linked:
            spec_in.default_value = min(0.32, float(spec_in.default_value))

    for img in bpy.data.images:
        if img.size[0] <= 0 or img.size[1] <= 0:
            continue
        longest = max(img.size[0], img.size[1])
        if longest > max_tex_size:
            ratio = max_tex_size / float(longest)
            new_w = max(64, int(round(img.size[0] * ratio)))
            new_h = max(64, int(round(img.size[1] * ratio)))
            img.scale(new_w, new_h)
            img.pack()


def _pick_gouache_material(name: str, mats: dict[str, bpy.types.Material]) -> bpy.types.Material:
    n = name.lower()
    if any(k in n for k in ("shoji", "window", "screen")):
        return mats["ShojiGlow"]
    if any(k in n for k in ("chochin", "paper_lantern")):
        return mats["ChochinGlow"]
    if any(k in n for k in ("lantern", "firebox", "lamp", "glow", "hearth")):
        return mats["LanternGlow"]
    if any(k in n for k in ("thatch", "straw", "reed", "kayabuki")):
        return mats["KayabukiThatch"]
    if any(k in n for k in ("roof", "tile", "kawara", "ridge", "eave")):
        return mats["KawaraTile"]
    if any(k in n for k in ("stone", "plinth", "base", "ishigaki", "rock", "foundation")):
        return mats["CastleIshigaki"]
    if any(k in n for k in ("plaster", "shikkui", "stucco", "wall")):
        return mats["ShikkuiPlaster"]
    if any(k in n for k in ("noren", "banner", "cloth", "fabric", "awning")):
        return mats["NorenIndigo"]
    if any(k in n for k in ("iron", "metal", "clasp", "hinge")):
        return mats["DarkIron"]
    if any(k in n for k in ("gold", "brass", "shachihoko", "finial")):
        return mats["GoldTrim"]
    if any(k in n for k in ("vermilion", "torii", "bridge", "lacquer")):
        return mats["VermilionLacquer"]
    if any(k in n for k in ("beam", "post", "frame", "charred", "koshi")):
        return mats["CharredTimber"]
    return mats["CedarTimber"]


def _apply_texture_strategy(
    mesh_objs: list[bpy.types.Object],
    strategy: str,
    max_tex_size: int,
) -> None:
    mats = common.get_materials()
    if strategy == "tripo_keep":
        _clamp_roughness_and_downsample(max_tex_size)
        return

    if strategy == "tripo_hybrid":
        _clamp_roughness_and_downsample(max_tex_size)
        for obj in mesh_objs:
            n = obj.name.lower()
            if any(k in n for k in ("shoji", "window", "lantern", "chochin", "firebox", "stone", "plinth", "ishigaki", "roof", "kawara", "thatch")):
                mat = _pick_gouache_material(obj.name, mats)
                obj.data.materials.clear()
                obj.data.materials.append(mat)
        return

    # blender_gouache: full replacement with seamless Midjourney gouache PBR + box UVs
    for obj in mesh_objs:
        mat = _pick_gouache_material(obj.name, mats)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        common.apply_box_uv(bm, scale=0.45)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.materials.clear()
        obj.data.materials.append(mat)


def _classify_and_build_cutaway(
    mesh_objs: list[bpy.types.Object],
    asset: dict[str, Any],
    extents_xyz: tuple[float, float, float],
) -> None:
    """Applies canonical cutaway naming (peek_roof_*, peek_upper_*, exterior_*) and adds interior room."""
    rules = asset.get("stage2_componentize", {}).get("canonical_part_rules") or {
        "peek_roof": ["roof", "tile", "kawara", "thatch", "ridge", "gable", "eave"],
        "peek_upper": ["upper", "second", "balcony", "loft", "attic"],
    }
    roof_keys = [k.lower() for k in rules.get("peek_roof", [])]
    upper_keys = [k.lower() for k in rules.get("peek_upper", [])]
    stories = int(asset.get("stories", 1))
    total_h = max(1.0, extents_xyz[2])
    roof_cut_z = total_h * (0.58 if stories == 1 else 0.64)
    upper_cut_z = total_h * 0.42

    classified_roof = 0
    for idx, obj in enumerate(mesh_objs):
        low = obj.name.lower()
        if low.startswith(("peek_roof", "peek_upper", "interior_", "exterior_")):
            if low.startswith(("peek_roof", "peek_upper")):
                classified_roof += 1
            continue
        bmin, bmax = _world_mesh_bounds([obj])
        mid_z = 0.5 * (bmin.z + bmax.z)
        if any(k in low for k in roof_keys) or mid_z >= roof_cut_z:
            obj.name = f"peek_roof_{idx}_{obj.name}"
            classified_roof += 1
        elif stories >= 2 and (any(k in low for k in upper_keys) or mid_z >= upper_cut_z):
            obj.name = f"peek_upper_{idx}_{obj.name}"
        else:
            obj.name = f"exterior_{idx}_{obj.name}"

    # Fallback: if all geometry arrived as one monolithic mesh, split polygons above eave height into peek_roof
    if classified_roof == 0 and mesh_objs:
        src = mesh_objs[0]
        bm = bmesh.new()
        bm.from_mesh(src.data)
        bm.faces.ensure_lookup_table()
        bm_roof = bmesh.new()
        bm_body = bmesh.new()
        for bm_dst, want_roof in ((bm_roof, True), (bm_body, False)):
            vert_map: dict[int, bmesh.types.BMVert] = {}
            for face in bm.faces:
                fc_z = (src.matrix_world @ face.calc_center_median()).z
                if (fc_z >= roof_cut_z) != want_roof:
                    continue
                new_verts = []
                for v in face.verts:
                    if v.index not in vert_map:
                        vert_map[v.index] = bm_dst.verts.new(v.co)
                    new_verts.append(vert_map[v.index])
                try:
                    bm_dst.faces.new(new_verts)
                except ValueError:
                    pass
        bm.free()
        if len(bm_roof.faces) > 0 and len(bm_body.faces) > 0:
            mat0 = src.data.materials[0] if src.data.materials else common.get_materials()["KawaraTile"]
            mat1 = src.data.materials[0] if src.data.materials else common.get_materials()["CedarTimber"]
            src.name = "exterior_body"
            bm_body.to_mesh(src.data)
            bm_body.free()
            common.finalize_mesh("peek_roof_split", bm_roof, mat0, smooth=True, box_uv_scale=0.55)
        else:
            bm_roof.free()
            bm_body.free()
            src.name = f"peek_roof_{src.name}"

    # Ensure hillside foundation stone skirt exists below ground so terraced slopes never show gaps
    skirt_depth = float(asset.get("foundation_skirt_m", 0.0))
    dims = asset["dimensions_m"]
    bx = float(dims["width"])
    bz = float(dims["depth"])
    if skirt_depth > 0.05 and not any("foundation" in o.name.lower() or "stone" in o.name.lower() for o in mesh_objs):
        bm_skirt = bmesh.new()
        common.add_game_box(bm_skirt, 0.0, -skirt_depth * 0.5, 0.0, bx * 0.96, skirt_depth, bz * 0.96, bevel=0.03)
        common.finalize_mesh(
            "exterior_foundation_skirt",
            bm_skirt,
            common.get_materials()["CastleIshigaki"],
            smooth=True,
            box_uv_scale=0.38,
        )

    # Assemble strictly inset, non-coplanar cutaway interior room & props
    archetype = str(asset.get("interior_archetype", "machiya"))
    interiors.build_house_interior(
        archetype=archetype,
        inner_bx=max(1.8, bx - 0.56),
        inner_bz=max(1.8, bz - 0.56),
        floor_y=0.38,
        wall_top_y=1.96,
        mats=common.get_materials(),
    )


def _merge_extra_clips(extra_clips_arg: str) -> None:
    """Imports additional retargeted Tripo GLBs and attaches their actions onto the primary Armature."""
    armatures = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if not armatures:
        print("Warning: --extra-clips provided but base GLB has no Armature; skipping merge.")
        return
    primary_arm = armatures[0]
    if primary_arm.animation_data is None:
        primary_arm.animation_data_create()

    # Push existing base action onto an NLA track if present
    if primary_arm.animation_data.action is not None:
        base_act = primary_arm.animation_data.action
        track = primary_arm.animation_data.nla_tracks.new()
        track.name = base_act.name
        track.strips.new(base_act.name, int(base_act.frame_range[0]), base_act)
        primary_arm.animation_data.action = None

    for pair in extra_clips_arg.split(","):
        if "=" not in pair:
            continue
        clip_name, clip_path_raw = pair.split("=", 1)
        clip_name = clip_name.strip()
        clip_path = Path(clip_path_raw.strip()).resolve()
        if not clip_path.exists():
            raise FileNotFoundError(f"Extra clip GLB not found: {clip_path}")

        before_objs = set(bpy.data.objects)
        before_acts = set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=str(clip_path))
        new_objs = [o for o in bpy.data.objects if o not in before_objs]
        new_acts = [a for a in bpy.data.actions if a not in before_acts]

        if new_acts:
            act = new_acts[0]
            act.name = clip_name
            track = primary_arm.animation_data.nla_tracks.new()
            track.name = clip_name
            track.strips.new(clip_name, int(act.frame_range[0]), act)

        for obj in new_objs:
            bpy.data.objects.remove(obj, do_unlink=True)


def _render_preview_sheet(preview_out: Path, is_peekable: bool) -> None:
    """Renders 4 corner views (+ cutaway roof-off view for peekable buildings) into one contact sheet."""
    from PIL import Image

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("PreviewWorld")
    scene.world.color = (0.16, 0.18, 0.22)

    mesh_objs = [o for o in bpy.data.objects if o.type == "MESH"]
    bmin, bmax = _world_mesh_bounds(mesh_objs)
    center = 0.5 * (bmin + bmax)
    radius = max(0.8, (bmax - bmin).length * 0.5)

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 45
    cam_obj = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj

    angles = [math.radians(45), math.radians(135), math.radians(225), math.radians(315)]
    tiles: list[Image.Image] = []

    with tempfile.TemporaryDirectory() as tmpdir:
        for i, az in enumerate(angles):
            dist = radius * 2.8
            cam_obj.location = (
                center.x + math.cos(az) * dist,
                center.y + math.sin(az) * dist,
                center.z + radius * 1.15,
            )
            direction = center - cam_obj.location
            cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
            tile_path = Path(tmpdir) / f"view_{i}.png"
            scene.render.filepath = str(tile_path)
            bpy.ops.render.render(write_still=True)
            tiles.append(Image.open(tile_path).convert("RGB"))

        if is_peekable:
            for obj in mesh_objs:
                low = obj.name.lower()
                if low.startswith(("peek_roof", "peek_upper")):
                    obj.hide_render = True
                elif low.startswith("interior_"):
                    obj.hide_render = False
            dist = radius * 2.4
            cam_obj.location = (center.x + dist * 0.55, center.y - dist * 0.55, center.z + radius * 1.75)
            direction = center - cam_obj.location
            cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
            cut_path = Path(tmpdir) / "cutaway.png"
            scene.render.filepath = str(cut_path)
            bpy.ops.render.render(write_still=True)
            tiles.append(Image.open(cut_path).convert("RGB"))
            for obj in mesh_objs:
                obj.hide_render = False

    bpy.data.objects.remove(cam_obj, do_unlink=True)
    bpy.data.cameras.remove(cam_data)

    sheet = Image.new("RGB", (480 * len(tiles), 480))
    for i, tile in enumerate(tiles):
        sheet.paste(tile, (i * 480, 0))
    preview_out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(preview_out)
    print(f"Saved preview sheet -> {preview_out}")


def main() -> None:
    args = _parse_cli()
    with open(args.catalog, "r", encoding="utf-8") as fh:
        catalog = json.load(fh)
    amap = {item["id"]: item for item in catalog["assets"]}
    if args.asset_id not in amap:
        raise KeyError(f"Asset '{args.asset_id}' not found in {args.catalog}")
    asset = amap[args.asset_id]

    common.clear_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    root_objs = [o for o in bpy.data.objects if o.parent is None]
    mesh_objs = [o for o in bpy.data.objects if o.type == "MESH"]

    extents_xyz = _normalize_scene_scale_and_pivot(root_objs, mesh_objs, asset["dimensions_m"])
    max_tex = int(asset.get("stage3_texture", {}).get("max_tex_size", 1024))
    _apply_texture_strategy(mesh_objs, args.texture_strategy, max_tex)

    if asset.get("peekable"):
        _classify_and_build_cutaway(mesh_objs, asset, extents_xyz)

    if args.extra_clips:
        _merge_extra_clips(args.extra_clips)

    if args.preview_out:
        _render_preview_sheet(Path(args.preview_out), bool(asset.get("peekable")))

    out_path = Path(args.output).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    has_anim = any(o.type == "ARMATURE" for o in bpy.data.objects) or len(bpy.data.actions) > 0
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        export_yup=True,
        export_apply=not has_anim,
        export_texcoords=True,
        export_normals=True,
        export_tangents=True,
        export_materials="EXPORT",
        export_animations=has_anim,
        export_nla_strips=has_anim,
        export_skins=has_anim,
        export_image_format="JPEG",
        export_jpeg_quality=90,
        use_selection=False,
    )
    print(f"Post-processed {args.asset_id} -> {out_path} ({out_path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
