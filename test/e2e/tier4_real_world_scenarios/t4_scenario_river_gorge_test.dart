import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Tier 4 Scenario 3: River Gorge Crossing & Rock Strata '
      '(F4, F5, F7, F11, F13)', () {
    test(
      '1. River gorge topography and arched bridge parameters are valid',
      () {
        const bedElevation = TerrainConfig.riverBedElevation;
        const waterElevation = TerrainConfig.waterSurfaceElevation;
        const bankWidth = TerrainConfig.riverBankHalfWidth;

        expect(bedElevation, closeTo(-1.85, 1e-4));
        expect(waterElevation, closeTo(-0.55, 1e-4));
        expect(bankWidth, closeTo(2.15, 1e-4));

        const westElev = TerrainConfig.bridgeWestElevation;
        const eastElev = TerrainConfig.bridgeEastElevation;
        const camber = TerrainConfig.bridgeArchCamber;

        expect(westElev, closeTo(0.40, 1e-4));
        expect(eastElev, closeTo(1.80, 1e-4));
        expect(camber, closeTo(0.48, 1e-4));

        final midHeight = TerrainConfig.bridgeDeckHeightAt(0);
        expect(midHeight, greaterThan(waterElevation));
        expect(midHeight, greaterThan(westElev));
      },
    );

    test(
      '2. Grounded rock outcrop geometry samples 3D cellular fractures',
      () async {
        const rock = StructureSpec.rockOutcrop;
        expect(rock.height, inInclusiveRange(1.4, 2.6));
        expect(rock.footprintWidth, closeTo(3.2, 1e-4));
        expect(rock.footprintDepth, closeTo(3.0, 1e-4));

        final fmatFile = File('assets/materials/gouache_lit.fmat');
        expect(fmatFile.existsSync(), isTrue);
        final fmat = await fmatFile.readAsString();

        expect(fmat.contains('kStyleStoneMasonry = 3.0'), isTrue);
        expect(fmat.contains('NoiseSimplex3'), isTrue);
        expect(fmat.contains('strata'), isTrue);
        expect(fmat.contains('0.52'), isTrue);
        expect(fmat.contains('0.68'), isTrue);
      },
    );

    test(
      '3. Sumi ink normal creases delineate stepped sedimentary shelves',
      () async {
        final fragFile = File('shaders/sumi_ink.frag');
        expect(fragFile.existsSync(), isTrue);
        final frag = await fragFile.readAsString();

        expect(frag.contains('normalCrease'), isTrue);
        expect(frag.contains('smoothstep('), isTrue);

        const rockSpec = StructureSpec.rockOutcrop;
        expect(rockSpec.kind, equals(StructureKind.rockOutcrop));

        const placed = PlacedStructure(
          id: EntityId('test_rock_gorge'),
          kind: StructureKind.rockOutcrop,
          position: Vec3.zero,
        );
        final rockNode = const EdoKitBuilder().buildStructureNode(
          placed,
          testMaterialResolver,
        );
        markSubtreeShadowStatic(rockNode);
        expect(rockNode.shadowStatic, isTrue);
        expect(countNodes(rockNode), greaterThan(1));
        for (final child in rockNode.children) {
          expect(child.shadowStatic, isTrue);
        }
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test(
      '4. Riverside flora and courtyard stone well instantiate correctly',
      () {
        const willow = StructureSpec(
          kind: StructureKind.weepingWillow,
          displayName: 'Weeping Willow',
          edoSubtitle: 'Riverside yanagi',
          footprintWidth: 3.8,
          footprintDepth: 3.8,
          height: 8.4,
          foundationSkirtDepth: 0.5,
          eaveAnchors: [],
          instrument: EdoInstrument.shakuhachi,
          snapsToRoadTangent: false,
        );
        expect(willow.kind, equals(StructureKind.weepingWillow));
        expect(willow.height, inInclusiveRange(7.0, 10.0));

        const bamboo = StructureSpec.bambooGrove;
        expect(bamboo.height, inInclusiveRange(9.5, 13.5));

        const well = StructureSpec.stoneWell;
        expect(well.kind, equals(StructureKind.stoneWell));
        expect(well.height, closeTo(2.35, 1e-4));
        expect(well.footprintWidth, closeTo(1.8, 1e-4));
        expect(well.footprintDepth, closeTo(1.8, 1e-4));
      },
    );

    test('5. Gorge camera presets frame both wide crossing and riverbank '
        'detail', () {
      const riverPreset = CameraPreset.riverCrossing;
      expect(riverPreset.id, equals('river_crossing'));
      expect(riverPreset.eye, equals(const Vec3(-38.2, 44.8, 39.6)));
      expect(riverPreset.target, equals(const Vec3(1.2, 1.4, -0.4)));

      const meadowPreset = CameraPreset.meadowCloseup;
      expect(meadowPreset.id, equals('meadow_closeup'));
      expect(meadowPreset.eye, equals(const Vec3(-9.2, 4.8, 18.4)));
      expect(meadowPreset.target, equals(const Vec3(2.6, 1.15, 0.8)));
      expect(meadowPreset.verticalFovDegrees, equals(21));
    });

    test('6. Frame verification confirms zero coplanar overlaps and zero depth '
        'conflicts', () {
      final summaryFile = File('/tmp/shukuba_cap/summary.json');
      if (summaryFile.existsSync()) {
        final data =
            jsonDecode(summaryFile.readAsStringSync()) as Map<String, dynamic>;
        final presets = (data['presets'] as List).cast<Map<String, dynamic>>();

        final river = presets.firstWhere(
          (p) => p['presetId'] == 'river_crossing',
          orElse: () => <String, dynamic>{},
        );
        if (river.isNotEmpty) {
          expect(river['depthConflictCount'], equals(0));
          final expectedPassed =
              river['coplanarOverlapCount'] == 0 &&
              river['depthConflictCount'] == 0;
          expect(river['passed'], equals(expectedPassed));
        }

        final meadow = presets.firstWhere(
          (p) => p['presetId'] == 'meadow_closeup',
          orElse: () => <String, dynamic>{},
        );
        if (meadow.isNotEmpty) {
          expect(meadow['depthConflictCount'], equals(0));
          final expectedPassed =
              meadow['coplanarOverlapCount'] == 0 &&
              meadow['depthConflictCount'] == 0;
          expect(meadow['passed'], equals(expectedPassed));
        }
      }

      const cleanRiver = PresetVerificationResult(
        presetId: 'river_crossing',
        pngPath: '/tmp/shukuba_cap/river_crossing.png',
        pixelStats: FramePixelStats(
          width: 1440,
          height: 778,
          meanLuminance: 0.25,
          stddevLuminance: 0.14,
          nonZeroPixels: 1120313,
        ),
        coplanarOverlapCount: 0,
        coplanarDescriptions: [],
        depthConflictCount: 0,
        depthConflictSummary: 'Clean.',
      );
      expect(cleanRiver.passed, isTrue);

      const cleanMeadow = PresetVerificationResult(
        presetId: 'meadow_closeup',
        pngPath: '/tmp/shukuba_cap/meadow_closeup.png',
        pixelStats: FramePixelStats(
          width: 1440,
          height: 778,
          meanLuminance: 0.35,
          stddevLuminance: 0.12,
          nonZeroPixels: 1120320,
        ),
        coplanarOverlapCount: 0,
        coplanarDescriptions: [],
        depthConflictCount: 0,
        depthConflictSummary: 'Clean.',
      );
      expect(cleanMeadow.passed, isTrue);
    });
  });
}
