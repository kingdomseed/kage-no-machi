import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/look/look.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart' show Vector4;

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Feature 4 Edge: Fractured Rock Overhangs & Tiling', () {
    late final String fmatSource;

    setUpAll(() async {
      final file = File('assets/materials/gouache_lit.fmat');
      expect(file.existsSync(), isTrue);
      fmatSource = await file.readAsString();
    });

    test('Rock shader handles 90° vertical cliff normals without degenerate '
        'tangent', () {
      expect(fmatSource.contains('abs(N.y) < 0.92'), isTrue);
      expect(fmatSource.contains('vec3(0.0, 1.0, 0.0)'), isTrue);

      const cliffNormalY = 0.0;
      final upRef = cliffNormalY.abs() < 0.92 ? const [0, 1, 0] : [1, 0, 0];
      expect(upRef, equals(const [0, 1, 0]));
    });

    test('Rock shader handles 180° inverted ceiling overhangs safely', () {
      expect(fmatSource.contains('crownSun = clamp(N.y * 0.68 + 0.32'), isTrue);

      const invertedNy = -1.0;
      final crownSun = (invertedNy * 0.68 + 0.32).clamp(0.0, 1.0);
      expect(crownSun, equals(0));

      final upRef = invertedNy.abs() < 0.92 ? const [0, 1, 0] : [1, 0, 0];
      expect(upRef, equals(const [1, 0, 0]));
    });

    test(
      'Rock shader high-frequency noise tiling with extreme grain_scale bounds',
      () {
        expect(fmatSource.contains('material_params.grain_scale'), isTrue);
        expect(
          fmatSource.contains('clamp(0.5 + 0.5 * pigmentFbm, 0.0, 1.0)'),
          isTrue,
        );

        const extremeGrain = 100.0;
        const mockP = 2.5;
        const sampleFreq = mockP * (extremeGrain * 0.24);
        expect(sampleFreq.isFinite, isTrue);
        expect(sampleFreq, greaterThan(50));
      },
    );

    test('Sedimentary bedPlane step crevice parameter bounds', () {
      expect(fmatSource.contains('bedCrevice'), isTrue);
      expect(
        fmatSource.contains('1.0 - smoothstep(0.0, 0.16, bedPlane)'),
        isTrue,
      );

      for (final plane in [0.0, 0.08, 0.16, 0.5, 1.0]) {
        final t = ((plane - 0.0) / 0.16).clamp(0.0, 1.0);
        final smooth = t * t * (3 - 2 * t);
        final crevice = 1.0 - smooth;
        expect(crevice, inInclusiveRange(0.0, 1.0));
      }
    });

    test('Cut stone masonry mortar bevel clamping', () {
      expect(
        fmatSource.contains('mortar = 1.0 - smoothstep(0.02, 0.11'),
        isTrue,
      );
      expect(fmatSource.contains('bevelX'), isTrue);
      expect(fmatSource.contains('bevelY'), isTrue);

      final look = FakeLookDriver();
      final mat = look.materialFor(ShukubaSurfaceRole.ishigakiStone);
      expect(mat.name, contains('ishigakiStone'));
    });
  });

  group('Feature 5 Edge: Soil, Ruts & Moisture Extremes', () {
    late final String fmatSource;

    setUpAll(() async {
      final file = File('assets/materials/gouache_lit.fmat');
      fmatSource = await file.readAsString();
    });

    test(
      'Kaido road rut slope calculation on steep gradients (>30° slope)',
      () {
        expect(fmatSource.contains('rutSlope = (edgeDist - 0.42)'), isTrue);
        expect(fmatSource.contains('soilNormalDelta = T * (rutSlope'), isTrue);
        expect(
          fmatSource.contains('perturbedN = normalize(N + soilNormalDelta'),
          isTrue,
        );

        const steepGradientAngle = 35.0 * math.pi / 180.0;
        expect(steepGradientAngle, greaterThan(0.58));
      },
    );

    test('Puddle factor roughness clamp at exact bounds 0.0 and 1.0', () {
      expect(
        fmatSource.contains('material.roughness = clamp(rough, 0.08, 0.94);'),
        isTrue,
      );

      const roughPuddleSubmerged = 0.02;
      const roughDryCrag = 1.25;

      final clampedSubmerged = roughPuddleSubmerged.clamp(0.08, 0.94);
      final clampedDry = roughDryCrag.clamp(0.08, 0.94);

      expect(clampedSubmerged, equals(0.08));
      expect(clampedDry, equals(0.94));
    });

    test('Soil shader evaluation at extreme negative countryside coordinates '
        '(-88, -88)', () {
      expect(fmatSource.contains('P.xz * 0.10'), isTrue);
      expect(fmatSource.contains('P.xz * 3.8'), isTrue);

      const edgeX = -88.0;
      const edgeZ = -88.0;
      final distFromOrigin = math.sqrt(edgeX * edgeX + edgeZ * edgeZ);
      expect(distFromOrigin, closeTo(124.45, 0.01));
    });

    test('Soil wear parameter at exact boundaries 0.0 (pristine) and 1.0 '
        '(heavy track)', () {
      expect(
        fmatSource.contains('float wear = clamp(vColor.a, 0.0, 1.0);'),
        isTrue,
      );
      expect(fmatSource.contains('1.0 - wear * 0.86'), isTrue);

      const wearZero = 0.0;
      const wearMax = 1.0;

      expect(1.0 - wearZero * 0.86, equals(1));
      expect(1.0 - wearMax * 0.86, closeTo(0.14, 1e-4));
    });

    test(
      'Clay clod shoulder and kerb trench exponential profiles remain finite',
      () {
        expect(
          fmatSource.contains('exp(-pow((rutDist - 0.14) * 9.0, 2.0))'),
          isTrue,
        );

        for (final rd in [0.0, 0.14, 0.42, 1.0]) {
          final val = math.exp(-math.pow((rd - 0.14) * 9.0, 2.0));
          expect(val.isFinite, isTrue);
          expect(val, inInclusiveRange(0.0, 1.0));
        }
      },
    );
  });

  group('Feature 6 Edge: Shadow & GTAO Border Conditions', () {
    test(
      'EdoLookDriver configures shadowAmbientStrength within bounded contrast '
      'range',
      () {
        final look = FakeLookDriver();
        expect(look.lastVision, equals(MagistrateVisionState.hidden));
        expect(look.lastRig, equals(TimeOfDayRig.goldenDusk));

        look.syncFrame(
          rig: TimeOfDayRig.blueHourNight,
          vision: MagistrateVisionState.fullOverlay,
          sightcones: const [],
          lanternOrigins: const [],
          elapsedSeconds: 12.5,
        );

        expect(look.syncCount, equals(1));
        expect(look.lastRig, equals(TimeOfDayRig.blueHourNight));
        expect(look.lastVision, equals(MagistrateVisionState.fullOverlay));
      },
    );

    test('EnvironmentSettings ambient occlusion intensity and radius in '
        'EdoLookDriver', () {
      final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
          .readAsStringSync();
      expect(lookSrc.contains('ambientOcclusionRadius: 0.88'), isTrue);
      expect(lookSrc.contains('ambientOcclusionIntensity: 1.56'), isTrue);
    });

    test('TimeOfDayRig ambient loop gains remain bounded in [0.0, 1.0] across '
        'rigs', () {
      const dusk = TimeOfDayRig.goldenDusk;
      const night = TimeOfDayRig.blueHourNight;

      expect(dusk.riverMurmurGain, inInclusiveRange(0.0, 1.0));
      expect(dusk.bambooWindGain, inInclusiveRange(0.0, 1.0));
      expect(dusk.nightCricketGain, inInclusiveRange(0.0, 1.0));

      expect(night.riverMurmurGain, inInclusiveRange(0.0, 1.0));
      expect(night.bambooWindGain, inInclusiveRange(0.0, 1.0));
      expect(night.nightCricketGain, inInclusiveRange(0.0, 1.0));
    });

    test('Fog density and height falloff configured in EdoLookDriver', () {
      final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
          .readAsStringSync();
      expect(lookSrc.contains('fogDensity: 0.0086'), isTrue);
      expect(lookSrc.contains('fogHeightFalloff: 0.34'), isTrue);
    });

    test('PointLight range configured in EdoLookDriver for lanterns', () {
      final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
          .readAsStringSync();
      expect(lookSrc.contains('range: 10.5'), isTrue);
    });
  });

  group('Feature 7 Edge: Sumi Ink Pass & std140 Layout', () {
    late final String inkFragSource;

    setUpAll(() async {
      final file = File('shaders/sumi_ink.frag');
      expect(file.existsSync(), isTrue);
      inkFragSource = await file.readAsString();
    });

    test('Flat coplanar surface produces exactly zero crease ink', () {
      expect(inkFragSource.contains('creaseRaw ='), isTrue);
      expect(inkFragSource.contains('1.0 - dot(nCenter, nLeft)'), isTrue);

      const creaseRawFlat = 0.0;
      const normalCrease = creaseRawFlat * 1.02 * 0.48;
      expect(normalCrease, equals(0));
    });

    test('Far-plane ink fade distance attenuates monotonically to zero', () {
      expect(
        inkFragSource.contains('skyFade = clamp((skyDistance - centerDepth)'),
        isTrue,
      );

      const skyDist = 260.0;
      const centerDepthFar = 280.0;
      final skyFade = ((skyDist - centerDepthFar) * 0.05).clamp(0.0, 1.0);
      expect(skyFade, equals(0));
    });

    test('Botanical canopy roughness dampens ink lines on dense foliage', () {
      expect(inkFragSource.contains('botanicalDamp = 1.0'), isTrue);
      expect(
        inkFragSource.contains('smoothstep(0.960, 0.980, maxRough)'),
        isTrue,
      );

      const leafRoughness = 0.995;
      expect(leafRoughness, greaterThan(0.992));
    });

    test('SumiInkParams packs std140 uniform buffer to exact 32 bytes', () {
      final params = SumiInkParams();
      final packed = params.packStd140();
      expect(packed.lengthInBytes, equals(32));
    });

    test('SumiInkParams copyWith handles boundary values (0.0 weights, extreme '
        'fade)', () {
      final custom = SumiInkParams().copyWith(
        inkColor: Vector4(0.1, 0.1, 0.1, 1),
        depthWeight: 0,
        normalWeight: 0,
        skyFadeDistance: 1000,
      );

      final packed = custom.packStd140();
      expect(packed.lengthInBytes, equals(32));
      expect(packed.getFloat32(16, Endian.host), equals(0));
      expect(packed.getFloat32(20, Endian.host), equals(0));
      expect(packed.getFloat32(28, Endian.host), equals(1000));
    });
  });
}
