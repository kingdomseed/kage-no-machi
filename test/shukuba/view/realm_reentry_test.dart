import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_scene/scene.dart' show Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/look/look.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_page.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_shell_overlays.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';
import 'package:material_ui/material_ui.dart' hide Material;

import '../../e2e/helpers/e2e_test_harness.dart';

bool _checkGpuAvailable() {
  try {
    Scene().dispose();
    return true;
  } on Object catch (_) {
    return false;
  }
}

Future<void> _pumpMicrotasksAndFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final gpuAvailable = _checkGpuAvailable();

  group('Town re-entry and detach lifecycle regressions', () {
    test('EdoWorldDriver detach and dispose before attach do not throw', () {
      final driver = EdoWorldDriver();
      expect(driver.detach, returnsNormally);
      expect(driver.dispose, returnsNormally);
    });

    test('EdoLookDriver detach and dispose before attach do not throw', () {
      final driver = EdoLookDriver(allowHeadlessFallback: true);
      expect(driver.detach, returnsNormally);
      expect(driver.dispose, returnsNormally);
    });

    test(
      'ShukubaController.detachFromScene resets ready state safely',
      () async {
      final look = FakeLookDriver();
      final world = EdoWorldDriver();
      final audio = FakeAudioDriver();
      final controller = ShukubaController(
        look: look,
        world: world,
        audio: audio,
      );

      await controller.initialize();
      expect(controller.isReady, isTrue);

      controller.detachFromScene();
      expect(controller.isReady, isFalse);
      expect(audio.isDisposed, isTrue);

      controller.dispose();
    });

    testWidgets(
      'LoadingCurtainOverlay renders active realm name and subtitle',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: LoadingCurtainOverlay(
                activeStage: BootStageId.valleyTerrain,
                completedTimings: [],
                realm: ShowcaseRealm.minatoJo,
              ),
            ),
          ),
        );

        expect(find.text('Preparing Minato-jō'), findsOneWidget);
        expect(find.text('港城の構築 (Staged Warmup)'), findsOneWidget);
      },
    );

    testWidgets(
      'Title Menu -> Town A -> Title Menu -> Town B -> Title Menu -> Town A '
      'switches realms cleanly without getting stuck',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final world = EdoWorldDriver();
        final look = FakeLookDriver();
        final audio = FakeAudioDriver();

        await tester.pumpWidget(
          MaterialApp(
            home: ShukubaPage(
              worldDriver: world,
              lookDriver: look,
              audioDriver: audio,
              initialMode: ShukubaShellMode.titleMenu,
            ),
          ),
        );
        await _pumpMicrotasksAndFrames(tester);

        expect(find.byType(TitleMenuOverlay), findsOneWidget);

        await tester.tap(find.text('Enter Valley (渓谷へ入る)'));
        await _pumpMicrotasksAndFrames(tester);

        expect(find.byType(TitleMenuOverlay), findsNothing);
        expect(find.text('Shukuba 宿場'), findsOneWidget);
        expect(world.realm, ShowcaseRealm.shukubaValley);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await _pumpMicrotasksAndFrames(tester);
        expect(find.byType(PauseMenuOverlay), findsOneWidget);

        await tester.tap(find.text('Return to Title (表紙へ戻る)'));
        await _pumpMicrotasksAndFrames(tester);
        expect(find.byType(TitleMenuOverlay), findsOneWidget);

        await tester.tap(find.text('Minato-jō (港城 · Castle Port)'));
        await _pumpMicrotasksAndFrames(tester);

        expect(find.byType(TitleMenuOverlay), findsNothing);
        expect(find.text('Minato-jō 港城'), findsOneWidget);
        expect(world.realm, ShowcaseRealm.minatoJo);
        expect(world.graph.structures, isNotEmpty);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await _pumpMicrotasksAndFrames(tester);
        expect(find.byType(PauseMenuOverlay), findsOneWidget);

        await tester.tap(find.text('Return to Title (表紙へ戻る)'));
        await _pumpMicrotasksAndFrames(tester);
        expect(find.byType(TitleMenuOverlay), findsOneWidget);

        await tester.tap(find.text('Enter Valley (渓谷へ入る)'));
        await _pumpMicrotasksAndFrames(tester);

        expect(find.byType(TitleMenuOverlay), findsNothing);
        expect(find.text('Shukuba 宿場'), findsOneWidget);
        expect(world.realm, ShowcaseRealm.shukubaValley);
        expect(world.graph.structures, isNotEmpty);
      },
    );

    test(
      'EdoWorldDriver and EdoLookDriver re-attach cleanly across multiple '
      'Scenes (GPU)',
      () async {
        final look = EdoLookDriver(allowHeadlessFallback: true);
        final world = EdoWorldDriver();
        final scene1 = Scene();
        final scene2 = Scene();

        await look.attach(scene1);
        await world.attachStaged(scene1, resolveMaterial: look.materialFor);
        expect(scene1.root.children, isNotEmpty);
        expect(world.graph.structures, isNotEmpty);

        world.detach();
        look.detach();
        scene1.dispose();

        await world.switchRealm(ShowcaseRealm.minatoJo);
        await look.attach(scene2);
        await world.attachStaged(scene2, resolveMaterial: look.materialFor);
        expect(world.realm, ShowcaseRealm.minatoJo);
        expect(world.graph.structures, isNotEmpty);
        expect(scene2.root.children, isNotEmpty);

        final secondAttachChildCount = scene2.root.children.length;
        // Re-attaching directly to a fresh scene without explicit detach first
        // must still detach cleanly instead of throwing or duplicating decals.
        final scene3 = Scene();
        await look.attach(scene3);
        await world.attachStaged(scene3, resolveMaterial: look.materialFor);
        expect(scene3.root.children.length, secondAttachChildCount);

        world.dispose();
        look.dispose();
        scene2.dispose();
        scene3.dispose();
      },
      skip: !gpuAvailable ? 'Requires Impeller/Flutter GPU backend' : false,
    );
  });
}
