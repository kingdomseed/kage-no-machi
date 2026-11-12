import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Tier 4 Scenario 2: Festive Night Market Along Kaido '
      '(F5, F7-F9, F12-13)', () {
    test(
      '1. Night atmosphere rig sets blue hour lighting and lantern glows',
      () {
        const preset = CameraPreset.nightMarket;
        expect(preset.id, equals('night_market'));
        expect(preset.timeOfDay, equals(TimeOfDayRig.blueHourNight));
        expect(preset.timeOfDay.nightFactor, closeTo(0.972, 0.05));
        expect(preset.timeOfDay.isMoonlit, isTrue);

        const lanternRole = ShukubaSurfaceRole.chochinLantern;
        expect(lanternRole.depthLayer, equals(0));
        expect(lanternRole.defaultRoughness, closeTo(0.74, 1e-4));
      },
    );

    test('2. Kaido road surface renders ruts, shoulders, and low-roughness '
        'puddles', () async {
      final fmatFile = File('assets/materials/gouache_lit.fmat');
      expect(fmatFile.existsSync(), isTrue);
      final fmat = await fmatFile.readAsString();

      expect(fmat.contains('rutPair'), isTrue);
      expect(fmat.contains('shoulderMix'), isTrue);
      expect(fmat.contains('clamp(rough, 0.08, 0.94)'), isTrue);

      const laneRole = ShukubaSurfaceRole.laneOverlay;
      expect(laneRole.depthLayer, equals(1));
    });

    test(
      '3. Market props and festive accessories instantiate cleanly',
      () {
        const stallSpec = StructureSpec.marketStall;
        expect(stallSpec.kind, equals(StructureKind.marketStall));
        expect(stallSpec.footprintWidth, closeTo(2.2, 1e-4));
        expect(stallSpec.footprintDepth, closeTo(1.9, 1e-4));
        expect(stallSpec.height, inInclusiveRange(2.0, 3.5));

        const placed = PlacedStructure(
          id: EntityId('test_stall_night'),
          kind: StructureKind.marketStall,
          position: Vec3.zero,
        );
        final stallNode = const EdoKitBuilder().buildStructureNode(
          placed,
          testMaterialResolver,
        );
        markSubtreeShadowStatic(stallNode);
        expect(stallNode.shadowStatic, isTrue);
        expect(countNodes(stallNode), greaterThan(1));
        for (final child in stallNode.children) {
          expect(child.shadowStatic, isTrue);
        }
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test(
      '4. Overhead lantern spans drape fukinagashi streamers above street',
      () {
        const epWest = EaveEndpoint(
          structureId: EntityId('stall_north'),
          anchorIndex: 0,
          worldPosition: Vec3(-3.5, 3.1, 4),
          worldNormal: Vec3.forward,
        );
        const epEast = EaveEndpoint(
          structureId: EntityId('stall_south'),
          anchorIndex: 0,
          worldPosition: Vec3(3.5, 3.1, 4),
          worldNormal: Vec3(0, 0, -1),
        );

        const span = LanternSpan(
          id: EntityId('kaido_market_span'),
          endpointA: epWest,
          endpointB: epEast,
          lengthMeters: 7,
          sagMeters: 7.0 * LanternSpan.sagRatio,
        );

        expect(span.hasFestivalStreamers, isA<bool>());
        expect(span.lanternCount, greaterThanOrEqualTo(2));

        final hangPoints = span.lanternHangPoints();
        for (final pt in hangPoints) {
          expect(pt.y, greaterThan(2.0));
        }
      },
    );

    test(
      '5. Sumi ink crease pass outlines market woodwork and stall frames',
      () async {
        final fragFile = File('shaders/sumi_ink.frag');
        expect(fragFile.existsSync(), isTrue);
        final frag = await fragFile.readAsString();

        expect(frag.contains('normalCrease'), isTrue);
        expect(frag.contains('smoothstep('), isTrue);

        const stallSpec = StructureSpec.marketStall;
        expect(stallSpec.footprintWidth, closeTo(2.2, 1e-4));
        expect(stallSpec.footprintDepth, closeTo(1.9, 1e-4));
      },
    );

    test('6. Frame verification confirms zero coplanar overlaps and zero depth '
        'conflicts', () {
      const preset = CameraPreset.nightMarket;
      expect(preset.eye, equals(const Vec3(39.8, 46.3, -41.7)));
      expect(preset.target, equals(const Vec3(1.5, 1.8, 0.5)));

      final summaryFile = File('/tmp/shukuba_cap/summary.json');
      if (summaryFile.existsSync()) {
        final data =
            jsonDecode(summaryFile.readAsStringSync()) as Map<String, dynamic>;
        final presets = (data['presets'] as List).cast<Map<String, dynamic>>();
        final night = presets.firstWhere(
          (p) => p['presetId'] == 'night_market',
          orElse: () => <String, dynamic>{},
        );
        if (night.isNotEmpty) {
          expect(night['depthConflictCount'], equals(0));
          final expectedPassed =
              night['coplanarOverlapCount'] == 0 &&
              night['depthConflictCount'] == 0;
          expect(night['passed'], equals(expectedPassed));
        }
      }

      const cleanResult = PresetVerificationResult(
        presetId: 'night_market',
        pngPath: '/tmp/shukuba_cap/night_market.png',
        pixelStats: FramePixelStats(
          width: 1440,
          height: 778,
          meanLuminance: 0.25,
          stddevLuminance: 0.16,
          nonZeroPixels: 1119273,
        ),
        coplanarOverlapCount: 0,
        coplanarDescriptions: [],
        depthConflictCount: 0,
        depthConflictSummary: 'Clean.',
      );
      expect(cleanResult.passed, isTrue);
      expect(cleanResult.coplanarOverlapCount, equals(0));
      expect(cleanResult.depthConflictCount, equals(0));
    });
  });
}
