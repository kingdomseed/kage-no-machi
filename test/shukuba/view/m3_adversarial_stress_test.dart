import 'dart:ui' as ui;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_page.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_shell_overlays.dart';
import 'package:material_ui/material_ui.dart' hide Material;

import '../../e2e/helpers/e2e_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Stress Test: Feature 14 (TitleMenuOverlay)', () {
    test('KinpakuPainter handles extreme and edge-case canvas sizes', () {
      const painter = KinpakuPainter();

      final rec0 = ui.PictureRecorder();
      final c0 = Canvas(rec0);
      expect(() => painter.paint(c0, Size.zero), returnsNormally);

      final rec1 = ui.PictureRecorder();
      final c1 = Canvas(rec1);
      expect(() => painter.paint(c1, const Size(1, 1)), returnsNormally);

      final rec2 = ui.PictureRecorder();
      final c2 = Canvas(rec2);
      expect(() => painter.paint(c2, const Size(12000, 8000)), returnsNormally);
    });

    test(
      'AutumnLeavesPainter handles extreme canvas sizes and NaN progress',
      () {
        const painter = AutumnLeavesPainter(progress: double.nan);

        for (final size in const [Size.zero, Size(1, 1), Size(12000, 8000)]) {
          final rec = ui.PictureRecorder();
          final canvas = Canvas(rec);
          expect(() => painter.paint(canvas, size), returnsNormally);
        }
      },
    );

    testWidgets('Rapid multi-click bursts on Enter Valley CTA button', (
      tester,
    ) async {
      var enterCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TitleMenuOverlay(onEnterValley: () => enterCount++),
          ),
        ),
      );

      final ctaFinder = find.text('Enter Valley (渓谷へ入る)');
      expect(ctaFinder, findsOneWidget);

      for (var i = 0; i < 5; i++) {
        await tester.tap(ctaFinder);
      }
      await tester.pump();

      expect(enterCount, equals(5));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'TitleMenuOverlay renders cleanly under small viewport (360x480)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TitleMenuOverlay(onEnterValley: () {})),
          ),
        );
        await tester.pump();

        expect(find.text('影の町'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Rapid opening, Esc dismissing, and reopening of dialogs', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TitleMenuOverlay(onEnterValley: () {})),
        ),
      );

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Field Notes (野帳)'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.textContaining('Welcome to Kage no Machi'), findsOneWidget);

        await tester.tap(find.text('Close (閉じる)'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.textContaining('Welcome to Kage no Machi'), findsNothing);
      }

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Settings (設定)'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Settings (設定)'), findsWidgets);

        await tester.tap(find.text('OK'));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('OK'), findsNothing);
      }

      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Stress Test: Feature 15 (LoadingCurtainOverlay)', () {
    testWidgets('Handles empty completed timings (cold start)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoadingCurtainOverlay(
              activeStage: BootStageId.lookAndShaders,
              completedTimings: [],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Preparing Shukuba Valley'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Handles out-of-order and duplicate stage timings gracefully', (
      tester,
    ) async {
      final erraticTimings = [
        const BootStageTiming(stage: BootStageId.gpuWarmup, durationMs: 12.3),
        const BootStageTiming(stage: BootStageId.valleyTerrain, durationMs: 45),
        const BootStageTiming(stage: BootStageId.gpuWarmup, durationMs: 99.9),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingCurtainOverlay(
              activeStage: BootStageId.audioSynthesis,
              completedTimings: erraticTimings,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Preparing Shukuba Valley'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Handles negative, infinite, and NaN durations gracefully', (
      tester,
    ) async {
      final boundaryTimings = [
        const BootStageTiming(
          stage: BootStageId.lookAndShaders,
          durationMs: -5,
        ),
        const BootStageTiming(
          stage: BootStageId.audioSynthesis,
          durationMs: double.nan,
        ),
        const BootStageTiming(
          stage: BootStageId.valleyTerrain,
          durationMs: double.infinity,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingCurtainOverlay(
              activeStage: BootStageId.townArchitecture,
              completedTimings: boundaryTimings,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Preparing Shukuba Valley'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Renders cleanly within minimum project viewport (800x600 and 640x480)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LoadingCurtainOverlay(
                activeStage: BootStageId.townArchitecture,
                completedTimings: [
                  BootStageTiming(
                    stage: BootStageId.lookAndShaders,
                    durationMs: 4.1,
                  ),
                  BootStageTiming(
                    stage: BootStageId.audioSynthesis,
                    durationMs: 12,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Preparing Shukuba Valley'), findsOneWidget);
        expect(tester.takeException(), isNull);

        tester.view.physicalSize = const Size(640, 480);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Sub-minimum viewport (<380px height) scrolls cleanly without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LoadingCurtainOverlay(
                activeStage: BootStageId.townArchitecture,
                completedTimings: [
                  BootStageTiming(
                    stage: BootStageId.lookAndShaders,
                    durationMs: 4.1,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group(
    'Adversarial Stress Test: Feature 16 (PauseMenuOverlay & Cascading Esc)',
    () {
      test(
        'EdoAudioDriver volume boundaries: 0.0, 1.0, negative, NaN, infinity',
        () {
          final driver = EdoAudioDriver();

          expect(driver.masterVolume, equals(1.0));

          driver.setMasterVolume(0);
          expect(driver.masterVolume, equals(0.0));

          driver.setMasterVolume(1);
          expect(driver.masterVolume, equals(1.0));

          driver.setMasterVolume(-0.5);
          expect(driver.masterVolume, equals(0.0));

          driver.setMasterVolume(-1000);
          expect(driver.masterVolume, equals(0.0));

          driver.setMasterVolume(1.5);
          expect(driver.masterVolume, equals(1.0));

          driver.setMasterVolume(9999);
          expect(driver.masterVolume, equals(1.0));

          driver.setMasterVolume(double.nan);
          expect(driver.masterVolume, equals(0.0));

          driver.setMasterVolume(double.infinity);
          expect(driver.masterVolume, equals(1.0));

          driver.setMasterVolume(-double.infinity);
          expect(driver.masterVolume, equals(0.0));

          driver.setMasterVolume(-0);
          expect(driver.masterVolume, equals(0.0));
        },
      );

      testWidgets('Rapid mute toggle in PauseMenuOverlay does not desync', (
        tester,
      ) async {
        final audio = EdoAudioDriver();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PauseMenuOverlay(
                onResume: () {},
                onReturnToTitle: () {},
                audioDriver: audio,
              ),
            ),
          ),
        );

        final muteBtn = find.byType(IconButton);
        expect(muteBtn, findsOneWidget);

        for (var i = 0; i < 10; i++) {
          await tester.tap(muteBtn);
          await tester.pump();
        }

        expect(audio.isMuted, isFalse);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'PauseMenuOverlay volume boundaries 0.0, 1.0 and slider dragging',
        (tester) async {
          final audio = EdoAudioDriver()..setMasterVolume(0);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PauseMenuOverlay(
                  onResume: () {},
                  onReturnToTitle: () {},
                  audioDriver: audio,
                ),
              ),
            ),
          );

          expect(find.text('0%'), findsOneWidget);

          final sliderFinder = find.byType(Slider);
          expect(sliderFinder, findsOneWidget);

          await tester.drag(sliderFinder, const Offset(300, 0));
          await tester.pump();

          expect(audio.masterVolume, equals(1.0));
          expect(find.text('100%'), findsOneWidget);

          await tester.drag(sliderFinder, const Offset(-600, 0));
          await tester.pump();

          expect(audio.masterVolume, equals(0.0));
          expect(find.text('0%'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('PauseMenuOverlay renders cleanly at 800x600 and 640x480', (
        tester,
      ) async {
        final audio = EdoAudioDriver();

        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PauseMenuOverlay(
                onResume: () {},
                onReturnToTitle: () {},
                audioDriver: audio,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('PAUSE — 一服 (Ippuku)'), findsOneWidget);
        expect(tester.takeException(), isNull);

        tester.view.physicalSize = const Size(640, 480);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'PauseMenuOverlay scrolls cleanly at sub-minimum viewport (<400px)',
        (tester) async {
          final audio = EdoAudioDriver();

          tester.view.physicalSize = const Size(500, 320);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PauseMenuOverlay(
                  onResume: () {},
                  onReturnToTitle: () {},
                  audioDriver: audio,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('Cascading Esc: Stroke -> Tool -> PauseMenu -> Resume', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ShukubaPage(
              lookDriver: FakeLookDriver(),
              worldDriver: FakeWorldDriver(),
              audioDriver: FakeAudioDriver(),
              initialMode: ShukubaShellMode.inValley,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Roads & Walls'));
        await tester.pump();
        await tester.tap(find.text('Road'));
        await tester.pump();

        expect(find.text('Cancel'), findsNothing);

        final hudFinder = find.byType(ShukubaHud);
        expect(hudFinder, findsOneWidget);
        final hud = tester.widget<ShukubaHud>(hudFinder);
        final controller = hud.controller
          ..beginStrokeAt(Vec3.zero)
          ..extendStrokeTo(const Vec3(5, 0, 5));
        await tester.pump();

        expect(controller.strokePoints.length, equals(2));
        expect(find.text('Cancel'), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(controller.strokePoints, isEmpty);
        expect(controller.activeTool, equals(const DrawLaneTool()));
        expect(find.byType(PauseMenuOverlay), findsNothing);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(controller.activeTool, equals(const ExploreTool()));
        expect(find.byType(PauseMenuOverlay), findsNothing);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(find.byType(PauseMenuOverlay), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(find.byType(PauseMenuOverlay), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'Cascading Esc: Stamp Tool -> Explore -> PauseMenu -> Resume',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ShukubaPage(
                lookDriver: FakeLookDriver(),
                worldDriver: FakeWorldDriver(),
                audioDriver: FakeAudioDriver(),
                initialMode: ShukubaShellMode.inValley,
              ),
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Shrines & Courtyards'));
          await tester.pump();
          await tester.tap(find.text('Bell Pavilion'));
          await tester.pump();

          final hud = tester.widget<ShukubaHud>(find.byType(ShukubaHud));
          expect(
            hud.controller.activeTool,
            equals(const StampStructureTool(kind: StructureKind.shoroBell)),
          );

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();

          expect(hud.controller.activeTool, equals(const ExploreTool()));
          expect(find.byType(PauseMenuOverlay), findsNothing);

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();

          expect(find.byType(PauseMenuOverlay), findsOneWidget);

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();

          expect(find.byType(PauseMenuOverlay), findsNothing);
        },
      );

      testWidgets('Rapid Esc keypress bursts do not corrupt state', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ShukubaPage(
              lookDriver: FakeLookDriver(),
              worldDriver: FakeWorldDriver(),
              audioDriver: FakeAudioDriver(),
              initialMode: ShukubaShellMode.inValley,
            ),
          ),
        );
        await tester.pump();

        for (var i = 0; i < 16; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
        }

        expect(find.byType(PauseMenuOverlay), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Esc in TitleMenu does NOT open PauseMenu', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ShukubaPage(initialMode: ShukubaShellMode.titleMenu),
          ),
        );
        await tester.pump();

        expect(find.byType(TitleMenuOverlay), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(find.byType(TitleMenuOverlay), findsOneWidget);
        expect(find.byType(PauseMenuOverlay), findsNothing);
        expect(tester.takeException(), isNull);
      });
    },
  );

  group(
    'Adversarial Stress Test: Feature 17 (TelemetryMonitorPill & Timer)',
    () {
      test('RollingFrameTimer handles extreme durations, NaN, infinity, and '
          'large bursts', () {
        final timer = RollingFrameTimer(windowSize: 10)
          ..ingestDurations(buildMs: 16, rasterMs: 16);
        expect(timer.sampleCount, equals(1));
        expect(timer.uiMs, closeTo(16.0, 1e-4));
        expect(timer.fps, closeTo(60.0, 0.5));

        timer.ingestDurations(buildMs: double.nan, rasterMs: double.infinity);
        expect(timer.sampleCount, equals(2));
        expect(timer.uiMs, closeTo(8.0, 1e-4));

        timer.ingestDurations(buildMs: -100, rasterMs: -50);
        expect(timer.sampleCount, equals(3));

        for (var i = 0; i < 1000; i++) {
          timer.ingestDurations(buildMs: 8.33, rasterMs: 8.33);
        }
        expect(timer.sampleCount, equals(10));
        expect(timer.uiMs, closeTo(8.33, 0.05));
        expect(timer.rasterMs, closeTo(8.33, 0.05));
        expect(timer.fps, closeTo(60.0, 0.5));

        timer
          ..reset()
          ..ingestDurations(buildMs: 500, rasterMs: 500);
        expect(timer.fps, closeTo(2.0, 0.1));

        timer
          ..reset()
          ..ingestDurations(buildMs: 0, rasterMs: 0);
        expect(timer.fps, equals(60.0));
      });

      testWidgets(
        'F3 key toggles telemetry pill across valley and pause modes',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ShukubaPage(
                lookDriver: FakeLookDriver(),
                worldDriver: FakeWorldDriver(),
                audioDriver: FakeAudioDriver(),
                initialMode: ShukubaShellMode.inValley,
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(TelemetryMonitorPill), findsNothing);

          await tester.sendKeyEvent(LogicalKeyboardKey.f3);
          await tester.pump();
          expect(find.byType(TelemetryMonitorPill), findsOneWidget);

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          expect(find.byType(PauseMenuOverlay), findsOneWidget);
          expect(find.byType(TelemetryMonitorPill), findsOneWidget);

          await tester.sendKeyEvent(LogicalKeyboardKey.f3);
          await tester.pump();
          expect(find.byType(TelemetryMonitorPill), findsNothing);

          await tester.sendKeyEvent(LogicalKeyboardKey.f3);
          await tester.pump();
          expect(find.byType(TelemetryMonitorPill), findsOneWidget);

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pump();
          expect(find.byType(PauseMenuOverlay), findsNothing);
          expect(find.byType(TelemetryMonitorPill), findsOneWidget);
        },
      );

      testWidgets('F3 pressed in TitleMenu does NOT display telemetry pill', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: ShukubaPage(initialMode: ShukubaShellMode.titleMenu),
          ),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.f3);
        await tester.pump();

        expect(find.byType(TelemetryMonitorPill), findsNothing);
        expect(tester.takeException(), isNull);
      });
    },
  );

  group(
    'Adversarial Stress Test: Feature 18 (_CityBuilderDock Permutations)',
    () {
      late ShukubaController controller;

      setUp(() {
        controller = ShukubaController(
          look: FakeLookDriver(),
          world: FakeWorldDriver(),
          audio: FakeAudioDriver(),
        );
      });

      tearDown(() {
        controller.dispose();
      });

      testWidgets(
        'Single-drawer accordion switches cleanly across all 4 categories',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ShukubaHud(
                  controller: controller,
                  onSelectPreset: (_) {},
                ),
              ),
            ),
          );

          final categories = [
            (HudToolCategory.dwellingsAndShops, 'Townhouse'),
            (HudToolCategory.roadsAndWalls, 'Road'),
            (HudToolCategory.treesAndRocks, 'Bamboo Grove'),
            (HudToolCategory.shrinesAndCourtyards, 'Bell Pavilion'),
          ];

          for (final (_, repTool) in categories) {
            expect(find.text(repTool), findsNothing);
          }

          for (var round = 0; round < 3; round++) {
            for (final (cat, repTool) in categories) {
              await tester.tap(find.text(cat.label));
              await tester.pump();

              expect(find.text(repTool), findsOneWidget);
              for (final (otherCat, otherTool) in categories) {
                if (otherCat != cat) {
                  expect(find.text(otherTool), findsNothing);
                }
              }
              expect(tester.takeException(), isNull);
            }
          }

          await tester.tap(find.text('Shrines & Courtyards'));
          await tester.pump();
          expect(find.text('Bell Pavilion'), findsNothing);
        },
      );

      testWidgets(
        'Selecting tool in collapsed category automatically opens its drawer',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ShukubaHud(
                  controller: controller,
                  onSelectPreset: (_) {},
                ),
              ),
            ),
          );

          expect(find.text('Bell Pavilion'), findsNothing);

          controller.selectTool(
            const StampStructureTool(kind: StructureKind.shoroBell),
          );
          await tester.pump();

          expect(find.text('Bell Pavilion'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('Builder dock renders without overflow on 800x600 viewport', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShukubaHud(controller: controller, onSelectPreset: (_) {}),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Dwellings & Shops'));
        await tester.pump();
        expect(find.text('Townhouse'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Shrines & Courtyards'));
        await tester.pump();
        expect(find.text('Bell Pavilion'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'Builder dock renders without overflow on 1024x768 viewport',
        (tester) async {
          tester.view.physicalSize = const Size(1024, 768);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ShukubaHud(
                  controller: controller,
                  onSelectPreset: (_) {},
                ),
              ),
            ),
          );
          await tester.pump();

          expect(tester.takeException(), isNull);
        },
      );
    },
  );
}
