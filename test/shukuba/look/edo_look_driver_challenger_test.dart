import 'dart:io';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('Challenger Stress Test: Feature 6 Look Driver & Lighting Rig', () {
    test(
      'shadowAmbientStrength at dusk (nightFactor = 0.0) is exactly 0.15',
      () {
        const nightFactor = 0.0;
        const shadowAmbientStrength = 0.15 + 0.05 * nightFactor;
        expect(shadowAmbientStrength, equals(0.15));
      },
    );

    test(
      'shadowAmbientStrength at midnight (nightFactor = 1.0) is exactly 0.20',
      () {
        const nightFactor = 1.0;
        const shadowAmbientStrength = 0.15 + 0.05 * nightFactor;
        expect(shadowAmbientStrength, equals(0.20));
      },
    );

    test(
      'shadowAmbientStrength across all nightFactor in [0.0, 1.0] is strictly '
      'within [0.15, 0.20] and monotonic',
      () {
        const steps = 10000;
        var previousStrength = -1.0;

        for (var i = 0; i <= steps; i++) {
          final t = i / steps;
          final nightFactor = t * t * (3 - 2 * t);
          final shadowAmbientStrength = 0.15 + 0.05 * nightFactor;

          expect(
            shadowAmbientStrength,
            greaterThanOrEqualTo(0.15),
            reason: 'At t=$t, shadowAmbientStrength must be >= 0.15',
          );
          expect(
            shadowAmbientStrength,
            lessThanOrEqualTo(0.20),
            reason: 'At t=$t, shadowAmbientStrength must be <= 0.20',
          );

          if (previousStrength >= 0) {
            expect(
              shadowAmbientStrength,
              greaterThanOrEqualTo(previousStrength),
              reason:
                  'shadowAmbientStrength must be monotonically '
                  'non-decreasing',
            );
          }
          previousStrength = shadowAmbientStrength;
        }
      },
    );

    test('TimeOfDayRig nightFactor bounds and transitions', () {
      const dusk = TimeOfDayRig.goldenDusk;
      expect(dusk.value, equals(0.15));
      expect(dusk.nightFactor, inInclusiveRange(0.0, 0.10));

      const night = TimeOfDayRig.blueHourNight;
      expect(night.value, equals(0.90));
      expect(night.nightFactor, inInclusiveRange(0.90, 1.0));

      const negativeRig = TimeOfDayRig(-0.5);
      expect(negativeRig.value, equals(0.0));
      expect(negativeRig.nightFactor, equals(0.0));

      const overflowRig = TimeOfDayRig(1.5);
      expect(overflowRig.value, equals(1.0));
      expect(overflowRig.nightFactor, equals(1.0));
    });

    test('Fill light intensity is pinned at 0.24 and color is pinned at '
        '(0.24, 0.38, 0.58)', () {
      final fillLight = DirectionalLight(
        intensity: 0.24,
        color: Vector3(0.24, 0.38, 0.58),
      );

      expect(fillLight.intensity, equals(0.24));
      expect(fillLight.color.x, closeTo(0.24, 1e-6));
      expect(fillLight.color.y, closeTo(0.38, 1e-6));
      expect(fillLight.color.z, closeTo(0.58, 1e-6));

      final aimVec = Vector3(0.3, -1, 0.4).normalized();
      expect(aimVec.length, closeTo(1.0, 1e-6));
      expect(
        aimVec.y,
        lessThan(0.0),
        reason: 'Fill light aims downward into street',
      );
    });

    test('Key directional light specifications for deep PCSS shadows', () {
      final keyLight = DirectionalLight(
        castsShadow: true,
        priority: 10,
        shadowCascadeCount: 3,
        shadowMaxDistance: 95,
        shadowMapResolution: 2048,
        shadowFilter: DirectionalShadowFilter.pcss,
        shadowAmbientStrength: 0.15,
        contactShadows: true,
      );

      expect(keyLight.castsShadow, isTrue);
      expect(keyLight.priority, 10);
      expect(keyLight.shadowCascadeCount, 3);
      expect(keyLight.shadowMaxDistance, 95);
      expect(keyLight.shadowMapResolution, 2048);
      expect(keyLight.shadowFilter, DirectionalShadowFilter.pcss);
      expect(keyLight.shadowAmbientStrength, 0.15);
      expect(keyLight.contactShadows, isTrue);
    });
  });

  group(
    'Challenger Stress Test: EnvironmentSettings GTAO & Lerp Integrity',
    () {
      late EnvironmentSettings duskSettings;
      late EnvironmentSettings nightSettings;

      setUp(() {
        duskSettings = EnvironmentSettings(
          toneMapping: ToneMappingMode.aces,
          exposure: 1.02,
          colorGradingEnabled: true,
          saturation: 1.22,
          contrast: 1.10,
          temperature: 0.05,
          bloomEnabled: true,
          bloomThreshold: 0.95,
          bloomIntensity: 0.26,
          bloomScatter: 0.74,
          ambientOcclusionEnabled: true,
          ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
          ambientOcclusionIntensity: 1.56,
          ambientOcclusionPower: 1.75,
          ambientOcclusionRadius: 0.88,
          ambientOcclusionBentNormals: true,
          ambientOcclusionSpecularMode: SpecularAmbientOcclusionMode.bentCone,
          fogEnabled: true,
          fogColor: Vector3(0.18, 0.30, 0.38),
          fogDensity: 0.0086,
          fogHeight: 1.35,
          fogHeightFalloff: 0.34,
          godRaysEnabled: true,
          godRaysIntensity: 0.42,
          godRaysDensity: 0.66,
          godRaysColor: Vector3(1, 0.80, 0.48),
          vignetteEnabled: true,
          vignetteIntensity: 0.24,
        );

        nightSettings = EnvironmentSettings(
          toneMapping: ToneMappingMode.aces,
          exposure: 0.98,
          colorGradingEnabled: true,
          saturation: 1.18,
          contrast: 1.14,
          temperature: -0.05,
          bloomEnabled: true,
          bloomThreshold: 0.72,
          bloomIntensity: 0.42,
          bloomScatter: 0.82,
          ambientOcclusionEnabled: true,
          ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
          ambientOcclusionIntensity: 1.56,
          ambientOcclusionPower: 1.85,
          ambientOcclusionRadius: 0.88,
          ambientOcclusionBentNormals: true,
          ambientOcclusionSpecularMode: SpecularAmbientOcclusionMode.bentCone,
          fogEnabled: true,
          fogColor: Vector3(0.036, 0.088, 0.175),
          fogDensity: 0.0112,
          fogHeight: 1.75,
          fogHeightFalloff: 0.30,
          godRaysEnabled: true,
          godRaysIntensity: 0.15,
          godRaysDensity: 0.52,
          godRaysColor: Vector3(0.42, 0.62, 0.94),
          vignetteEnabled: true,
          vignetteIntensity: 0.36,
        );
      });

      test('Dusk EnvironmentSettings matches exact GTAO parameters', () {
        expect(duskSettings.ambientOcclusionEnabled, isTrue);
        expect(
          duskSettings.ambientOcclusionMethod,
          AmbientOcclusionMethod.groundTruth,
        );
        expect(duskSettings.ambientOcclusionIntensity, closeTo(1.56, 1e-6));
        expect(duskSettings.ambientOcclusionRadius, closeTo(0.88, 1e-6));
        expect(duskSettings.ambientOcclusionBentNormals, isTrue);
        expect(
          duskSettings.ambientOcclusionSpecularMode,
          SpecularAmbientOcclusionMode.bentCone,
        );
      });

      test('Night EnvironmentSettings matches exact GTAO parameters', () {
        expect(nightSettings.ambientOcclusionEnabled, isTrue);
        expect(
          nightSettings.ambientOcclusionMethod,
          AmbientOcclusionMethod.groundTruth,
        );
        expect(nightSettings.ambientOcclusionIntensity, closeTo(1.56, 1e-6));
        expect(nightSettings.ambientOcclusionRadius, closeTo(0.88, 1e-6));
        expect(nightSettings.ambientOcclusionBentNormals, isTrue);
        expect(
          nightSettings.ambientOcclusionSpecularMode,
          SpecularAmbientOcclusionMode.bentCone,
        );
      });

      test(
        'EnvironmentSettings.lerp preserves GTAO parameters and specular mode '
        'at all intermediate values',
        () {
          const testFactors = [
            0.0,
            0.001,
            0.1,
            0.25,
            0.4999,
            0.50,
            0.5001,
            0.75,
            0.9,
            0.999,
            1.0,
          ];

          for (final t in testFactors) {
            final lerped = EnvironmentSettings.lerp(
              duskSettings,
              nightSettings,
              t,
            );

            expect(
              lerped.ambientOcclusionEnabled,
              isTrue,
              reason: 'AO must remain enabled at t=$t',
            );
            expect(
              lerped.ambientOcclusionMethod,
              AmbientOcclusionMethod.groundTruth,
              reason: 'AO method must remain groundTruth at t=$t',
            );
            expect(
              lerped.ambientOcclusionIntensity,
              closeTo(1.56, 1e-6),
              reason:
                  'ambientOcclusionIntensity must remain 1.56 across lerp '
                  'at t=$t',
            );
            expect(
              lerped.ambientOcclusionRadius,
              closeTo(0.88, 1e-6),
              reason:
                  'ambientOcclusionRadius must remain 0.88 across lerp '
                  'at t=$t',
            );
            expect(
              lerped.ambientOcclusionBentNormals,
              isTrue,
              reason: 'ambientOcclusionBentNormals must remain true at t=$t',
            );
            expect(
              lerped.ambientOcclusionSpecularMode,
              SpecularAmbientOcclusionMode.bentCone,
              reason: 'specular mode must remain bentCone across lerp at t=$t',
            );

            expect(
              lerped.ambientOcclusionPower,
              inInclusiveRange(1.75 - 1e-6, 1.85 + 1e-6),
              reason:
                  'ambientOcclusionPower interpolates smoothly between '
                  '1.75 and 1.85',
            );
            expect(
              lerped.exposure,
              inInclusiveRange(0.98 - 1e-6, 1.02 + 1e-6),
              reason: 'exposure interpolates smoothly between 0.98 and 1.02',
            );
            expect(
              lerped.vignetteIntensity,
              inInclusiveRange(0.24 - 1e-6, 0.36 + 1e-6),
              reason:
                  'vignetteIntensity interpolates smoothly between '
                  '0.24 and 0.36',
            );
          }
        },
      );

      test('High-resolution sweep: 1000 lerp steps show zero NaN, zero drops, '
          'zero corruption', () {
        const steps = 1000;
        for (var i = 0; i <= steps; i++) {
          final t = i / steps;
          final lerped = EnvironmentSettings.lerp(
            duskSettings,
            nightSettings,
            t,
          );

          expect(lerped.ambientOcclusionIntensity.isFinite, isTrue);
          expect(lerped.ambientOcclusionRadius.isFinite, isTrue);
          expect(lerped.ambientOcclusionPower.isFinite, isTrue);
          expect(lerped.exposure.isFinite, isTrue);
          expect(lerped.fogDensity.isFinite, isTrue);
          expect(lerped.fogHeight.isFinite, isTrue);

          expect(lerped.ambientOcclusionIntensity, closeTo(1.56, 1e-5));
          expect(lerped.ambientOcclusionRadius, closeTo(0.88, 1e-5));
          expect(lerped.ambientOcclusionBentNormals, isTrue);
          expect(
            lerped.ambientOcclusionSpecularMode,
            SpecularAmbientOcclusionMode.bentCone,
          );
        }
      });
    },
  );

  group('Challenger Static Audit: edo_look_driver.dart Source Conformance', () {
    late final String source;

    setUpAll(() {
      final file = File('lib/shukuba/look/edo_look_driver.dart');
      expect(file.existsSync(), isTrue);
      source = file.readAsStringSync();
    });

    test('Verifies exact directional key light shadowAmbientStrength equation '
        'in syncFrame', () {
      expect(
        source,
        contains('shadowAmbientStrength = 0.15 + 0.05 * rig.nightFactor'),
      );
      expect(source, contains('shadowAmbientStrength: 0.15'));
    });

    test('Verifies fill light intensity and color pinned in both setup and '
        'syncFrame', () {
      expect(source, contains('intensity: 0.24'));
      expect(source, contains('color: Vector3(0.24, 0.38, 0.58)'));
      expect(source, contains('..intensity = 0.24'));
      expect(source, contains('..color = Vector3(0.24, 0.38, 0.58)'));
    });

    test(
      'Verifies dusk and night EnvironmentSettings configuration in source',
      () {
        expect(source, contains('ambientOcclusionIntensity: 1.56'));
        expect(source, contains('ambientOcclusionRadius: 0.88'));
        expect(source, contains('ambientOcclusionBentNormals: true'));
        expect(
          source,
          contains(
            'ambientOcclusionSpecularMode: '
            'SpecularAmbientOcclusionMode.bentCone',
          ),
        );

        final matchesIntensity = RegExp(r'ambientOcclusionIntensity:\s*1\.56')
            .allMatches(source);
        expect(matchesIntensity.length, greaterThanOrEqualTo(2));

        final matchesRadius = RegExp(r'ambientOcclusionRadius:\s*0\.88')
            .allMatches(source);
        expect(matchesRadius.length, greaterThanOrEqualTo(2));

        final matchesBentNormals = RegExp(
          r'ambientOcclusionBentNormals:\s*true',
        ).allMatches(source);
        expect(matchesBentNormals.length, greaterThanOrEqualTo(2));

        final matchesSpecular = RegExp(
          r'ambientOcclusionSpecularMode:\s*'
          r'SpecularAmbientOcclusionMode\.bentCone',
        ).allMatches(source);
        expect(matchesSpecular.length, greaterThanOrEqualTo(2));
      },
    );

    test('Verifies syncFrame calls EnvironmentSettings.lerp with dusk, night, '
        'and rig.nightFactor', () {
      expect(
        source,
        contains(
          'EnvironmentSettings.lerp(\n'
          '        dusk,\n'
          '        night,\n'
          '        rig.nightFactor,\n'
          '      )',
        ),
      );
    });
  });
}
