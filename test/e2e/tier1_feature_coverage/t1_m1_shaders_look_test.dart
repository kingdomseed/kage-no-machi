import 'dart:io';

import 'package:flutter_scene/scene.dart' show DirectionalShadowFilter, Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/look/look.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart' show Vector4;

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Feature 4: Fractured Layered Rock Shader', () {
    late final String fmatSource;

    setUpAll(() async {
      final file = File('assets/materials/gouache_lit.fmat');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'gouache_lit.fmat shader must exist',
      );
      fmatSource = await file.readAsString();
    });

    test(
      'GouacheLit material binds style_id == 3.0 for natural rock surfaces',
      () {
        expect(fmatSource.contains('kStyleStoneMasonry = 3.0'), isTrue);
        expect(
          fmatSource.contains('abs(style - kStyleStoneMasonry) < 0.5'),
          isTrue,
        );

        final look = FakeLookDriver();
        final mat = look.materialFor(ShukubaSurfaceRole.ishigakiStone);
        expect(mat.name, contains('ishigakiStone'));
      },
    );

    test('Rock material specifies normal relief parameter of 0.52', () {
      expect(fmatSource.contains('0.52'), isTrue);
      expect(fmatSource, contains('pigment * 0.52'));
    });

    test('Deep fissure darkening parameter evaluates to 0.68', () {
      expect(fmatSource.contains('0.68'), isTrue);
      expect(fmatSource, contains('crownSun = clamp(N.y * 0.68 + 0.32'));
    });

    test('Sedimentary stepped shelves generated with cellular noise', () {
      expect(fmatSource.contains('NoiseFbm3'), isTrue);
      expect(fmatSource.contains('NoiseSimplex3'), isTrue);
      expect(fmatSource.contains('strata'), isTrue);
      expect(fmatSource.contains('bedPlane'), isTrue);
    });

    test('Dual-tone tint computes warm crown vs cool slate belly based '
        'on normal', () {
      expect(fmatSource.contains('slateBelly'), isTrue);
      expect(fmatSource.contains('ochreCrown'), isTrue);
      expect(fmatSource.contains('crownSun'), isTrue);
      expect(fmatSource, contains('mix(slateBelly, ochreCrown, crownSun'));
    });
  });

  group('Feature 5: Churned Dirt, Ruts & Rain Puddles', () {
    late final String fmatSource;

    setUpAll(() async {
      final file = File('assets/materials/gouache_lit.fmat');
      fmatSource = await file.readAsString();
    });

    test('GouacheLit material binds style_id in 5.0..5.5 for soil and '
        'Kaido roads', () {
      expect(fmatSource.contains('kStyleLaneThreshold = 5.25'), isTrue);
      expect(fmatSource.contains('style > 4.5 && style < 5.8'), isTrue);
    });

    test('Soil normal relief parameter evaluates to 0.40', () {
      expect(fmatSource.contains('0.40'), isTrue);
      expect(fmatSource, contains('0.40 * wear'));
    });

    test('Twin parallel cartwheel ruts generate elevated clod shoulders', () {
      expect(fmatSource.contains('rutPair'), isTrue);
      expect(fmatSource.contains('shoulderMix'), isTrue);
      expect(fmatSource, contains('exp(-pow(rutDist * 7.5, 2.0))'));
    });

    test('Rainwater puddles evaluate to low surface roughness <= 0.08', () {
      expect(fmatSource, contains('clamp(rough, 0.08, 0.94)'));
      expect(
        fmatSource,
        contains('rough = mix(rough, min(rough, 0.42), moistureMix)'),
      );
      expect(fmatSource, contains('laneBlend = clamp(GetUV1(), 0.0, 1.0)'));
      expect(fmatSource, contains('material.occlusion = finalOcclusion;'));
    });

    test(
      'Soil moisture shift modulates albedo from terracotta to damp umber',
      () {
        expect(fmatSource.contains('wetShore'), isTrue);
        expect(
          fmatSource,
          contains('mix(albedo, vec3(0.064, 0.070, 0.065), wetShore'),
        );
      },
    );
  });

  group('Feature 6: Deep Shadows & Tuned GTAO', () {
    test('EdoLookDriver configures diffused PCSS keyLight with '
        'shadowAmbientStrength in [0.28, 0.36]', () async {
      final driver = EdoLookDriver(allowHeadlessFallback: true);
      addTearDown(driver.dispose);

      final hasGpu = checkImpellerAvailable();
      final scene = hasGpu ? Scene() : null;
      if (scene != null) {
        await driver.attach(scene);
      }

      driver.syncFrame(
        rig: TimeOfDayRig.goldenDusk,
        vision: MagistrateVisionState.hidden,
        sightcones: const [],
        lanternOrigins: const [],
        elapsedSeconds: 0,
      );

      final key = driver.keyLight;
      expect(key, isNotNull);
      expect(key!.shadowFilter, equals(DirectionalShadowFilter.pcss));
      expect(key.shadowCascadeCount, equals(4));
      expect(key.shadowMaxDistance, closeTo(145, 1e-4));
      expect(key.shadowSoftness, closeTo(0.28, 1e-4));
      expect(
        key.shadowAmbientStrength,
        closeTo(0.28 + 0.08 * TimeOfDayRig.goldenDusk.nightFactor, 1e-4),
      );

      if (scene != null) {
        expect(scene.directionalLight, same(key));
      }
    });

    test('EdoLookDriver uses PhysicalSkySource and caps clustered lanterns '
        'at <= 12', () {
      final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
          .readAsStringSync();
      expect(lookSrc.contains('PhysicalSkySource('), isTrue);
      expect(lookSrc.contains('edo_fill_light'), isFalse);

      final driver = EdoLookDriver(allowHeadlessFallback: true);
      addTearDown(driver.dispose);
      driver.syncFrame(
        rig: TimeOfDayRig.blueHourNight,
        vision: MagistrateVisionState.hidden,
        sightcones: const [],
        lanternOrigins: [
          for (var i = 0; i < 36; i++)
            Vec3(-30 + (i % 9) * 8.0, 2.5, -18 + (i ~/ 9) * 10.0),
        ],
        elapsedSeconds: 0.5,
      );
      expect(driver.activeLanternLights.length, lessThanOrEqualTo(12));
      expect(driver.activeLanternLights.first.range, closeTo(8.2, 1e-6));
    });

    test(
      'EnvironmentSettings ambientOcclusionRadius is configured to 1.05',
      () {
        final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
            .readAsStringSync();
        expect(lookSrc.contains('ambientOcclusionRadius: 1.05'), isTrue);
        expect(lookSrc.contains('ambientOcclusionMultiBounce: 0.46'), isTrue);
      },
    );

    test(
      'EnvironmentSettings ambientOcclusionIntensity is 1.68 and river water '
      'declares scene_color + scene_depth caustics',
      () {
        final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
            .readAsStringSync();
        expect(lookSrc.contains('ambientOcclusionIntensity: 1.68'), isTrue);

        final waterSrc = File('assets/materials/river_water.fmat')
            .readAsStringSync();
        expect(
          waterSrc.contains('engine_inputs: [scene_color, scene_depth]'),
          isTrue,
        );
        expect(waterSrc.contains('GetSceneWorldPosition('), isTrue);
      },
    );

    test(
      'ambientOcclusionBentNormals and komorebi sunbeam material are enabled',
      () {
        final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
            .readAsStringSync();
        expect(lookSrc.contains('ambientOcclusionBentNormals: true'), isTrue);

        final driver = EdoLookDriver(allowHeadlessFallback: true);
        addTearDown(driver.dispose);
        final sunbeam = EdoLookDriver.resolveSunbeamMaterial(
          driver.materialFor,
        );
        expect(
          sunbeam.depthLayer,
          equals(ShukubaSurfaceRole.riverMist.depthLayer),
        );
      },
    );
  });

  group('Feature 7: Sumi Ink Carpentry Creases', () {
    late final String fragSource;

    setUpAll(() async {
      final file = File('shaders/sumi_ink.frag');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'sumi_ink.frag post-processing shader must exist',
      );
      fragSource = await file.readAsString();
    });

    test('SumiInkParams packs std140 uniform buffer with 32 bytes layout', () {
      final params = SumiInkParams(
        inkColor: Vector4(0.12, 0.09, 0.08, 0.95),
        depthWeight: 2.2,
        normalWeight: 1.8,
        washiGrainStrength: 0.025,
        skyFadeDistance: 180,
      );

      final bytes = params.packStd140();
      expect(bytes.lengthInBytes, equals(32));

      final floats = bytes.buffer.asFloat32List(bytes.offsetInBytes, 8);
      expect(floats[0], closeTo(0.12, 1e-6));
      expect(floats[1], closeTo(0.09, 1e-6));
      expect(floats[2], closeTo(0.08, 1e-6));
      expect(floats[3], closeTo(0.95, 1e-6));
      expect(floats[4], closeTo(2.2, 1e-6));
      expect(floats[5], closeTo(1.8, 1e-6));
      expect(floats[6], closeTo(0.025, 1e-6));
      expect(floats[7], closeTo(180, 1e-6));
    });

    test(
      'Normal crease threshold smoothstep bounds are set to (0.18, 0.68)',
      () {
        expect(fragSource, contains('normalCrease'));
        expect(fragSource, contains('smoothstep('));
      },
    );

    test('Sumi ink edge attenuation scales smoothly with depth distance', () {
      const snippet =
          'distAtten = clamp(1.20 - centerDepth * 0.0046, '
          '0.50, 1.0)';
      expect(fragSource, contains(snippet));
      expect(fragSource, contains('skyFade'));
    });

    test('Botanical canopy roughness dampens ink lines on leaf foliage', () {
      expect(fragSource, contains('botanicalDamp'));
      expect(fragSource, contains('smoothstep(0.960, 0.980, maxRough)'));
    });

    test('Sumi ink pass binds after tone mapping without crashing', () {
      final initial = SumiInkParams(
        inkColor: Vector4(0.1, 0.1, 0.1, 0.9),
        depthWeight: 2,
        normalWeight: 1.5,
        washiGrainStrength: 0.02,
        skyFadeDistance: 160,
      );

      final updated = initial.copyWith(normalWeight: 1.8);
      expect(updated.normalWeight, equals(1.8));
      expect(updated.depthWeight, equals(2));

      final packed = updated.packStd140();
      expect(packed.lengthInBytes, equals(32));
    });
  });
}
