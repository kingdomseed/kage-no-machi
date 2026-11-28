#!/usr/bin/env python3
"""Kage no Machi 3D asset workflow CLI (Midjourney -> Tripo MCP -> Blender -> flutter_scene).

Subcommands:
  status        Show stage progress across catalog.json and state.json.
  prompts       Print Stage 0 Midjourney prompts and detect local references.
  plan-tripo    Emit schema-validated Tripo MCP JSON payloads for Stages 1-5.
  record        Atomically persist non-secret task/model IDs into state.json.
  upload-grant  Read Tripo upload grant JSON from stdin and HTTP/2 PUT the file.
  download-glb  Read signed model_url from stdin and HTTP/2 download + inspect.
  postprocess   Run headless Blender 5.3.0 normalization, cutaway & verification.
  verify-glb    Validate GLB header, extensions, cutaway hierarchy, rig & textures.
"""

from __future__ import annotations

import argparse
import io
import json
import mimetypes
import os
import shutil
import struct
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
CATALOG_PATH = HERE / "catalog.json"
STATE_PATH = HERE / "state.json"
WORK_DIR = HERE / "work"
MJ_ASSETS_DIR = REPO_ROOT / "docs" / "references" / "midjourney" / "assets"

FORBIDDEN_STATE_KEYS = {
    "upload_url",
    "download_url",
    "model_url",
    "required_headers",
    "authorization",
    "token",
    "signature",
    "x-amz-signature",
}

SUPPORTED_FLUTTER_SCENE_EXTENSIONS = {
    "KHR_texture_transform",
    "EXT_meshopt_compression",
    "KHR_mesh_quantization",
    "KHR_draco_mesh_compression",
    "KHR_materials_unlit",
    "KHR_materials_emissive_strength",
    "KHR_materials_ior",
    "KHR_materials_specular",
    "KHR_materials_clearcoat",
    "KHR_materials_sheen",
    "KHR_materials_transmission",
    "KHR_materials_volume",
    "KHR_materials_variants",
    "KHR_materials_pbrSpecularGlossiness",
}

MAX_TRIPO_IMAGE_BYTES = 20 * 1024 * 1024
ALLOWED_IMAGE_MIMES = {"image/png", "image/jpeg", "image/webp"}
HD_VERSIONS = {"v2.5-20250123", "v3.0-20250812", "v3.1-20260211"}
SMART_MESH_VERSIONS = {"Nexus-v1.0-20260214", "Nexus-v2.0-20260801"}


def load_catalog(path: Path = CATALOG_PATH) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def get_asset_map(catalog: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {item["id"]: item for item in catalog["assets"]}


def _contains_forbidden_key(obj: Any) -> str | None:
    if isinstance(obj, dict):
        for k, v in obj.items():
            kl = str(k).lower()
            if kl in FORBIDDEN_STATE_KEYS or any(bad in kl for bad in ("upload_url", "download_url", "model_url", "authorization", "signature", "token")):
                return str(k)
            nested = _contains_forbidden_key(v)
            if nested is not None:
                return nested
    elif isinstance(obj, list):
        for item in obj:
            nested = _contains_forbidden_key(item)
            if nested is not None:
                return nested
    return None


def load_state(path: Path = STATE_PATH) -> dict[str, Any]:
    if not path.exists():
        return {"schema_version": 1, "assets": {}}
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def save_state(state: dict[str, Any], path: Path = STATE_PATH) -> None:
    bad = _contains_forbidden_key(state)
    if bad is not None:
        raise ValueError(f"Refusing to persist secret/signed field in state.json: {bad}")
    tmp = path.with_suffix(".json.tmp")
    with tmp.open("w", encoding="utf-8") as fh:
        json.dump(state, fh, indent=2, sort_keys=True)
        fh.write("\n")
    os.replace(tmp, path)


def idempotency_key(asset_id: str, stage: int, substep: str = "", rev: int = 1) -> str:
    slug = asset_id.replace("_", "-")
    mid = f"-{substep.replace('_', '-')}" if substep else ""
    key = f"knm-{slug}-s{stage}{mid}-v{rev}"
    if len(key) > 128:
        key = key[:128]
    return key


def reference_dir_for(asset_id: str) -> Path:
    return MJ_ASSETS_DIR / asset_id


def discover_local_references(asset_id: str) -> dict[str, str]:
    ref_dir = reference_dir_for(asset_id)
    found: dict[str, str] = {}
    if not ref_dir.exists():
        return found
    for view in ("front", "left", "right", "back", "interior", "sheet"):
        for ext in (".png", ".jpg", ".jpeg", ".webp"):
            candidate = ref_dir / f"{view}{ext}"
            if candidate.exists():
                found[view] = str(candidate.relative_to(REPO_ROOT))
                break
    return found


def build_midjourney_prompts(
    asset: dict[str, Any],
    style_bible: dict[str, Any],
    *,
    sref: str | None = None,
) -> dict[str, Any]:
    mj = asset["stage0_midjourney"]
    use_char = bool(mj.get("use_character_suffix", False))
    suffix = (
        style_bible["midjourney_character_suffix"]
        if use_char
        else style_bible["midjourney_extraction_suffix"]
    )
    ar = mj.get("aspect_ratio", "1:1")
    ar_flag = "" if "--ar " in suffix else f" --ar {ar}"
    sref_flag = f" --sref {sref}" if sref else ""
    exterior_prompt = f"{mj['subject_prompt']}, {suffix}{ar_flag}{sref_flag}"
    out: dict[str, Any] = {
        "asset_id": asset["id"],
        "category": asset["category"],
        "label": asset["label"],
        "reference_dir": str(reference_dir_for(asset["id"]).relative_to(REPO_ROOT)),
        "views": mj.get("views", ["front"]),
        "local_files": discover_local_references(asset["id"]),
        "exterior_prompt": exterior_prompt,
    }
    if mj.get("interior_prompt"):
        int_suffix = style_bible["midjourney_interior_suffix"]
        out["interior_prompt"] = f"{mj['interior_prompt']}, {int_suffix}{sref_flag}"
    return out


def build_tripo_plan(
    asset: dict[str, Any],
    *,
    stage: str = "all",
    rev: int = 1,
    prefer_smart_mesh: bool = False,
    source_model_id: str | None = None,
    image_key: str | None = None,
    multiview_keys: dict[str, str] | None = None,
    part_names: list[str] | None = None,
    state_entry: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Builds strictly schema-compliant Tripo MCP payloads for Stages 1-5."""
    aid = asset["id"]
    st = state_entry or {}
    s1_cfg = dict(asset["stage1_tripo"])
    s2_cfg = dict(asset.get("stage2_componentize", {"mode": "none"}))
    s3_cfg = dict(asset.get("stage3_texture", {}))
    s4_cfg = dict(asset.get("stage4_rig", {"enabled": False}))
    s5_cfg = dict(asset.get("stage5_animate", {"enabled": False}))

    if prefer_smart_mesh and s1_cfg["family"] == "hd":
        s1_cfg["family"] = "smart_mesh"
        s1_cfg["model_version"] = "Nexus-v2.0-20260801"
        s1_cfg["face_limit"] = 20000 if asset.get("peekable") else 16000
        s1_cfg["quad"] = True
        s1_cfg["symmetry"] = False
        s1_cfg.pop("geometry_quality", None)
        s1_cfg.pop("generate_parts", None)
        s1_cfg.pop("segmentation_granularity", None)
        if s2_cfg.get("mode") == "from_generation":
            s2_cfg["mode"] = "segment"

    family = s1_cfg["family"]
    version = s1_cfg["model_version"]
    if family == "hd" and version not in HD_VERSIONS:
        raise ValueError(f"Unsupported HD model_version: {version}")
    if family == "smart_mesh" and version not in SMART_MESH_VERSIONS:
        raise ValueError(f"Unsupported Smart Mesh model_version: {version}")

    steps: list[dict[str, Any]] = []
    want_all = stage == "all"

    # --- Stage 1: Model Generation ---
    if want_all or stage == "1":
        use_multiview = bool(s1_cfg.get("multiview", False))
        if multiview_keys and "front" in multiview_keys and len(multiview_keys) >= 2:
            use_multiview = True
        elif image_key and not multiview_keys:
            use_multiview = False

        tool_name = "tripo_multiview_to_model" if use_multiview else "tripo_image_to_model"
        gen_parts = bool(s1_cfg.get("generate_parts", False)) and family == "hd"
        texture_flag = False if gen_parts else bool(s1_cfg.get("texture", False))

        payload: dict[str, Any] = {
            "idempotency_key": idempotency_key(aid, 1, "model", rev),
            "family": family,
            "model_version": version,
            "texture": texture_flag,
        }
        if use_multiview:
            mv = multiview_keys or {}
            payload["front"] = mv.get("front", "<upload_grant.object_key for front>")
            for side in ("left", "right", "back"):
                if side in mv:
                    payload[side] = mv[side]
                elif side in asset["stage0_midjourney"].get("views", []):
                    payload[side] = f"<upload_grant.object_key for {side}>"
            if len([k for k in ("left", "right", "back") if k in payload]) == 0:
                payload["back"] = "<upload_grant.object_key for back>"
        else:
            payload["image_key"] = image_key or "<upload_grant.object_key for front>"

        if family == "smart_mesh":
            face_limit = int(s1_cfg.get("face_limit", 12000))
            if face_limit < 500:
                raise ValueError("Smart Mesh face_limit must be >= 500")
            payload["face_limit"] = face_limit
            if version == "Nexus-v2.0-20260801":
                payload["quad"] = bool(s1_cfg.get("quad", True))
                if "symmetry" in s1_cfg:
                    payload["symmetry"] = bool(s1_cfg["symmetry"])
            else:
                payload["quad"] = False
        else:
            if version == "v3.1-20260211" and "geometry_quality" in s1_cfg:
                payload["geometry_quality"] = s1_cfg["geometry_quality"]
            if "face_limit" in s1_cfg:
                payload["face_limit"] = int(s1_cfg["face_limit"])
            if "quad" in s1_cfg:
                payload["quad"] = bool(s1_cfg["quad"])
            if gen_parts:
                payload["generate_parts"] = True
                payload["segmentation_granularity"] = s1_cfg.get(
                    "segmentation_granularity", "balanced"
                )

        if texture_flag:
            payload["pbr"] = bool(s3_cfg.get("pbr", True))
            payload["texture_quality"] = s3_cfg.get("texture_quality", "standard")
            payload["delight"] = bool(s3_cfg.get("delight", True))

        ref_credits = (
            "100 base credits (Smart Mesh P2 reference estimate; Studio-side plan terms apply)"
            if version == "Nexus-v2.0-20260801"
            else (
                "35 base credits (Smart Mesh P1 reference estimate)"
                if version == "Nexus-v1.0-20260214"
                else (
                    "15 base + 15 detailed geometry + 30 part generation = ~60 reference credits (not live account balance)"
                    if gen_parts and payload.get("geometry_quality") == "detailed"
                    else "15 base credits (+ optional HD add-ons; reference estimate only)"
                )
            )
        )
        steps.append(
            {
                "stage": 1,
                "name": "Build 3D model",
                "tool": tool_name,
                "arguments": payload,
                "reference_cost_note": ref_credits,
            }
        )

    model_ref = (
        source_model_id
        or st.get("stage2_model_id")
        or st.get("stage1_model_id")
        or "<result model_id from Stage 1>"
    )
    known_parts = part_names or st.get("part_names") or ["<authoritative part_name from tripo_get_model_asset>"]

    # --- Stage 2: Componentize ---
    if want_all or stage == "2":
        mode = s2_cfg.get("mode", "none")
        if mode == "none":
            steps.append(
                {
                    "stage": 2,
                    "name": "Componentize (skipped)",
                    "skipped": True,
                    "reason": s2_cfg.get("notes", "Whole unsegmented model required for this asset."),
                }
            )
        else:
            if mode == "from_generation":
                steps.append(
                    {
                        "stage": 2,
                        "name": "Inspect generated part catalogue",
                        "tool": "tripo_get_model_asset",
                        "arguments": {"model_id": model_ref},
                        "note": "Confirm parts_known=true and record part_names before completion or per-part texturing.",
                    }
                )
            elif mode in ("segment", "segment_and_complete"):
                steps.append(
                    {
                        "stage": 2,
                        "name": "Segment whole model into parts",
                        "tool": "tripo_segment_model",
                        "arguments": {
                            "idempotency_key": idempotency_key(aid, 2, "segment", rev),
                            "source_model_id": model_ref,
                            "segmentation_granularity": s2_cfg.get("granularity", "balanced"),
                        },
                        "reference_cost_note": "40 reference credits (member feature; not live account balance).",
                    }
                )
            if s2_cfg.get("complete_parts") or mode == "segment_and_complete":
                steps.append(
                    {
                        "stage": 2,
                        "name": "Complete occluded geometry on separated parts (optional for cutaway roofs/walls)",
                        "tool": "tripo_complete_model",
                        "arguments": {
                            "idempotency_key": idempotency_key(aid, 2, "complete", rev),
                            "source_model_id": "<segmented model_id>",
                            "part_names": known_parts,
                        },
                        "reference_cost_note": "0 credits on paid plans (AI completion; Studio eligibility applies).",
                    }
                )
            if s2_cfg.get("smart_low_poly_limit"):
                slp_limit = int(s2_cfg["smart_low_poly_limit"])
                use_quad = slp_limit <= 10000
                steps.append(
                    {
                        "stage": 2,
                        "name": "Smart Low Poly retopology (optional if HD mesh exceeds frame budget)",
                        "tool": "tripo_smart_low_poly_model",
                        "arguments": {
                            "idempotency_key": idempotency_key(aid, 2, "lowpoly", rev),
                            "source_model_id": "<segmented or completed model_id>",
                            "face_limit": slp_limit,
                            "quad": use_quad,
                            "do_bake": True,
                            "part_names": known_parts,
                        },
                        "reference_cost_note": "30 reference credits (paid plans).",
                    }
                )

    # --- Stage 3: Texture & Upscale vs Custom Texturing ---
    if want_all or stage == "3":
        tex_source = source_model_id or st.get("stage2_model_id") or st.get("stage1_model_id") or "<model_id from Stage 1/2>"
        tex_payload: dict[str, Any] = {
            "idempotency_key": idempotency_key(aid, 3, "texture", rev),
            "source_model_id": tex_source,
            "texture_quality": s3_cfg.get("texture_quality", "standard"),
            "delight": bool(s3_cfg.get("delight", True)),
            "texture_alignment": "geometry",
        }
        if multiview_keys and "front" in multiview_keys and len(multiview_keys) >= 2:
            tex_payload["images"] = {
                k: v for k, v in multiview_keys.items() if k in ("front", "left", "right", "back")
            }
        else:
            tex_payload["image_key"] = image_key or "<upload_grant.object_key for front>"

        path_a: list[dict[str, Any]] = [
            {
                "tool": "tripo_texture_model",
                "arguments": tex_payload,
                "reference_cost_note": "10 credits (standard 2K) or 20 credits (detailed 4K) reference estimate.",
            }
        ]
        if s3_cfg.get("upscale_quality") in ("detailed", "extreme"):
            path_a.append(
                {
                    "tool": "tripo_texture_upscale",
                    "arguments": {
                        "idempotency_key": idempotency_key(aid, 3, "upscale", rev),
                        "source_model_id": "<textured model_id>",
                        "texture_quality": s3_cfg["upscale_quality"],
                    },
                    "reference_cost_note": "10 reference credits (member feature; 8K extreme requires Max).",
                }
            )
        if s3_cfg.get("pbr", True):
            path_a.append(
                {
                    "tool": "tripo_generate_pbr",
                    "arguments": {
                        "idempotency_key": idempotency_key(aid, 3, "pbr", rev),
                        "source_model_id": "<textured or upscaled model_id>",
                    },
                    "reference_cost_note": "5 reference credits (optional if PBR maps are missing).",
                }
            )

        steps.append(
            {
                "stage": 3,
                "name": "Texture & upscale (Path A: Tripo) OR custom texturing (Path B: Blender Gouache)",
                "default_strategy": s3_cfg.get("default_strategy", "tripo_then_gate"),
                "path_a_tripo": path_a,
                "path_b_custom_blender": {
                    "optional_tripo_uv": {
                        "tool": "tripo_uv_unwrap",
                        "arguments": {
                            "idempotency_key": idempotency_key(aid, 3, "uv", rev),
                            "source_model_id": tex_source,
                        },
                    },
                    "command": (
                        f"python3 tools/asset_pipeline/pipeline.py postprocess {aid} "
                        f"--input tools/asset_pipeline/work/{aid}/raw.glb "
                        f"--texture-strategy blender_gouache --render-preview"
                    ),
                    "hybrid_command": (
                        f"python3 tools/asset_pipeline/pipeline.py postprocess {aid} "
                        f"--input tools/asset_pipeline/work/{aid}/raw.glb "
                        f"--texture-strategy tripo_hybrid --render-preview"
                    ),
                },
            }
        )

    # --- Stage 4: Rig ---
    if want_all or stage == "4":
        if not s4_cfg.get("enabled", False):
            steps.append({"stage": 4, "name": "Rig (not required)", "skipped": True})
        else:
            rig_payload: dict[str, Any] = {
                "idempotency_key": idempotency_key(aid, 4, "rig", rev),
                "source_model_id": source_model_id or st.get("stage3_model_id") or "<textured whole model_id>",
                "topology": s4_cfg.get("topology", "biped"),
            }
            if s4_cfg.get("spec"):
                rig_payload["spec"] = s4_cfg["spec"]
            steps.append(
                {
                    "stage": 4,
                    "name": "Rig whole character model",
                    "tool": "tripo_rig_model",
                    "arguments": rig_payload,
                    "reference_cost_note": "20 reference credits (whole unrigged model required).",
                }
            )

    # --- Stage 5: Animate ---
    if want_all or stage == "5":
        if not s5_cfg.get("enabled", False):
            steps.append({"stage": 5, "name": "Animate (not required)", "skipped": True})
        else:
            rigged_id = source_model_id or st.get("rigged_model_id") or "<rigged model_id from Stage 4>"
            for clip in s5_cfg.get("clips", []):
                cname = clip["name"]
                steps.append(
                    {
                        "stage": 5,
                        "name": f"Retarget clip '{cname}'",
                        "tool": "tripo_retarget_model",
                        "arguments": {
                            "idempotency_key": idempotency_key(aid, 5, f"clip-{cname}", rev),
                            "source_model_id": rigged_id,
                            "motion_id": clip["motion_id"],
                            "motion_source": clip.get("motion_source", "preset"),
                        },
                        "reference_cost_note": "0 credits (motion retarget; Studio eligibility applies).",
                    }
                )
            steps.append(
                {
                    "stage": 5,
                    "name": "Optional custom motion generation (tripo_text_to_motion)",
                    "optional": True,
                    "tool": "tripo_text_to_motion",
                    "arguments": {
                        "idempotency_key": idempotency_key(aid, 5, "custom-motion", rev),
                        "segments": [
                            {
                                "prompt": f"{asset['label']} walking calmly along an Edo town street",
                                "duration_seconds": 4,
                            }
                        ],
                    },
                    "reference_cost_note": "20 reference credits (standalone motion asset).",
                }
            )

    return {
        "asset_id": aid,
        "label": asset["label"],
        "target_glb": asset["target_glb"],
        "peekable": bool(asset.get("peekable", False)),
        "steps": steps,
    }


def parse_glb_chunks(glb_path: Path) -> tuple[dict[str, Any], bytes]:
    raw = glb_path.read_bytes()
    if len(raw) < 20:
        raise ValueError(f"GLB too short ({len(raw)} bytes): {glb_path}")
    magic, version, total_len = struct.unpack_from("<4sII", raw, 0)
    if magic != b"glTF":
        raise ValueError(f"Invalid GLB magic {magic!r} in {glb_path}")
    if version != 2:
        raise ValueError(f"Unsupported glTF binary version {version} in {glb_path}")
    if total_len > len(raw):
        raise ValueError(f"Truncated GLB: header declares {total_len} bytes, file has {len(raw)}")

    offset = 12
    json_chunk: dict[str, Any] | None = None
    bin_chunk = b""
    while offset + 8 <= total_len:
        chunk_len, chunk_type = struct.unpack_from("<I4s", raw, offset)
        offset += 8
        chunk_data = raw[offset : offset + chunk_len]
        offset += chunk_len
        if chunk_type == b"JSON":
            json_chunk = json.loads(chunk_data.decode("utf-8"))
        elif chunk_type == b"BIN\x00":
            bin_chunk = chunk_data
    if json_chunk is None:
        raise ValueError(f"GLB missing JSON chunk: {glb_path}")
    return json_chunk, bin_chunk


def _inspect_image_size(data: bytes) -> tuple[int, int] | None:
    try:
        from PIL import Image

        with Image.open(io.BytesIO(data)) as im:
            return im.size
    except Exception:
        return None


def verify_glb(glb_path: Path, asset: dict[str, Any] | None = None) -> dict[str, Any]:
    errors: list[str] = []
    warnings: list[str] = []
    if not glb_path.exists():
        return {"ok": False, "path": str(glb_path), "errors": ["File does not exist"], "warnings": []}

    gltf, bin_chunk = parse_glb_chunks(glb_path)
    ext_req = list(gltf.get("extensionsRequired") or [])
    ext_used = list(gltf.get("extensionsUsed") or [])
    unsupported = [e for e in ext_req if e not in SUPPORTED_FLUTTER_SCENE_EXTENSIONS]
    if unsupported:
        errors.append(f"Unsupported extensionsRequired for flutter_scene: {unsupported}")

    nodes = gltf.get("nodes") or []
    meshes = gltf.get("meshes") or []
    skins = gltf.get("skins") or []
    animations = gltf.get("animations") or []
    images = gltf.get("images") or []
    buffer_views = gltf.get("bufferViews") or []

    if not meshes:
        errors.append("GLB contains zero meshes")

    node_names = [str(n.get("name", "")) for n in nodes]
    lower_names = [n.lower() for n in node_names]
    roof_nodes = [n for n, ln in zip(node_names, lower_names) if ln.startswith(("peek_roof", "peek_upper"))]
    interior_room_nodes = [n for n, ln in zip(node_names, lower_names) if ln.startswith("interior_room")]
    interior_prop_nodes = [n for n, ln in zip(node_names, lower_names) if ln.startswith("interior_props")]
    anim_names = [str(a.get("name", f"anim_{i}")) for i, a in enumerate(animations)]

    # Compute raw accessor position bounds across primitives
    accessors = gltf.get("accessors") or []
    min_v = [float("inf"), float("inf"), float("inf")]
    max_v = [float("-inf"), float("-inf"), float("-inf")]
    for mesh in meshes:
        for prim in mesh.get("primitives") or []:
            pos_idx = (prim.get("attributes") or {}).get("POSITION")
            if pos_idx is None or pos_idx >= len(accessors):
                continue
            acc = accessors[pos_idx]
            amin = acc.get("min")
            amax = acc.get("max")
            if amin and amax and len(amin) == 3 and len(amax) == 3:
                for i in range(3):
                    min_v[i] = min(min_v[i], float(amin[i]))
                    max_v[i] = max(max_v[i], float(amax[i]))

    bounds_valid = all(v != float("inf") and v != float("-inf") for v in min_v + max_v)
    extents = [round(max_v[i] - min_v[i], 3) for i in range(3)] if bounds_valid else None
    if not bounds_valid:
        warnings.append("Could not read POSITION accessor min/max bounds")

    # Inspect embedded image resolutions
    max_tex_dim = 0
    image_dims: list[tuple[int, int]] = []
    for img in images:
        bv_idx = img.get("bufferView")
        if bv_idx is None or bv_idx >= len(buffer_views):
            continue
        bv = buffer_views[bv_idx]
        off = int(bv.get("byteOffset", 0))
        ln = int(bv.get("byteLength", 0))
        dims = _inspect_image_size(bin_chunk[off : off + ln])
        if dims:
            image_dims.append(dims)
            max_tex_dim = max(max_tex_dim, dims[0], dims[1])

    if asset is not None:
        if asset.get("peekable"):
            if not roof_nodes:
                errors.append("Peekable building GLB missing peek_roof* / peek_upper* node(s)")
            if not interior_room_nodes:
                errors.append("Peekable building GLB missing interior_room* node(s)")
            if not interior_prop_nodes:
                errors.append("Peekable building GLB missing interior_props* node(s)")
        if asset.get("stage4_rig", {}).get("enabled") and not skins:
            warnings.append("Character asset has stage4_rig enabled but GLB currently has 0 skins (procedural rig fallback active)")
        if asset.get("stage5_animate", {}).get("enabled") and not animations:
            warnings.append("Character asset has stage5_animate enabled but GLB currently has 0 animations")
        tex_cap = int(asset.get("stage3_texture", {}).get("max_tex_size", 1024))
        if max_tex_dim > tex_cap:
            warnings.append(f"Embedded texture max dimension {max_tex_dim}px exceeds budget {tex_cap}px")

    return {
        "ok": len(errors) == 0,
        "path": str(glb_path),
        "size_kb": round(glb_path.stat().st_size / 1024.0, 1),
        "mesh_count": len(meshes),
        "node_count": len(nodes),
        "skin_count": len(skins),
        "animation_clips": anim_names,
        "extensions_used": ext_used,
        "extensions_required": ext_req,
        "roof_nodes": roof_nodes,
        "interior_room_nodes": interior_room_nodes,
        "interior_prop_nodes": interior_prop_nodes,
        "extents_xyz": extents,
        "max_texture_px": max_tex_dim,
        "errors": errors,
        "warnings": warnings,
    }


def _find_blender() -> str:
    mac_bin = Path("/Applications/Blender.app/Contents/MacOS/Blender")
    if mac_bin.exists():
        return str(mac_bin)
    found = shutil.which("blender")
    if found:
        return found
    raise FileNotFoundError("Blender 5.3.0 executable not found.")


def cmd_status(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    state = load_state()
    assets = catalog["assets"]
    if args.category:
        assets = [a for a in assets if a["category"] == args.category]

    print(f"{'ASSET ID':26} {'CAT':14} {'PEEK':4} {'RIG':3} {'S0':3} {'S1':3} {'S2':3} {'S3':3} {'S4':3} {'S5':3} {'TARGET'}")
    print("-" * 112)
    for a in assets:
        st = state.get("assets", {}).get(a["id"], {})
        stages = st.get("stages", {})
        refs = discover_local_references(a["id"])
        s0 = "OK" if refs else stages.get("0", {}).get("status", "-")[:3]
        cols = [stages.get(str(i), {}).get("status", "-")[:3] for i in range(1, 6)]
        exists = "yes" if (REPO_ROOT / a["target_glb"]).exists() else "no"
        print(
            f"{a['id']:26} {a['category']:14} "
            f"{'yes' if a.get('peekable') else 'no':4} "
            f"{'yes' if a.get('stage4_rig', {}).get('enabled') else 'no':3} "
            f"{s0:3} {cols[0]:3} {cols[1]:3} {cols[2]:3} {cols[3]:3} {cols[4]:3} "
            f"{a['target_glb']} ({exists})"
        )
    return 0


def cmd_prompts(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    amap = get_asset_map(catalog)
    if args.asset_id:
        if args.asset_id not in amap:
            print(f"Unknown asset_id: {args.asset_id}", file=sys.stderr)
            return 2
        selected = [amap[args.asset_id]]
    elif args.category:
        selected = [a for a in catalog["assets"] if a["category"] == args.category]
    else:
        selected = catalog["assets"]

    results = [build_midjourney_prompts(a, catalog["style_bible"], sref=args.sref) for a in selected]
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        for r in results:
            print(f"=== {r['asset_id']} ({r['label']}) ===")
            print(f"Save dir : {r['reference_dir']}")
            print(f"Views    : {', '.join(r['views'])}")
            print(f"Local    : {r['local_files'] or 'none yet'}")
            print(f"Exterior : {r['exterior_prompt']}")
            if "interior_prompt" in r:
                print(f"Interior : {r['interior_prompt']}")
            print()
    return 0


def cmd_plan_tripo(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    amap = get_asset_map(catalog)
    if args.asset_id not in amap:
        print(f"Unknown asset_id: {args.asset_id}", file=sys.stderr)
        return 2
    state = load_state()
    st_entry = state.get("assets", {}).get(args.asset_id)

    mv: dict[str, str] | None = None
    if args.multiview_keys:
        mv = {}
        for pair in args.multiview_keys.split(","):
            if "=" in pair:
                k, v = pair.split("=", 1)
                mv[k.strip()] = v.strip()

    parts = [p.strip() for p in args.parts.split(",") if p.strip()] if args.parts else None
    plan = build_tripo_plan(
        amap[args.asset_id],
        stage=args.stage,
        rev=args.rev,
        prefer_smart_mesh=args.prefer_smart_mesh,
        source_model_id=args.source_model_id,
        image_key=args.image_key,
        multiview_keys=mv,
        part_names=parts,
        state_entry=st_entry,
    )
    print(json.dumps(plan, indent=2))
    return 0


def cmd_record(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    amap = get_asset_map(catalog)
    if args.asset_id not in amap:
        print(f"Unknown asset_id: {args.asset_id}", file=sys.stderr)
        return 2
    state = load_state()
    entry = state.setdefault("assets", {}).setdefault(args.asset_id, {"stages": {}})
    stage_rec = entry.setdefault("stages", {}).setdefault(str(args.stage), {})
    stage_rec["status"] = args.status
    stage_rec["updated_at"] = datetime.now(timezone.utc).isoformat()
    if args.idempotency_key:
        stage_rec["idempotency_key"] = args.idempotency_key
    if args.task_id:
        stage_rec["task_id"] = args.task_id
    if args.model_id:
        stage_rec["model_id"] = args.model_id
        entry[f"stage{args.stage}_model_id"] = args.model_id
    if args.rigged_model_id:
        entry["rigged_model_id"] = args.rigged_model_id
    if args.parts:
        entry["part_names"] = [p.strip() for p in args.parts.split(",") if p.strip()]
    if args.texture_strategy:
        entry["texture_strategy"] = args.texture_strategy
    if args.clip:
        clips = entry.setdefault("animation_clips", {})
        for item in args.clip:
            if "=" in item:
                k, v = item.split("=", 1)
                clips[k.strip()] = v.strip()
    if args.notes:
        stage_rec["notes"] = args.notes
    save_state(state)
    print(f"Recorded {args.asset_id} stage {args.stage} -> {args.status}")
    return 0


def cmd_upload_grant(args: argparse.Namespace) -> int:
    local_file = Path(args.local_file).resolve()
    if not local_file.exists():
        print(f"Local file not found: {local_file}", file=sys.stderr)
        return 2
    size = local_file.stat().st_size
    if size < 1 or size > MAX_TRIPO_IMAGE_BYTES:
        print(f"Image size {size} bytes out of allowed 1..{MAX_TRIPO_IMAGE_BYTES}", file=sys.stderr)
        return 2
    mime, _ = mimetypes.guess_type(str(local_file))
    if mime not in ALLOWED_IMAGE_MIMES:
        print(f"Unsupported image MIME type: {mime}", file=sys.stderr)
        return 2

    raw_grant = json.loads(sys.stdin.read())
    grant = raw_grant.get("upload_grant", raw_grant)
    upload_url = grant["upload_url"]
    object_key = grant["object_key"]
    headers: dict[str, str] = dict(grant.get("required_headers") or {})
    if "Content-Type" not in headers and "content-type" not in {k.lower() for k in headers}:
        headers["Content-Type"] = mime

    cfg_lines = [f'url = "{upload_url}"', 'request = "PUT"']
    for k, v in headers.items():
        cfg_lines.append(f'header = "{k}: {v}"')
    cfg_payload = ("\n".join(cfg_lines) + "\n").encode("utf-8")

    proc = subprocess.run(
        [
            "curl",
            "--disable",
            "--http2",
            "--fail",
            "--silent",
            "--show-error",
            "--data-binary",
            f"@{local_file}",
            "--config",
            "-",
        ],
        input=cfg_payload,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        print(f"Upload PUT failed (curl exit {proc.returncode})", file=sys.stderr)
        return proc.returncode
    # Print ONLY opaque object_key; never echo signed URL or headers.
    print(json.dumps({"object_key": object_key, "size_bytes": size, "content_type": mime}))
    return 0


def cmd_download_glb(args: argparse.Namespace) -> int:
    signed_url = sys.stdin.read().strip()
    if not signed_url.startswith("https://"):
        print("Expected HTTPS signed model_url on stdin", file=sys.stderr)
        return 2
    out_path = Path(args.out_path).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    cfg = f'url = "{signed_url}"\n'.encode("utf-8")
    proc = subprocess.run(
        [
            "curl",
            "--disable",
            "--http2",
            "--fail",
            "--silent",
            "--show-error",
            "--output",
            str(out_path),
            "--config",
            "-",
        ],
        input=cfg,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        print(f"GLB download failed (curl exit {proc.returncode})", file=sys.stderr)
        return proc.returncode

    report = verify_glb(out_path)
    decoded_path: str | None = None
    if args.decode_meshopt and "EXT_meshopt_compression" in report.get("extensions_used", []):
        decoded = out_path.with_name(f"{out_path.stem}_decoded.glb")
        dec_proc = subprocess.run(
            ["npx", "--yes", "@gltf-transform/cli", "dequantize", str(out_path), str(decoded)],
            capture_output=True,
            text=True,
            check=False,
        )
        if dec_proc.returncode == 0 and decoded.exists():
            decoded_path = str(decoded)
        else:
            report["warnings"].append(f"gltf-transform dequantize failed: {dec_proc.stderr.strip()}")
    report["decoded_path"] = decoded_path
    print(json.dumps(report, indent=2))
    return 0 if report["ok"] else 1


def cmd_postprocess(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    amap = get_asset_map(catalog)
    if args.asset_id not in amap:
        print(f"Unknown asset_id: {args.asset_id}", file=sys.stderr)
        return 2
    asset = amap[args.asset_id]
    in_path = Path(args.input).resolve()
    if not in_path.exists():
        print(f"Input GLB not found: {in_path}", file=sys.stderr)
        return 2

    work_out = WORK_DIR / args.asset_id / f"{args.asset_id}_processed.glb"
    work_out.parent.mkdir(parents=True, exist_ok=True)

    blender_bin = _find_blender()
    cmd = [
        blender_bin,
        "--background",
        "--python",
        str(HERE / "blender_postprocess.py"),
        "--",
        "--catalog",
        str(CATALOG_PATH),
        "--asset-id",
        args.asset_id,
        "--input",
        str(in_path),
        "--output",
        str(work_out),
        "--texture-strategy",
        args.texture_strategy,
    ]
    if args.extra_clips:
        cmd.extend(["--extra-clips", args.extra_clips])
    if args.render_preview:
        cmd.extend(["--preview-out", str(work_out.parent / "preview_sheet.png")])

    proc = subprocess.run(cmd, check=False)
    if proc.returncode != 0:
        return proc.returncode

    report = verify_glb(work_out, asset=asset)
    print(json.dumps(report, indent=2))
    if not report["ok"]:
        return 1

    if args.install:
        dest = REPO_ROOT / asset["target_glb"]
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(work_out, dest)
        print(f"Installed verified GLB -> {dest}")
    return 0


def cmd_verify_glb(args: argparse.Namespace) -> int:
    asset = None
    if args.asset_id:
        amap = get_asset_map(load_catalog())
        if args.asset_id not in amap:
            print(f"Unknown asset_id: {args.asset_id}", file=sys.stderr)
            return 2
        asset = amap[args.asset_id]
    report = verify_glb(Path(args.glb_path).resolve(), asset=asset)
    print(json.dumps(report, indent=2))
    return 0 if report["ok"] else 1


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Kage no Machi 3D asset workflow CLI")
    sub = p.add_subparsers(dest="command", required=True)

    sp = sub.add_parser("status", help="Show pipeline stage progress")
    sp.add_argument("--category", default=None)
    sp.set_defaults(func=cmd_status)

    sp = sub.add_parser("prompts", help="Generate Stage 0 Midjourney prompts")
    sp.add_argument("asset_id", nargs="?", default=None)
    sp.add_argument("--category", default=None)
    sp.add_argument("--sref", default=None, help="Optional Midjourney --sref URL")
    sp.add_argument("--json", action="store_true")
    sp.set_defaults(func=cmd_prompts)

    sp = sub.add_parser("plan-tripo", help="Emit schema-validated Tripo MCP JSON payloads")
    sp.add_argument("asset_id")
    sp.add_argument("--stage", default="all", choices=["1", "2", "3", "4", "5", "all"])
    sp.add_argument("--rev", type=int, default=1)
    sp.add_argument("--prefer-smart-mesh", action="store_true")
    sp.add_argument("--source-model-id", default=None)
    sp.add_argument("--image-key", default=None)
    sp.add_argument("--multiview-keys", default=None, help="Comma-separated view=key pairs")
    sp.add_argument("--parts", default=None, help="Comma-separated authoritative part_names")
    sp.set_defaults(func=cmd_plan_tripo)

    sp = sub.add_parser("record", help="Record non-secret stage state into state.json")
    sp.add_argument("asset_id")
    sp.add_argument("--stage", type=int, required=True, choices=[0, 1, 2, 3, 4, 5])
    sp.add_argument("--status", default="done", choices=["pending", "in_progress", "done", "failed", "skipped"])
    sp.add_argument("--idempotency-key", default=None)
    sp.add_argument("--task-id", default=None)
    sp.add_argument("--model-id", default=None)
    sp.add_argument("--rigged-model-id", default=None)
    sp.add_argument("--parts", default=None)
    sp.add_argument("--texture-strategy", default=None, choices=["tripo_keep", "tripo_hybrid", "blender_gouache"])
    sp.add_argument("--clip", action="append", default=None, help="Repeatable name=clip_name")
    sp.add_argument("--notes", default=None)
    sp.set_defaults(func=cmd_record)

    sp = sub.add_parser("upload-grant", help="PUT local image using Tripo upload_grant JSON on stdin")
    sp.add_argument("local_file")
    sp.set_defaults(func=cmd_upload_grant)

    sp = sub.add_parser("download-glb", help="Download GLB from signed model_url on stdin")
    sp.add_argument("out_path")
    sp.add_argument("--decode-meshopt", action="store_true")
    sp.set_defaults(func=cmd_download_glb)

    sp = sub.add_parser("postprocess", help="Normalize, re-texture, add interiors, merge clips, and verify")
    sp.add_argument("asset_id")
    sp.add_argument("--input", required=True)
    sp.add_argument("--extra-clips", default=None, help="Comma-separated clip_name=/path/to/clip.glb")
    sp.add_argument(
        "--texture-strategy",
        default="tripo_keep",
        choices=["tripo_keep", "tripo_hybrid", "blender_gouache"],
    )
    sp.add_argument("--render-preview", action="store_true")
    sp.add_argument("--install", action="store_true")
    sp.set_defaults(func=cmd_postprocess)

    sp = sub.add_parser("verify-glb", help="Validate GLB compatibility with Kage no Machi")
    sp.add_argument("glb_path")
    sp.add_argument("--asset-id", default=None)
    sp.set_defaults(func=cmd_verify_glb)

    return p


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
