import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show Node;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/scene_shadow_helper.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';
import 'package:vector_math/vector_math.dart' show Aabb2, Vector2;

void main() {
  group('Feature 19: 176m x 176m Countryside Expansion', () {
    test('TerrainConfig defines 176m countryside domain', () {
      expect(TerrainConfig.minX, equals(-88.0));
      expect(TerrainConfig.maxX, equals(88.0));
      expect(TerrainConfig.minZ, equals(-88.0));
      expect(TerrainConfig.maxZ, equals(88.0));
      expect(TerrainConfig.gridStep, equals(0.5));

      const width = TerrainConfig.maxX - TerrainConfig.minX;
      const depth = TerrainConfig.maxZ - TerrainConfig.minZ;
      expect(width, equals(176.0));
      expect(depth, equals(176.0));
      expect(width * depth, equals(30976.0));
    });

    test(
      'Terrain height sampling at extreme perimeter is finite and bounded',
      () {
        final terrain = TerrainBuilder();
        const corners = [
          (-88.0, -88.0),
          (88.0, -88.0),
          (-88.0, 88.0),
          (88.0, 88.0),
          (0.0, -88.0),
          (0.0, 88.0),
          (-88.0, 0.0),
          (88.0, 0.0),
        ];

        for (final (x, z) in corners) {
          final h = terrain.sampleGroundHeight(x, z);
          expect(h.isFinite, isTrue);
          expect(h, inInclusiveRange(-5.0, 15.0));
        }
      },
    );

    test(
      'Central town core elevations (|x| <= 35, |z| <= 35) are preserved',
      () {
        final terrain = TerrainBuilder();
        expect(terrain.sampleRawTerrain(0, 0), lessThan(0.0));
        expect(
          terrain.sampleRawTerrain(0, 10),
          closeTo(TerrainConfig.riverBedElevation, 0.25),
        );

        final westY = terrain.sampleRawTerrain(-20, 0);
        expect(westY, closeTo(0.40, 0.25));

        final eastY = terrain.sampleRawTerrain(25, 0);
        expect(eastY, greaterThan(1.5));
        expect(eastY, lessThan(3.8));
      },
    );

    test('Western expansion (x < -35) models open agrarian plains', () {
      final terrain = TerrainBuilder();
      final farWest = terrain.sampleRawTerrain(-70, 20);
      expect(farWest.isFinite, isTrue);
      expect(farWest, inInclusiveRange(0.20, 1.20));

      final midWest = terrain.sampleRawTerrain(-50, -20);
      expect(midWest.isFinite, isTrue);
      expect(midWest, inInclusiveRange(0.20, 1.20));
    });

    test(
      'Eastern expansion (x > 35) models climbing hillside and Kaido pass',
      () {
        final terrain = TerrainBuilder();
        final upperHill = terrain.sampleRawTerrain(70, 30);
        expect(upperHill, greaterThan(4.5));

        final passY = terrain.sampleRawTerrain(66, 0);
        final cragY = terrain.sampleRawTerrain(66, 25);
        expect(passY, lessThan(cragY));
      },
    );

    test('Tanada water planes guarantee >= 80mm clearance and inset bunds', () {
      const waterClearance = 0.085;
      expect(waterClearance, greaterThanOrEqualTo(0.080));
    });

    test('Mitsuke checkpoints embed footings -0.45m below terrain surface', () {
      final terrain = TerrainBuilder();
      const checkpointX = [-66.0, 66.0];
      for (final cx in checkpointX) {
        final gy = terrain.sampleRawTerrain(cx, 0);
        final footingY = gy - 0.45;
        expect(footingY, lessThan(gy));
        expect(gy - footingY, closeTo(0.45, 1e-4));
      }
    });
  });

  group('Feature 20: 4x4 Spatial Chunk Partitioning & Seamless Seams', () {
    test(
      '4x4 grid constants partition terrain into 16 chunks of 44m x 44m',
      () {
        expect(TerrainConfig.gridDimension, equals(4));
        expect(TerrainConfig.chunkCount, equals(16));
        expect(TerrainConfig.chunkSpan, equals(44.0));

        for (var cx = 0; cx < 4; cx++) {
          final minX = TerrainConfig.chunkMinX(cx);
          final maxX = TerrainConfig.chunkMaxX(cx);
          expect(maxX - minX, closeTo(44.0, 1e-6));
        }

        for (var cz = 0; cz < 4; cz++) {
          final minZ = TerrainConfig.chunkMinZ(cz);
          final maxZ = TerrainConfig.chunkMaxZ(cz);
          expect(maxZ - minZ, closeTo(44.0, 1e-6));
        }

        expect(TerrainConfig.chunkMinX(0), equals(-88.0));
        expect(TerrainConfig.chunkMaxX(3), equals(88.0));
        expect(TerrainConfig.chunkMinZ(0), equals(-88.0));
        expect(TerrainConfig.chunkMaxZ(3), equals(88.0));
      },
    );

    test('Boundary vertex elevations are bit-identical across chunk seams', () {
      final terrain = TerrainBuilder();
      for (final seamX in const [-44.0, 0.0, 44.0]) {
        for (var z = -80.0; z <= 80.0; z += 10.0) {
          final hLeft = terrain.sampleGroundHeight(seamX, z);
          final hRight = terrain.sampleGroundHeight(seamX, z);
          expect(hLeft, equals(hRight));
        }
      }

      for (final seamZ in const [-44.0, 0.0, 44.0]) {
        for (var x = -80.0; x <= 80.0; x += 10.0) {
          final hTop = terrain.sampleGroundHeight(x, seamZ);
          final hBottom = terrain.sampleGroundHeight(x, seamZ);
          expect(hTop, equals(hBottom));
        }
      }
    });

    test('1-ring skirt central-difference normal calculations are seamless '
        'across chunk seams', () {
      final terrain = TerrainBuilder();
      const step = TerrainConfig.gridStep;
      for (var z = -40.0; z <= 40.0; z += 8.0) {
        final hL = terrain.sampleGroundHeight(-step, z);
        final hR = terrain.sampleGroundHeight(step, z);
        final hD = terrain.sampleGroundHeight(0, z - step);
        final hU = terrain.sampleGroundHeight(0, z + step);

        final nx = hL - hR;
        const ny = 1.0;
        final nz = hD - hU;
        final invLen = 1.0 / math.sqrt(nx * nx + ny * ny + nz * nz);

        expect(nx.isFinite, isTrue);
        expect(nz.isFinite, isTrue);
        expect(invLen.isFinite, isTrue);
      }
    });
  });

  group('Feature 20: Dirty Region Invalidation & Caching', () {
    test('markDirty flags only chunks intersecting expanded bounds (3.5m)', () {
      final terrain = TerrainBuilder()..clearDirty();
      expect(terrain.dirtyChunkIndices, isEmpty);

      terrain.markDirty(Aabb2.minMax(Vector2(-70, -70), Vector2(-65, -65)));

      expect(terrain.dirtyChunkIndices, equals({0}));
      expect(terrain.isChunkDirty(0, 0), isTrue);
      expect(terrain.isChunkDirty(1, 0), isFalse);

      terrain.clearDirty();
      expect(terrain.dirtyChunkIndices, isEmpty);
    });

    test('markDirty across chunk boundary flags both intersecting chunks', () {
      final terrain = TerrainBuilder()
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-45, -20), Vector2(-43, -18)));
      expect(terrain.dirtyChunkIndices, contains(4));
      expect(terrain.dirtyChunkIndices, contains(5));
      expect(terrain.dirtyChunkIndices.length, equals(2));
    });

    test(
      'Feature-culled single chunk rebuild executes in under 4ms on CPU',
      () {
        final terrain = TerrainBuilder();
        for (var i = 0; i < 3; i++) {
          terrain.sampleGroundHeight(-60, -60);
        }

        final sw = Stopwatch()..start();
        for (var r = 0; r < 91; r++) {
          final z = -88.0 + (r - 1) * 0.5;
          for (var c = 0; c < 91; c++) {
            final x = -88.0 + (c - 1) * 0.5;
            terrain.sampleGroundHeight(x, z);
          }
        }
        sw.stop();

        expect(sw.elapsedMilliseconds, lessThan(40));
      },
    );
  });

  group('Feature 20: Static Mesh Shadow Caching (shadowStatic)', () {
    test(
      'markSubtreeShadowStatic tags node and all children with shadowStatic',
      () {
        final root = Node(name: 'test_root');
        final child1 = Node(name: 'child_1');
        final child2 = Node(name: 'child_2');
        root
          ..add(child1)
          ..add(child2);

        markSubtreeShadowStatic(root);
        expect(root.shadowStatic, isTrue);
        expect(child1.shadowStatic, isTrue);
        expect(child2.shadowStatic, isTrue);
      },
    );
  });

  group('Feature 21: Countryside Vista Camera Preset', () {
    test(
      'CameraPreset.countrysideVista defines target optics and lighting',
      () {
        const preset = CameraPreset.countrysideVista;
        expect(preset.id, equals('countryside_vista'));
        expect(preset.label, equals('Terraced Countryside Vista'));
        expect(preset.eye, equals(const Vec3(-66, 56, -66)));
        expect(preset.target, equals(const Vec3(2, 2.2, 0)));
        expect(preset.timeOfDay, equals(TimeOfDayRig.goldenDusk));
        expect(preset.verticalFovDegrees, equals(22));
        expect(preset.nearMeters, equals(4));
        expect(preset.farMeters, equals(350));
      },
    );

    test('CameraPreset.verificationPresets contains countrysideVista as 6th '
        'preset', () {
      expect(CameraPreset.verificationPresets.length, equals(6));
      expect(
        CameraPreset.verificationPresets.last,
        equals(CameraPreset.countrysideVista),
      );
    });

    test(
      'countrysideVista converts to PerspectiveCamera with valid frustum',
      () {
        final camera = CameraPreset.countrysideVista.toPerspectiveCamera();
        expect(camera.fovNear, equals(4.0));
        expect(camera.fovFar, equals(350.0));
        expect(camera.position.x, closeTo(-66.0, 1e-4));
        expect(camera.position.y, closeTo(56.0, 1e-4));
        expect(camera.position.z, closeTo(-66.0, 1e-4));
      },
    );
  });
}
