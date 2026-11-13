import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/look/look.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart';

bool gpuAvailable() {
  try {
    Scene();
    return true;
  } on Object catch (_) {
    return false;
  }
}

void main() {
  group('SumiInkParams std140 layout and packing', () {
    test('packs exactly 32 bytes into std140 buffer with correct offsets', () {
      final params = SumiInkParams(
        inkColor: Vector4(0.12, 0.09, 0.08, 0.95),
        depthWeight: 2.2,
        normalWeight: 1.8,
        washiGrainStrength: 0.025,
        skyFadeDistance: 180,
      );

      final bytes = params.packStd140();
      expect(bytes.lengthInBytes, 32);

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

    test('copyWith updates individual fields while preserving others', () {
      final initial = SumiInkParams(
        inkColor: Vector4(0.1, 0.2, 0.3, 0.4),
        depthWeight: 2,
        normalWeight: 1.2,
        washiGrainStrength: 0.02,
        skyFadeDistance: 150,
      );

      final updated = initial.copyWith(depthWeight: 2.5, skyFadeDistance: 220);

      expect(updated.depthWeight, 2.5);
      expect(updated.skyFadeDistance, 220);
      expect(updated.inkColor, Vector4(0.1, 0.2, 0.3, 0.4));
      expect(updated.normalWeight, 1.2);
      expect(updated.washiGrainStrength, 0.02);
    });
  });

  group('EdoLookDriver lantern clustering and punctual light budget', () {
    test('merges nearby lanterns within 5.5m into weighted centroids sorted by '
        'weight and capped at 12', () {
      final origins = <Vec3>[
        const Vec3(40, 2.4, 40),
        const Vec3(0, 2.5, 0),
        const Vec3(2, 2.5, 0),
        const Vec3(0, 2.5, 2),
        const Vec3(-22, 2.6, -12),
        const Vec3(-20, 2.6, -12),
        for (var i = 0; i < 42; i++)
          Vec3(-90 + (i % 14) * 14.0, 2.5, -36 + (i ~/ 14) * 24.0),
      ];
      expect(origins.length, 48);

      final clusters = EdoLookDriver.clusterLanternOrigins(origins);
      expect(clusters.length, EdoLookDriver.maxLanternPointLights);
      expect(clusters.length, lessThanOrEqualTo(12));

      expect(clusters.first.weight, greaterThanOrEqualTo(3));
      for (var i = 1; i < clusters.length; i++) {
        expect(
          clusters[i - 1].weight,
          greaterThanOrEqualTo(clusters[i].weight),
        );
      }

      final focused = EdoLookDriver.clusterLanternOrigins(const [
        Vec3(50, 2, 50),
        Vec3(0, 3, 0),
        Vec3(3, 3, 0),
        Vec3(0, 3, 3),
      ]);
      expect(focused.length, 2);
      expect(focused.first.weight, 3);
      expect(focused.first.centroid.x, closeTo(1.0, 1e-6));
      expect(focused.first.centroid.y, closeTo(3.0, 1e-6));
      expect(focused.first.centroid.z, closeTo(1.0, 1e-6));
      expect(focused.last.weight, 1);
    });

    test('syncFrame caps active PointLights at <= 12 even when given 45+ '
        'lanternOrigins and mounts zero secondary fill lights', () async {
      final driver = EdoLookDriver(allowHeadlessFallback: true);
      final scene = gpuAvailable() ? Scene() : null;
      if (scene != null) {
        await driver.attach(scene);
      }

      final denseLanterns = <Vec3>[
        for (var i = 0; i < 46; i++)
          Vec3(-32 + (i % 9) * 8.5, 2.8, -24 + (i ~/ 9) * 11.0),
      ];

      driver.syncFrame(
        rig: TimeOfDayRig.blueHourNight,
        vision: MagistrateVisionState.hidden,
        sightcones: const [],
        lanternOrigins: denseLanterns,
        elapsedSeconds: 0.5,
      );

      expect(driver.activeLanternLights.length, 12);
      expect(driver.activeLanternLights.length, lessThanOrEqualTo(12));
      for (final light in driver.activeLanternLights) {
        expect(light.range, closeTo(8.2, 1e-6));
        expect(light.falloffExponent, closeTo(2.0, 1e-6));
        expect(light.intensity, greaterThan(0));
      }

      if (scene != null) {
        final fillNodes = scene.root.children
            .where((n) => n.name == 'edo_fill_light')
            .toList();
        expect(fillNodes, isEmpty);

        final lanternNodes = scene.root.children
            .where((n) => n.name.startsWith('lantern_light_'))
            .toList();
        expect(lanternNodes.length, 12);
        final activeCount = lanternNodes.where((n) => n.visible).length;
        expect(activeCount, 12);
      }

      driver.syncFrame(
        rig: TimeOfDayRig.goldenDusk,
        vision: MagistrateVisionState.hidden,
        sightcones: const [],
        lanternOrigins: const [
          Vec3(-12, 2.6, 0),
          Vec3(-11, 2.6, 0.5),
          Vec3(18, 2.6, -6),
        ],
        elapsedSeconds: 1,
      );

      expect(driver.activeLanternLights.length, 2);
      expect(
        driver.activeLanternLights.first.intensity,
        closeTo(
          TimeOfDayRig.goldenDusk.lanternPointLightIntensity * 0.68 * 1.16,
          1e-5,
        ),
      );
      expect(
        driver.activeLanternLights.last.intensity,
        closeTo(
          TimeOfDayRig.goldenDusk.lanternPointLightIntensity * 0.68,
          1e-5,
        ),
      );
      expect(
        driver.activeLanternLights.first.intensity,
        greaterThan(driver.activeLanternLights.last.intensity),
      );

      if (scene != null) {
        final visibleLanterns = scene.root.children
            .where((n) => n.name.startsWith('lantern_light_') && n.visible)
            .toList();
        expect(visibleLanterns.length, 2);
      }

      driver.dispose();
      expect(driver.activeLanternLights, isEmpty);
    });
  });

  group('EdoLookDriver solar sky horizon trajectory', () {
    test(
      'solarSkyDirectionFor descends continuously from +24 deg through +2 deg '
      'at 0.55 to below the horizon at night',
      () {
        final atStart = EdoLookDriver.solarSkyDirectionFor(
          const TimeOfDayRig(0),
        );
        final atDusk = EdoLookDriver.solarSkyDirectionFor(
          TimeOfDayRig.goldenDusk,
        );
        final atSwitch = EdoLookDriver.solarSkyDirectionFor(
          const TimeOfDayRig(0.55),
        );
        final atNight = EdoLookDriver.solarSkyDirectionFor(
          TimeOfDayRig.blueHourNight,
        );
        final atMidnight = EdoLookDriver.solarSkyDirectionFor(
          const TimeOfDayRig(1),
        );

        expect(atStart.length, closeTo(1.0, 1e-6));
        expect(atSwitch.length, closeTo(1.0, 1e-6));
        expect(atNight.length, closeTo(1.0, 1e-6));
        expect(atMidnight.length, closeTo(1.0, 1e-6));

        expect(atStart.y, closeTo(math.sin(24 * degrees2Radians), 1e-5));
        expect(atDusk.y, greaterThan(0.28));
        expect(atSwitch.y, closeTo(math.sin(2 * degrees2Radians), 1e-5));
        expect(atNight.y, lessThan(0));
        expect(atMidnight.y, closeTo(math.sin(-8 * degrees2Radians), 1e-5));

        var prevY = atStart.y;
        for (var i = 1; i <= 100; i++) {
          final currentY = EdoLookDriver.solarSkyDirectionFor(
            TimeOfDayRig(i / 100),
          ).y;
          expect(currentY, lessThan(prevY));
          prevY = currentY;
        }

        expect(TimeOfDayRig.blueHourNight.celestialRayDirection.y, lessThan(0));
      },
    );
  });

  group('EdoLookDriver headless attach, materials, and syncFrame', () {
    test('materialFor preserves depthLayer ordering', () async {
      final driver = EdoLookDriver(allowHeadlessFallback: true);
      if (gpuAvailable()) {
        final scene = Scene();
        await driver.attach(scene);
      }

      final groundMat = driver.materialFor(ShukubaSurfaceRole.packedEarth);
      final kitMat = driver.materialFor(ShukubaSurfaceRole.ishigakiStone);
      final meadowMat = driver.materialFor(ShukubaSurfaceRole.groundMeadow);
      final livingMat = driver.materialFor(ShukubaSurfaceRole.livingMeadow);
      final pineMat = driver.materialFor(ShukubaSurfaceRole.pineCanopy);
      final willowMat = driver.materialFor(ShukubaSurfaceRole.willowCanopy);
      final laneMat = driver.materialFor(ShukubaSurfaceRole.laneOverlay);
      final wallMat = driver.materialFor(ShukubaSurfaceRole.plasterWall);
      final waterMat = driver.materialFor(ShukubaSurfaceRole.riverWater);
      final mistMat = driver.materialFor(ShukubaSurfaceRole.riverMist);
      final haloMat = driver.materialFor(ShukubaSurfaceRole.lanternHaze);
      final moteMat = driver.materialFor(ShukubaSurfaceRole.airborneMotes);

      expect(groundMat.depthLayer, 0);
      expect(kitMat.depthLayer, 0);
      expect(meadowMat.depthLayer, 0);
      expect(livingMat.depthLayer, 0);
      expect(pineMat.depthLayer, 0);
      expect(willowMat.depthLayer, 0);
      expect(wallMat.depthLayer, 0);
      expect(waterMat.depthLayer, 1);
      expect(laneMat.depthLayer, 1);
      expect(mistMat.depthLayer, 3);
      expect(haloMat.depthLayer, 4);
      expect(moteMat.depthLayer, 4);

      driver.dispose();
    });

    test('syncFrame updates PCSS key light, PhysicalSkySource, and environment '
        'across Dusk and Night', () async {
      final driver = EdoLookDriver(allowHeadlessFallback: true);
      final scene = gpuAvailable() ? Scene() : null;
      if (scene != null) {
        await driver.attach(scene);
      }

      const sightconeA = WatchSightcone(
        sourceId: EntityId('tower_1'),
        origin: Vec3(10, 0, 15),
        yawRadians: 0.5,
        rangeMeters: 16,
        halfAngleRadians: 0.45,
        alertLevel: 0.2,
        isWatchtower: true,
      );

      const sightconeB = WatchSightcone(
        sourceId: EntityId('guard_1'),
        origin: Vec3(5, 0, 5),
        yawRadians: -0.2,
        rangeMeters: 10,
        halfAngleRadians: 0.40,
        alertLevel: 0.8,
      );

      final lanterns = [const Vec3(2, 3, 4), const Vec3(14, 3, 8)];

      driver.syncFrame(
        rig: TimeOfDayRig.goldenDusk,
        vision: MagistrateVisionState.watchtowerPreview,
        sightcones: [sightconeA, sightconeB],
        lanternOrigins: lanterns,
        elapsedSeconds: 1,
      );

      final key = driver.keyLight;
      expect(key, isNotNull);
      expect(key!.castsShadow, isTrue);
      expect(key.angularRadius, closeTo(0.052, 1e-6));
      expect(key.shadowSoftness, closeTo(0.28, 1e-6));
      expect(key.shadowCascadeCount, 4);
      expect(key.shadowMaxDistance, closeTo(145, 1e-6));
      expect(key.shadowCascadeSplitLambda, closeTo(0.65, 1e-6));
      expect(key.shadowMapResolution, 2048);
      expect(key.shadowFilter, DirectionalShadowFilter.pcss);
      expect(key.contactShadows, isTrue);
      expect(key.contactShadowDistance, closeTo(0.45, 1e-6));
      expect(
        key.shadowAmbientStrength,
        closeTo(0.28 + 0.08 * TimeOfDayRig.goldenDusk.nightFactor, 1e-5),
      );

      if (scene != null) {
        expect(scene.directionalLight, same(key));

        final duskNf = TimeOfDayRig.goldenDusk.nightFactor;
        final env = scene.environmentSettings;
        expect(env.toneMapping, ToneMappingMode.aces);
        expect(
          env.environmentIntensity,
          closeTo(7.20 * (1 - duskNf) + 0.68 * duskNf, 1e-5),
        );
        expect(
          env.exposure,
          closeTo(0.95 * (1 - duskNf) + 0.84 * duskNf, 1e-5),
        );
        expect(env.ambientOcclusionEnabled, isTrue);
        expect(env.ambientOcclusionMethod, AmbientOcclusionMethod.groundTruth);
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
        expect(env.fogEnabled, isTrue);
        expect(env.fogMode, FogMode.exponential);
        expect(env.fogStart, closeTo(18 * (1 - duskNf) + 22 * duskNf, 1e-5));
        expect(
          env.fogDensity,
          closeTo(0.0046 * (1 - duskNf) + 0.0052 * duskNf, 1e-6),
        );
        expect(
          env.fogMaxOpacity,
          closeTo(0.48 * (1 - duskNf) + 0.44 * duskNf, 1e-5),
        );
        expect(
          env.fogSunInScatter,
          closeTo(0.07 * (1 - duskNf) + 0.02 * duskNf, 1e-5),
        );
        expect(
          env.fogSkyColorInfluence,
          closeTo(0.24 * (1 - duskNf) + 0.16 * duskNf, 1e-5),
        );
        expect(env.fogHeight, closeTo(1.4, 1e-5));
        expect(env.fogHeightFalloff, closeTo(0.34, 1e-5));
        expect(env.godRaysEnabled, isTrue);
        expect(
          env.godRaysIntensity,
          closeTo(0.64 * (1 - duskNf) + 0.06 * duskNf, 1e-5),
        );
        expect(
          env.godRaysDensity,
          closeTo(0.50 * (1 - duskNf) + 0.26 * duskNf, 1e-5),
        );
        expect(env.godRaysAnisotropy, closeTo(0.66, 1e-5));
        expect(env.godRaysStepCount, 64);
        expect(env.godRaysMaxDistance, closeTo(54, 1e-5));
        expect(env.godRaysMaxDistance, lessThan(key.shadowMaxDistance));
      }

      driver.syncFrame(
        rig: TimeOfDayRig.blueHourNight,
        vision: MagistrateVisionState.fullOverlay,
        sightcones: [sightconeA, sightconeB],
        lanternOrigins: lanterns,
        elapsedSeconds: 2,
      );

      expect(
        driver.keyLight!.shadowAmbientStrength,
        closeTo(0.28 + 0.08 * TimeOfDayRig.blueHourNight.nightFactor, 1e-5),
      );
      expect(
        driver.keyLight!.shadowAmbientStrength,
        inInclusiveRange(0.28, 0.36),
      );

      if (scene != null) {
        final nightNf = TimeOfDayRig.blueHourNight.nightFactor;
        final nightEnv = scene.environmentSettings;
        expect(
          nightEnv.environmentIntensity,
          closeTo(7.20 * (1 - nightNf) + 0.68 * nightNf, 1e-5),
        );
        expect(
          nightEnv.exposure,
          closeTo(0.95 * (1 - nightNf) + 0.84 * nightNf, 1e-5),
        );
        expect(
          nightEnv.bloomThreshold,
          closeTo(0.96 * (1 - nightNf) + 0.88 * nightNf, 1e-5),
        );
        expect(
          nightEnv.bloomIntensity,
          closeTo(0.24 * (1 - nightNf) + 0.28 * nightNf, 1e-5),
        );
        expect(
          nightEnv.bloomScatter,
          closeTo(0.74 * (1 - nightNf) + 0.72 * nightNf, 1e-5),
        );
      }

      driver.dispose();
    });

    test('syncFrame execution is idempotent over repeated calls', () async {
      final driver = EdoLookDriver(allowHeadlessFallback: true);
      final scene = gpuAvailable() ? Scene() : null;
      if (scene != null) {
        await driver.attach(scene);
      }

      final initialChildCount = scene?.root.children.length ?? 0;

      const sightcone = WatchSightcone(
        sourceId: EntityId('tower_1'),
        origin: Vec3.zero,
        yawRadians: 0,
        rangeMeters: 12,
        halfAngleRadians: 0.4,
        isWatchtower: true,
      );

      for (var frame = 0; frame < 5; frame++) {
        driver.syncFrame(
          rig: TimeOfDayRig.goldenDusk,
          vision: MagistrateVisionState.hidden,
          sightcones: const [sightcone],
          lanternOrigins: const [Vec3(0, 2, 0)],
          elapsedSeconds: frame * 0.016,
        );
      }

      if (scene != null) {
        expect(scene.root.children.length, initialChildCount);
      }

      driver.dispose();
      if (scene != null) {
        expect(scene.root.children.length, lessThan(initialChildCount));
      }
    });
  });
}
