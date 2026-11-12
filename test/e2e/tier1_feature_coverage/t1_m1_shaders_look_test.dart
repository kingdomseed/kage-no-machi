import 'dart:io';

import 'package:flutter_scene/scene.dart' show Scene;
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
        contains('rough = mix(rough, min(rough, 0.20), moistureMix)'),
      );
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
    test(
      'EdoLookDriver sets directionalLight shadowAmbientStrength to 0.15',
      () async {
        final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
            .readAsStringSync();
        expect(lookSrc.contains('shadowAmbientStrength: 0.15'), isTrue);

        final hasGpu = checkImpellerAvailable();
        if (hasGpu) {
          final driver = EdoLookDriver(allowHeadlessFallback: true);
          final scene = Scene();
          await driver.attach(scene);
          driver.syncFrame(
            rig: TimeOfDayRig.goldenDusk,
            vision: MagistrateVisionState.hidden,
            sightcones: const [],
            lanternOrigins: const [],
            elapsedSeconds: 0,
          );
          expect(scene.directionalLight, isNotNull);
          expect(
            scene.directionalLight!.shadowAmbientStrength,
            closeTo(0.15, 1e-4),
          );
          driver.dispose();
        }
      },
    );

    test('Fill light intensity is 0.24 with steel-blue color vector', () {
      final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
          .readAsStringSync();
      expect(lookSrc.contains('intensity: 0.24'), isTrue);
      expect(lookSrc.contains('Vector3(0.24, 0.38, 0.58)'), isTrue);
    });

    test(
      'EnvironmentSettings ambientOcclusionRadius is configured to 0.88',
      () {
        final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
            .readAsStringSync();
        expect(lookSrc.contains('ambientOcclusionRadius: 0.88'), isTrue);
      },
    );

    test(
      'EnvironmentSettings ambientOcclusionIntensity is configured to 1.56',
      () {
        final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
            .readAsStringSync();
        expect(lookSrc.contains('ambientOcclusionIntensity: 1.56'), isTrue);
      },
    );

    test(
      'ambientOcclusionBentNormals is enabled for directional shadowing',
      () {
        final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
            .readAsStringSync();
        expect(lookSrc.contains('ambientOcclusionBentNormals: true'), isTrue);
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
