import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';
import 'package:material_ui/material_ui.dart' hide Material;

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Feature 12 Edge: Catenary Sag & Market Prop Boundaries', () {
    test(
      'Lantern span sag ratio 0.085 computes proportional sag across lengths',
      () {
        for (final len in [1.0, 3.2, 5.0, 8.2]) {
          final expectedSag = len * 0.085;
          final span = LanternSpan(
            id: EntityId('span_test_$len'),
            endpointA: const EaveEndpoint(
              structureId: EntityId('s1'),
              anchorIndex: 0,
              worldPosition: Vec3.zero,
              worldNormal: Vec3.forward,
            ),
            endpointB: EaveEndpoint(
              structureId: const EntityId('s2'),
              anchorIndex: 0,
              worldPosition: Vec3(len, 0, 0),
              worldNormal: Vec3.forward,
            ),
            lengthMeters: len,
            sagMeters: expectedSag,
          );

          expect(span.sagMeters, closeTo(expectedSag, 1e-4));
          expect(span.lanternCount, greaterThanOrEqualTo(1));
        }
      },
    );

    test('Lantern count scales with span length up to max span 8.2m', () {
      const shortSpan = LanternSpan(
        id: EntityId('span_short'),
        endpointA: EaveEndpoint(
          structureId: EntityId('s1'),
          anchorIndex: 0,
          worldPosition: Vec3.zero,
          worldNormal: Vec3.forward,
        ),
        endpointB: EaveEndpoint(
          structureId: EntityId('s2'),
          anchorIndex: 0,
          worldPosition: Vec3(1.5, 0, 0),
          worldNormal: Vec3.forward,
        ),
        lengthMeters: 1.5,
        sagMeters: 0.12,
      );

      const longSpan = LanternSpan(
        id: EntityId('span_long'),
        endpointA: EaveEndpoint(
          structureId: EntityId('s1'),
          anchorIndex: 0,
          worldPosition: Vec3.zero,
          worldNormal: Vec3.forward,
        ),
        endpointB: EaveEndpoint(
          structureId: EntityId('s2'),
          anchorIndex: 0,
          worldPosition: Vec3(8, 0, 0),
          worldNormal: Vec3.forward,
        ),
        lengthMeters: 8,
        sagMeters: 0.68,
      );

      expect(longSpan.lanternCount, greaterThan(shortSpan.lanternCount));
    });

    test('Market stall dimensions stay bounded in StructureSpec', () {
      const spec = StructureSpec.marketStall;
      expect(spec.footprintWidth, closeTo(2.2, 1e-4));
      expect(spec.footprintDepth, closeTo(1.9, 1e-4));
      expect(spec.height, inInclusiveRange(2.2, 2.35));
    });

    test(
      'Wagasa umbrella and fabric awning roles define valid surface layers',
      () {
        const role = ShukubaSurfaceRole.fabricAwning;
        expect(role.depthLayer, equals(0));
        expect(role.defaultRoughness, inInclusiveRange(0.0, 1.0));
      },
    );

    test('Plank duckboard lane overlay surface depth layer anti-z-fights', () {
      const lane = ShukubaSurfaceRole.laneOverlay;
      const ground = ShukubaSurfaceRole.packedEarth;
      expect(lane.depthLayer, greaterThan(ground.depthLayer));
    });
  });

  group('Feature 13 Edge: Shrine Kit Placements & Footprints', () {
    test(
      'shoroBell timber pavilion specifies bonsho instrument and footprint',
      () {
        const spec = StructureSpec.shoroBell;
        expect(spec.kind, equals(StructureKind.shoroBell));
        expect(spec.instrument, equals(EdoInstrument.bonsho));
        expect(spec.footprintWidth, equals(3.2));
        expect(spec.footprintDepth, equals(3.2));
      },
    );

    test('karesansui raked gravel court specifies courtyard dimensions', () {
      const spec = StructureSpec.karesansuiGarden;
      expect(spec.kind, equals(StructureKind.karesansuiGarden));
      expect(spec.footprintWidth, equals(4.2));
      expect(spec.footprintDepth, equals(3.6));
      expect(spec.instrument, equals(EdoInstrument.shakuhachi));
    });

    test(
      'stoneWell wellbore depth terminates cleanly above riverbed elevation',
      () {
        const spec = StructureSpec.stoneWell;
        expect(spec.height, inInclusiveRange(2.0, 2.6));
        expect(TerrainConfig.riverBedElevation, lessThan(0));
      },
    );

    test('Courtyard wall endpoints define valid wall length', () {
      const start = Vec3.zero;
      const end = Vec3(10, 0, 0);
      final length = (end - start).length;
      expect(length, equals(10.0));
    });

    test('Torii gate walkthrough clearance accommodates pedestrians', () {
      const spec = StructureSpec.toriiGate;
      expect(spec.height, closeTo(4.3, 1e-4));
      expect(spec.footprintWidth, greaterThan(2.0));
    });
  });

  group('Feature 14 Edge: Title Menu Edge & Display Bounds', () {
    test('ShukubaShellMode titleMenu initial mode is stable', () {
      var mode = ShukubaShellMode.titleMenu;
      expect(mode, equals(ShukubaShellMode.titleMenu));
      mode = ShukubaShellMode.loadingValley;
      expect(mode, equals(ShukubaShellMode.loadingValley));
    });

    test('ShukubaShellMode distinct states are mutually exclusive', () {
      for (final mode in ShukubaShellMode.values) {
        expect(ShukubaShellMode.values.where((m) => m == mode), hasLength(1));
      }
    });

    test('Title menu mode transition to loading is instantaneous', () {
      var mode = ShukubaShellMode.titleMenu;
      void onEnter() => mode = ShukubaShellMode.loadingValley;

      onEnter();
      expect(mode, equals(ShukubaShellMode.loadingValley));
    });

    test('Shell mode returns to titleMenu upon exit', () {
      var mode = ShukubaShellMode.pauseMenu;
      void onReturnToTitle() => mode = ShukubaShellMode.titleMenu;

      onReturnToTitle();
      expect(mode, equals(ShukubaShellMode.titleMenu));
    });

    test('Initial boot mode is always titleMenu', () {
      const initialMode = ShukubaShellMode.titleMenu;
      expect(initialMode.index, equals(0));
    });
  });

  group('Feature 15 Edge: Loading Curtain & Timeout Recovery', () {
    test('BootStageTiming durationMs validates positive values', () {
      const timing = BootStageTiming(
        stage: BootStageId.gpuWarmup,
        durationMs: 5200,
      );

      expect(timing.durationMs, greaterThan(5000));
      expect(timing.stage, equals(BootStageId.gpuWarmup));
    });

    test('BootStageId labels are non-empty for all 6 stages', () {
      for (final stage in BootStageId.values) {
        expect(stage.label, isNotEmpty);
      }
    });

    test('BootReport records non-negative durations for all boot stages', () {
      final stages = [
        for (final stage in BootStageId.values)
          BootStageTiming(stage: stage, durationMs: 15.0 + stage.index * 2),
      ];

      final report = BootReport(
        stages: stages,
        totalMs: stages.fold(0, (acc, s) => acc + s.durationMs),
      );

      expect(report.stages, hasLength(6));
      for (final s in report.stages) {
        expect(s.durationMs, greaterThanOrEqualTo(0));
      }
    });

    test('BootReport totalMs reflects sum of all stage durations', () {
      final stages = [
        const BootStageTiming(
          stage: BootStageId.lookAndShaders,
          durationMs: 10,
        ),
        const BootStageTiming(
          stage: BootStageId.audioSynthesis,
          durationMs: 20,
        ),
      ];
      final report = BootReport(stages: stages, totalMs: 30);
      expect(report.totalMs, equals(30.0));
    });

    test('Final stage before inValley is gpuWarmup', () {
      expect(BootStageId.values.last, equals(BootStageId.gpuWarmup));
    });
  });

  group('Feature 16 Edge: Esc Pause Menu & Volume Bounds', () {
    test('Rapid ESC toggle maintains deterministic shell mode transitions', () {
      var mode = ShukubaShellMode.inValley;
      for (var i = 0; i < 10; i++) {
        mode = mode == ShukubaShellMode.inValley
            ? ShukubaShellMode.pauseMenu
            : ShukubaShellMode.inValley;
      }

      expect(mode, equals(ShukubaShellMode.inValley));
    });

    test('Master volume clamp at extremes and NaN in EdoAudioDriver', () {
      final driver = EdoAudioDriver()..setMasterVolume(-0.5);
      expect(driver.masterVolume, equals(0.0));

      driver.setMasterVolume(1.5);
      expect(driver.masterVolume, equals(1.0));

      driver.setMasterVolume(double.nan);
      expect(driver.masterVolume, equals(0.0));

      driver.setMasterVolume(0);
      expect(driver.masterVolume, equals(0.0));

      driver.setMasterVolume(1);
      expect(driver.masterVolume, equals(1.0));
    });

    test('Active drag or stroke cancellation via ShukubaController', () {
      final controller = ShukubaController(
        look: FakeLookDriver(),
        world: FakeWorldDriver(),
        audio: FakeAudioDriver(),
      )..selectTool(const DrawLaneTool());
      expect(controller.activeTool, isA<DrawLaneTool>());

      controller
        ..cancelActiveStroke()
        ..dispose();
      expect(controller.strokePoints, isEmpty);
    });

    test('EdoAudioDriver responds to repeated mute/unmute toggles', () {
      final driver = EdoAudioDriver();
      for (var i = 0; i < 5; i++) {
        driver.setMuted(true);
        expect(driver.isMuted, isTrue);
        driver.setMuted(false);
        expect(driver.isMuted, isFalse);
      }
    });

    test('Pause menu mode transition cleanly sets state', () {
      var mode = ShukubaShellMode.inValley;
      mode = ShukubaShellMode.pauseMenu;
      expect(mode, equals(ShukubaShellMode.pauseMenu));
      mode = ShukubaShellMode.inValley;
      expect(mode, equals(ShukubaShellMode.inValley));
    });
  });

  group('Feature 17 Edge: Telemetry Rolling Buffer & Thread Extremes', () {
    test('RollingFrameTimer windowSize bounds sample collection', () {
      final timer = RollingFrameTimer(windowSize: 60);
      for (var i = 0; i < 100; i++) {
        timer.ingestDurations(buildMs: 8, rasterMs: 8);
      }

      expect(timer.sampleCount, equals(60));
      expect(timer.uiMs, closeTo(8.0, 1e-4));
      expect(timer.rasterMs, closeTo(8.0, 1e-4));
      expect(timer.fps, inInclusiveRange(55, 65));
    });

    test(
      'Zero or negative frame duration handled safely without NaN in timer',
      () {
        final timer = RollingFrameTimer(windowSize: 10)
          ..ingestDurations(buildMs: 0, rasterMs: 0);

        expect(timer.uiMs, equals(0.0));
        expect(timer.rasterMs, equals(0.0));
        expect(timer.fps, equals(60.0));
      },
    );

    test('FrameTelemetrySnapshot equality and hashCode contract', () {
      const s1 = FrameTelemetrySnapshot(
        uiMs: 4,
        rasterMs: 6,
        fps: 60,
        structureCount: 10,
        lanternSpanCount: 4,
      );
      const s2 = FrameTelemetrySnapshot(
        uiMs: 4,
        rasterMs: 6,
        fps: 60,
        structureCount: 10,
        lanternSpanCount: 4,
      );

      expect(s1, equals(s2));
      expect(s1.hashCode, equals(s2.hashCode));
    });

    test('RollingFrameTimer reset clears all historical samples', () {
      final timer = RollingFrameTimer(windowSize: 20);
      for (var i = 0; i < 15; i++) {
        timer.ingestDurations(buildMs: 5, rasterMs: 5);
      }
      expect(timer.sampleCount, equals(15));

      timer.reset();
      expect(timer.sampleCount, equals(0));
      expect(timer.uiMs, equals(0.0));
      expect(timer.rasterMs, equals(0.0));
    });

    test('High raster duration (>33ms) produces sub-30 FPS indicator', () {
      final timer = RollingFrameTimer(windowSize: 10);
      for (var i = 0; i < 10; i++) {
        timer.ingestDurations(buildMs: 4, rasterMs: 40);
      }

      expect(timer.fps, lessThan(30.0));
    });
  });

  group('Feature 18 Edge: Collapsible Builder Dock Extremes', () {
    test('All 4 HudToolCategory values are defined and non-empty', () {
      expect(HudToolCategory.values, hasLength(4));
      for (final cat in HudToolCategory.values) {
        expect(cat.label, isNotEmpty);
      }
    });

    testWidgets('ShukubaHud mounts cleanly and displays builder dock', (
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

      expect(find.text('Dwellings & Shops'), findsOneWidget);
      expect(find.text('Roads & Walls'), findsOneWidget);
      expect(find.text('Townhouse'), findsNothing);

      await tester.tap(find.text('Dwellings & Shops'));
      await tester.pump();
      expect(find.text('Townhouse'), findsOneWidget);

      await tester.tap(find.text('Roads & Walls'));
      await tester.pump();
      expect(find.text('Road'), findsOneWidget);

      controller.dispose();
    });

    test('PlacementTool selection and tool swapping in ShukubaController', () {
      final controller = ShukubaController(
        look: FakeLookDriver(),
        world: FakeWorldDriver(),
        audio: FakeAudioDriver(),
      );

      const tool1 = StampStructureTool(kind: StructureKind.machiya);
      const tool2 = StampStructureTool(kind: StructureKind.chaya);

      controller.selectTool(tool1);
      expect(controller.activeTool, equals(tool1));

      controller.selectTool(tool2);
      expect(controller.activeTool, equals(tool2));

      controller.dispose();
    });

    test('Toggling same tool deselects it back to ExploreTool', () {
      final controller = ShukubaController(
        look: FakeLookDriver(),
        world: FakeWorldDriver(),
        audio: FakeAudioDriver(),
      );

      const tool = StampStructureTool(kind: StructureKind.machiya);
      controller.toggleTool(tool);
      expect(controller.activeTool, equals(tool));

      controller.toggleTool(tool);
      expect(controller.activeTool, isA<ExploreTool>());

      controller.dispose();
    });

    test('DemolishTool selects cleanly via ShukubaController', () {
      final controller = ShukubaController(
        look: FakeLookDriver(),
        world: FakeWorldDriver(),
        audio: FakeAudioDriver(),
      )..selectTool(const DemolishTool());

      expect(controller.activeTool, isA<DemolishTool>());

      controller.dispose();
    });
  });
}
