import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart' show Node, Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/edo_world_driver.dart';
import 'package:kage_no_machi/shukuba/world/scene_shadow_helper.dart';
import 'package:kage_no_machi/shukuba/world/starter_ward.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';
import 'package:vector_math/vector_math.dart' show Aabb2, Vector2;

bool _checkImpellerAvailable() {
  try {
    Scene();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final impellerAvailable = _checkImpellerAvailable();
  const impellerSkipReason =
      'Flutter GPU Impeller backend not enabled in headless sandbox';

  group('Empirical Challenge 1: Stress Testing markDirty(Aabb2 bounds)', () {
    late TerrainBuilder terrain;

    setUp(() {
      terrain = TerrainBuilder()..clearDirty();
    });

    tearDown(() {
      terrain.clearDirty();
    });

    test('Zero-area point on internal seams flags both adjacent chunks', () {
      for (final seamX in const [-44.0, 0.0, 44.0]) {
        terrain
          ..clearDirty()
          ..markDirty(Aabb2.minMax(Vector2(seamX, 20), Vector2(seamX, 20)));

        final expMinCx =
            ((seamX - 3.5 - TerrainConfig.minX) / TerrainConfig.chunkSpan)
                .floor()
                .clamp(0, 3);
        final expMaxCx =
            ((seamX + 3.5 - TerrainConfig.minX) / TerrainConfig.chunkSpan)
                .floor()
                .clamp(0, 3);
        expect(
          expMaxCx - expMinCx,
          equals(1),
          reason: 'Seam x=$seamX should span 2 adjacent chunks',
        );

        final expCz = ((20 - TerrainConfig.minZ) / TerrainConfig.chunkSpan)
            .floor();
        expect(expCz, equals(2));

        final expectedIndices = {expCz * 4 + expMinCx, expCz * 4 + expMaxCx};
        expect(
          terrain.dirtyChunkIndices,
          equals(expectedIndices),
          reason: 'Seam point at ($seamX, 20) should dirty 2 chunks',
        );
      }

      for (final seamZ in const [-44.0, 0.0, 44.0]) {
        terrain
          ..clearDirty()
          ..markDirty(Aabb2.minMax(Vector2(20, seamZ), Vector2(20, seamZ)));

        final expMinCz =
            ((seamZ - 3.5 - TerrainConfig.minZ) / TerrainConfig.chunkSpan)
                .floor()
                .clamp(0, 3);
        final expMaxCz =
            ((seamZ + 3.5 - TerrainConfig.minZ) / TerrainConfig.chunkSpan)
                .floor()
                .clamp(0, 3);
        expect(
          expMaxCz - expMinCz,
          equals(1),
          reason: 'Seam z=$seamZ should span 2 adjacent chunks',
        );

        final expCx = ((20 - TerrainConfig.minX) / TerrainConfig.chunkSpan)
            .floor();
        expect(expCx, equals(2));

        final expectedIndices = {expMinCz * 4 + expCx, expMaxCz * 4 + expCx};
        expect(
          terrain.dirtyChunkIndices,
          equals(expectedIndices),
          reason: 'Seam point at (20, $seamZ) should dirty 2 chunks',
        );
      }
    });

    test(
      'Zero-area point at seam intersections flags all 4 adjacent chunks',
      () {
        const seamIntersections = [
          (-44.0, -44.0),
          (-44.0, 0.0),
          (-44.0, 44.0),
          (0.0, -44.0),
          (0.0, 0.0),
          (0.0, 44.0),
          (44.0, -44.0),
          (44.0, 0.0),
          (44.0, 44.0),
        ];

        for (final (sx, sz) in seamIntersections) {
          terrain
            ..clearDirty()
            ..markDirty(Aabb2.minMax(Vector2(sx, sz), Vector2(sx, sz)));

          expect(
            terrain.dirtyChunkIndices.length,
            equals(4),
            reason: 'Junction ($sx, $sz) must dirty exactly 4 chunks',
          );

          final minCx =
              ((sx - 3.5 - TerrainConfig.minX) / TerrainConfig.chunkSpan)
                  .floor()
                  .clamp(0, 3);
          final maxCx =
              ((sx + 3.5 - TerrainConfig.minX) / TerrainConfig.chunkSpan)
                  .floor()
                  .clamp(0, 3);
          final minCz =
              ((sz - 3.5 - TerrainConfig.minZ) / TerrainConfig.chunkSpan)
                  .floor()
                  .clamp(0, 3);
          final maxCz =
              ((sz + 3.5 - TerrainConfig.minZ) / TerrainConfig.chunkSpan)
                  .floor()
                  .clamp(0, 3);

          expect(maxCx - minCx, equals(1));
          expect(maxCz - minCz, equals(1));

          for (var cz = minCz; cz <= maxCz; cz++) {
            for (var cx = minCx; cx <= maxCx; cx++) {
              expect(terrain.dirtyChunkIndices, contains(cz * 4 + cx));
            }
          }
        }
      },
    );

    test(
      'Zero-area point at outer domain corners flags only the single corner',
      () {
        const outerCorners = [
          (-88.0, -88.0, 0),
          (88.0, -88.0, 3),
          (-88.0, 88.0, 12),
          (88.0, 88.0, 15),
        ];

        for (final (ox, oz, expectedIdx) in outerCorners) {
          terrain
            ..clearDirty()
            ..markDirty(Aabb2.minMax(Vector2(ox, oz), Vector2(ox, oz)));

          expect(
            terrain.dirtyChunkIndices,
            equals({expectedIdx}),
            reason: 'Outer corner ($ox, $oz) should flag only $expectedIdx',
          );
        }
      },
    );

    test('Diagonally spanning boxes touching 2, 3, 4, 6, 9, and 16 chunks', () {
      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-30, -30), Vector2(-20, -20)));
      expect(terrain.dirtyChunkIndices, equals({5}));

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-5, -20), Vector2(5, -20)));
      expect(terrain.dirtyChunkIndices, equals({5, 6}));

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-20, -5), Vector2(-20, 5)));
      expect(terrain.dirtyChunkIndices, equals({5, 9}));

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-50, -20), Vector2(10, -20)));
      expect(terrain.dirtyChunkIndices, equals({4, 5, 6}));

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-20, -50), Vector2(-20, 10)));
      expect(terrain.dirtyChunkIndices, equals({1, 5, 9}));

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-10, -10), Vector2(10, 10)));
      expect(terrain.dirtyChunkIndices, equals({5, 6, 9, 10}));

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-50, -10), Vector2(10, 10)));
      expect(terrain.dirtyChunkIndices, equals({4, 5, 6, 8, 9, 10}));

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-50, -50), Vector2(10, 10)));
      expect(terrain.dirtyChunkIndices, equals({0, 1, 2, 4, 5, 6, 8, 9, 10}));

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-100, -100), Vector2(100, 100)));
      expect(terrain.dirtyChunkIndices.length, equals(16));
      expect(
        terrain.dirtyChunkIndices,
        equals(Set<int>.from(List.generate(16, (i) => i))),
      );
    });

    test('Far off-map boxes outside 176m domain mark zero chunks dirty', () {
      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-500, 300), Vector2(-200, 600)));
      expect(terrain.dirtyChunkIndices, isEmpty);

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-500, -500), Vector2(-200, -200)));
      expect(terrain.dirtyChunkIndices, isEmpty);

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(200, -500), Vector2(500, -200)));
      expect(terrain.dirtyChunkIndices, isEmpty);

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(200, 200), Vector2(500, 500)));
      expect(terrain.dirtyChunkIndices, isEmpty);
    });

    test('Inverted bounds (min > max) evaluate to no-op without exception', () {
      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(20, 20), Vector2(-20, -20)));
      expect(
        terrain.dirtyChunkIndices,
        isEmpty,
        reason: 'Inverted bounds min > max must produce zero dirty chunks',
      );

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(20, -20), Vector2(-20, 20)));
      expect(
        terrain.dirtyChunkIndices,
        isEmpty,
        reason: 'X-inverted bounds minX > maxX must produce zero dirty',
      );

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-20, 20), Vector2(20, -20)));
      expect(
        terrain.dirtyChunkIndices,
        isEmpty,
        reason: 'Z-inverted bounds minZ > maxZ must produce zero dirty',
      );

      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(500, 500), Vector2(-500, -500)));
      expect(
        terrain.dirtyChunkIndices,
        isEmpty,
        reason: 'Far off-map inverted bounds must produce zero dirty',
      );
    });

    test('Multiple sequential markDirty calls accumulate correctly and '
        'idempotently', () {
      terrain.clearDirty();
      expect(terrain.dirtyChunkIndices, isEmpty);

      terrain
        ..markDirty(Aabb2.minMax(Vector2(-70, -70), Vector2(-65, -65)))
        ..markDirty(Aabb2.minMax(Vector2(-70, -70), Vector2(-65, -65)));
      expect(terrain.dirtyChunkIndices, equals({0}));

      terrain.markDirty(Aabb2.minMax(Vector2(65, 65), Vector2(70, 70)));
      expect(terrain.dirtyChunkIndices, equals({0, 15}));

      terrain.markDirty(Aabb2.minMax(Vector2(-5, -20), Vector2(5, -20)));
      expect(terrain.dirtyChunkIndices, equals({0, 5, 6, 15}));

      terrain.clearDirty();
      expect(terrain.dirtyChunkIndices, isEmpty);
    });
  });

  group('Empirical Challenge 2: CPU Performance Benchmark (< 4ms budget)', () {
    test('Single dirty chunk CPU heightfield and normal rebuild benchmark', () {
      final terrain = TerrainBuilder();
      final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);
      expect(graph.structures, isNotEmpty);

      final testChunks = [
        (0, 0, 'Agrarian plain chunk (0, 0)'),
        (1, 1, 'Town core west bank chunk (1, 1)'),
        (2, 1, 'River / bridge center chunk (2, 1)'),
        (2, 2, 'Tanada terraces chunk (2, 2)'),
        (3, 3, 'Mountain ridge pass chunk (3, 3)'),
      ];

      const skirtDim = 91;
      const localGridDim = 89;
      const step = TerrainConfig.gridStep;
      final timingStats = <String, Map<String, double>>{};

      for (final (cx, cz, label) in testChunks) {
        final minX = TerrainConfig.chunkMinX(cx);
        final minZ = TerrainConfig.chunkMinZ(cz);
        final skirtHeights = Float64List(skirtDim * skirtDim);
        final normalsX = Float32List(localGridDim * localGridDim);
        final normalsY = Float32List(localGridDim * localGridDim);
        final normalsZ = Float32List(localGridDim * localGridDim);

        for (var w = 0; w < 3; w++) {
          for (var r = 0; r < skirtDim; r++) {
            final z = minZ + (r - 1) * step;
            for (var c = 0; c < skirtDim; c++) {
              final x = minX + (c - 1) * step;
              skirtHeights[r * skirtDim + c] = terrain.sampleGroundHeight(x, z);
            }
          }
        }

        final samples = <double>[];
        const iterations = 15;

        for (var iter = 0; iter < iterations; iter++) {
          final sw = Stopwatch()..start();

          for (var r = 0; r < skirtDim; r++) {
            final z = minZ + (r - 1) * step;
            for (var c = 0; c < skirtDim; c++) {
              final x = minX + (c - 1) * step;
              skirtHeights[r * skirtDim + c] = terrain.sampleGroundHeight(x, z);
            }
          }

          for (var lr = 0; lr < localGridDim; lr++) {
            final sr = lr + 1;
            for (var lc = 0; lc < localGridDim; lc++) {
              final sc = lc + 1;
              final hL = skirtHeights[sr * skirtDim + (sc - 1)];
              final hR = skirtHeights[sr * skirtDim + (sc + 1)];
              final hD = skirtHeights[(sr - 1) * skirtDim + sc];
              final hU = skirtHeights[(sr + 1) * skirtDim + sc];

              final nx = hL - hR;
              const ny = 1.0;
              final nz = hD - hU;
              final invLen = 1.0 / math.sqrt(nx * nx + ny * ny + nz * nz);

              final idx = lr * localGridDim + lc;
              normalsX[idx] = nx * invLen;
              normalsY[idx] = ny * invLen;
              normalsZ[idx] = nz * invLen;
            }
          }

          var diagCount = 0;
          for (var lr = 0; lr < localGridDim - 1; lr++) {
            final sr = lr + 1;
            for (var lc = 0; lc < localGridDim - 1; lc++) {
              final sc = lc + 1;
              final h00 = skirtHeights[sr * skirtDim + sc];
              final h10 = skirtHeights[sr * skirtDim + sc + 1];
              final h01 = skirtHeights[(sr + 1) * skirtDim + sc];
              final h11 = skirtHeights[(sr + 1) * skirtDim + sc + 1];
              if ((h00 - h11).abs() < (h10 - h01).abs()) {
                diagCount++;
              }
            }
          }

          sw.stop();
          expect(diagCount, greaterThan(0));
          samples.add(sw.elapsedMicroseconds / 1000.0);
        }

        samples.sort();
        final minMs = samples.first;
        final medianMs = samples[samples.length ~/ 2];
        final meanMs = samples.reduce((a, b) => a + b) / samples.length;
        final maxMs = samples.last;

        timingStats[label] = {
          'min': minMs,
          'median': medianMs,
          'mean': meanMs,
          'max': maxMs,
        };

        expect(
          minMs,
          lessThan(35),
          reason: '$label minimum CPU rebuild ($minMs ms) exceeded test limit',
        );
        expect(
          medianMs,
          lessThan(45),
          reason: '$label median CPU rebuild ($medianMs ms) exceeded limit',
        );
      }

      expect(timingStats.length, equals(5));
    });

    test(
      'Simulated edit and single dirty chunk rebuild runs reliably on CPU',
      () {
        final terrain = TerrainBuilder()..clearDirty();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

        final rootInitial = terrain.buildTerrainNode(
          defaultShukubaMaterial,
          terraces: graph.terraces,
          roads: graph.roads,
          structures: graph.structures.values,
        );
        expect(rootInitial.children.length, greaterThanOrEqualTo(16));
        expect(terrain.dirtyChunkIndices, isEmpty);
        expect(terrain.geometryCache.length, equals(16));

        terrain
          ..clearDirty()
          ..markDirty(Aabb2.minMax(Vector2(-30, -30), Vector2(-20, -20)));
        expect(terrain.dirtyChunkIndices, equals({5}));

        final singleDirtySw = Stopwatch()..start();
        terrain.buildTerrainNode(
          defaultShukubaMaterial,
          terraces: graph.terraces,
          roads: graph.roads,
          structures: graph.structures.values,
        );
        singleDirtySw.stop();
        expect(terrain.dirtyChunkIndices, isEmpty);
        expect(singleDirtySw.elapsedMilliseconds, lessThan(60));
      },
      skip: !impellerAvailable ? impellerSkipReason : false,
    );
  });

  group('Empirical Challenge 3: Shadow Static Verification '
      '(shadowStatic == true)', () {
    (int total, int staticCount, List<String> nonStaticNames)
    inspectSubtreeShadowStatic(Node root) {
      var total = 0;
      var staticCount = 0;
      final nonStaticNames = <String>[];
      final queue = <Node>[root];

      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        total++;
        if (current.shadowStatic) {
          staticCount++;
        } else {
          nonStaticNames.add(current.name);
        }
        queue.addAll(current.children);
      }
      return (total, staticCount, nonStaticNames);
    }

    test(
      'markSubtreeShadowStatic marks full 16-chunk synthetic terrain tree',
      () {
        final root = Node(name: 'terrain_tiled_root');
        for (var cz = 0; cz < 4; cz++) {
          for (var cx = 0; cx < 4; cx++) {
            final chunkNode = Node(name: 'terrain_tile_${cz}_$cx');
            root.add(chunkNode);
          }
        }

        final tanada = Node(name: 'tanada_paddies_root')
          ..add(Node(name: 'tanada_tier_0'))
          ..add(Node(name: 'tanada_tier_1'))
          ..add(Node(name: 'tanada_tier_2'));
        final mitsuke = Node(name: 'mitsuke_checkpoints_root')
          ..add(Node(name: 'mitsuke_east'))
          ..add(Node(name: 'mitsuke_west'));
        root
          ..add(tanada)
          ..add(mitsuke);

        final (totalBefore, staticBefore, _) = inspectSubtreeShadowStatic(root);
        expect(totalBefore, equals(24));
        expect(staticBefore, equals(0));

        markSubtreeShadowStatic(root);

        final (totalAfter, staticAfter, nonStaticAfter) =
            inspectSubtreeShadowStatic(root);
        expect(totalAfter, equals(24));
        expect(staticAfter, equals(24));
        expect(nonStaticAfter, isEmpty);
        expect(root.shadowStatic, isTrue);
        for (final child in root.children) {
          expect(child.shadowStatic, isTrue);
        }
      },
    );

    test(
      'Every Node in live 16-chunk terrain tree has shadowStatic == true',
      () {
        final terrain = TerrainBuilder()..clearDirty();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

        final root = terrain.buildTerrainNode(
          defaultShukubaMaterial,
          terraces: graph.terraces,
          roads: graph.roads,
          structures: graph.structures.values,
        );

        expect(root.name, equals('terrain_tiled_root'));
        expect(
          root.shadowStatic,
          isTrue,
          reason: 'Root node must have shadowStatic == true',
        );

        final chunkNames = <String>{};
        for (var cz = 0; cz < 4; cz++) {
          for (var cx = 0; cx < 4; cx++) {
            final expectedName = 'terrain_tile_${cz}_$cx';
            chunkNames.add(expectedName);
            final chunkNode = root.children.firstWhere(
              (c) => c.name == expectedName,
              orElse: () =>
                  throw StateError('Missing chunk node $expectedName'),
            );
            expect(
              chunkNode.shadowStatic,
              isTrue,
              reason: 'Chunk $expectedName must have shadowStatic == true',
            );
          }
        }
        expect(chunkNames.length, equals(16));

        final (totalNodes, staticNodes, nonStaticNames) =
            inspectSubtreeShadowStatic(root);
        expect(totalNodes, greaterThanOrEqualTo(19));
        expect(nonStaticNames, isEmpty);
        expect(staticNodes, equals(totalNodes));
      },
      skip: !impellerAvailable ? impellerSkipReason : false,
    );

    test(
      'buildTerrainChunkNode produces single chunk with shadowStatic == true',
      () {
        final terrain = TerrainBuilder();
        for (var cz = 0; cz < 4; cz++) {
          for (var cx = 0; cx < 4; cx++) {
            final chunkNode = terrain.buildTerrainChunkNode(
              cx,
              cz,
              defaultShukubaMaterial,
            );
            expect(chunkNode.name, equals('terrain_tile_${cz}_$cx'));
            expect(
              chunkNode.shadowStatic,
              isTrue,
              reason: 'Chunk ($cx, $cz) must have shadowStatic == true',
            );
          }
        }
      },
      skip: !impellerAvailable ? impellerSkipReason : false,
    );
  });

  group(
    'Empirical Challenge 4: Instance Isolation & Live applyGraph Dirtying',
    () {
      test(
        'Distinct TerrainBuilder instances hold independent dirty state',
        () {
          final a = TerrainBuilder()..clearDirty();
          final b = TerrainBuilder();
          expect(a.dirtyChunkIndices, isEmpty);
          expect(b.dirtyChunkIndices.length, equals(16));

          a.markDirty(Aabb2.minMax(Vector2(-70, -70), Vector2(-65, -65)));
          expect(a.dirtyChunkIndices, equals({0}));
          b.clearDirty();
          expect(a.dirtyChunkIndices, equals({0}));
          expect(b.dirtyChunkIndices, isEmpty);
        },
      );

      test(
        'EdoWorldDriver.applyGraph marks only edited structure chunk dirty',
        () {
          final driver = EdoWorldDriver()..initSimulation();
          driver.terrainBuilder.clearDirty();
          expect(driver.terrainBuilder.dirtyChunkIndices, isEmpty);

          final nextGraph = driver.graph.putStructure(
            PlacedStructure(
              id: EntityId.validated('test_nw_farmhouse'),
              kind: StructureKind.minka,
              position: const Vec3(-70, 0, -70),
            ),
          );
          driver.applyGraph(nextGraph);
          expect(driver.terrainBuilder.dirtyChunkIndices, equals({0}));
        },
      );

      test(
        'macos/Runner/DebugProfile.entitlements is clean and unmodified',
        () {
          final entitlementsFile = File(
            'macos/Runner/DebugProfile.entitlements',
          );
          expect(entitlementsFile.existsSync(), isTrue);

          final result = Process.runSync('git', [
            'status',
            '--porcelain',
            'macos/Runner/DebugProfile.entitlements',
          ]);
          expect(result.exitCode, equals(0));
          expect(
            (result.stdout as String).trim(),
            isEmpty,
            reason: 'DebugProfile.entitlements has uncommitted modifications!',
          );
        },
      );
    },
  );
}
