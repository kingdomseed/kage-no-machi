import 'dart:io';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/look/look.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';

bool _gpuAvailable() {
  try {
    Scene();
    return true;
  } on Object catch (_) {
    return false;
  }
}

void main() {
  group('Challenger Stress Test: Slice-8 Look Driver & Lighting Rig', () {
    test(
      'EdoLookDriver keyLight shadowAmbientStrength is 0.28 at t=0.0 and 0.36 '
      'at t=1.0',
      () {
        final driver = EdoLookDriver(allowHeadlessFallback: true);
        addTearDown(driver.dispose);

        driver.syncFrame(
          rig: const TimeOfDayRig(0),
          vision: MagistrateVisionState.hidden,
          sightcones: const [],
          lanternOrigins: const [],
          elapsedSeconds: 0,
        );
        expect(driver.keyLight, isNotNull);
        expect(driver.keyLight!.shadowAmbientStrength, closeTo(0.28, 1e-6));

        driver.syncFrame(
          rig: const TimeOfDayRig(1),
          vision: MagistrateVisionState.hidden,
          sightcones: const [],
          lanternOrigins: const [],
          elapsedSeconds: 1,
        );
        expect(driver.keyLight!.shadowAmbientStrength, closeTo(0.36, 1e-6));
      },
    );

    test('EdoLookDriver keyLight shadowAmbientStrength across 1000 rigs in '
        '[0.0, 1.0] stays in [0.28, 0.36] and is monotonic', () {
      final driver = EdoLookDriver(allowHeadlessFallback: true);
      addTearDown(driver.dispose);

      const steps = 1000;
      var previousStrength = -1.0;

      for (var i = 0; i <= steps; i++) {
        final t = i / steps;
        driver.syncFrame(
          rig: TimeOfDayRig(t),
          vision: MagistrateVisionState.hidden,
          sightcones: const [],
          lanternOrigins: const [],
          elapsedSeconds: t,
        );
        final strength = driver.keyLight!.shadowAmbientStrength;
        expect(
          strength,
          greaterThanOrEqualTo(0.28 - 1e-6),
          reason: 'At t=$t, shadowAmbientStrength must be >= 0.28',
        );
        expect(
          strength,
          lessThanOrEqualTo(0.36 + 1e-6),
          reason: 'At t=$t, shadowAmbientStrength must be <= 0.36',
        );
        if (previousStrength >= 0) {
          expect(
            strength,
            greaterThanOrEqualTo(previousStrength - 1e-9),
            reason:
                'shadowAmbientStrength must be monotonically non-decreasing',
          );
        }
        previousStrength = strength;
      }
    });

    test('TimeOfDayRig nightFactor bounds and clamping', () {
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

    test(
      'Starter ward lantern origins cluster to <= 12 active PointLights with '
      '8.2m range and zero secondary fill light',
      () async {
        final world = EdoWorldDriver()..initSimulation();
        final origins = world.activeLanternOrigins;
        expect(origins.length, greaterThan(16));

        final clusters = EdoLookDriver.clusterLanternOrigins(origins);
        expect(clusters.length, lessThanOrEqualTo(12));
        expect(clusters.length, EdoLookDriver.maxLanternPointLights);
        for (var i = 1; i < clusters.length; i++) {
          expect(
            clusters[i - 1].weight,
            greaterThanOrEqualTo(clusters[i].weight),
          );
        }

        final driver = EdoLookDriver(allowHeadlessFallback: true);
        addTearDown(driver.dispose);
        final scene = _gpuAvailable() ? Scene() : null;
        if (scene != null) {
          await driver.attach(scene);
        }

        driver.syncFrame(
          rig: TimeOfDayRig.blueHourNight,
          vision: MagistrateVisionState.hidden,
          sightcones: const [],
          lanternOrigins: origins,
          elapsedSeconds: 0.5,
        );

        expect(driver.activeLanternLights.length, lessThanOrEqualTo(12));
        for (final light in driver.activeLanternLights) {
          expect(light.range, closeTo(8.2, 1e-6));
          expect(light.falloffExponent, closeTo(2.0, 1e-6));
          expect(light.intensity, greaterThan(0));
        }

        if (scene != null) {
          expect(
            scene.root.children.where((n) => n.name == 'edo_fill_light'),
            isEmpty,
          );
        }
      },
    );

    test('EdoLookDriver keyLight configures soft 4-cascade PCSS shadows over '
        '145m', () {
      final driver = EdoLookDriver(allowHeadlessFallback: true);
      addTearDown(driver.dispose);

      driver.syncFrame(
        rig: TimeOfDayRig.goldenDusk,
        vision: MagistrateVisionState.hidden,
        sightcones: const [],
        lanternOrigins: const [],
        elapsedSeconds: 0,
      );

      final keyLight = driver.keyLight!;
      expect(keyLight.castsShadow, isTrue);
      expect(keyLight.priority, 10);
      expect(keyLight.angularRadius, closeTo(0.052, 1e-6));
      expect(keyLight.shadowSoftness, closeTo(0.28, 1e-6));
      expect(keyLight.shadowCascadeCount, 4);
      expect(keyLight.shadowMaxDistance, closeTo(145, 1e-6));
      expect(keyLight.shadowCascadeSplitLambda, closeTo(0.65, 1e-6));
      expect(keyLight.shadowMapResolution, 2048);
      expect(keyLight.shadowFilter, DirectionalShadowFilter.pcss);
      expect(keyLight.contactShadows, isTrue);
      expect(keyLight.contactShadowDistance, closeTo(0.45, 1e-6));
    });
  });

  group('Challenger Stress Test: PhysicalSky, GTAO & Shader Invariants', () {
    test('EdoLookDriver scene environment interpolates wide GTAO, exponential '
        'fog, and god rays across [0.0, 1.0]', () async {
      final driver = EdoLookDriver(allowHeadlessFallback: true);
      addTearDown(driver.dispose);

      if (_gpuAvailable()) {
        final scene = Scene();
        await driver.attach(scene);

        for (var i = 0; i <= 50; i++) {
          final t = i / 50.0;
          driver.syncFrame(
            rig: TimeOfDayRig(t),
            vision: MagistrateVisionState.hidden,
            sightcones: const [],
            lanternOrigins: const [],
            elapsedSeconds: t,
          );
          final env = scene.environmentSettings;
          expect(env.toneMapping, ToneMappingMode.aces);
          expect(env.ambientOcclusionEnabled, isTrue);
          expect(
            env.ambientOcclusionMethod,
            AmbientOcclusionMethod.groundTruth,
          );
          expect(env.ambientOcclusionBentNormals, isTrue);
          expect(
            env.ambientOcclusionSpecularMode,
            SpecularAmbientOcclusionMode.bentCone,
          );
          expect(env.ambientOcclusionIntensity, closeTo(1.68, 1e-5));
          expect(env.ambientOcclusionRadius, closeTo(1.05, 1e-5));
          expect(env.ambientOcclusionPower, closeTo(1.85, 1e-5));
          expect(env.ambientOcclusionMultiBounce, closeTo(0.46, 1e-5));
          expect(env.ambientOcclusionDirectLightAffect, closeTo(0.30, 1e-5));
          expect(env.exposure, inInclusiveRange(0.92 - 1e-5, 0.96 + 1e-5));
          expect(env.fogEnabled, isTrue);
          expect(env.fogMode, FogMode.exponential);
          expect(env.fogHeight, closeTo(1.8, 1e-5));
          expect(env.fogHeightFalloff, closeTo(0.28, 1e-5));
          expect(env.godRaysEnabled, isTrue);
          expect(env.godRaysStepCount, 36);
        }
      }

      final sunbeamMat = EdoLookDriver.resolveSunbeamMaterial(
        driver.materialFor,
      );
      expect(
        sunbeamMat.depthLayer,
        equals(ShukubaSurfaceRole.riverMist.depthLayer),
      );
    });

    test('EdoLookDriver wires PhysicalSkySource, SkyEnvironment, and zero '
        'secondary directional fill lights', () {
      final source = File('lib/shukuba/look/edo_look_driver.dart')
          .readAsStringSync();

      expect(source, contains('PhysicalSkySource('));
      expect(source, contains('SkyEnvironment('));
      expect(source, isNot(contains('GradientSkySource')));
      expect(source, isNot(contains('edo_fill_light')));
      expect(source, contains('maxLanternPointLights = 12'));
      expect(source, contains('lanternPointLightRangeMeters = 8.2'));
      expect(
        source,
        contains('shadowAmbientStrength = 0.28 + 0.08 * rig.nightFactor'),
      );
      expect(source, contains('ambientOcclusionIntensity: 1.68'));
      expect(source, contains('ambientOcclusionRadius: 1.05'));
      expect(source, contains('ambientOcclusionMultiBounce: 0.46'));
      expect(source, contains('EnvironmentSettings.lerp('));
    });

    test('GouacheLit and RiverWater shaders enforce parallax, occlusion, UV1 '
        'blending, and scene_color/scene_depth caustics', () {
      final gouache = File('assets/materials/gouache_lit.fmat')
          .readAsStringSync();
      expect(gouache, contains('fwidth(P0)'));
      expect(gouache, contains('SampleReliefHeight('));
      expect(gouache, contains('laneBlend = clamp(GetUV1(), 0.0, 1.0)'));
      expect(gouache, contains('EvaluateGardenPath('));
      expect(gouache, contains('EvaluateKaidoRoad('));
      expect(gouache, contains('EvaluateNaturalGround('));
      expect(gouache, contains('material.occlusion = finalOcclusion;'));

      final water = File('assets/materials/river_water.fmat')
          .readAsStringSync();
      expect(water, contains('engine_inputs: [scene_color, scene_depth]'));
      expect(water, contains('GetSceneDepth('));
      expect(water, contains('GetSceneWorldPosition('));
      expect(water, contains('GetSceneColor('));
      expect(water, contains('exp(-vec3(2.6, 0.95, 0.78) * thickness)'));
    });
  });
}
