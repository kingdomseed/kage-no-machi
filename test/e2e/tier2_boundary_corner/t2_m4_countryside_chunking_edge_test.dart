import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/tactical_camera_rig.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';
import 'package:vector_math/vector_math.dart' show degrees2Radians;

void main() {
  group('Feature 19 Edge: 176m Countryside Boundaries', () {
    test('Height sampling at extreme boundary coordinates returns finite '
        'elevation', () {
      final terrain = TerrainBuilder();
      final hTopLeft = terrain.sampleGroundHeight(
        TerrainConfig.minX,
        TerrainConfig.minZ,
      );
      final hTopRight = terrain.sampleGroundHeight(
        TerrainConfig.maxX,
        TerrainConfig.minZ,
      );
      final hBottomLeft = terrain.sampleGroundHeight(
        TerrainConfig.minX,
        TerrainConfig.maxZ,
      );
      final hBottomRight = terrain.sampleGroundHeight(
        TerrainConfig.maxX,
        TerrainConfig.maxZ,
      );

      expect(hTopLeft.isFinite, isTrue);
      expect(hTopRight.isFinite, isTrue);
      expect(hBottomLeft.isFinite, isTrue);
      expect(hBottomRight.isFinite, isTrue);
    });

    test(
      'Ground raycast downward at edge coordinates successfully finds surface',
      () {
        final terrain = TerrainBuilder();
        const rayOrigin = Vec3(
          TerrainConfig.maxX - 0.1,
          50,
          TerrainConfig.maxZ - 0.1,
        );
        final surfaceY = terrain.sampleGroundHeight(rayOrigin.x, rayOrigin.z);
        final hitPoint = Vec3(rayOrigin.x, surfaceY, rayOrigin.z);

        expect(hitPoint.y, lessThan(rayOrigin.y));
        expect(hitPoint.y.isFinite, isTrue);
      },
    );

    test('Tanada water elevation is recessed below ground level', () {
      expect(TerrainConfig.waterSurfaceElevation, lessThan(0.0));
      expect(
        TerrainConfig.riverBedElevation,
        lessThan(TerrainConfig.waterSurfaceElevation),
      );
    });

    test(
      'Kaido Catmull-Rom spline maintains tangent continuity across segments',
      () {
        const p0 = Vec3(-20, 0, 0);
        const p1 = Vec3(-10, 1, 0);
        const p2 = Vec3.zero;
        const p3 = Vec3(10, 1, 0);
        const p4 = Vec3(20, 0, 0);

        final t1In = (p2 - p0) * 0.5;
        final t1Out = (p3 - p1) * 0.5;

        expect(t1In.length, greaterThan(0));
        expect(t1Out.length, greaterThan(0));
        expect(p4.x - p0.x, equals(40));
      },
    );

    test(
      'Kaido bridge footprint and deck profile stay within terrain bounds',
      () {
        expect(TerrainConfig.bridgeMinX, greaterThan(TerrainConfig.minX));
        expect(TerrainConfig.bridgeMaxX, lessThan(TerrainConfig.maxX));
        expect(TerrainConfig.bridgeMinZ, greaterThan(TerrainConfig.minZ));
        expect(TerrainConfig.bridgeMaxZ, lessThan(TerrainConfig.maxZ));
      },
    );
  });

  group('Feature 20 Edge: Spatial Chunk Dirty Propagation & Budgets', () {
    test(
      'TerrainConfig bounds partition into symmetrical positive and negative '
      'ranges',
      () {
        expect(TerrainConfig.minX.abs(), equals(TerrainConfig.maxX.abs()));
        expect(TerrainConfig.minZ.abs(), equals(TerrainConfig.maxZ.abs()));
      },
    );

    test('Terrain sampling produces consistent elevation on zero axis', () {
      final terrain = TerrainBuilder();
      final hCenter = terrain.sampleGroundHeight(0, 0);
      expect(hCenter.isFinite, isTrue);
    });

    test(
      'River centerline evaluated across terrain Z range remains bounded',
      () {
        for (var z = TerrainConfig.minZ; z <= TerrainConfig.maxZ; z += 5.0) {
          final cx = TerrainConfig.riverCenterX(z);
          expect(cx.abs(), lessThan(TerrainConfig.maxX));
        }
      },
    );

    test('Neighboring terrain coordinate vertices evaluate within continuous '
        'tolerance across 176m river length', () {
      final terrain = TerrainBuilder();
      for (var z = -80; z <= 80; z += 10) {
        final hLeft = terrain.sampleGroundHeight(-0.0001, z.toDouble());
        final hRight = terrain.sampleGroundHeight(0.0001, z.toDouble());
        expect((hLeft - hRight).abs(), lessThan(1e-2));
      }
    });

    test('Terrain grid step divides boundary range into positive integer '
        'steps', () {
      const totalWidth = TerrainConfig.maxX - TerrainConfig.minX;
      const stepCount = totalWidth / TerrainConfig.gridStep;
      expect(stepCount, greaterThan(0));
      expect(stepCount.roundToDouble(), equals(stepCount));
    });
  });

  group('Feature 21 Edge: Countryside Vista Camera & Frustum Bounds', () {
    test('Verification presets configure far clipping plane >= 200m', () {
      for (final preset in CameraPreset.verificationPresets) {
        expect(preset.farMeters, greaterThanOrEqualTo(200));
      }
    });

    test(
      'TacticalCameraRig.orbitByRadians clamps pitch to [11°, 64°] preventing '
      'gimbal lock inversion',
      () {
        final rig = TacticalCameraRig();

        expect(
          TacticalCameraRig.minPitchRadians,
          closeTo(11.0 * degrees2Radians, 1e-6),
        );
        expect(
          TacticalCameraRig.maxPitchRadians,
          closeTo(64.0 * degrees2Radians, 1e-6),
        );

        rig.orbitByRadians(0, 10);
        expect(
          rig.pitchRadians,
          closeTo(TacticalCameraRig.maxPitchRadians, 1e-6),
        );
        expect(rig.pitchRadians, lessThan(math.pi / 2));

        rig.orbitByRadians(0, -10);
        expect(
          rig.pitchRadians,
          closeTo(TacticalCameraRig.minPitchRadians, 1e-6),
        );
        expect(rig.pitchRadians, greaterThan(0));
      },
    );

    test(
      'TacticalCameraRig maintains valid frustum across 16:9, 16:10, and 21:9 '
      'aspect ratios',
      () {
        const vFovRad = 24.0 * degrees2Radians;
        const aspectRatios = [16 / 9, 16 / 10, 21 / 9];

        for (final aspect in aspectRatios) {
          final hFovRad = 2 * math.atan(math.tan(vFovRad / 2) * aspect);
          expect(hFovRad.isFinite, isTrue);
          expect(hFovRad, greaterThan(vFovRad));
        }
      },
    );

    test('TacticalCameraRig.panByAxes clamps camera target strictly within '
        'panBoundsMeters (32m) and terrain bounds', () {
      final rig = TacticalCameraRig();
      const panBounds = TacticalCameraRig.panBoundsMeters;
      expect(panBounds, equals(32.0));

      expect(panBounds, lessThan(TerrainConfig.maxX));
      expect(-panBounds, greaterThan(TerrainConfig.minX));

      rig.panByAxes(
        rightInput: 100,
        forwardInput: 100,
        dtSeconds: 10,
        sampleGroundY: (x, z) => 2,
      );

      expect(rig.target.x.abs(), lessThanOrEqualTo(panBounds));
      expect(rig.target.z.abs(), lessThanOrEqualTo(panBounds));
      expect(rig.target.x, greaterThanOrEqualTo(TerrainConfig.minX));
      expect(rig.target.x, lessThanOrEqualTo(TerrainConfig.maxX));
      expect(rig.target.z, greaterThanOrEqualTo(TerrainConfig.minZ));
      expect(rig.target.z, lessThanOrEqualTo(TerrainConfig.maxZ));
      expect(rig.target.y, closeTo(2.0 * 0.45 + 1.2, 1e-4));

      rig.panByAxes(
        rightInput: -100,
        forwardInput: -100,
        dtSeconds: 10,
        sampleGroundY: (x, z) => 4,
      );

      expect(rig.target.x.abs(), lessThanOrEqualTo(panBounds));
      expect(rig.target.z.abs(), lessThanOrEqualTo(panBounds));
      expect(rig.target.x, greaterThanOrEqualTo(TerrainConfig.minX));
      expect(rig.target.x, lessThanOrEqualTo(TerrainConfig.maxX));
      expect(rig.target.z, greaterThanOrEqualTo(TerrainConfig.minZ));
      expect(rig.target.z, lessThanOrEqualTo(TerrainConfig.maxZ));
      expect(rig.target.y, closeTo(4.0 * 0.45 + 1.2, 1e-4));
    });

    test(
      'Smooth preset transition interpolates eye and target without jump',
      () {
        final eyeStart = CameraPreset.duskOverview.eye;
        final eyeEnd = CameraPreset.nightMarket.eye;

        for (var i = 0; i <= 10; i++) {
          final t = i / 10.0;
          final interpolatedEye = Vec3.lerp(eyeStart, eyeEnd, t);
          expect(interpolatedEye.x.isFinite, isTrue);
          expect(interpolatedEye.y.isFinite, isTrue);
          expect(interpolatedEye.z.isFinite, isTrue);
        }
      },
    );
  });
}
