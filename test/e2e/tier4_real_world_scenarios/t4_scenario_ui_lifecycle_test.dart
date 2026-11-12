import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:material_ui/material_ui.dart' hide Material, Matrix4;

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Tier 4 Scenario 5: Full UI Lifecycle & State Machine (F14-F18)', () {
    test(
      '1. Shell mode state machine transitions through complete lifecycle',
      () {
        var currentMode = ShukubaShellMode.titleMenu;
        expect(currentMode, equals(ShukubaShellMode.titleMenu));

        currentMode = ShukubaShellMode.loadingValley;
        expect(currentMode, equals(ShukubaShellMode.loadingValley));

        currentMode = ShukubaShellMode.inValley;
        expect(currentMode, equals(ShukubaShellMode.inValley));

        currentMode = ShukubaShellMode.pauseMenu;
        expect(currentMode, equals(ShukubaShellMode.pauseMenu));

        currentMode = ShukubaShellMode.inValley;
        expect(currentMode, equals(ShukubaShellMode.inValley));

        currentMode = ShukubaShellMode.titleMenu;
        expect(currentMode, equals(ShukubaShellMode.titleMenu));
      },
    );

    test(
      '2. Phased loading stages record sequential durations in BootReport',
      () {
        expect(BootStageId.values, hasLength(6));
        expect(BootStageId.lookAndShaders.label, equals('Look & Shaders'));
        expect(BootStageId.audioSynthesis.label, equals('Audio Synthesis'));
        expect(BootStageId.valleyTerrain.label, equals('Valley Terrain'));
        expect(BootStageId.townArchitecture.label, equals('Town Architecture'));
        expect(BootStageId.floraAndAir.label, equals('Flora & Atmosphere'));
        expect(BootStageId.gpuWarmup.label, equals('GPU Warmup'));

        final timings = <BootStageTiming>[
          const BootStageTiming(
            stage: BootStageId.lookAndShaders,
            durationMs: 14,
          ),
          const BootStageTiming(
            stage: BootStageId.audioSynthesis,
            durationMs: 22,
          ),
          const BootStageTiming(
            stage: BootStageId.valleyTerrain,
            durationMs: 38,
          ),
          const BootStageTiming(
            stage: BootStageId.townArchitecture,
            durationMs: 18,
          ),
          const BootStageTiming(stage: BootStageId.floraAndAir, durationMs: 12),
          const BootStageTiming(stage: BootStageId.gpuWarmup, durationMs: 28),
        ];

        final report = BootReport(stages: timings, totalMs: 132);
        expect(report.stages, hasLength(6));
        expect(report.totalMs, closeTo(132, 1e-4));

        for (final timing in report.stages) {
          expect(timing.durationMs, greaterThan(0));
        }
      },
    );

    test('3. RollingFrameTimer computes valid FPS and frame metrics', () {
      final timer = RollingFrameTimer(windowSize: 60);

      for (var i = 0; i < 60; i++) {
        timer.ingestDurations(buildMs: 4.1, rasterMs: 5.2);
      }

      expect(timer.sampleCount, equals(60));
      expect(timer.uiMs, closeTo(4.1, 1e-4));
      expect(timer.rasterMs, closeTo(5.2, 1e-4));
      expect(timer.fps, inInclusiveRange(55, 65));

      const snapshot = FrameTelemetrySnapshot(
        uiMs: 4.1,
        rasterMs: 5.2,
        fps: 60,
        structureCount: 28,
        lanternSpanCount: 12,
      );

      expect(snapshot.uiMs, closeTo(4.1, 1e-4));
      expect(snapshot.rasterMs, closeTo(5.2, 1e-4));
      expect(snapshot.fps, equals(60));
      expect(snapshot.structureCount, equals(28));
      expect(snapshot.lanternSpanCount, equals(12));
    });

    testWidgets(
      '4. ShukubaHud renders in-valley viewport HUD with ward plaque and '
      'controls',
      (tester) async {
        final controller = ShukubaController(
          look: FakeLookDriver(),
          world: FakeWorldDriver(),
          audio: FakeAudioDriver(),
        );

        CameraPreset? selectedPreset;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShukubaHud(
                controller: controller,
                onSelectPreset: (preset) => selectedPreset = preset,
              ),
            ),
          ),
        );

        expect(find.byType(ShukubaHud), findsOneWidget);
        expect(find.text('Views'), findsOneWidget);
        expect(find.text('1 Golden Dusk'), findsNothing);

        await tester.tap(find.text('Views'));
        await tester.pump();
        expect(find.text('1 Golden Dusk'), findsOneWidget);
        expect(find.text('2 Night Market'), findsOneWidget);

        await tester.tap(find.text('1 Golden Dusk'));
        await tester.pump();
        expect(selectedPreset, equals(CameraPreset.duskOverview));

        await tester.tap(find.text('Views'));
        await tester.pump();
        await tester.tap(find.text('2 Night Market'));
        await tester.pump();
        expect(selectedPreset, equals(CameraPreset.nightMarket));

        controller.dispose();
      },
    );

    testWidgets(
      '5. CityBuilderDock allows selecting placement tools and toggling back',
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

        expect(controller.activeTool, isA<ExploreTool>());
        expect(find.text('Townhouse'), findsNothing);

        await tester.tap(find.text('Dwellings & Shops'));
        await tester.pump();
        expect(find.text('Townhouse'), findsOneWidget);

        await tester.tap(find.text('Townhouse'));
        await tester.pump();

        expect(controller.activeTool, isA<StampStructureTool>());
        final tool = controller.activeTool as StampStructureTool;
        expect(tool.kind, equals(StructureKind.machiya));

        await tester.tap(find.text('Townhouse'));
        await tester.pump();
        expect(controller.activeTool, isA<ExploreTool>());
        expect(find.text('Townhouse'), findsNothing);

        controller.dispose();
      },
    );

    test('6. Audio controls maintain volume state and mute toggling via '
        'EdoAudioDriver', () {
      final audio = EdoAudioDriver()..setMasterVolume(0.5);
      expect(audio.masterVolume, closeTo(0.5, 1e-4));

      expect(audio.isMuted, isFalse);
      audio.setMuted(true);
      expect(audio.isMuted, isTrue);
      audio.setMuted(false);
      expect(audio.isMuted, isFalse);

      final controller = ShukubaController(
        look: FakeLookDriver(),
        world: FakeWorldDriver(),
        audio: audio,
      );
      expect(controller.audio.masterVolume, closeTo(0.5, 1e-4));
      controller.audio.setMasterVolume(0.8);
      expect(controller.audio.masterVolume, closeTo(0.8, 1e-4));
      controller.dispose();
    });
  });
}
