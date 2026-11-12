import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show Node, Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/world/atmosphere_builder.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';
import 'package:kage_no_machi/shukuba/world/edo_world_driver.dart';
import 'package:kage_no_machi/shukuba/world/flora_scatter_builder.dart';
import 'package:kage_no_machi/shukuba/world/starter_ward.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';

import '../../e2e/helpers/e2e_test_harness.dart';

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
  group('Slice 7: Own Title Branding Invariant', () {
    test('Zero lib/ Dart files contain Shadow Tactics title strings', () {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in dartFiles) {
        final content = file.readAsStringSync().toLowerCase();
        expect(
          content,
          isNot(contains('shadow tactics')),
          reason: '${file.path} must not reference Shadow Tactics branding',
        );
        expect(
          content,
          isNot(contains('return of the shogun')),
          reason: '${file.path} must not reference Return of the Shogun',
        );
      }
    });
  });

  group('Slice 7: Procedural Building Variations & Auto-Advancing Stamps', () {
    test('Multi-variant StructureSpecs expose named silhouettes', () {
      expect(StructureSpec.minka.variantCount, equals(4));
      expect(StructureSpec.machiya.variantCount, equals(4));
      expect(StructureSpec.chaya.variantCount, equals(3));
      expect(StructureSpec.kura.variantCount, equals(3));
      expect(StructureSpec.marketStall.variantCount, equals(4));

      for (var i = 0; i < 4; i++) {
        expect(StructureSpec.minka.variantLabelAt(i), isNotEmpty);
        expect(StructureSpec.machiya.variantLabelAt(i), isNotEmpty);
      }
      expect(
        StructureSpec.minka.variantLabelAt(4),
        equals(StructureSpec.minka.variantLabelAt(0)),
      );
    });

    test(
      'Consecutive farmhouse placements auto-advance through all 4 variants',
      () {
        final controller = ShukubaController(
          look: FakeLookDriver(),
          world: FakeWorldDriver(),
          audio: FakeAudioDriver(),
        );
        addTearDown(controller.dispose);

        controller.selectTool(
          const StampStructureTool(kind: StructureKind.minka),
        );
        final placedVariants = <int>[];
        for (var i = 0; i < 4; i++) {
          final point = Vec3(-28.0 + i * 7.5, 0, -24);
          controller
            ..updateHoverPoint(point)
            ..handlePrimaryPlotTap(point);
        }

        final minkas = controller.graph.structures.values
            .where((s) => s.kind == StructureKind.minka)
            .toList();
        for (final s in minkas) {
          placedVariants.add(s.resolvedVariant);
        }
        expect(placedVariants.toSet(), equals({0, 1, 2, 3}));
        expect(
          controller.activeTool,
          equals(const StampStructureTool(kind: StructureKind.minka)),
        );
      },
    );

    test(
      'cycleStampVariant wraps forward and backward modulo variantCount',
      () {
        final controller = ShukubaController(
          look: FakeLookDriver(),
          world: FakeWorldDriver(),
          audio: FakeAudioDriver(),
        );
        addTearDown(controller.dispose);

        controller
          ..selectTool(const StampStructureTool(kind: StructureKind.chaya))
          ..cycleStampVariant();
        expect(
          (controller.activeTool as StampStructureTool).resolvedVariant,
          equals(1),
        );

        controller.cycleStampVariant(-2);
        expect(
          (controller.activeTool as StampStructureTool).resolvedVariant,
          equals(2),
        );
      },
    );

    test(
      'structureLanternLocalOffsets aligns within building eave bounds across '
      'all variants',
      () {
        const kinds = [
          StructureKind.machiya,
          StructureKind.minka,
          StructureKind.chaya,
          StructureKind.kura,
          StructureKind.marketStall,
        ];
        for (final kind in kinds) {
          final spec = kind.spec;
          for (var v = 0; v < spec.variantCount; v++) {
            final placed = PlacedStructure(
              id: EntityId('probe_${kind.name}_$v'),
              kind: kind,
              position: Vec3.zero,
              variant: v,
            );
            final hooks = EdoKitBuilder.structureLanternLocalOffsets(placed);
            for (final hook in hooks) {
              expect(
                hook.y,
                inInclusiveRange(1.4, spec.height),
                reason: 'Hook height out of bounds for ${kind.name} v$v',
              );
              expect(
                hook.z.abs(),
                lessThanOrEqualTo(spec.footprintDepth * 0.5 + 0.65),
                reason: 'Hook Z floated too far from eave for ${kind.name} v$v',
              );
            }
          }
        }
      },
    );

    test(
      'Starter ward populates multiple farmhouse and townhouse variants',
      () {
        final terrain = TerrainBuilder();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

        final minkaVariants = graph.structures.values
            .where((s) => s.kind == StructureKind.minka)
            .map((s) => s.resolvedVariant)
            .toSet();
        final machiyaVariants = graph.structures.values
            .where((s) => s.kind == StructureKind.machiya)
            .map((s) => s.resolvedVariant)
            .toSet();

        expect(minkaVariants.length, greaterThanOrEqualTo(3));
        expect(machiyaVariants.length, greaterThanOrEqualTo(3));
      },
    );
  });

  group('Slice 7: Contour-Graded Tanada, Road-Stair Seams & Capture Atlas', () {
    test(
      'Contour-graded tanada shelves step gently (<= 0.56 m) without cliffs',
      () {
        final terrain = TerrainBuilder();

        const tiers = TerrainBuilder.tanadaTierElevations;
        expect(tiers, hasLength(6));
        for (var i = 1; i < tiers.length; i++) {
          final delta = tiers[i] - tiers[i - 1];
          expect(delta, inInclusiveRange(0.35, 0.56));
        }

        const sampleZ = 36.0;
        final baseX = TerrainBuilder.tanadaBaseCurveX(sampleZ);
        var prevH = terrain.sampleGroundHeight(baseX - 2, sampleZ);
        for (var step = 0; step <= 52; step++) {
          final x = baseX - 2.0 + step * 0.5;
          final h = terrain.sampleGroundHeight(x, sampleZ);
          expect(
            (h - prevH).abs(),
            lessThanOrEqualTo(0.55),
            reason: 'Abrupt cliff step detected across tanada at x=$x',
          );
          prevH = h;
        }
      },
    );

    test(
      'Flooded tanada basin predicate excludes dry bunds and town center',
      () {
        expect(TerrainBuilder.isInsideTanadaFloodedBasin(0, 0), isFalse);
        final midCurveX = TerrainBuilder.tanadaBaseCurveX(36);
        expect(
          TerrainBuilder.isInsideTanadaFloodedBasin(midCurveX + 1.8, 36),
          isTrue,
        );
        expect(
          TerrainBuilder.isInsideTanadaFloodedBasin(midCurveX + 0.5, 36),
          isFalse,
        );
      },
    );

    test('Atlas harness covers 10 seam cameras and 22 specimen turntables', () {
      expect(ShukubaFrameHarness.geometrySeamPresets, hasLength(10));
      final totalSpecimens = ShukubaFrameHarness.turntableStructureKinds.fold(
        0,
        (sum, kind) => sum + kind.spec.variantCount,
      );
      expect(totalSpecimens, equals(22));
    });

    test(
      'East and West Kaido highways span continuously to the valley rim',
      () {
        final terrain = TerrainBuilder();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);
        final west = graph.roads.firstWhere(
          (r) => r.id == const EntityId('road_kaido_west'),
        );
        final east = graph.roads.firstWhere(
          (r) => r.id == const EntityId('road_kaido_east'),
        );

        expect(west.controlPoints.first.x, lessThanOrEqualTo(-87));
        expect(west.controlPoints.last.x, closeTo(-5.2, 0.1));
        expect(east.controlPoints.first.x, closeTo(5.2, 0.1));
        expect(east.controlPoints.last.x, greaterThanOrEqualTo(87));
      },
    );

    test(
      'AtmosphereBuilder builds empty ShukubaGraph without empty ward buffers',
      () {
        final terrain = TerrainBuilder();
        final node = const AtmosphereBuilder().buildAtmosphereNode(
          graph: ShukubaGraph(),
          resolveMaterial: defaultShukubaMaterial,
          sampleGroundY: terrain.sampleGroundHeight,
        );
        final mistGroup = node.children.firstWhere(
          (n) => n.name == 'atmosphere_mist_ribbons',
        );
        final childNames = mistGroup.children.map((n) => n.name).toSet();
        expect(childNames, contains('atmosphere_mist_river_south'));
        expect(childNames, contains('atmosphere_mist_river_north'));
        expect(childNames, isNot(contains('atmosphere_mist_west_ward')));
        expect(childNames, isNot(contains('atmosphere_mist_east_ward')));
      },
      skip: !impellerAvailable
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : false,
    );
  });

  group('Slice 8: Chunked Flora, Gorge Clearance, Roji & Feathering', () {
    late TerrainBuilder terrain;
    late ShukubaGraph graph;

    double wardGroundY(double x, double z) => terrain.sampleGroundHeight(
      x,
      z,
      terraces: graph.terraces,
      roads: graph.roads,
    );

    setUpAll(() {
      terrain = TerrainBuilder();
      graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);
    });

    test(
      'Every 4x4 flora chunk stays <= 48 m in XZ (zero 172 m near-plane clamp)',
      () {
        const flora = FloraScatterBuilder();
        final summaries = flora.computeChunkSummaries(
          graph: graph,
          sampleGroundY: wardGroundY,
        );

        expect(summaries.length, equals(TerrainConfig.chunkCount));
        var totalInstances = 0;
        for (final summary in summaries.values) {
          expect(
            summary.nodeName,
            equals('flora_tile_${summary.row}_${summary.col}'),
          );
          expect(
            summary.spanX,
            lessThanOrEqualTo(48.0),
            reason: '${summary.nodeName} exceeded 48 m X span',
          );
          expect(
            summary.spanZ,
            lessThanOrEqualTo(48.0),
            reason: '${summary.nodeName} exceeded 48 m Z span',
          );
          expect(summary.spanX, lessThanOrEqualTo(50.0));
          expect(summary.spanZ, lessThanOrEqualTo(50.0));
          totalInstances += summary.instanceCount;
        }
        expect(totalInstances, greaterThan(18000));

        final singleChunk = flora.computeChunkSummaries(
          graph: graph,
          sampleGroundY: wardGroundY,
          onlyChunks: const {0},
        );
        expect(singleChunk.keys, equals(const {0}));
        expect(
          singleChunk[0]!.instanceCount,
          equals(summaries[0]!.instanceCount),
        );
      },
    );

    test(
      'Built flora chunk scene nodes eliminate flora_meadow_sward and bound '
      'every child <= 50 m',
      () {
        final root = const FloraScatterBuilder().buildFloraScatterNode(
          graph: graph,
          resolveMaterial: defaultShukubaMaterial,
          sampleGroundY: wardGroundY,
        );

        expect(root.name, equals('flora_scatter_root'));
        expect(root.children.length, equals(TerrainConfig.chunkCount));

        void verifyNoLegacyNode(Node node) {
          expect(node.name, isNot(equals('flora_meadow_sward')));
          node.children.forEach(verifyNoLegacyNode);
        }

        verifyNoLegacyNode(root);
        for (final tile in root.children) {
          expect(tile.name, startsWith('flora_tile_'));
          final bounds = tile.combinedWorldBounds;
          expect(bounds, isNotNull);
          expect(bounds!.max.x - bounds.min.x, lessThanOrEqualTo(50.0));
          expect(bounds.max.z - bounds.min.z, lessThanOrEqualTo(50.0));
        }
      },
      skip: !impellerAvailable
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : false,
    );

    test(
      'EdoWorldDriver marks only affected flora chunks dirty on local edit',
      () {
        final driver = EdoWorldDriver()
          ..initSimulation()
          ..clearDirtyFlora();
        expect(driver.dirtyFloraChunkIndices, isEmpty);

        final nextGraph = driver.graph.putStructure(
          PlacedStructure(
            id: EntityId.validated('probe_nw_flora_dirty'),
            kind: StructureKind.minka,
            position: const Vec3(-70, 0, -70),
          ),
        );
        driver.applyGraph(nextGraph);
        expect(driver.dirtyFloraChunkIndices, equals(const {0}));
      },
    );

    test('Zero gorge boulders or starter_ward rockOutcrops intrude into any '
        'RoadSpline corridor', () {
      final unfilteredRocks = terrain.computeGorgeRockFootprints();
      final filteredRocks = terrain.computeGorgeRockFootprints(
        roads: graph.roads,
      );
      expect(filteredRocks, isNotEmpty);
      expect(filteredRocks.length, lessThanOrEqualTo(unfilteredRocks.length));

      for (final rock in filteredRocks) {
        for (final road in graph.roads) {
          final dist = road.nearestSample(rock.center).horizontalDistance;
          final minClear = road.widthMeters * 0.5 + rock.radius + 0.59;
          expect(
            dist,
            greaterThanOrEqualTo(minClear),
            reason:
                'Gorge boulder at ${rock.center} intruded on ${road.id.value}',
          );
        }
      }

      final rockOutcrops = graph.structures.values.where(
        (s) => s.kind == StructureKind.rockOutcrop,
      );
      expect(rockOutcrops.length, greaterThanOrEqualTo(12));

      for (final rock in rockOutcrops) {
        final rockRadius =
            math.max(rock.spec.footprintWidth, rock.spec.footprintDepth) * 0.5;
        for (final road in graph.roads) {
          final dist = road.nearestSample(rock.position).horizontalDistance;
          expect(
            dist,
            greaterThanOrEqualTo(road.widthMeters * 0.5 + rockRadius + 0.35),
            reason:
                'Rock outcrop ${rock.id.value} intruded on ${road.id.value}',
          );
        }
      }

      for (final s in graph.structures.values) {
        expect(
          TerrainBuilder.isInsideTanadaFloodedBasin(s.position.x, s.position.z),
          isFalse,
          reason: '${s.id.value} placed inside flooded tanada basin',
        );
      }

      final countryside = graph.structures.values
          .where((s) => s.position.x.abs() >= 25 || s.position.z.abs() >= 25)
          .toList();
      expect(
        countryside.where((s) => s.id.value.contains('sugi')).length,
        greaterThanOrEqualTo(8),
      );
      expect(
        countryside.where((s) => s.kind == StructureKind.weepingWillow).length,
        greaterThanOrEqualTo(5),
      );
      expect(
        countryside.where((s) => s.position.x < -25 && s.position.z > 25),
        isNotEmpty,
      );
      expect(
        countryside.where((s) => s.position.x < -25 && s.position.z < -25),
        isNotEmpty,
      );
      expect(
        countryside.where((s) => s.position.x > 25 && s.position.z > 25),
        isNotEmpty,
      );
      expect(
        countryside.where((s) => s.position.x > 25 && s.position.z < -25),
        isNotEmpty,
      );
    });

    test('Every RoadStyle.gardenPath connects to a parent road and reaches a '
        'destination structure', () {
      final gardenPaths = graph.roads
          .where((r) => r.style == RoadStyle.gardenPath)
          .toList();
      final kaidoRoads = graph.roads
          .where((r) => r.style == RoadStyle.kaidoRoad)
          .toList();
      final destinations = graph.structures.values
          .where((s) => !s.kind.isNaturalFeature)
          .toList();

      expect(gardenPaths.length, greaterThanOrEqualTo(5));

      for (final roji in gardenPaths) {
        final startPt = roji.controlPoints.first;
        final endPt = roji.controlPoints.last;

        final connectedParent = kaidoRoads.any(
          (parent) =>
              parent.nearestSample(startPt).horizontalDistance <=
              parent.widthMeters * 0.5 + 1.25,
        );
        expect(
          connectedParent,
          isTrue,
          reason:
              '${roji.id.value} entry at $startPt does not connect to a '
              'kaidoRoad',
        );

        PlacedStructure? nearestDest;
        var bestGap = double.infinity;
        for (final dest in destinations) {
          final centerDist = dest.position.horizontalDistanceTo(endPt);
          final outerRadius =
              math.max(dest.spec.footprintWidth, dest.spec.footprintDepth) *
              0.5;
          final edgeGap = centerDist - outerRadius;
          if (edgeGap < bestGap) {
            bestGap = edgeGap;
            nearestDest = dest;
          }
        }

        expect(nearestDest, isNotNull);
        expect(
          bestGap,
          inInclusiveRange(0.35, 1.65),
          reason:
              '${roji.id.value} terminus at $endPt did not land cleanly in '
              'front of ${nearestDest?.id.value} (edgeGap=$bestGap)',
        );
      }
    });

    test(
      'Free road endpoints taper width and emit uv1.x > 0.8 while gardenPath '
      'junctions emit uv1.y > 0.8',
      () {
        double rowSpanAt(RoadRibbonData ribbon, int row) {
          final vLeft = row * ribbon.colCount;
          final vRight = vLeft + (ribbon.colCount - 1);
          final dx = ribbon.positions[vRight * 3] - ribbon.positions[vLeft * 3];
          final dz =
              ribbon.positions[vRight * 3 + 2] -
              ribbon.positions[vLeft * 3 + 2];
          return math.sqrt(dx * dx + dz * dz);
        }

        final marketAlley = graph.roads.firstWhere(
          (r) => r.id == const EntityId('road_market_alley'),
        );
        final alleyRibbon = terrain.computeRoadRibbonData(
          marketAlley,
          wardGroundY,
          allRoads: graph.roads,
          terraces: graph.terraces,
        );

        expect(alleyRibbon.freeStart, isFalse);
        expect(alleyRibbon.freeEnd, isTrue);

        final midRow = alleyRibbon.rowCount ~/ 2;
        final tipRow = alleyRibbon.rowCount - 1;
        final midWidth = rowSpanAt(alleyRibbon, midRow);
        final tipWidth = rowSpanAt(alleyRibbon, tipRow);
        expect(midWidth, closeTo(marketAlley.widthMeters, 0.15));
        expect(tipWidth, lessThan(marketAlley.widthMeters * 0.50));

        final tipCenterIdx = tipRow * alleyRibbon.colCount + 2;
        final midCenterIdx = midRow * alleyRibbon.colCount + 2;
        final midShoulderIdx = midRow * alleyRibbon.colCount;
        expect(alleyRibbon.texCoords1[tipCenterIdx * 2], greaterThan(0.8));
        expect(alleyRibbon.texCoords1[midCenterIdx * 2], closeTo(0.0, 1e-4));
        expect(
          alleyRibbon.texCoords1[midShoulderIdx * 2],
          inInclusiveRange(0.45, 0.65),
        );

        for (final roji in graph.roads.where(
          (r) => r.style == RoadStyle.gardenPath,
        )) {
          final ribbon = terrain.computeRoadRibbonData(
            roji,
            wardGroundY,
            allRoads: graph.roads,
            terraces: graph.terraces,
          );
          expect(
            ribbon.startCrossBlendsToKaido,
            isTrue,
            reason: '${roji.id.value} should cross-blend into kaidoRoad',
          );
          expect(
            ribbon.freeEnd,
            isTrue,
            reason: '${roji.id.value} terminus should feather into doorstep',
          );

          const mouthCenterIdx = 2;
          final endTipCenterIdx = (ribbon.rowCount - 1) * ribbon.colCount + 2;
          expect(
            ribbon.texCoords1[mouthCenterIdx * 2 + 1],
            greaterThan(0.8),
            reason: '${roji.id.value} mouth uv1.y must cross-blend > 0.8',
          );
          expect(
            ribbon.texCoords1[endTipCenterIdx * 2],
            greaterThan(0.8),
            reason: '${roji.id.value} free tip uv1.x must feather > 0.8',
          );
          expect(
            rowSpanAt(ribbon, 0),
            greaterThan(roji.widthMeters * 1.15),
            reason: '${roji.id.value} mouth should flare into parent road',
          );
          expect(
            rowSpanAt(ribbon, ribbon.rowCount - 1),
            lessThan(roji.widthMeters * 0.50),
            reason: '${roji.id.value} free tip should taper organically',
          );
        }
      },
    );
  });
}
