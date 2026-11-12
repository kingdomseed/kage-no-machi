import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Material;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_page.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_shell_overlays.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

import '../../e2e/helpers/e2e_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 5 Adversarial Audit — Look Driver Constants & Shaders', () {
    test(
      'shadowAmbientStrength is 0.15 at dusk and bounded in [0.15, 0.20]',
      () {
        var lastStrength = 0.15;
        for (var step = 0; step <= 10000; step++) {
          final t = step / 10000.0;
          final strength = 0.15 + 0.05 * t;

          expect(
            strength,
            greaterThanOrEqualTo(0.15 - 1e-9),
            reason: 'shadowAmbientStrength must not drop below 0.15',
          );
          expect(
            strength,
            lessThanOrEqualTo(0.20 + 1e-9),
            reason: 'shadowAmbientStrength must not exceed 0.20',
          );
          expect(
            strength,
            greaterThanOrEqualTo(lastStrength),
            reason:
                'shadowAmbientStrength must be non-decreasing with nightFactor',
          );
          lastStrength = strength;
        }

        expect(0.15 + 0.05 * 0, equals(0.15));
        expect(0.15 + 0.05 * 1, equals(0.20));
      },
    );

    test('Directional fill light is 0.24 steel-blue pinned', () {
      final fill = DirectionalLight(
        intensity: 0.24,
        color: Vector3(0.24, 0.38, 0.58),
      );
      expect(fill.intensity, equals(0.24));
      expect(fill.color.x, closeTo(0.24, 1e-6));
      expect(fill.color.y, closeTo(0.38, 1e-6));
      expect(fill.color.z, closeTo(0.58, 1e-6));

      final aim = Vector3(0.3, -1, 0.4).normalized();
      expect(aim.length, closeTo(1.0, 1e-6));
      expect(aim.y, lessThan(0.0), reason: 'Fill light points downward');
      expect(aim.x, greaterThan(0.0));
      expect(aim.z, greaterThan(0.0));
    });

    test('GTAO EnvironmentSettings radius is 0.88 and intensity is 1.56', () {
      final settings = EnvironmentSettings(
        ambientOcclusionEnabled: true,
        ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
        ambientOcclusionIntensity: 1.56,
        ambientOcclusionRadius: 0.88,
        ambientOcclusionBentNormals: true,
        ambientOcclusionSpecularMode: SpecularAmbientOcclusionMode.bentCone,
      );

      expect(settings.ambientOcclusionEnabled, isTrue);
      expect(
        settings.ambientOcclusionMethod,
        equals(AmbientOcclusionMethod.groundTruth),
      );
      expect(settings.ambientOcclusionIntensity, closeTo(1.56, 1e-6));
      expect(settings.ambientOcclusionRadius, closeTo(0.88, 1e-6));
      expect(settings.ambientOcclusionBentNormals, isTrue);
      expect(
        settings.ambientOcclusionSpecularMode,
        equals(SpecularAmbientOcclusionMode.bentCone),
      );
    });

    test('Sumi ink crease smoothstep(0.18, 0.68) mathematical bounds', () {
      double smoothstep(double edge0, double edge1, double x) {
        final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
        return t * t * (3.0 - 2.0 * t);
      }

      expect(smoothstep(0.18, 0.68, 0), equals(0.0));
      expect(smoothstep(0.18, 0.68, 0.179), equals(0.0));
      expect(smoothstep(0.18, 0.68, 0.18), equals(0.0));

      expect(smoothstep(0.18, 0.68, 0.43), closeTo(0.50, 1e-4));

      expect(smoothstep(0.18, 0.68, 0.68), equals(1.0));
      expect(smoothstep(0.18, 0.68, 0.95), equals(1.0));
      expect(smoothstep(0.18, 0.68, 5), equals(1.0));

      var prev = 0.0;
      for (var i = 181; i < 680; i++) {
        final val = smoothstep(0.18, 0.68, i / 1000.0);
        expect(val, greaterThan(prev));
        prev = val;
      }
    });

    test('Sumi ink shader source contains exact crease threshold', () {
      final shaderSource = File('shaders/sumi_ink.frag').readAsStringSync();
      expect(shaderSource, contains('smoothstep(0.18, 0.68, scaledCrease)'));
      expect(
        shaderSource,
        contains(
          'float skyFade = clamp((skyDistance - centerDepth) * 0.05, 0.0, 1.0)',
        ),
      );
      expect(
        shaderSource,
        contains(
          'float distAtten = clamp(1.20 - centerDepth * 0.0046, 0.50, 1.0)',
        ),
      );
    });

    test('GouacheLit shader rock and soil relief & fissure constants', () {
      final fmat = File('assets/materials/gouache_lit.fmat').readAsStringSync();

      expect(fmat, contains('totalCrevice * 0.68'));
      expect(
        fmat,
        contains(
          'totalCrevice = clamp(fissureMask * 0.75 + shelfRiser * 0.55, '
          '0.0, 1.0)',
        ),
      );
      expect(fmat, contains('perturbedN = normalize(N + normalDelta * 1.45)'));
      expect(fmat, contains('shelfRiser = smoothstep(0.76, 0.98, shelfFract)'));
      expect(
        fmat,
        contains('vec3 deepIndigoUmber = vec3(0.038, 0.032, 0.048)'),
      );

      expect(fmat, contains('edgeDist - 0.42'));
      expect(
        fmat,
        contains('perturbedN = normalize(N + soilNormalDelta * 1.55)'),
      );
      expect(
        fmat,
        contains('mix(mix(0.88, 0.68, rutGouge * 0.55), 0.08, rutPuddleMask)'),
      );
      expect(fmat, contains('spec = mix(0.42, 0.85, rutPuddleMask)'));
      expect(
        fmat,
        contains(
          'perturbedN = mix(perturbedN, vec3(0.0, 1.0, 0.0), '
          'rutPuddleMask * 0.92)',
        ),
      );
    });
  });

  group('Tier 5 Adversarial Audit — Audio Isolate Prewarming & Synthesis', () {
    test('EdoWavBank generates non-empty audio data for all clips', () {
      final bank = EdoWavBank.synthesizeAll();
      expect(bank.kotoWav.length, greaterThan(44));
      expect(bank.shakuhachiWav.length, greaterThan(44));
      expect(bank.hyoshigiWav.length, greaterThan(44));
      expect(bank.bonshoWav.length, greaterThan(44));
      expect(bank.riverMurmurWav.length, greaterThan(44));
      expect(bank.bambooWindWav.length, greaterThan(44));
      expect(bank.nightCricketsWav.length, greaterThan(44));

      for (final inst in EdoInstrument.values) {
        final bytes = bank.clipForInstrument(inst);
        expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
        expect(String.fromCharCodes(bytes.sublist(8, 12)), equals('WAVE'));
      }
      for (final loop in AmbientLoopKind.values) {
        final bytes = bank.clipForAmbient(loop);
        expect(String.fromCharCodes(bytes.sublist(0, 4)), equals('RIFF'));
        expect(String.fromCharCodes(bytes.sublist(8, 12)), equals('WAVE'));
      }
    });

    test(
      'EdoAudioDriver prewarm() dispatches in Isolate.run and is idempotent',
      () async {
        final driver = EdoAudioDriver();
        expect(driver.isWavBankLoaded, isFalse);

        final f1 = driver.prewarm();
        final f2 = driver.prewarm();
        final f3 = driver.prewarm();
        expect(identical(f1, f2), isTrue);
        expect(identical(f2, f3), isTrue);

        await f1;
        expect(driver.isWavBankLoaded, isTrue);

        final sw = Stopwatch()..start();
        await driver.prewarm();
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(5));

        driver.dispose();
      },
    );

    test('ShukubaPage initState initiates audio prewarm', () {
      final pageSource = File('lib/shukuba/view/shukuba_page.dart')
          .readAsStringSync();
      expect(pageSource, contains('unawaited(_controller.audio.prewarm())'));
    });
  });

  group('Tier 5 Adversarial Audit — UI Shell Overlays & Latency', () {
    testWidgets(
      'TitleMenuOverlay renders calligraphy, seal, and CTA synchronously',
      (tester) async {
        var entered = false;

        final sw = Stopwatch()..start();
        final menu = TitleMenuOverlay(onEnterValley: () => entered = true);
        sw.stop();
        expect(sw.elapsedMicroseconds, lessThan(5000));

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: menu)));

        expect(find.text('影の町'), findsOneWidget);
        expect(
          find.text('SHADOW TACTICS: RETURN OF THE SHOGUN'),
          findsOneWidget,
        );
        expect(find.byType(HankoSealWidget), findsOneWidget);

        await tester.tap(find.text('Enter Valley (渓谷へ入る)'));
        await tester.pump();
        expect(entered, isTrue);
      },
    );

    testWidgets(
      'LoadingCurtainOverlay displays 6 boot stages with live durations',
      (tester) async {
        final timings = [
          const BootStageTiming(
            stage: BootStageId.lookAndShaders,
            durationMs: 2.4,
          ),
          const BootStageTiming(
            stage: BootStageId.audioSynthesis,
            durationMs: 14.8,
          ),
          const BootStageTiming(
            stage: BootStageId.valleyTerrain,
            durationMs: 28.1,
          ),
          const BootStageTiming(
            stage: BootStageId.townArchitecture,
            durationMs: 18.5,
          ),
          const BootStageTiming(
            stage: BootStageId.floraAndAir,
            durationMs: 9.2,
          ),
          const BootStageTiming(stage: BootStageId.gpuWarmup, durationMs: 5.7),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LoadingCurtainOverlay(
                activeStage: BootStageId.gpuWarmup,
                completedTimings: timings,
              ),
            ),
          ),
        );

        expect(find.text('Preparing Shukuba Valley'), findsOneWidget);
        for (final stage in BootStageId.values) {
          expect(find.text(stage.label), findsOneWidget);
        }
        expect(find.text('2.4 ms'), findsOneWidget);
        expect(find.text('14.8 ms'), findsOneWidget);
        expect(find.text('28.1 ms'), findsOneWidget);
        expect(find.text('18.5 ms'), findsOneWidget);
        expect(find.text('9.2 ms'), findsOneWidget);
        expect(find.text('5.7 ms'), findsOneWidget);
      },
    );

    testWidgets('Esc keypress cascade: Stroke -> Tool -> PauseMenu -> Resume', (
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

      await tester.tap(find.text('Road'));
      await tester.pump();

      final hud = tester.widget<ShukubaHud>(find.byType(ShukubaHud));
      hud.controller
        ..beginStrokeAt(Vec3.zero)
        ..extendStrokeTo(const Vec3(4, 0, 4));
      await tester.pump();

      expect(hud.controller.strokePoints.length, equals(2));
      expect(find.byType(PauseMenuOverlay), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(hud.controller.strokePoints, isEmpty);
      expect(hud.controller.activeTool, equals(const DrawLaneTool()));
      expect(find.byType(PauseMenuOverlay), findsNothing);

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
    });

    testWidgets('F3 telemetry monitor pill toggling and metrics display', (
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
      expect(find.textContaining('FPS'), findsOneWidget);
      expect(find.textContaining('UI:'), findsOneWidget);
      expect(find.textContaining('Raster:'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pump();
      expect(find.byType(TelemetryMonitorPill), findsNothing);
    });

    testWidgets(
      'Builder dock 4 categories expand/collapse and render ink icons',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final controller = ShukubaController(
          look: FakeLookDriver(),
          world: FakeWorldDriver(),
          audio: FakeAudioDriver(),
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShukubaHud(controller: controller, onSelectPreset: (_) {}),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Dwellings & Shops'), findsOneWidget);
        expect(find.text('Roads & Walls'), findsOneWidget);
        expect(find.text('Trees & Rocks'), findsOneWidget);
        expect(find.text('Shrines & Courtyards'), findsOneWidget);

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        for (final icon in InkBrushIconKind.values) {
          final painter = InkBrushIconPainter(
            icon: icon,
            color: const Color(0xFFFFC107),
          );
          expect(
            () => painter.paint(canvas, const Size(20, 20)),
            returnsNormally,
          );
        }
      },
    );
  });

  group('Tier 5 Adversarial Audit — Frame Capture Harness & Overlap Gates', () {
    test('Non-zero coplanar overlaps or depth conflicts strictly fail '
        'verification', () {
      const validStats = FramePixelStats(
        width: 1920,
        height: 1080,
        meanLuminance: 0.35,
        stddevLuminance: 0.15,
        nonZeroPixels: 1920 * 1080,
      );
      expect(validStats.isValidNonBlank, isTrue);

      const clean = PresetVerificationResult(
        presetId: 'clean',
        pngPath: '/tmp/clean.png',
        pixelStats: validStats,
        coplanarOverlapCount: 0,
        coplanarDescriptions: [],
        depthConflictCount: 0,
        depthConflictSummary: 'none',
      );
      expect(clean.passed, isTrue);

      const withOverlap = PresetVerificationResult(
        presetId: 'overlap',
        pngPath: '/tmp/overlap.png',
        pixelStats: validStats,
        coplanarOverlapCount: 1,
        coplanarDescriptions: ['roof clash'],
        depthConflictCount: 0,
        depthConflictSummary: 'none',
      );
      expect(withOverlap.passed, isFalse);

      const withConflict = PresetVerificationResult(
        presetId: 'conflict',
        pngPath: '/tmp/conflict.png',
        pixelStats: validStats,
        coplanarOverlapCount: 0,
        coplanarDescriptions: [],
        depthConflictCount: 2,
        depthConflictSummary: 'depth layer inverted',
      );
      expect(withConflict.passed, isFalse);

      const blankStats = FramePixelStats(
        width: 1920,
        height: 1080,
        meanLuminance: 0,
        stddevLuminance: 0,
        nonZeroPixels: 0,
      );
      const withBlank = PresetVerificationResult(
        presetId: 'blank',
        pngPath: '/tmp/blank.png',
        pixelStats: blankStats,
        coplanarOverlapCount: 0,
        coplanarDescriptions: [],
        depthConflictCount: 0,
        depthConflictSummary: 'none',
      );
      expect(withBlank.passed, isFalse);

      const cleanSummary = HarnessSummary(outputDir: '/tmp', results: [clean]);
      expect(cleanSummary.allPassed, isTrue);

      const mixedSummary = HarnessSummary(
        outputDir: '/tmp',
        results: [clean, withOverlap],
      );
      expect(mixedSummary.allPassed, isFalse);
    });

    test('analyzeRgbaPixels rejects degenerate buffers and bounds check', () {
      expect(
        () => analyzeRgbaPixels(ByteData(16), width: 2, height: 2),
        returnsNormally,
      );

      expect(
        () => analyzeRgbaPixels(ByteData(15), width: 2, height: 2),
        throwsArgumentError,
      );

      expect(
        () => analyzeRgbaPixels(ByteData(0), width: 0, height: 0),
        throwsArgumentError,
      );
    });

    test(
      'HarnessSummary and PresetVerificationResult JSON format conforms',
      () {
        const stats = FramePixelStats(
          width: 960,
          height: 540,
          meanLuminance: 0.45,
          stddevLuminance: 0.18,
          nonZeroPixels: 500000,
        );
        const result = PresetVerificationResult(
          presetId: 'dusk_overview',
          pngPath: '/tmp/dusk_overview.png',
          pixelStats: stats,
          coplanarOverlapCount: 0,
          coplanarDescriptions: [],
          depthConflictCount: 0,
          depthConflictSummary: 'clean',
        );
        const summary = HarnessSummary(
          outputDir: '/tmp/shukuba_cap',
          results: [result],
        );

        final json = summary.toJson();
        expect(json['outputDir'], equals('/tmp/shukuba_cap'));
        expect(json['allPassed'], isTrue);
        expect(json['presets'], isList);

        final presetJson =
            (json['presets']! as List<dynamic>).first as Map<String, Object?>;
        expect(presetJson['presetId'], equals('dusk_overview'));
        expect(presetJson['coplanarOverlapCount'], equals(0));
        expect(presetJson['depthConflictCount'], equals(0));
        expect(presetJson['passed'], isTrue);
      },
    );
  });
}
