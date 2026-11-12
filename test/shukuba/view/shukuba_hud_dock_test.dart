import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Material;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';

import '../../e2e/helpers/e2e_test_harness.dart';

void main() {
  group('Feature 18: Collapsible 4-Category Builder Dock & Sumi-e Icons', () {
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

    testWidgets('Renders all 4 category tabs and defaults to fully expanded', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
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

      expect(find.text('Dwellings & Shops'), findsOneWidget);
      expect(find.text('Roads & Walls'), findsOneWidget);
      expect(find.text('Trees & Rocks'), findsOneWidget);
      expect(find.text('Shrines & Courtyards'), findsOneWidget);

      expect(find.text('Townhouse'), findsOneWidget);
      expect(find.text('Farmhouse'), findsOneWidget);
      expect(find.text('Road'), findsOneWidget);
      expect(find.text('Courtyard Wall'), findsOneWidget);
      expect(find.text('Bamboo Grove'), findsOneWidget);
      expect(find.text('Bell Pavilion'), findsOneWidget);
      expect(find.text('Zen Gravel Court'), findsOneWidget);
      expect(find.text('Courtyard Well'), findsOneWidget);
      expect(find.text('Lantern Gate'), findsOneWidget);
    });

    testWidgets('Tapping category tabs toggles expand/collapse state', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
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

      expect(find.text('Townhouse'), findsOneWidget);

      await tester.tap(find.text('Dwellings & Shops'));
      await tester.pump();

      expect(find.text('Townhouse'), findsNothing);
      expect(find.text('Farmhouse'), findsNothing);

      expect(find.text('Road'), findsOneWidget);
      expect(find.text('Bell Pavilion'), findsOneWidget);

      await tester.tap(find.text('Dwellings & Shops'));
      await tester.pump();

      expect(find.text('Townhouse'), findsOneWidget);
      expect(find.text('Farmhouse'), findsOneWidget);
    });

    testWidgets('Selecting tool cards selects appropriate PlacementTool', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
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

      await tester.tap(find.text('Bell Pavilion'));
      await tester.pump();
      expect(
        controller.activeTool,
        equals(const StampStructureTool(kind: StructureKind.shoroBell)),
      );

      await tester.tap(find.text('Zen Gravel Court'));
      await tester.pump();
      expect(
        controller.activeTool,
        equals(const StampStructureTool(kind: StructureKind.karesansuiGarden)),
      );

      await tester.tap(find.text('Courtyard Well'));
      await tester.pump();
      expect(
        controller.activeTool,
        equals(const StampStructureTool(kind: StructureKind.stoneWell)),
      );

      await tester.tap(find.text('Farmhouse'));
      await tester.pump();
      expect(
        controller.activeTool,
        equals(const StampStructureTool(kind: StructureKind.minka)),
      );

      await tester.tap(find.text('Road'));
      await tester.pump();
      expect(controller.activeTool, equals(const DrawLaneTool()));

      await tester.tap(find.text('Demolish'));
      await tester.pump();
      expect(controller.activeTool, equals(const DemolishTool()));
    });

    testWidgets(
      'Rotate chip appears when stamp tool is active and rotates yaw',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
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

        await tester.tap(find.text('Bell Pavilion'));
        await tester.pump();

        expect(find.text('Rotate [R]'), findsOneWidget);

        await tester.tap(find.text('Rotate [R]'));
        await tester.pump();

        final tool = controller.activeTool as StampStructureTool;
        expect(tool.yawOffsetRadians, closeTo(3.14159 / 4, 1e-3));
      },
    );

    test('InkBrushIconPainter paints all 25 icons without error', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(24, 24);

      for (final kind in InkBrushIconKind.values) {
        final painter = InkBrushIconPainter(icon: kind, color: Colors.amber);
        expect(
          () => painter.paint(canvas, size),
          returnsNormally,
          reason: 'Failed to paint icon $kind',
        );
        expect(painter.shouldRepaint(painter), isFalse);
      }
    });
  });
}
