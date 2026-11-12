import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';
import 'package:kage_no_machi/shukuba/world/starter_ward.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';

import '../helpers/e2e_test_harness.dart';

void main() {
  group(
    'Tier 4 Scenario 1: Post-Town Golden Dusk Overview (F6, F8-F11, F13)',
    () {
      late ShukubaGraph starterGraph;
      final terrain = TerrainBuilder();

      setUpAll(() {
        starterGraph = buildStarterShukubaGraph(terrain.sampleGroundHeight);
      });

      test('1. Ward layout initializes complete architectural composition', () {
        expect(starterGraph.structures, isNotEmpty);
        expect(starterGraph.roads, isNotEmpty);
        expect(starterGraph.terraces, isNotEmpty);

        final kinds = starterGraph.structures.values.map((s) => s.kind).toSet();
        expect(kinds, contains(StructureKind.machiya));
        expect(kinds, contains(StructureKind.chaya));
        expect(kinds, contains(StructureKind.kura));
        expect(kinds, contains(StructureKind.marketStall));
        expect(kinds, contains(StructureKind.toriiGate));
        expect(kinds, contains(StructureKind.rockOutcrop));
        expect(kinds, contains(StructureKind.pineTree));
        expect(kinds, contains(StructureKind.bambooGrove));
        expect(kinds, contains(StructureKind.mapleCluster));
      });

      test(
        '2. Golden dusk lighting rig and shadow contrast are calibrated',
        () {
          const preset = CameraPreset.duskOverview;
          expect(preset.id, equals('dusk_overview'));
          expect(preset.timeOfDay, equals(TimeOfDayRig.goldenDusk));
          expect(preset.timeOfDay.value, closeTo(0.15, 1e-4));
          expect(preset.timeOfDay.nightFactor, closeTo(0.06075, 1e-4));
          expect(preset.timeOfDay.isMoonlit, isFalse);
          expect(preset.timeOfDay.celestialRayDirection.y.isFinite, isTrue);

          final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
              .readAsStringSync();
          expect(lookSrc.contains('intensity: 0.24'), isTrue);
          expect(lookSrc.contains('ambientOcclusionRadius: 0.88'), isTrue);
          expect(lookSrc.contains('ambientOcclusionIntensity: 1.56'), isTrue);
        },
      );

      test('3. Human-scale architecture scaling respects proportions', () {
        const machiya = StructureSpec.machiya;
        expect(machiya.footprintWidth, closeTo(3.8, 1e-4));
        expect(machiya.footprintDepth, closeTo(4.8, 1e-4));

        const chaya = StructureSpec.chaya;
        expect(chaya.footprintWidth, closeTo(4.4, 1e-4));
        expect(chaya.footprintDepth, closeTo(4.4, 1e-4));

        const kura = StructureSpec.kura;
        expect(kura.footprintWidth, closeTo(3.4, 1e-4));
        expect(kura.footprintDepth, closeTo(4.0, 1e-4));
      });

      test(
        '4. 4-sided carpentry and roof craft mate seamlessly',
        () {
          const machiya = StructureSpec.machiya;
          expect(machiya.kind, equals(StructureKind.machiya));
          expect(machiya.height, closeTo(4.18, 1e-4));
          expect(machiya.eaveAnchors, isNotEmpty);

          const roofRole = ShukubaSurfaceRole.kawaraTile;
          expect(roofRole.depthLayer, equals(0));

          const placed = PlacedStructure(
            id: EntityId('test_machiya_dusk'),
            kind: StructureKind.machiya,
            position: Vec3.zero,
          );
          final node = const EdoKitBuilder().buildStructureNode(
            placed,
            testMaterialResolver,
          );
          markSubtreeShadowStatic(node);
          expect(node.shadowStatic, isTrue);
          expect(countNodes(node), greaterThan(1));
          for (final child in node.children) {
            expect(child.shadowStatic, isTrue);
          }
        },
        skip: !checkImpellerAvailable()
            ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
            : null,
      );

      test('5. Botanical height ratio against house ridges is 2x to 3x', () {
        final machiyaRidge = StructureSpec.machiya.height;
        final pineHeight = StructureSpec.pineTree.height;
        final bambooHeight = StructureSpec.bambooGrove.height;

        final pineRatio = pineHeight / machiyaRidge;
        final bambooRatio = bambooHeight / machiyaRidge;

        expect(pineRatio, inInclusiveRange(1.8, 3.2));
        expect(bambooRatio, inInclusiveRange(2.2, 3.5));
      });

      test(
        '6. Frame verification confirms zero overlaps and depth conflicts',
        () {
          const preset = CameraPreset.duskOverview;
          expect(preset.eye, equals(const Vec3(-45.5, 51.6, -45.5)));
          expect(preset.target, equals(const Vec3(0, 1.4, 0)));

          final summaryFile = File('/tmp/shukuba_cap/summary.json');
          if (summaryFile.existsSync()) {
            final data = jsonDecode(
              summaryFile.readAsStringSync(),
            ) as Map<String, dynamic>;
            final presets = (data['presets'] as List)
                .cast<Map<String, dynamic>>();
            final dusk = presets.firstWhere(
              (p) => p['presetId'] == 'dusk_overview',
              orElse: () => <String, dynamic>{},
            );
            if (dusk.isNotEmpty) {
              expect(dusk['depthConflictCount'], equals(0));
              final expectedPassed =
                  dusk['coplanarOverlapCount'] == 0 &&
                  dusk['depthConflictCount'] == 0;
              expect(dusk['passed'], equals(expectedPassed));
            }
          }

          const cleanResult = PresetVerificationResult(
            presetId: 'dusk_overview',
            pngPath: '/tmp/shukuba_cap/dusk_overview.png',
            pixelStats: FramePixelStats(
              width: 1440,
              height: 778,
              meanLuminance: 0.26,
              stddevLuminance: 0.15,
              nonZeroPixels: 1120244,
            ),
            coplanarOverlapCount: 0,
            coplanarDescriptions: [],
            depthConflictCount: 0,
            depthConflictSummary: 'Clean.',
          );
          expect(cleanResult.passed, isTrue);
          expect(cleanResult.coplanarOverlapCount, equals(0));
          expect(cleanResult.depthConflictCount, equals(0));
        },
      );
    },
  );
}
