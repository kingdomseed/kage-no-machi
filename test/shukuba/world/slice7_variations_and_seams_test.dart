import 'dart:io';

import 'package:flutter_scene/scene.dart' show Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/world/atmosphere_builder.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';
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
}
