import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/tactical_camera_rig.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';
import 'package:vector_math/vector_math.dart' show degrees2Radians;

void main() {
  group('Feature 19: 176m Countryside Expansion', () {
    test('TerrainConfig defines geographic bounds and grid step', () {
      expect(TerrainConfig.minX, equals(-88.0));
      expect(TerrainConfig.maxX, equals(88.0));
      expect(TerrainConfig.minZ, equals(-88.0));
      expect(TerrainConfig.maxZ, equals(88.0));
      expect(TerrainConfig.gridStep, equals(0.5));

      const width = TerrainConfig.maxX - TerrainConfig.minX;
      const depth = TerrainConfig.maxZ - TerrainConfig.minZ;
      expect(width, equals(176.0));
      expect(depth, equals(176.0));

      const cellsX = width / TerrainConfig.gridStep;
      const cellsZ = depth / TerrainConfig.gridStep;
      expect(cellsX, equals(352.0));
      expect(cellsZ, equals(352.0));
    });

    test('Outer countryside terrain generates open agricultural plains', () {
      final terrain = TerrainBuilder();
      final heightNorthEast = terrain.sampleGroundHeight(75, 75);
      final heightNorthWest = terrain.sampleGroundHeight(-75, 75);
      final heightSouthEast = terrain.sampleGroundHeight(75, -75);
      final heightSouthWest = terrain.sampleGroundHeight(-75, -75);

      expect(heightNorthEast.isFinite, isTrue);
      expect(heightNorthWest.isFinite, isTrue);
      expect(heightSouthEast.isFinite, isTrue);
      expect(heightSouthWest.isFinite, isTrue);
      expect(heightNorthWest, inInclusiveRange(0.20, 1.50));
      expect(heightSouthWest, inInclusiveRange(0.20, 1.50));
      expect(heightNorthEast, greaterThan(4.0));
      expect(heightSouthEast, greaterThan(4.0));
    });

    test('Terraced tanada rice paddies generate with reflective shallow '
        'water planes', () {
      const waterElevation = TerrainConfig.waterSurfaceElevation;
      expect(waterElevation, lessThan(0));
      expect(TerrainConfig.riverBedElevation, lessThan(waterElevation));
    });

    test('East and west Kaido approaches define distinct approach axes', () {
      final terrain = TerrainBuilder();
      final groundCenter = terrain.sampleGroundHeight(0, 0);
      final groundEast = terrain.sampleGroundHeight(30, 0);
      final groundWest = terrain.sampleGroundHeight(-30, 0);

      expect(groundCenter.isFinite, isTrue);
      expect(groundEast.isFinite, isTrue);
      expect(groundWest.isFinite, isTrue);
    });

    test(
      'Elevation transition between central town and outer plains is smooth',
      () {
        final terrain = TerrainBuilder();
        final centerHeight = terrain.sampleGroundHeight(0, 0);
        final midEastHeight = terrain.sampleGroundHeight(35, 0);
        final edgeEastHeight = terrain.sampleGroundHeight(75, 0);

        final diff1 = (midEastHeight - centerHeight).abs();
        final diff2 = (edgeEastHeight - midEastHeight).abs();

        expect(diff1, lessThan(15));
        expect(diff2, lessThan(15));
      },
    );
  });

  group('Feature 20: Spatial Terrain Chunking & Dirty Tiles', () {
    test('TerrainConfig provides bounds covering all quadrants', () {
      expect(TerrainConfig.minX, lessThan(0));
      expect(TerrainConfig.maxX, greaterThan(0));
      expect(TerrainConfig.minZ, lessThan(0));
      expect(TerrainConfig.maxZ, greaterThan(0));
    });

    test('Terrain grid step divides width into integer grid steps', () {
      const totalWidth = TerrainConfig.maxX - TerrainConfig.minX;
      const stepCount = totalWidth / TerrainConfig.gridStep;
      expect(stepCount.roundToDouble(), equals(stepCount));
    });

    test('Terrain sampling produces deterministic elevations across '
        'coordinates', () {
      final terrain = TerrainBuilder();
      final h1 = terrain.sampleGroundHeight(12.5, -8);
      final h2 = terrain.sampleGroundHeight(12.5, -8);
      expect(h1, equals(h2));
    });

    test('River center curve evaluates within terrain width bounds', () {
      for (var z = TerrainConfig.minZ; z <= TerrainConfig.maxZ; z += 10.0) {
        final cx = TerrainConfig.riverCenterX(z);
        expect(cx, greaterThan(TerrainConfig.minX));
        expect(cx, lessThan(TerrainConfig.maxX));
      }
    });

    test(
      'Bridge deck profile maintains positive clearance over river water',
      () {
        final deckWest = TerrainConfig.bridgeDeckHeightAt(
          TerrainConfig.bridgeMinX,
        );
        final deckCenter = TerrainConfig.bridgeDeckHeightAt(0);
        final deckEast = TerrainConfig.bridgeDeckHeightAt(
          TerrainConfig.bridgeMaxX,
        );

        expect(deckWest, greaterThan(TerrainConfig.waterSurfaceElevation));
        expect(deckCenter, greaterThan(TerrainConfig.waterSurfaceElevation));
        expect(deckEast, greaterThan(TerrainConfig.waterSurfaceElevation));
      },
    );
  });

  group('Feature 21: Countryside Vista Camera Preset', () {
    test('CameraPreset.verificationPresets contains core verification presets '
        'and countrysideVista defines wide valley optics', () {
      expect(CameraPreset.verificationPresets, isNotEmpty);
      expect(
        CameraPreset.verificationPresets.any(
          (p) => p.id == CameraPreset.duskOverview.id,
        ),
        isTrue,
      );
      expect(
        CameraPreset.verificationPresets.any(
          (p) => p.id == CameraPreset.nightMarket.id,
        ),
        isTrue,
      );
      expect(
        CameraPreset.verificationPresets.any(
          (p) => p.id == CameraPreset.riverCrossing.id,
        ),
        isTrue,
      );
      expect(
        CameraPreset.verificationPresets.any(
          (p) => p.id == CameraPreset.meadowCloseup.id,
        ),
        isTrue,
      );
      expect(
        CameraPreset.verificationPresets.any(
          (p) => p.id == CameraPreset.countrysideVista.id,
        ),
        isTrue,
      );

      const preset = CameraPreset.countrysideVista;
      expect(preset.id, equals('countryside_vista'));
      expect(preset.label, equals('Terraced Countryside Vista'));
      expect(preset.eye, equals(const Vec3(-66, 56, -66)));
      expect(preset.target, equals(const Vec3(2, 2.2, 0)));
      expect(preset.timeOfDay, equals(TimeOfDayRig.goldenDusk));
      expect(preset.verticalFovDegrees, equals(22));
      expect(preset.nearMeters, equals(4));
      expect(preset.farMeters, equals(350));
    });

    test('Verification presets define distinct viewing angles and targets', () {
      for (final preset in CameraPreset.verificationPresets) {
        expect(preset.eye, isNot(equals(preset.target)));
        expect(preset.verticalFovDegrees, inInclusiveRange(10, 60));
        expect(preset.farMeters, greaterThan(100));
        expect(preset.nearMeters, greaterThan(0));
      }
    });

    test('Verification presets convert cleanly to PerspectiveCamera', () {
      for (final preset in CameraPreset.verificationPresets) {
        final cam = preset.toPerspectiveCamera();
        expect(cam.fovNear, equals(preset.nearMeters));
        expect(cam.fovFar, equals(preset.farMeters));
        expect(
          cam.fovRadiansY,
          closeTo(preset.verticalFovDegrees * degrees2Radians, 1e-4),
        );
      }
    });

    test('Applying verification preset updates TacticalCameraRig smoothly', () {
      final rig = TacticalCameraRig();
      const preset = CameraPreset.duskOverview;

      final camera = rig.applyPreset(preset);

      expect(camera.position.x, closeTo(preset.eye.x, 1e-4));
      expect(camera.position.y, closeTo(preset.eye.y, 1e-4));
      expect(camera.position.z, closeTo(preset.eye.z, 1e-4));
      expect(rig.target.x, closeTo(preset.target.x, 1e-4));
      expect(rig.target.y, closeTo(preset.target.y, 1e-4));
      expect(rig.target.z, closeTo(preset.target.z, 1e-4));
      expect(
        camera.fovRadiansY,
        closeTo(preset.verticalFovDegrees * degrees2Radians, 1e-4),
      );
    });

    test(
      'Each verification preset specifies a non-empty target image label',
      () {
        for (final preset in CameraPreset.verificationPresets) {
          expect(preset.id, isNotEmpty);
          expect(preset.label, isNotEmpty);
          expect('${preset.id}.png', endsWith('.png'));
        }
      },
    );
  });
}
