import 'dart:io';

import 'package:flutter_scene/build_hooks.dart';
import 'package:hooks/hooks.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    // flutter_scene:init:start
    // Import .glb and .fscene sources under assets/, loadable by source path
    // with loadScene (and hot-reloadable). A no-op when there are no scenes.
    buildScenes(
      buildInput: input,
      buildOutput: output,
      compressTextures: true,
      alignForCompression: true,
    );
    // Compile .fmat materials under assets/, loadable by source path with
    // loadFmatMaterial (and hot-reloadable). A no-op when there are none.
    await buildMaterials(buildInput: input, buildOutput: output);
    const etc1s = TextureEncoding.etc1s(quality: 180);
    buildTextures(
      buildInput: input,
      buildOutput: output,
      textures: const [
        'assets/textures/kawara_tile.png',
        'assets/textures/kawara_tile_normal.png',
        'assets/textures/castle_ishigaki.png',
        'assets/textures/castle_ishigaki_normal.png',
        'assets/textures/cobblestone_edo.png',
        'assets/textures/cobblestone_edo_normal.png',
        'assets/textures/kaido_earth.png',
        'assets/textures/kaido_earth_normal.png',
        'assets/textures/meadow_moss.png',
        'assets/textures/meadow_moss_normal.png',
        'assets/textures/cedar_timber.png',
        'assets/textures/cedar_timber_normal.png',
        'assets/textures/shikkui_plaster.png',
        'assets/textures/shikkui_plaster_normal.png',
        'assets/textures/kayabuki_thatch.png',
        'assets/textures/kayabuki_thatch_normal.png',
        'assets/textures/mountain_forest.png',
        'assets/textures/mountain_forest_normal.png',
        'assets/textures/sky_edo_dusk.png',
        'assets/textures/foliage_maple.png',
        'assets/textures/foliage_willow.png',
        'assets/textures/foliage_pine.png',
        'assets/textures/foliage_bamboo.png',
      ],
      contents: const {
        'assets/textures/kawara_tile_normal.png': TextureContent.normal,
        'assets/textures/castle_ishigaki_normal.png': TextureContent.normal,
        'assets/textures/cobblestone_edo_normal.png': TextureContent.normal,
        'assets/textures/kaido_earth_normal.png': TextureContent.normal,
        'assets/textures/meadow_moss_normal.png': TextureContent.normal,
        'assets/textures/cedar_timber_normal.png': TextureContent.normal,
        'assets/textures/shikkui_plaster_normal.png': TextureContent.normal,
        'assets/textures/kayabuki_thatch_normal.png': TextureContent.normal,
        'assets/textures/mountain_forest_normal.png': TextureContent.normal,
      },
      encodings: const {
        'assets/textures/kawara_tile.png': etc1s,
        'assets/textures/castle_ishigaki.png': etc1s,
        'assets/textures/cobblestone_edo.png': etc1s,
        'assets/textures/kaido_earth.png': etc1s,
        'assets/textures/meadow_moss.png': etc1s,
        'assets/textures/cedar_timber.png': etc1s,
        'assets/textures/shikkui_plaster.png': etc1s,
        'assets/textures/kayabuki_thatch.png': etc1s,
        'assets/textures/mountain_forest.png': etc1s,
        'assets/textures/sky_edo_dusk.png': etc1s,
      },
      alignForCompression: true,
    );
    // flutter_scene:init:end
    final sumiManifest = File.fromUri(
      input.packageRoot.resolve('shaders/sumi_ink.shaderbundle.json'),
    );
    if (sumiManifest.existsSync()) {
      await buildTargetShaderBundleJson(
        buildInput: input,
        buildOutput: output,
        manifestFileName: 'shaders/sumi_ink.shaderbundle.json',
      );
    }
  });
}
