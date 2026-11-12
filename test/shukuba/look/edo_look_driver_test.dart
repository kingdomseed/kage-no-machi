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

  group('EdoLookDriver headless attach, materials, and syncFrame', () {
    test(
      'materialFor and resolveSunbeamMaterial preserve depthLayer ordering',
      () async {
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
        final sunbeamMat = EdoLookDriver.resolveSunbeamMaterial(
          driver.materialFor,
        );
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
        expect(sunbeamMat.depthLayer, 3);
        expect(haloMat.depthLayer, 4);
        expect(moteMat.depthLayer, 4);

        driver.dispose();
      },
    );

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

        final env = scene.environmentSettings;
        expect(env.toneMapping, ToneMappingMode.aces);
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
        expect(env.fogSkyColorInfluence, closeTo(0.36, 1e-5));
        expect(env.fogHeight, closeTo(1.8, 1e-5));
        expect(env.fogHeightFalloff, closeTo(0.28, 1e-5));
        expect(env.godRaysEnabled, isTrue);
        expect(env.godRaysDensity, closeTo(0.72, 1e-5));
        expect(env.godRaysAnisotropy, closeTo(0.76, 1e-5));
        expect(env.godRaysStepCount, 36);
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
        expect(
          scene.environmentSettings.exposure,
          inInclusiveRange(0.92, 0.96),
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
