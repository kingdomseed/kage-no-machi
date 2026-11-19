import 'dart:io';

import 'package:flutter_scene/build_hooks.dart';
import 'package:hooks/hooks.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    // flutter_scene:init:start
    // Import .glb and .fscene sources under assets/, loadable by source path
    // with loadScene (and hot-reloadable). A no-op when there are no scenes.
    buildScenes(buildInput: input, buildOutput: output);
    // Compile .fmat materials under assets/, loadable by source path with
    // loadFmatMaterial (and hot-reloadable). A no-op when there are none.
    await buildMaterials(buildInput: input, buildOutput: output);
    buildTextures(
      buildInput: input,
      buildOutput: output,
      textures: const [
        'assets/textures/kawara_tile.png',
        'assets/textures/ishigaki_stone.png',
        'assets/textures/kaido_earth.png',
        'assets/textures/meadow_moss.png',
        'assets/textures/cedar_timber.png',
        'assets/textures/shikkui_plaster.png',
        'assets/textures/kayabuki_thatch.png',
        'assets/textures/foliage_maple.png',
        'assets/textures/foliage_willow.png',
        'assets/textures/foliage_pine.png',
        'assets/textures/foliage_bamboo.png',
      ],
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
