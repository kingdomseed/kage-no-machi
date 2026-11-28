"""Antigravity run_workflow script for Kage no Machi Stages 0-5 3D asset production.

Invoke with:
  run_workflow(
      ScriptPath="<repo>/tools/asset_pipeline/workflows/produce_asset_batch.py",
      Description="Produce Edo 3D assets via Midjourney + Tripo MCP + Blender",
      Args={
          "asset_ids": ["edo_person_merchant", "edo_handcart", "machiya_hero"],
          "prefer_smart_mesh": False,
          "texture_strategy": "tripo_then_gate",
          "install": False,
      },
  )
"""

asset_ids = args.get("asset_ids") or []
prefer_smart_mesh = bool(args.get("prefer_smart_mesh", False))
texture_strategy = str(args.get("texture_strategy", "tripo_then_gate"))
install_assets = bool(args.get("install", False))

if not asset_ids:
    raise ValueError("Args must include a non-empty 'asset_ids' list.")

phase("Stage 0: Midjourney Reference Intake")
log(f"Preparing {len(asset_ids)} asset(s): {', '.join(asset_ids)}")

ref_results = await pipeline(
    asset_ids,
    lambda aid: agent(
        prompt=(
            f"Run Stage 0 (Midjourney reference generation) for Kage no Machi asset `{aid}`.\n"
            f"1. Read `.agents/skills/edo-asset-workflow/SKILL.md`.\n"
            f"2. Run `python3 tools/asset_pipeline/pipeline.py prompts {aid} --json` to get the exact prompt(s) "
            f"and check `local_files`.\n"
            f"3. If required reference images already exist under `docs/references/midjourney/assets/{aid}/`, "
            f"record Stage 0 done and return them.\n"
            f"4. Otherwise generate clean reference art in Midjourney via Helium (`browse` MCP first, "
            f"`cua-driver` on Helium second; reuse tab id `midjourney`), save outputs to "
            f"`docs/references/midjourney/assets/{aid}/front.png` (and additional views/interior if listed), "
            f"and record Stage 0 done with `pipeline.py record {aid} --stage 0 --status done`."
        ),
        schema={
            "type": "object",
            "properties": {
                "asset_id": {"type": "string"},
                "status": {"type": "string"},
                "reference_files": {"type": "array", "items": {"type": "string"}},
            },
            "required": ["asset_id", "status", "reference_files"],
        },
        role=f"Midjourney Ref: {aid}",
    ),
)

for r in ref_results:
    log(f"Stage 0 [{r['asset_id']}]: {r['status']} -> {r['reference_files']}")

phase("Stages 1-5: Tripo MCP Modeling, Componentizing, Texturing Gate, Rigging & Blender Post-Process")
sm_flag = "--prefer-smart-mesh" if prefer_smart_mesh else ""
install_flag = "--install" if install_assets else ""

prod_results = await pipeline(
    asset_ids,
    lambda aid: agent(
        prompt=(
            f"Execute Stages 1-5 for Kage no Machi asset `{aid}`.\n"
            f"Read `.agents/skills/edo-asset-workflow/SKILL.md` and `tripo-studio-mcp` SKILL.md first.\n"
            f"1. Run `python3 tools/asset_pipeline/pipeline.py plan-tripo {aid} {sm_flag}` to obtain exact "
            f"schema-validated Tripo MCP payloads and stable `idempotency_key`s.\n"
            f"2. Upload local Midjourney reference(s) from `docs/references/midjourney/assets/{aid}/` using "
            f"`tripo_create_image_upload_grant` + `pipeline.py upload-grant <file>` (never log signed URLs).\n"
            f"3. Run Stage 1 (`tripo_multiview_to_model` or `tripo_image_to_model`), poll `tripo_get_model_task` "
            f"to terminal success, and record `model_id` via `pipeline.py record`.\n"
            f"4. Run Stage 2 componentization when configured (`tripo_get_model_asset` for `generate_parts=true`, "
            f"or `tripo_segment_model` + optional `tripo_complete_model` / `tripo_smart_low_poly_model`).\n"
            f"5. Run Stage 3 texture gate (`texture_strategy={texture_strategy}`):\n"
            f"   - If `blender_gouache`, skip Tripo texturing and re-texture in Blender.\n"
            f"   - Otherwise run `tripo_texture_model` (+ optional upscale/PBR), download via `pipeline.py download-glb`, "
            f"postprocess with `--render-preview`, inspect `preview_sheet.png`, and fall back to `--texture-strategy tripo_hybrid` "
            f"or `blender_gouache` if Tripo textures look muddy or off-palette.\n"
            f"6. If `stage4_rig.enabled` is true, run `tripo_rig_model` on the whole model.\n"
            f"7. If `stage5_animate.enabled` is true, retarget each clip via `tripo_retarget_model`, download clip GLBs, "
            f"and merge them with `pipeline.py postprocess {aid} --extra-clips ...`.\n"
            f"8. Finish with `pipeline.py postprocess {aid} --render-preview {install_flag}` and confirm `verify-glb` passes."
        ),
        schema={
            "type": "object",
            "properties": {
                "asset_id": {"type": "string"},
                "status": {"type": "string"},
                "chosen_texture_strategy": {"type": "string"},
                "final_glb": {"type": "string"},
                "preview_sheet": {"type": "string"},
                "verified": {"type": "boolean"},
            },
            "required": ["asset_id", "status", "chosen_texture_strategy", "verified"],
        },
        role=f"Tripo Asset: {aid}",
    ),
)

for r in prod_results:
    log(f"Stages 1-5 [{r['asset_id']}]: {r['status']} (tex={r['chosen_texture_strategy']}, verified={r['verified']})")

if install_assets:
    phase("Final Metal & Flutter Verification")
    verify_res = await agent(
        prompt=(
            "Run `flutter analyze`, `flutter test`, and macOS Metal captures "
            "(`flutter run -d macos --enable-flutter-gpu --dart-define=SHUKUBA_CAPTURE_DIR=/tmp/shukuba_cap_batch "
            "--dart-define=SHUKUBA_AUTO_EXIT=true`). Confirm `coplanarOverlapCount == 0` and `depthConflictCount == 0` "
            "across all presets including `interior_peek_closeup`, and visually inspect the rendered PNGs."
        ),
        schema={"type": "string"},
        role="Metal Verifier",
    )
    log(verify_res)
