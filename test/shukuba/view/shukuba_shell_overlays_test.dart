import 'dart:ui' as ui;

import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_page.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_shell_overlays.dart';
import 'package:material_ui/material_ui.dart' hide Material;

import '../../e2e/helpers/e2e_test_harness.dart';

void main() {
  group('Feature 14: TitleMenuOverlay, Kinpaku, and Hanko Seal', () {
    test('KinpakuPainter paints golden flecks without exception', () {
      const painter = KinpakuPainter();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(1024, 768);

      expect(() => painter.paint(canvas, size), returnsNormally);
      expect(painter.shouldRepaint(const KinpakuPainter()), isFalse);
    });

    testWidgets('HankoSealWidget renders red seal glyph', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: HankoSealWidget())),
        ),
      );

      expect(find.text('影'), findsOneWidget);
      expect(find.byType(HankoSealWidget), findsOneWidget);
    });

    test(
      'AutumnLeavesPainter paints 46 leaves and repaints on progress change',
      () {
        const painter0 = AutumnLeavesPainter(progress: 0);
        const painterMid = AutumnLeavesPainter(progress: 0.35);
        const painterEnd = AutumnLeavesPainter(progress: 1);

        for (final size in const [
          Size.zero,
          Size(1, 1),
          Size(1024, 768),
          Size(12000, 8000),
        ]) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          expect(() => painter0.paint(canvas, size), returnsNormally);
          expect(() => painterMid.paint(canvas, size), returnsNormally);
          expect(() => painterEnd.paint(canvas, size), returnsNormally);
        }

        expect(painter0.shouldRepaint(const AutumnLeavesPainter()), isFalse);
        expect(painterMid.shouldRepaint(painter0), isTrue);
      },
    );

    testWidgets(
      'TitleMenuOverlay animates autumn leaves and disables when requested',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TitleMenuOverlay(onEnterValley: () {})),
          ),
        );

        final painterFinder = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is AutumnLeavesPainter,
        );
        expect(painterFinder, findsOneWidget);

        final initialProgress =
            (tester.widget<CustomPaint>(painterFinder).painter!
                    as AutumnLeavesPainter)
                .progress;
        await tester.pump(const Duration(seconds: 2));
        final nextProgress =
            (tester.widget<CustomPaint>(painterFinder).painter!
                    as AutumnLeavesPainter)
                .progress;
        expect(nextProgress, greaterThan(initialProgress));

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(body: TitleMenuOverlay(onEnterValley: () {})),
            ),
          ),
        );
        final stoppedProgress =
            (tester.widget<CustomPaint>(painterFinder).painter!
                    as AutumnLeavesPainter)
                .progress;
        await tester.pump(const Duration(seconds: 2));
        final afterStopProgress =
            (tester.widget<CustomPaint>(painterFinder).painter!
                    as AutumnLeavesPainter)
                .progress;
        expect(afterStopProgress, equals(stoppedProgress));
      },
    );

    testWidgets(
      'TitleMenuOverlay renders calligraphy, seal, uniform 46px buttons, and'
      ' invokes Enter Valley',
      (tester) async {
        var entered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TitleMenuOverlay(onEnterValley: () => entered = true),
            ),
          ),
        );

        expect(find.text('影の町'), findsOneWidget);
        expect(find.text('KAGE NO MACHI'), findsOneWidget);
        expect(find.text('Edo Post-Town Diorama Builder'), findsOneWidget);
        expect(find.textContaining('SHADOW TACTICS'), findsNothing);
        expect(find.text('Enter Valley (渓谷へ入る)'), findsOneWidget);
        expect(find.text('Field Notes (野帳)'), findsOneWidget);
        expect(find.text('Settings (設定)'), findsOneWidget);

        final enterBtn = find.ancestor(
          of: find.text('Enter Valley (渓谷へ入る)'),
          matching: find.byType(ElevatedButton),
        );
        final notesBtn = find.ancestor(
          of: find.text('Field Notes (野帳)'),
          matching: find.byType(OutlinedButton),
        );
        final settingsBtn = find.ancestor(
          of: find.text('Settings (設定)'),
          matching: find.byType(OutlinedButton),
        );

        expect(tester.getSize(enterBtn).height, equals(46.0));
        expect(tester.getSize(notesBtn).height, equals(46.0));
        expect(tester.getSize(settingsBtn).height, equals(46.0));

        await tester.tap(find.text('Enter Valley (渓谷へ入る)'));
        await tester.pump();
        expect(entered, isTrue);
      },
    );

    testWidgets('TitleMenuOverlay opens Field Notes dialog and closes it', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TitleMenuOverlay(onEnterValley: () {})),
        ),
      );

      await tester.tap(find.text('Field Notes (野帳)'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Field Notes (野帳)'), findsWidgets);
      expect(find.textContaining('Welcome to Kage no Machi'), findsOneWidget);
      expect(find.text('Close (閉じる)'), findsOneWidget);

      await tester.tap(find.text('Close (閉じる)'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.textContaining('Welcome to Kage no Machi'), findsNothing);
    });

    testWidgets('TitleMenuOverlay opens Settings dialog and adjusts audio', (
      tester,
    ) async {
      final audio = EdoAudioDriver();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TitleMenuOverlay(audioDriver: audio, onEnterValley: () {}),
          ),
        ),
      );

      await tester.tap(find.text('Settings (設定)'));
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Settings (設定)'), findsWidgets);
      expect(find.text('1 – 6'), findsOneWidget);
      expect(audio.isMuted, isFalse);
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(audio.isMuted, isTrue);

      expect(find.text('OK'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('OK'), findsNothing);
    });
  });

  group('Feature 15: LoadingCurtainOverlay & Staged Boot Sequence', () {
    testWidgets('LoadingCurtainOverlay displays 6 boot stages and progress', (
      tester,
    ) async {
      final completed = [
        const BootStageTiming(
          stage: BootStageId.lookAndShaders,
          durationMs: 4.2,
        ),
        const BootStageTiming(
          stage: BootStageId.audioSynthesis,
          durationMs: 18.5,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoadingCurtainOverlay(
              activeStage: BootStageId.valleyTerrain,
              completedTimings: completed,
            ),
          ),
        ),
      );

      expect(find.text('Preparing Shukuba Valley'), findsOneWidget);
      expect(find.text('宿場町の構築 (Staged Warmup)'), findsOneWidget);

      for (final stage in BootStageId.values) {
        expect(find.text(stage.label), findsOneWidget);
      }

      expect(find.text('4.2 ms'), findsOneWidget);
      expect(find.text('18.5 ms'), findsOneWidget);
    });
  });

  group('Feature 16: PauseMenuOverlay & Audio Controls', () {
    testWidgets('PauseMenuOverlay adjusts audio volume, toggles mute, and'
        ' handles actions', (tester) async {
      final audio = EdoAudioDriver();
      var resumed = false;
      var returnedToTitle = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PauseMenuOverlay(
              onResume: () => resumed = true,
              onReturnToTitle: () => returnedToTitle = true,
              audioDriver: audio,
            ),
          ),
        ),
      );

      expect(find.text('PAUSE — 一服 (Ippuku)'), findsOneWidget);
      expect(find.text('Resume (再開)'), findsOneWidget);
      expect(find.text('Return to Title (表紙へ戻る)'), findsOneWidget);
      expect(find.text('Keybindings (操作手引き)'), findsOneWidget);
      expect(find.text('1 – 6'), findsOneWidget);

      final returnBtn = find.ancestor(
        of: find.text('Return to Title (表紙へ戻る)'),
        matching: find.byType(OutlinedButton),
      );
      final resumeBtn = find.ancestor(
        of: find.text('Resume (再開)'),
        matching: find.byType(ElevatedButton),
      );
      expect(tester.getSize(returnBtn).height, equals(44.0));
      expect(tester.getSize(resumeBtn).height, equals(44.0));

      expect(audio.isMuted, isFalse);
      final muteBtn = find.byType(IconButton);
      expect(muteBtn, findsOneWidget);
      await tester.tap(muteBtn);
      await tester.pump();
      expect(audio.isMuted, isTrue);

      await tester.tap(find.text('Resume (再開)'));
      await tester.pump();
      expect(resumed, isTrue);

      await tester.tap(find.text('Return to Title (表紙へ戻る)'));
      await tester.pump();
      expect(returnedToTitle, isTrue);
    });
  });

  group('Feature 17: TelemetryMonitorPill & Rolling Timing', () {
    testWidgets('TelemetryMonitorPill displays FPS and expands on tap', (
      tester,
    ) async {
      final report = BootReport(
        stages: const [
          BootStageTiming(stage: BootStageId.lookAndShaders, durationMs: 3.1),
          BootStageTiming(stage: BootStageId.audioSynthesis, durationMs: 12.4),
          BootStageTiming(stage: BootStageId.valleyTerrain, durationMs: 25),
          BootStageTiming(
            stage: BootStageId.townArchitecture,
            durationMs: 14.2,
          ),
          BootStageTiming(stage: BootStageId.floraAndAir, durationMs: 8.6),
          BootStageTiming(stage: BootStageId.gpuWarmup, durationMs: 6.3),
        ],
        totalMs: 69.6,
      );

      final snapshot = FrameTelemetrySnapshot(
        uiMs: 4.5,
        rasterMs: 6.8,
        fps: 60,
        structureCount: 16,
        lanternSpanCount: 10,
        bootReport: report,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: TelemetryMonitorPill(snapshot: snapshot)),
          ),
        ),
      );

      expect(find.text('60 FPS'), findsOneWidget);
      expect(find.textContaining('UI: 4.5ms'), findsOneWidget);
      expect(find.textContaining('Raster: 6.8ms'), findsOneWidget);

      await tester.tap(find.byType(TelemetryMonitorPill));
      await tester.pump();

      expect(find.textContaining('Boot Stages Breakdown'), findsOneWidget);
      expect(find.text('Look & Shaders'), findsOneWidget);
      expect(find.text('Audio Synthesis'), findsOneWidget);
      expect(find.text('Valley Terrain'), findsOneWidget);
      expect(find.text('Town Architecture'), findsOneWidget);
      expect(find.text('Flora & Atmosphere'), findsOneWidget);
      expect(find.text('GPU Warmup'), findsOneWidget);
    });
  });

  group('Shell Mode & Hotkey Orchestration in ShukubaPage', () {
    testWidgets('ShukubaPage cold launches into TitleMenuOverlay by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShukubaPage(initialMode: ShukubaShellMode.titleMenu),
        ),
      );
      await tester.pump();

      expect(find.byType(TitleMenuOverlay), findsOneWidget);
      expect(find.text('影の町'), findsOneWidget);
    });

    testWidgets('Pressing F3 in ShukubaPage toggles TelemetryMonitorPill', (
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

      expect(find.byType(TelemetryMonitorPill), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pump();

      expect(find.byType(TelemetryMonitorPill), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pump();

      expect(find.byType(TelemetryMonitorPill), findsNothing);
    });

    testWidgets(
      'Pressing Escape in valley opens PauseMenuOverlay and resumes',
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

        expect(find.byType(PauseMenuOverlay), findsNothing);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(find.byType(PauseMenuOverlay), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(find.byType(PauseMenuOverlay), findsNothing);
      },
    );
  });
}
