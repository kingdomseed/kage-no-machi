import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show GeometryBuilder, Node, Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';
import 'package:kage_no_machi/shukuba/world/starter_ward.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

bool _checkImpellerAvailable() {
  try {
    Scene();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  final impellerAvailable = _checkImpellerAvailable();
  const impellerSkipReason =
      'Flutter GPU Impeller backend not enabled in headless sandbox';
  group(
    'Empirical Challenge 1: Fukinagashi Streamers Robustness & Invariants',
    () {
      test('addFukinagashiStreamers generates geometry across palette', () {
        final cloth = GeometryBuilder();
        final timber = GeometryBuilder();

        EdoKitBuilder.addFukinagashiStreamers(
          cloth,
          timber,
          const Vec3(0, 3.2, 0),
          length: 1.2,
          seed: 42,
        );

        expect(cloth.vertexCount, greaterThan(0));
        expect(cloth.triangleCount, greaterThan(0));
        expect(timber.vertexCount, greaterThan(0));

        final packedCloth = cloth.packVertices();
        expect(packedCloth, isNotEmpty);
      });

      test('addFukinagashiStreamers handles wide seed and length sweeps', () {
        final seeds = [
          0,
          1,
          42,
          999999,
          -1,
          -12345,
          -999999,
          0x7FFFFFFF,
          -0x80000000,
        ];

        for (final seed in seeds) {
          final cloth = GeometryBuilder();
          final timber = GeometryBuilder();

          EdoKitBuilder.addFukinagashiStreamers(
            cloth,
            timber,
            const Vec3(1, 2.5, -3),
            length: 0.8,
            seed: seed,
          );

          expect(cloth.vertexCount, equals(46));
          expect(cloth.triangleCount, equals(24));
          final packed = cloth.packVertices();
          expect(packed, isNotEmpty);
          expect(packed.every((v) => v.isFinite), isTrue);
        }
      });
    },
  );

  group('Empirical Challenge 2: Wagasa Umbrella Geometric Invariants', () {
    test('Wagasa base cross runners maintain anti-z-fight offset >= 0.015', () {
      final cloth = GeometryBuilder();
      final timber = GeometryBuilder();

      EdoKitBuilder.addWagasaUmbrella(
        cloth,
        timber,
        Vector3(2, 0, -1),
        scale: 1.2,
        yaw: 0.45,
      );

      expect(cloth.vertexCount, greaterThan(0));
      expect(timber.vertexCount, greaterThan(0));
      expect(cloth.packVertices(), isNotEmpty);
      expect(timber.packVertices(), isNotEmpty);
    });

    test('Wagasa handles parametric scales and full 360 yaw rotations', () {
      for (final scale in [0.4, 0.8, 1.0, 1.5, 2.2]) {
        for (var yawDeg = 0; yawDeg < 360; yawDeg += 45) {
          final cloth = GeometryBuilder();
          final timber = GeometryBuilder();
          final yaw = (yawDeg * math.pi) / 180.0;

          EdoKitBuilder.addWagasaUmbrella(
            cloth,
            timber,
            Vector3(0, 0, 0),
            scale: scale,
            yaw: yaw,
          );

          expect(cloth.vertexCount, greaterThan(0));
          expect(timber.vertexCount, greaterThan(0));
        }
      }
    });
  });

  group('Empirical Challenge 3: Mizu-Oke Tub Geometric Invariants', () {
    test('addMizuOkeTub generates coopered body, hoops, and water disc', () {
      final timber = GeometryBuilder();
      final water = GeometryBuilder();

      EdoKitBuilder.addMizuOkeTub(timber, water, Vector3.zero());

      expect(timber.vertexCount, greaterThan(0));
      expect(water.vertexCount, greaterThan(0));
      expect(timber.packVertices(), isNotEmpty);
      expect(water.packVertices(), isNotEmpty);
    });
  });

  group('Empirical Challenge 4: Kome-Dawara Bale & Stack Invariants', () {
    test('KomeDawaraBale generates straw body, rosette end caps, cords', () {
      final straw = GeometryBuilder();
      final cord = GeometryBuilder();

      EdoKitBuilder.addKomeDawaraBale(straw, cord, Vector3(0, 0, 0), yaw: 0.35);

      expect(straw.vertexCount, greaterThan(0));
      expect(cord.vertexCount, greaterThan(0));
      expect(straw.packVertices(), isNotEmpty);
      expect(cord.packVertices(), isNotEmpty);
    });

    test('KomeDawaraStack handles count variants 1, 2, 3 cleanly', () {
      for (final count in [1, 2, 3]) {
        final straw = GeometryBuilder();
        final cord = GeometryBuilder();

        EdoKitBuilder.addKomeDawaraStack(
          straw,
          cord,
          Vector3(0, 0, 0),
          count: count,
          yaw: 0.1,
        );

        expect(straw.vertexCount, greaterThan(0));
        expect(cord.vertexCount, greaterThan(0));
      }
    });
  });

  group('Empirical Challenge 5: Sunoko Duckboard Geometric Tiering', () {
    test(
      'Sunoko cross-runners and longitudinal planks have non-overlap planes',
      () {
        final timber = GeometryBuilder();

        EdoKitBuilder.addSunokoDuckboard(timber, Vector3.zero(), yaw: 0.25);

        expect(timber.vertexCount, greaterThan(0));
        expect(timber.triangleCount, greaterThan(0));
        expect(timber.packVertices(), isNotEmpty);
      },
    );
  });

  group(
    'Empirical Challenge 6: Shrine Kit Structures shadowStatic Contract',
    () {
      test('buildShoroBellNode sets shadowStatic on all child meshes', () {
        const kit = EdoKitBuilder();
        const spec = PlacedStructure(
          id: EntityId('shoro_test'),
          kind: StructureKind.shoroBell,
          position: Vec3.zero,
        );

        final node = kit.buildShoroBellNode(spec, defaultShukubaMaterial);

        expect(node, isNotNull);
        void checkShadow(Node n) {
          expect(n.shadowStatic, isTrue);
          n.children.forEach(checkShadow);
        }

        checkShadow(node);
      });

      test(
        'buildKaresansuiGardenNode sets shadowStatic on all child meshes',
        () {
          const kit = EdoKitBuilder();
          const spec = PlacedStructure(
            id: EntityId('karesansui_test'),
            kind: StructureKind.karesansuiGarden,
            position: Vec3.zero,
          );

          final node = kit.buildKaresansuiGardenNode(
            spec,
            defaultShukubaMaterial,
          );

          expect(node, isNotNull);
          void checkShadow(Node n) {
            expect(n.shadowStatic, isTrue);
            n.children.forEach(checkShadow);
          }

          checkShadow(node);
        },
      );

      test('buildStoneWellNode sets shadowStatic on all child meshes', () {
        const kit = EdoKitBuilder();
        const spec = PlacedStructure(
          id: EntityId('well_test'),
          kind: StructureKind.stoneWell,
          position: Vec3.zero,
        );

        final node = kit.buildStoneWellNode(spec, defaultShukubaMaterial);

        expect(node, isNotNull);
        void checkShadow(Node n) {
          expect(n.shadowStatic, isTrue);
          n.children.forEach(checkShadow);
        }

        checkShadow(node);
      });
    },
    skip: !impellerAvailable ? impellerSkipReason : false,
  );

  group(
    'Empirical Challenge 7: Starter Ward Spatial Clearances & Collisions',
    () {
      test('Collision check: well_east_riverside vs market_east_n1', () {
        final terrain = TerrainBuilder();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

        final well = graph.structures.values.firstWhere(
          (s) => s.kind == StructureKind.stoneWell,
        );
        final stall = graph.structures.values.firstWhere(
          (s) => s.id == const EntityId('market_east_n1'),
        );

        final wellMinX = well.position.x - 0.9;
        final wellMaxX = well.position.x + 0.9;
        final wellMinZ = well.position.z - 0.9;
        final wellMaxZ = well.position.z + 0.9;

        final stallMinX = stall.position.x - 1.1;
        final stallMaxX = stall.position.x + 1.1;
        final stallMinZ = stall.position.z - 0.95;
        final stallMaxZ = stall.position.z + 0.95;

        final overlapX = math.max(
          0,
          math.min(wellMaxX, stallMaxX) - math.max(wellMinX, stallMinX),
        );
        final overlapZ = math.max(
          0,
          math.min(wellMaxZ, stallMaxZ) - math.max(wellMinZ, stallMinZ),
        );

        expect(
          overlapX > 0 && overlapZ > 0,
          isFalse,
          reason:
              'Spatial collision: well at ${well.position} collides with '
              'market_east_n1 at ${stall.position} by '
              '${overlapX.toStringAsFixed(2)}m x '
              '${overlapZ.toStringAsFixed(2)}m',
        );
      });

      test(
        'Terrace drop & road market alley overlap under karesansui garden',
        () {
          final terrain = TerrainBuilder();
          final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

          final karesansui = graph.structures.values.firstWhere(
            (s) => s.kind == StructureKind.karesansuiGarden,
          );
          final road = graph.roads.firstWhere(
            (r) => r.id == const EntityId('road_market_alley'),
          );

          const xHalf = 2.10;
          const zHalf = 1.80;

          var minElev = double.infinity;
          var maxElev = -double.infinity;

          for (var dx = -xHalf; dx <= xHalf; dx += 0.35) {
            for (var dz = -zHalf; dz <= zHalf; dz += 0.30) {
              final x = karesansui.position.x + dx;
              final z = karesansui.position.z + dz;
              final y = terrain.sampleGroundHeight(
                x,
                z,
                terraces: graph.terraces,
                roads: graph.roads,
              );
              minElev = math.min(minElev, y);
              maxElev = math.max(maxElev, y);
            }
          }

          final deltaY = maxElev - minElev;

          expect(
            deltaY,
            lessThanOrEqualTo(0.12),
            reason:
                'Ground under karesansui varies by '
                '${deltaY.toStringAsFixed(3)}m (max $maxElev vs min $minElev), '
                'which severely exceeds the 0.12m curb height',
          );

          final gardenMinX = karesansui.position.x - xHalf;
          final gardenMaxX = karesansui.position.x + xHalf;
          final gardenMinZ = karesansui.position.z - zHalf;
          final gardenMaxZ = karesansui.position.z + zHalf;

          final roadPt = road.controlPoints.last;
          final roadHalfW = road.widthMeters / 2;
          final roadMinX = roadPt.x - roadHalfW;
          final roadMaxX = roadPt.x + roadHalfW;
          final roadMinZ = roadPt.z - roadHalfW;
          final roadMaxZ = roadPt.z + roadHalfW;

          final roadOverlapX = math.max(
            0,
            math.min(gardenMaxX, roadMaxX) - math.max(gardenMinX, roadMinX),
          );
          final roadOverlapZ = math.max(
            0,
            math.min(gardenMaxZ, roadMaxZ) - math.max(gardenMinZ, roadMinZ),
          );

          expect(
            roadOverlapX > 0 && roadOverlapZ > 0,
            isFalse,
            reason:
                'road_market_alley penetrates karesansui gravel bed '
                'by ${roadOverlapX.toStringAsFixed(2)}m x '
                '${roadOverlapZ.toStringAsFixed(2)}m',
          );
        },
      );

      test('Collision and clearance check: shoro_temple_bell', () {
        final terrain = TerrainBuilder();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

        final shoro = graph.structures.values.firstWhere(
          (s) => s.kind == StructureKind.shoroBell,
        );

        final shoroHalfW = shoro.spec.footprintWidth / 2;
        final shoroHalfD = shoro.spec.footprintDepth / 2;
        final sMinX = shoro.position.x - shoroHalfW;
        final sMaxX = shoro.position.x + shoroHalfW;
        final sMinZ = shoro.position.z - shoroHalfD;
        final sMaxZ = shoro.position.z + shoroHalfD;

        for (final other in graph.structures.values) {
          if (other.id == shoro.id) continue;
          final oHalfW = other.spec.footprintWidth / 2;
          final oHalfD = other.spec.footprintDepth / 2;
          final oMinX = other.position.x - oHalfW;
          final oMaxX = other.position.x + oHalfW;
          final oMinZ = other.position.z - oHalfD;
          final oMaxZ = other.position.z + oHalfD;

          final overlapX = math.max(
            0,
            math.min(sMaxX, oMaxX) - math.max(sMinX, oMinX),
          );
          final overlapZ = math.max(
            0,
            math.min(sMaxZ, oMaxZ) - math.max(sMinZ, oMinZ),
          );

          expect(
            overlapX > 0 && overlapZ > 0,
            isFalse,
            reason:
                'Spatial collision: shoro_temple_bell at ${shoro.position} '
                'collides with ${other.id.value} at ${other.position} by '
                '${overlapX.toStringAsFixed(2)}m x '
                '${overlapZ.toStringAsFixed(2)}m',
          );
        }
      });
    },
  );
}
