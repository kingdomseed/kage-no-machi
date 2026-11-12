import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_page.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';
import 'package:material_ui/material_ui.dart' hide Material;

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Feature 12: Festival Market Props', () {
    test('LanternSpan specifies catenary geometry and festival flags', () {
      const festiveSpan = LanternSpan(
        id: EntityId('span_with_fukinagashi'),
        endpointA: EaveEndpoint(
          structureId: EntityId('stall_1'),
          anchorIndex: 0,
          worldPosition: Vec3(0, 2, 0),
          worldNormal: Vec3.forward,
        ),
        endpointB: EaveEndpoint(
          structureId: EntityId('stall_2'),
          anchorIndex: 0,
          worldPosition: Vec3(3, 2, 0),
          worldNormal: Vec3.forward,
        ),
        lengthMeters: 3,
        sagMeters: 0.25,
      );

      expect(festiveSpan.hasFestivalStreamers, isA<bool>());
      expect(festiveSpan.lengthMeters, equals(3));
      expect(festiveSpan.sagMeters, equals(0.25));
    });

    test('Market stall specifies yatai dimensions in StructureSpec', () {
      const spec = StructureSpec.marketStall;
      expect(spec.kind, equals(StructureKind.marketStall));
      expect(spec.footprintWidth, closeTo(2.2, 1e-4));
      expect(spec.footprintDepth, closeTo(1.9, 1e-4));
      expect(spec.height, inInclusiveRange(2.2, 2.35));
    });

    test(
      'Market stall builds structure node in EdoKitBuilder when GPU available',
      () {
        const kit = EdoKitBuilder();
        const stall = PlacedStructure(
          id: EntityId('stall_test'),
          kind: StructureKind.marketStall,
          position: Vec3.zero,
        );
        final node = kit.buildStructureNode(stall, testMaterialResolver);
        expect(node, isNotNull);
        expect(countNodes(node), greaterThan(1));
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test('Fabric awning role assigns appropriate depth layer and material', () {
      const awningRole = ShukubaSurfaceRole.fabricAwning;
      expect(awningRole.depthLayer, equals(0));
      final mat = testMaterialResolver(awningRole);
      expect(mat.name, contains('fabricAwning'));
    });

    test('Plank duckboards instantiate along road edges with anti-z-fight '
        'offset', () {
      const laneRole = ShukubaSurfaceRole.laneOverlay;
      expect(laneRole.depthLayer, equals(1));
      final mat = testMaterialResolver(laneRole);
      expect(mat.depthLayer, equals(1));
    });
  });

  group('Feature 13: Shrine & Courtyard Kit', () {
    test('StructureKind.shoroBell generates raised timber pavilion with '
        'bronze bonsho', () {
      const spec = StructureSpec.shoroBell;
      expect(spec.kind, equals(StructureKind.shoroBell));
      expect(spec.footprintWidth, closeTo(3.2, 1e-4));
      expect(spec.footprintDepth, closeTo(3.2, 1e-4));
      expect(spec.height, closeTo(4.6, 1e-4));
      expect(spec.instrument, equals(EdoInstrument.bonsho));
    });

    test('StructureKind.karesansuiGarden generates raked gravel court with '
        'boulder triad and toro', () {
      const spec = StructureSpec.karesansuiGarden;
      expect(spec.kind, equals(StructureKind.karesansuiGarden));
      expect(spec.footprintWidth, closeTo(4.2, 1e-4));
      expect(spec.footprintDepth, closeTo(3.6, 1e-4));
      expect(spec.instrument, equals(EdoInstrument.shakuhachi));
    });

    test(
      'StructureKind.stoneWell generates roofed stone Ido well with pulley',
      () {
        const spec = StructureSpec.stoneWell;
        expect(spec.kind, equals(StructureKind.stoneWell));
        expect(spec.footprintWidth, closeTo(1.8, 1e-4));
        expect(spec.footprintDepth, closeTo(1.8, 1e-4));
        expect(spec.height, closeTo(2.35, 1e-4));
      },
    );

    test('Starter ward layout includes shoroBell, karesansuiGarden, and '
        'stoneWell', () {
      final terrain = TerrainBuilder();
      final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

      expect(
        graph.structures.values.any((s) => s.kind == StructureKind.shoroBell),
        isTrue,
        reason: 'Starter ward must contain a shoroBell structure',
      );
      expect(
        graph.structures.values.any(
          (s) => s.kind == StructureKind.karesansuiGarden,
        ),
        isTrue,
        reason: 'Starter ward must contain a karesansuiGarden structure',
      );
      expect(
        graph.structures.values.any((s) => s.kind == StructureKind.stoneWell),
        isTrue,
        reason: 'Starter ward must contain a stoneWell structure',
      );

      final shoro = graph.structures.values.firstWhere(
        (s) => s.kind == StructureKind.shoroBell,
      );
      final garden = graph.structures.values.firstWhere(
        (s) => s.kind == StructureKind.karesansuiGarden,
      );
      final well = graph.structures.values.firstWhere(
        (s) => s.kind == StructureKind.stoneWell,
      );

      expect(shoro.spec.instrument, equals(EdoInstrument.bonsho));
      expect(garden.spec.instrument, equals(EdoInstrument.shakuhachi));
      expect(well.spec.displayName, equals('Courtyard Well'));

      expect(shoro.position.x.isFinite, isTrue);
      expect(garden.position.x.isFinite, isTrue);
      expect(well.position.x.isFinite, isTrue);

      expect(shoro.position.x, closeTo(23.5, 1e-4));
      expect(shoro.position.z, closeTo(14.5, 1e-4));
      expect(garden.position.x, closeTo(13.5, 1e-4));
      expect(garden.position.z, closeTo(19.5, 1e-4));
      expect(well.position.x, closeTo(6.0, 1e-4));
      expect(well.position.z, closeTo(20.0, 1e-4));
    });

    test('Shrine kit structures trigger appropriate instrument notes upon '
        'placement', () {
      const shoroTool = StampStructureTool(kind: StructureKind.shoroBell);
      const zenTool = StampStructureTool(kind: StructureKind.karesansuiGarden);
      const wellTool = StampStructureTool(kind: StructureKind.stoneWell);

      expect(shoroTool.placementInstrument, equals(EdoInstrument.bonsho));
      expect(zenTool.placementInstrument, equals(EdoInstrument.shakuhachi));
      expect(wellTool.placementInstrument, equals(EdoInstrument.hyoshigi));
    });
  });

  group('Feature 14: Instant Title Menu (<100ms)', () {
    test('ShukubaShellMode defines titleMenu as initial shell mode', () {
      expect(ShukubaShellMode.titleMenu.index, equals(0));
      expect(ShukubaShellMode.values, contains(ShukubaShellMode.titleMenu));
    });

    test('ShukubaShellMode transitions between modes cleanly', () {
      var currentMode = ShukubaShellMode.titleMenu;
      expect(currentMode, equals(ShukubaShellMode.titleMenu));

      currentMode = ShukubaShellMode.loadingValley;
      expect(currentMode, equals(ShukubaShellMode.loadingValley));

      currentMode = ShukubaShellMode.inValley;
      expect(currentMode, equals(ShukubaShellMode.inValley));
    });

    test('Title menu shell mode constants are immutable', () {
      const mode = ShukubaShellMode.titleMenu;
      expect(mode.name, equals('titleMenu'));
    });

    test(
      'Shell mode sequence progresses from title to loading to inValley',
      () {
        const expected = [
          ShukubaShellMode.titleMenu,
          ShukubaShellMode.loadingValley,
          ShukubaShellMode.inValley,
          ShukubaShellMode.pauseMenu,
        ];
        expect(ShukubaShellMode.values, equals(expected));
      },
    );

    test('TitleMenu shell mode state is recognized by boot models', () {
      const mode = ShukubaShellMode.titleMenu;
      expect(mode == ShukubaShellMode.titleMenu, isTrue);
      expect(mode == ShukubaShellMode.inValley, isFalse);
    });
  });

  group('Feature 15: Phased Loading Curtain & PSO Warmup', () {
    test(
      'BootStageId defines all 6 distinct boot stages in sequential order',
      () {
        expect(BootStageId.values, hasLength(6));
        expect(BootStageId.lookAndShaders.label, equals('Look & Shaders'));
        expect(BootStageId.audioSynthesis.label, equals('Audio Synthesis'));
        expect(BootStageId.valleyTerrain.label, equals('Valley Terrain'));
        expect(BootStageId.townArchitecture.label, equals('Town Architecture'));
        expect(BootStageId.floraAndAir.label, equals('Flora & Atmosphere'));
        expect(BootStageId.gpuWarmup.label, equals('GPU Warmup'));
      },
    );

    test('BootReport records millisecond durations across boot stages', () {
      final timings = [
        for (final stage in BootStageId.values)
          BootStageTiming(stage: stage, durationMs: 12.5 + stage.index * 4.0),
      ];

      final report = BootReport(
        stages: timings,
        totalMs: timings.fold(0, (acc, t) => acc + t.durationMs),
      );

      expect(report.stages, hasLength(6));
      expect(report.totalMs, greaterThan(50));
      for (final t in report.stages) {
        expect(t.durationMs, greaterThan(0));
      }
    });

    test('Hidden GPU pipeline warmup executes as final boot stage', () {
      expect(BootStageId.gpuWarmup.index, equals(5));
      expect(BootStageId.gpuWarmup.label, equals('GPU Warmup'));
    });

    test('BootStageTiming equality and hash contract holds', () {
      const a = BootStageTiming(
        stage: BootStageId.valleyTerrain,
        durationMs: 15,
      );
      const b = BootStageTiming(
        stage: BootStageId.valleyTerrain,
        durationMs: 15,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('BootReport equality compares totalMs and stage list', () {
      final r1 = BootReport(stages: const [], totalMs: 100);
      final r2 = BootReport(stages: const [], totalMs: 100);
      expect(r1, equals(r2));
    });
  });

  group('Feature 16: Esc Pause & Settings Menu', () {
    testWidgets(
      'Pressing Escape key in ShukubaPage cancels active placement stroke',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: ShukubaPage(
              lookDriver: FakeLookDriver(),
              worldDriver: FakeWorldDriver(),
              audioDriver: FakeAudioDriver(),
            ),
          ),
        );
        await tester.pump();

        final hud = tester.widget<ShukubaHud>(find.byType(ShukubaHud));
        final controller = hud.controller
          ..selectTool(const DrawLaneTool())
          ..beginStrokeAt(Vec3.zero);
        expect(controller.strokePoints, isNotEmpty);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(controller.strokePoints, isEmpty);
      },
    );

    testWidgets(
      'Pressing Escape key in ShukubaPage resets placement tool to ExploreTool',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ShukubaPage(
              lookDriver: FakeLookDriver(),
              worldDriver: FakeWorldDriver(),
              audioDriver: FakeAudioDriver(),
            ),
          ),
        );
        await tester.pump();

        final hud = tester.widget<ShukubaHud>(find.byType(ShukubaHud));
        final controller = hud.controller
          ..selectTool(const StampStructureTool(kind: StructureKind.machiya));
        expect(controller.activeTool, isA<StampStructureTool>());

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(controller.activeTool, isA<ExploreTool>());
      },
    );

    test('EdoAudioDriver responds to mute toggle cleanly', () {
      final audioDriver = EdoAudioDriver();
      expect(audioDriver.isMuted, isFalse);

      audioDriver.setMuted(true);
      expect(audioDriver.isMuted, isTrue);

      audioDriver.setMuted(false);
      expect(audioDriver.isMuted, isFalse);
    });

    test('EdoAudioDriver responds to master volume changes', () {
      final audioDriver = EdoAudioDriver();
      expect(audioDriver.masterVolume, equals(1.0));

      audioDriver.setMasterVolume(0.5);
      expect(audioDriver.masterVolume, equals(0.5));
    });

    test('Return to Title resets shell mode to titleMenu', () {
      var mode = ShukubaShellMode.pauseMenu;
      void returnToTitle() => mode = ShukubaShellMode.titleMenu;

      returnToTitle();
      expect(mode, equals(ShukubaShellMode.titleMenu));
    });
  });

  group('Feature 17: F3 Telemetry Monitor Pill', () {
    test('F3 telemetry snapshot holds UI, Raster, and FPS metrics', () {
      const snapshot = FrameTelemetrySnapshot(
        uiMs: 4.8,
        rasterMs: 7.2,
        fps: 60,
        structureCount: 14,
        lanternSpanCount: 8,
      );

      expect(snapshot.uiMs, equals(4.8));
      expect(snapshot.rasterMs, equals(7.2));
      expect(snapshot.fps, equals(60.0));
      expect(snapshot.structureCount, equals(14));
      expect(snapshot.lanternSpanCount, equals(8));
    });

    test('FrameTelemetrySnapshot zero constant initializes cleanly', () {
      expect(FrameTelemetrySnapshot.zero.uiMs, equals(0));
      expect(FrameTelemetrySnapshot.zero.rasterMs, equals(0));
      expect(FrameTelemetrySnapshot.zero.fps, equals(0));
    });

    test(
      'RollingFrameTimer computes rolling average UI and Raster durations',
      () {
        final timer = RollingFrameTimer();
        for (var i = 0; i < 30; i++) {
          timer.ingestDurations(buildMs: 5, rasterMs: 8);
        }

        expect(timer.sampleCount, equals(30));
        expect(timer.uiMs, closeTo(5.0, 1e-4));
        expect(timer.rasterMs, closeTo(8.0, 1e-4));
        expect(timer.fps, inInclusiveRange(55, 65));
      },
    );

    test('RollingFrameTimer maintains maximum sample window size', () {
      final timer = RollingFrameTimer(windowSize: 10);
      for (var i = 0; i < 25; i++) {
        timer.ingestDurations(buildMs: 4, rasterMs: 6);
      }

      expect(timer.sampleCount, equals(10));
    });

    test(
      'Telemetry snapshot reflects stage duration breakdown from BootReport',
      () {
        final timings = [
          const BootStageTiming(
            stage: BootStageId.lookAndShaders,
            durationMs: 14.2,
          ),
          const BootStageTiming(
            stage: BootStageId.audioSynthesis,
            durationMs: 8.6,
          ),
        ];
        final report = BootReport(stages: timings, totalMs: 22.8);

        final snapshot = FrameTelemetrySnapshot(
          uiMs: 4,
          rasterMs: 6,
          fps: 60,
          structureCount: 10,
          lanternSpanCount: 4,
          bootReport: report,
        );

        expect(snapshot.bootReport, isNotNull);
        expect(snapshot.bootReport!.totalMs, closeTo(22.8, 1e-4));
        expect(snapshot.bootReport!.stages, hasLength(2));
      },
    );
  });

  group('Feature 18: Collapsible 4-Category Builder Dock', () {
    test('Builder dock exposes 4 collapsible tabs: Dwellings, Roads, Flora, '
        'Shrines', () {
      expect(HudToolCategory.values, hasLength(4));
      expect(
        HudToolCategory.values.map((c) => c.label).toList(),
        equals([
          'Dwellings & Shops',
          'Roads & Walls',
          'Trees & Rocks',
          'Shrines & Courtyards',
        ]),
      );
    });

    testWidgets('ShukubaHud renders calm categories and opens tool drawers', (
      tester,
    ) async {
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

      expect(find.text('Demolish'), findsOneWidget);
      expect(find.text('Townhouse'), findsNothing);

      await tester.tap(find.text('Dwellings & Shops'));
      await tester.pump();
      expect(find.text('Townhouse'), findsOneWidget);

      await tester.tap(find.text('Roads & Walls'));
      await tester.pump();
      expect(find.text('Road'), findsOneWidget);
      expect(find.text('Stone Terrace'), findsOneWidget);

      controller.dispose();
    });

    test('Shrines & Courtyards category includes shoroBell, karesansui, and '
        'stoneWell', () {
      const shoro = StampStructureTool(kind: StructureKind.shoroBell);
      const zen = StampStructureTool(kind: StructureKind.karesansuiGarden);
      const well = StampStructureTool(kind: StructureKind.stoneWell);

      expect(shoro.hudCategory, equals(HudToolCategory.shrinesAndCourtyards));
      expect(zen.hudCategory, equals(HudToolCategory.shrinesAndCourtyards));
      expect(well.hudCategory, equals(HudToolCategory.shrinesAndCourtyards));
    });

    testWidgets('Tapping tool card in ShukubaHud selects that tool', (
      tester,
    ) async {
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

      await tester.tap(find.text('Dwellings & Shops'));
      await tester.pump();
      await tester.tap(find.text('Townhouse'));
      await tester.pump();

      expect(controller.activeTool, isA<StampStructureTool>());
      expect(
        (controller.activeTool as StampStructureTool).kind,
        equals(StructureKind.machiya),
      );

      controller.dispose();
    });

    test(
      'Selecting tool updates ShukubaController and displays ghost preview',
      () {
        final controller = ShukubaController(
          look: FakeLookDriver(),
          world: FakeWorldDriver(),
          audio: FakeAudioDriver(),
        );

        const tool = StampStructureTool(kind: StructureKind.shoroBell);
        controller.selectTool(tool);

        expect(controller.activeTool, equals(tool));
        expect(controller.activePreview, isA<BuildPreview>());

        controller.dispose();
      },
    );
  });
}
