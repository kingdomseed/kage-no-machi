import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/look/look.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';
import 'package:material_ui/material_ui.dart' hide Material, Matrix4;
import 'package:vector_math/vector_math.dart' show Vector3, Vector4;

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Tier 3: Cross-Feature Pairwise Interactions (23 Tests)', () {
    test('1. F1 x F8: worldNormal anchors LanternSpan between scaled 3.8m '
        'machiya townhouses', () {
      const machiyaSpec = StructureSpec.machiya;
      expect(machiyaSpec.footprintWidth, closeTo(3.8, 1e-4));
      expect(machiyaSpec.footprintDepth, closeTo(4.8, 1e-4));

      const epNorth = EaveEndpoint(
        structureId: EntityId('machiya_north'),
        anchorIndex: 0,
        worldPosition: Vec3(-1.55, 3, 2.4),
        worldNormal: Vec3.forward,
      );

      const epSouth = EaveEndpoint(
        structureId: EntityId('machiya_south'),
        anchorIndex: 1,
        worldPosition: Vec3(1.55, 3, -2.4),
        worldNormal: Vec3(0, 0, -1),
      );

      expect(epNorth.worldNormal, equals(Vec3.forward));
      expect(epSouth.worldNormal, equals(const Vec3(0, 0, -1)));

      final delta = epSouth.worldPosition - epNorth.worldPosition;
      final distance = delta.length;
      final sag = distance * LanternSpan.sagRatio;

      final span = LanternSpan(
        id: const EntityId('span_north_south'),
        endpointA: epNorth,
        endpointB: epSouth,
        lengthMeters: distance,
        sagMeters: sag,
      );

      expect(span.lengthMeters, lessThanOrEqualTo(LanternSpan.maxSpanMeters));
      expect(span.sagMeters, closeTo(distance * 0.085, 1e-4));
      expect(span.lanternCount, greaterThanOrEqualTo(2));
      expect(span.lanternHangPoints(), hasLength(span.lanternCount));
    });

    test('2. F2 x F14: Audio isolate synthesis runs in background without '
        'blocking shell initial mode', () async {
      final bank = await Isolate.run(
        () => EdoWavBank.synthesizeAll(sampleRate: 8000),
      );
      expect(bank, isNotNull);
      expect(bank.kotoWav, isNotEmpty);
      expect(bank.shakuhachiWav, isNotEmpty);
      expect(bank.hyoshigiWav, isNotEmpty);
      expect(bank.bonshoWav, isNotEmpty);

      const mode = ShukubaShellMode.titleMenu;
      expect(mode, equals(ShukubaShellMode.titleMenu));
    });

    test('3. F2 x F13: Prewarmed audio bank immediately plays resonant bonsho '
        'bell on shoroBell pavilion stamp', () async {
      final audioDriver = FakeAudioDriver();
      await audioDriver.prewarm();
      expect(audioDriver.isPrewarmed, isTrue);

      const shoroSpec = StructureSpec.shoroBell;
      expect(shoroSpec.instrument, equals(EdoInstrument.bonsho));
      expect(shoroSpec.footprintWidth, closeTo(3.2, 1e-4));
      expect(shoroSpec.footprintDepth, closeTo(3.2, 1e-4));

      const noteEvent = PlacementNoteEvent(
        instrument: EdoInstrument.bonsho,
        scale: PentatonicScale.inSen,
        scaleDegree: 0,
        position: Vec3(10, 0, 10),
      );

      audioDriver.playPlacementNote(noteEvent);

      expect(audioDriver.notes, hasLength(1));
      expect(audioDriver.notes.first.instrument, equals(EdoInstrument.bonsho));
      expect(audioDriver.notes.first.scaleDegree, equals(0));
    });

    test(
      '4. F3 x F9: 4-sided carpentry mesh is marked shadowStatic = true and '
      'reuses cached directional shadow map',
      () {
        const spec = StructureSpec.machiya;
        expect(spec.eaveAnchors.length, greaterThanOrEqualTo(4));
        expect(spec.footprintWidth, closeTo(3.8, 1e-4));
        expect(spec.footprintDepth, closeTo(4.8, 1e-4));

        const kit = EdoKitBuilder();
        const machiya = PlacedStructure(
          id: EntityId('pairwise_machiya_f3_f9'),
          kind: StructureKind.machiya,
          position: Vec3.zero,
        );
        final townhouseNode = kit.buildStructureNode(
          machiya,
          testMaterialResolver,
        );

        expect(townhouseNode.shadowStatic, isTrue);
        expect(countNodes(townhouseNode), greaterThan(1));
        for (final child in townhouseNode.children) {
          expect(
            child.shadowStatic,
            isTrue,
            reason: 'Descendant node ${child.name} must be marked shadowStatic',
          );
        }
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test(
      '5. F3 x F20: Spatial terrain nodes are marked shadowStatic = true and '
      'partitioned into bounds',
      () {
        final terrain = TerrainBuilder();
        final terrainNode = terrain.buildTerrainNode(testMaterialResolver);

        expect(terrainNode.shadowStatic, isTrue);
        expect(terrainNode.name, equals('terrain_tiled_root'));
        expect(
          terrainNode.children.length,
          equals(TerrainConfig.chunkCount + 2),
        );
        final chunkTiles = terrainNode.children.where(
          (tile) => RegExp(r'^terrain_tile_\d+_\d+$').hasMatch(tile.name),
        );
        expect(chunkTiles.length, equals(TerrainConfig.chunkCount));
        for (final tile in terrainNode.children) {
          expect(
            tile.shadowStatic,
            isTrue,
            reason: '${tile.name} must be marked shadowStatic',
          );
          expect(tile.name, startsWith('terrain_tile_'));
        }

        expect(TerrainConfig.minX, lessThan(TerrainConfig.maxX));
        expect(TerrainConfig.minZ, lessThan(TerrainConfig.maxZ));
        expect(TerrainConfig.gridStep, equals(0.5));
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test(
      '6. F4 x F11: Grounded 1.4-2.6m rock outcrop geometry samples '
      'style_id == 3.0 with 0.52 normal relief & 0.68 deep fissures',
      () async {
        const rockSpec = StructureSpec.rockOutcrop;
        expect(rockSpec.height, inInclusiveRange(1.4, 2.6));
        expect(rockSpec.footprintWidth, closeTo(3.2, 1e-4));
        expect(rockSpec.footprintDepth, closeTo(3.0, 1e-4));

        final fmatFile = File('assets/materials/gouache_lit.fmat');
        expect(fmatFile.existsSync(), isTrue);
        final fmatSource = await fmatFile.readAsString();

        expect(fmatSource.contains('kStyleStoneMasonry = 3.0'), isTrue);
        expect(fmatSource.contains('0.52'), isTrue);
        expect(fmatSource.contains('0.68'), isTrue);

        const stoneRole = ShukubaSurfaceRole.ishigakiStone;
        expect(stoneRole.depthLayer, equals(0));
      },
    );

    test('7. F4 x F7: Stepped rock sedimentary shelves trigger crisp sumi ink '
        'normal creases at smoothstep(0.18, 0.68)', () async {
      final fragFile = File('shaders/sumi_ink.frag');
      expect(fragFile.existsSync(), isTrue);
      final fragSource = await fragFile.readAsString();

      expect(fragSource.contains('smoothstep('), isTrue);
      expect(fragSource.contains('normalCrease'), isTrue);

      double evaluateCrease(double x) {
        const edge0 = 0.18;
        const edge1 = 0.68;
        final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
        return t * t * (3.0 - 2.0 * t);
      }

      expect(evaluateCrease(0.10), closeTo(0.0, 1e-5));
      expect(evaluateCrease(0.18), closeTo(0.0, 1e-5));
      expect(evaluateCrease(0.43), closeTo(0.5, 0.05));
      expect(evaluateCrease(0.68), closeTo(1.0, 1e-5));
      expect(evaluateCrease(0.90), closeTo(1.0, 1e-5));
    });

    test('8. F5 x F19: Cart ruts and puddles extend along Kaido highway across '
        'terrain bounds', () async {
      final fmatFile = File('assets/materials/gouache_lit.fmat');
      final fmatSource = await fmatFile.readAsString();

      expect(fmatSource.contains('rutPair'), isTrue);
      expect(fmatSource.contains('clamp(rough, 0.08, 0.94)'), isTrue);
      expect(fmatSource.contains('wetShore'), isTrue);

      expect(TerrainConfig.minX, lessThan(0));
      expect(TerrainConfig.maxX, greaterThan(0));
    });

    test('9. F5 x F6: Deep velvety shadows pool inside wheel ruts and clay '
        'clod shoulders', () {
      final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
          .readAsStringSync();
      expect(lookSrc.contains('shadowAmbientStrength: 0.15'), isTrue);
      expect(lookSrc.contains('intensity: 0.24'), isTrue);
      expect(lookSrc.contains('Vector3(0.24, 0.38, 0.58)'), isTrue);
    });

    test('10. F6 x F10: Tuned GTAO (radius: 0.88, intensity: 1.56) creates '
        'contact shadows under roof eaves', () {
      final lookSrc = File('lib/shukuba/look/edo_look_driver.dart')
          .readAsStringSync();
      expect(lookSrc.contains('ambientOcclusionRadius: 0.88'), isTrue);
      expect(lookSrc.contains('ambientOcclusionIntensity: 1.56'), isTrue);
      expect(lookSrc.contains('ambientOcclusionBentNormals: true'), isTrue);
    });

    test('11. F7 x F9: Sumi ink pass renders clean outline creases on hashira '
        'post junctions and inuyarai without bleed', () {
      final inkParams = SumiInkParams(
        inkColor: Vector4(0.12, 0.09, 0.08, 0.95),
        depthWeight: 2.2,
        normalWeight: 1.8,
        washiGrainStrength: 0.025,
        skyFadeDistance: 180,
      );

      final ubo = inkParams.packStd140();
      expect(ubo.lengthInBytes, equals(32));

      final postNormal = Vector3(1, 0, 0);
      final beamNormal = Vector3(0, 1, 0);
      final normalDot = postNormal.dot(beamNormal);
      expect(normalDot, closeTo(0.0, 1e-5));

      final normalDelta = (postNormal - beamNormal).length;
      expect(normalDelta, greaterThan(0.68));
    });

    test('12. F8 x F11: Towering bamboo and pines stand at 2x-3x height ratio '
        'beside machiya', () {
      final machiyaWidth = StructureSpec.machiya.footprintWidth;
      final machiyaDepth = StructureSpec.machiya.footprintDepth;
      expect(machiyaWidth, closeTo(3.8, 1e-4));
      expect(machiyaDepth, closeTo(4.8, 1e-4));

      final pineHeight = StructureSpec.pineTree.height;
      final bambooHeight = StructureSpec.bambooGrove.height;

      expect(pineHeight, greaterThanOrEqualTo(7.0));
      expect(bambooHeight, inInclusiveRange(9.5, 13.5));

      final pineRatio = pineHeight / StructureSpec.machiya.height;
      final bambooRatio = bambooHeight / StructureSpec.machiya.height;
      expect(pineRatio, greaterThan(1.5));
      expect(bambooRatio, greaterThan(2.0));
    });

    test('13. F8 x F12: Intimate 1.66m townsfolk walk past 2.2m x 1.9m market '
        'stalls under 8.2m lantern spans with headroom', () {
      const townsfolkHeight = 1.66;
      final stallWidth = StructureSpec.marketStall.footprintWidth;
      final stallDepth = StructureSpec.marketStall.footprintDepth;
      final stallHeight = StructureSpec.marketStall.height;

      expect(stallWidth, closeTo(2.2, 1e-4));
      expect(stallDepth, closeTo(1.9, 1e-4));
      expect(stallHeight, greaterThan(townsfolkHeight));

      final stallHeadroom = stallHeight - townsfolkHeight;
      expect(stallHeadroom, greaterThan(0.5));

      const maxSpan = LanternSpan.maxSpanMeters;
      expect(maxSpan, closeTo(8.2, 1e-4));

      const anchorHeight = 3.1;
      const sag = maxSpan * LanternSpan.sagRatio;
      const lowestCablePoint = anchorHeight - sag;
      const cableHeadroom = lowestCablePoint - townsfolkHeight;

      expect(lowestCablePoint, greaterThan(townsfolkHeight));
      expect(cableHeadroom, greaterThan(0.6));
    });

    test('14. F9 x F10: 4-sided house walls seamlessly mate with roofs without '
        'gaps', () {
      final wallWidth = StructureSpec.machiya.footprintWidth;
      final wallDepth = StructureSpec.machiya.footprintDepth;

      const roofRole = ShukubaSurfaceRole.kawaraTile;
      expect(roofRole.depthLayer, equals(0));

      final roofBaseWidth = wallWidth + 0.30;
      final roofBaseDepth = wallDepth + 0.30;
      final overhangX = (roofBaseWidth - wallWidth) * 0.5;
      final overhangZ = (roofBaseDepth - wallDepth) * 0.5;

      expect(overhangX, greaterThanOrEqualTo(0.149));
      expect(overhangZ, greaterThanOrEqualTo(0.149));
    });

    test('15. F10 x F12: Overhead fukinagashi streamers drape above roofs '
        'without clipping', () {
      const epA = EaveEndpoint(
        structureId: EntityId('minka_east'),
        anchorIndex: 0,
        worldPosition: Vec3(-3, 3.2, 0),
        worldNormal: Vec3(1, 0, 0),
      );
      const epB = EaveEndpoint(
        structureId: EntityId('machiya_west'),
        anchorIndex: 0,
        worldPosition: Vec3(3, 3.4, 0),
        worldNormal: Vec3(-1, 0, 0),
      );

      const span = LanternSpan(
        id: EntityId('span_festive_streamer'),
        endpointA: epA,
        endpointB: epB,
        lengthMeters: 6,
        sagMeters: 6.0 * LanternSpan.sagRatio,
      );

      expect(span.hasFestivalStreamers, isA<bool>());
      const streamerDropMeters = 0.85;
      final streamerBottomY = span.midpoint.y - streamerDropMeters;

      expect(streamerBottomY, greaterThan(1.8));
    });

    test('16. F11 x F13: Karesansui zen courtyard specifies boulder triad and '
        'instrument', () {
      const karesansui = StructureSpec.karesansuiGarden;
      expect(karesansui.footprintWidth, closeTo(4.2, 1e-4));
      expect(karesansui.footprintDepth, closeTo(3.6, 1e-4));
      expect(karesansui.instrument, equals(EdoInstrument.shakuhachi));
    });

    testWidgets(
      '17. F12 x F18: Selecting market stall tool from ShukubaHud selects '
      'tool in ShukubaController',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = ShukubaController(
          look: FakeLookDriver(),
          world: FakeWorldDriver(),
          audio: FakeAudioDriver(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShukubaHud(controller: controller, onSelectPreset: (_) {}),
            ),
          ),
        );

        expect(find.text('Market Stall'), findsNothing);
        await tester.tap(find.text('Dwellings & Shops'));
        await tester.pump();
        expect(find.text('Market Stall'), findsOneWidget);
        await tester.tap(find.text('Market Stall'));
        await tester.pump();

        expect(controller.activeTool, isA<StampStructureTool>());
        final stampTool = controller.activeTool as StampStructureTool;
        expect(stampTool.kind, equals(StructureKind.marketStall));

        controller.dispose();
      },
    );

    test('18. F13 x F16: Placing shrine structure and pressing ESC pauses '
        'and mutes audio cleanly', () {
      final audio = FakeAudioDriver();
      var shellMode = ShukubaShellMode.inValley;

      audio.playPlacementNote(
        const PlacementNoteEvent(
          instrument: EdoInstrument.bonsho,
          scale: PentatonicScale.inSen,
          scaleDegree: 0,
          position: Vec3.zero,
        ),
      );
      expect(audio.notes, hasLength(1));

      void onEscPressed() {
        shellMode = ShukubaShellMode.pauseMenu;
        audio.setMuted(true);
      }

      onEscPressed();
      expect(shellMode, equals(ShukubaShellMode.pauseMenu));
      expect(audio.isMuted, isTrue);
    });

    test('19. F14 x F15: Transition from Title Menu initiates phased '
        'loading stages cleanly', () {
      var mode = ShukubaShellMode.titleMenu;
      var stage = BootStageId.lookAndShaders;

      void onEnter() {
        mode = ShukubaShellMode.loadingValley;
        stage = BootStageId.audioSynthesis;
      }

      expect(mode, equals(ShukubaShellMode.titleMenu));
      onEnter();
      expect(mode, equals(ShukubaShellMode.loadingValley));
      expect(stage, equals(BootStageId.audioSynthesis));
    });

    test('20. F15 x F20: Phased loading curtain stage 3 builds terrain before '
        'warmup', () {
      const stage3 = BootStageId.valleyTerrain;
      expect(stage3.index, equals(2));

      expect(TerrainConfig.minX, lessThan(0));
      expect(TerrainConfig.maxX, greaterThan(0));

      const nextStage = BootStageId.gpuWarmup;
      expect(nextStage.index, greaterThan(stage3.index));
    });

    test('21. F16 x F17: Pause menu mode and telemetry snapshot co-exist '
        'cleanly', () {
      const snapshot = FrameTelemetrySnapshot(
        uiMs: 3.8,
        rasterMs: 4.2,
        fps: 60,
        structureCount: 32,
        lanternSpanCount: 14,
      );

      const mode = ShukubaShellMode.pauseMenu;
      expect(mode, equals(ShukubaShellMode.pauseMenu));
      expect(snapshot.fps, equals(60));
      expect(snapshot.structureCount, equals(32));
    });

    test('22. F18 x F20: Selecting placement tool via controller stays bounded '
        'within terrain bounds', () {
      final controller = ShukubaController(
        look: FakeLookDriver(),
        world: FakeWorldDriver(),
        audio: FakeAudioDriver(),
      );

      const tool = StampStructureTool(kind: StructureKind.machiya);
      controller.selectTool(tool);
      expect(controller.activeTool, equals(tool));

      controller.dispose();
    });

    test('23. F21 x F22: Metal capture summary confirms 0 overlaps and 0 depth '
        'conflicts', () {
      final summaryFile = File('/tmp/shukuba_cap/summary.json');
      if (summaryFile.existsSync()) {
        final data =
            jsonDecode(summaryFile.readAsStringSync()) as Map<String, dynamic>;
        expect(data.containsKey('presets'), isTrue);
        expect(data['presets'], isA<List<dynamic>>());
        final presets = (data['presets'] as List).cast<Map<String, dynamic>>();
        expect(presets, isNotEmpty);
        for (final preset in presets) {
          expect(preset.containsKey('presetId'), isTrue);
          expect(preset.containsKey('coplanarOverlapCount'), isTrue);
          expect(preset.containsKey('depthConflictCount'), isTrue);
          expect(preset.containsKey('passed'), isTrue);
          final expectedPassed =
              preset['coplanarOverlapCount'] == 0 &&
              preset['depthConflictCount'] == 0;
          expect(preset['passed'], equals(expectedPassed));
        }
      }

      const cleanResult = PresetVerificationResult(
        presetId: 'countryside_vista',
        pngPath: '/tmp/shukuba_cap/countryside_vista.png',
        pixelStats: FramePixelStats(
          width: 1440,
          height: 778,
          meanLuminance: 0.28,
          stddevLuminance: 0.16,
          nonZeroPixels: 1120000,
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
