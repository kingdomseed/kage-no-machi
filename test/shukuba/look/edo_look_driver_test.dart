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

  group('EdoLookDriver headless attach, materials, and syncFrame', () {
    test(
      'materialFor preserves depthLayer ordering for ground, kit, and lane',
      () async {
        final driver = EdoLookDriver(allowHeadlessFallback: true);
        if (gpuAvailable()) {
          final scene = Scene();
          await driver.attach(scene);
        }

        final groundMat = driver.materialFor(ShukubaSurfaceRole.packedEarth);
        final kitMat = driver.materialFor(ShukubaSurfaceRole.ishigakiStone);
        final laneMat = driver.materialFor(ShukubaSurfaceRole.laneOverlay);
        final wallMat = driver.materialFor(ShukubaSurfaceRole.plasterWall);
        final waterMat = driver.materialFor(ShukubaSurfaceRole.riverWater);

        expect(groundMat.depthLayer, -1);
        expect(kitMat.depthLayer, 0);
        expect(wallMat.depthLayer, 0);
        expect(waterMat.depthLayer, 0);
        expect(laneMat.depthLayer, 1);

        driver.dispose();
      },
    );

    test(
      'syncFrame updates lights and sightcones across Dusk and Night',
      () async {
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

        final lanterns = [const Vec3(2, 3, 4), const Vec3(6, 3, 8)];

        driver.syncFrame(
          rig: TimeOfDayRig.goldenDusk,
          vision: MagistrateVisionState.watchtowerPreview,
          sightcones: [sightconeA, sightconeB],
          lanternOrigins: lanterns,
          elapsedSeconds: 1,
        );

        if (scene != null) {
          expect(scene.directionalLight, isNotNull);
          expect(scene.directionalLight!.castsShadow, isTrue);
          expect(scene.directionalLight!.shadowCascadeCount, 3);
          expect(scene.directionalLight!.shadowMapResolution, 2048);
        }

        driver.syncFrame(
          rig: TimeOfDayRig.blueHourNight,
          vision: MagistrateVisionState.fullOverlay,
          sightcones: [sightconeA, sightconeB],
          lanternOrigins: lanterns,
          elapsedSeconds: 2,
        );

        if (scene != null) {
          expect(
            scene.directionalLight!.shadowAmbientStrength,
            greaterThan(0.35),
          );
        }

        driver.dispose();
      },
    );

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
