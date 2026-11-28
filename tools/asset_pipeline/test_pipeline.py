#!/usr/bin/env python3
"""Unit & integration tests for the Kage no Machi 3D asset workflow."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import pipeline  # noqa: E402


class AssetPipelineUnitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog = pipeline.load_catalog()
        self.amap = pipeline.get_asset_map(self.catalog)

    def test_catalog_covers_all_required_categories(self) -> None:
        cats = {a["category"] for a in self.catalog["assets"]}
        for required in ("people", "props", "vehicles", "buildings", "fortifications", "landmarks"):
            self.assertIn(required, cats, f"Missing category {required}")

        peekable = [a["id"] for a in self.catalog["assets"] if a.get("peekable")]
        self.assertGreaterEqual(len(peekable), 11, "Expected all 11 hero houses to be peekable")
        for expected in ("machiya_hero", "minka_hero_v0", "teahouse_hero", "kura_warehouse_hero"):
            self.assertIn(expected, peekable)

        rigged = [a["id"] for a in self.catalog["assets"] if a.get("stage4_rig", {}).get("enabled")]
        self.assertGreaterEqual(len(rigged), 6, "Expected all 6 Edo character archetypes to be rigged")

    def test_smart_mesh_character_plan_follows_tripo_schema(self) -> None:
        plan = pipeline.build_tripo_plan(
            self.amap["edo_person_merchant"],
            stage="all",
            rev=1,
            multiview_keys={"front": "obj_f", "back": "obj_b"},
        )
        s1 = [s for s in plan["steps"] if s["stage"] == 1][0]
        self.assertEqual(s1["tool"], "tripo_multiview_to_model")
        args = s1["arguments"]
        self.assertEqual(args["family"], "smart_mesh")
        self.assertEqual(args["model_version"], "Nexus-v2.0-20260801")
        self.assertFalse(args["texture"])
        self.assertGreaterEqual(args["face_limit"], 500)
        self.assertTrue(args["quad"])
        self.assertTrue(args["symmetry"])
        # Critical Tripo schema invariant: omit texture sub-fields when texture=false
        for forbidden in ("pbr", "texture_quality", "delight", "generate_parts", "geometry_quality"):
            self.assertNotIn(forbidden, args)

        # Stage 2 skipped for rigged characters
        s2 = [s for s in plan["steps"] if s["stage"] == 2][0]
        self.assertTrue(s2.get("skipped"))

        # Stage 4 rig omits spec by default and sets topology=biped
        s4 = [s for s in plan["steps"] if s["stage"] == 4][0]
        self.assertEqual(s4["tool"], "tripo_rig_model")
        self.assertEqual(s4["arguments"]["topology"], "biped")
        self.assertNotIn("spec", s4["arguments"])

        # Stage 5 retargets idle + walk presets
        s5_retargets = [s for s in plan["steps"] if s["stage"] == 5 and s.get("tool") == "tripo_retarget_model"]
        self.assertEqual(len(s5_retargets), 2)
        motion_ids = {s["arguments"]["motion_id"] for s in s5_retargets}
        self.assertEqual(motion_ids, {"preset:biped:wait", "preset:biped:walk"})

    def test_hd_building_plan_and_smart_mesh_override(self) -> None:
        hd_plan = pipeline.build_tripo_plan(self.amap["machiya_hero"], stage="all")
        s1_hd = [s for s in hd_plan["steps"] if s["stage"] == 1][0]["arguments"]
        self.assertEqual(s1_hd["family"], "hd")
        self.assertEqual(s1_hd["model_version"], "v3.1-20260211")
        self.assertTrue(s1_hd["generate_parts"])
        self.assertFalse(s1_hd["texture"])
        self.assertEqual(s1_hd["segmentation_granularity"], "balanced")
        self.assertNotIn("symmetry", s1_hd)
        for forbidden in ("pbr", "texture_quality", "delight"):
            self.assertNotIn(forbidden, s1_hd)

        # Stage 3 includes both Tripo path and custom Blender gouache path
        s3 = [s for s in hd_plan["steps"] if s["stage"] == 3][0]
        self.assertIn("path_a_tripo", s3)
        self.assertIn("path_b_custom_blender", s3)
        self.assertIn("blender_gouache", s3["path_b_custom_blender"]["command"])

        # Smart Mesh override switches to Nexus v2 and Stage 2 segmentation
        sm_plan = pipeline.build_tripo_plan(
            self.amap["machiya_hero"], stage="all", prefer_smart_mesh=True
        )
        s1_sm = [s for s in sm_plan["steps"] if s["stage"] == 1][0]["arguments"]
        self.assertEqual(s1_sm["family"], "smart_mesh")
        self.assertEqual(s1_sm["model_version"], "Nexus-v2.0-20260801")
        self.assertNotIn("generate_parts", s1_sm)
        self.assertGreaterEqual(s1_sm["face_limit"], 10000)
        s2_tools = [s.get("tool") for s in sm_plan["steps"] if s["stage"] == 2]
        self.assertIn("tripo_segment_model", s2_tools)

    def test_state_rejects_signed_urls_and_secrets(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            st_path = Path(tmp) / "state.json"
            clean = {"schema_version": 1, "assets": {"machiya_hero": {"stage1_model_id": "abc"}}}
            pipeline.save_state(clean, st_path)
            self.assertEqual(pipeline.load_state(st_path)["assets"]["machiya_hero"]["stage1_model_id"], "abc")

            for bad_key in ("upload_url", "model_url", "download_url", "required_headers", "authorization"):
                dirty = {"schema_version": 1, "assets": {"machiya_hero": {bad_key: "https://secret"}}}
                with self.assertRaises(ValueError):
                    pipeline.save_state(dirty, st_path)

    def test_midjourney_prompt_generation_includes_interior_for_peekable(self) -> None:
        p_house = pipeline.build_midjourney_prompts(self.amap["machiya_hero"], self.catalog["style_bible"])
        self.assertIn("exterior_prompt", p_house)
        self.assertIn("interior_prompt", p_house)
        self.assertIn("--style raw", p_house["exterior_prompt"])

        p_person = pipeline.build_midjourney_prompts(self.amap["edo_person_samurai"], self.catalog["style_bible"])
        self.assertIn("A-pose", p_person["exterior_prompt"])
        self.assertNotIn("interior_prompt", p_person)

    def test_verify_glb_passes_on_all_cutaway_buildings(self) -> None:
        peekable_buildings = [a for a in self.catalog["assets"] if a.get("peekable")]
        for asset in peekable_buildings:
            glb = REPO_ROOT / asset["target_glb"]
            if not glb.exists():
                continue
            report = pipeline.verify_glb(glb, asset=asset)
            self.assertTrue(
                report["ok"],
                f"GLB verification failed for {asset['id']} ({glb}): {report['errors']}",
            )
            self.assertGreater(len(report["roof_nodes"]), 0, f"{asset['id']} missing roof cutaway node")
            self.assertGreater(len(report["interior_room_nodes"]), 0, f"{asset['id']} missing interior_room node")
            self.assertGreater(len(report["interior_prop_nodes"]), 0, f"{asset['id']} missing interior_props node")

    def test_blender_postprocess_roundtrip_on_synthetic_house(self) -> None:
        """End-to-end Blender headless postprocess test verifying normalization + cutaway assembly."""
        blender = pipeline._find_blender()
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            raw_glb = tmp_dir / "raw_tripo_house.glb"
            out_glb = tmp_dir / "processed_house.glb"
            # Generate a minimal raw house GLB (body + roof) using Blender
            gen_script = (
                "import bpy\n"
                "bpy.ops.wm.read_factory_settings(use_empty=True)\n"
                "bpy.ops.mesh.primitive_cube_add(size=2.0, location=(0, 0, 1.0))\n"
                "bpy.context.active_object.name = 'part_walls'\n"
                "bpy.ops.mesh.primitive_cone_add(radius1=1.6, depth=1.2, location=(0, 0, 2.6))\n"
                "bpy.context.active_object.name = 'part_roof_tiles'\n"
                f"bpy.ops.export_scene.gltf(filepath={str(raw_glb)!r}, export_format='GLB', export_yup=True)\n"
            )
            p1 = subprocess.run(
                [blender, "--background", "--python-expr", gen_script],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(p1.returncode, 0, f"Synthetic GLB export failed: {p1.stderr}")
            self.assertTrue(raw_glb.exists())

            p2 = subprocess.run(
                [
                    blender,
                    "--background",
                    "--python",
                    str(HERE / "blender_postprocess.py"),
                    "--",
                    "--catalog",
                    str(HERE / "catalog.json"),
                    "--asset-id",
                    "minka_hero_v0",
                    "--input",
                    str(raw_glb),
                    "--output",
                    str(out_glb),
                    "--texture-strategy",
                    "blender_gouache",
                ],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(p2.returncode, 0, f"Postprocess failed: {p2.stdout}\n{p2.stderr}")
            report = pipeline.verify_glb(out_glb, asset=self.amap["minka_hero_v0"])
            self.assertTrue(report["ok"], f"Postprocessed GLB failed verify: {report}")
            self.assertGreater(len(report["roof_nodes"]), 0)
            self.assertGreater(len(report["interior_room_nodes"]), 0)
            self.assertGreater(len(report["interior_prop_nodes"]), 0)


if __name__ == "__main__":
    unittest.main()
