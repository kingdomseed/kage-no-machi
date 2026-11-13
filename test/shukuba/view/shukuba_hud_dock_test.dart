import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:material_ui/material_ui.dart' hide Material;

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

    testWidgets(
      'Renders calm single-row dock by default with zero drawers expanded',
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

        expect(find.text('Dwellings & Shops'), findsOneWidget);
        expect(find.text('Roads & Walls'), findsOneWidget);
        expect(find.text('Trees & Rocks'), findsOneWidget);
        expect(find.text('Shrines & Courtyards'), findsOneWidget);
        expect(find.text('Views'), findsOneWidget);

        expect(find.text('Townhouse'), findsNothing);
        expect(find.text('Farmhouse'), findsNothing);
        expect(find.text('Road'), findsNothing);
        expect(find.text('Bamboo Grove'), findsNothing);
        expect(find.text('Bell Pavilion'), findsNothing);
        expect(find.text('Done'), findsNothing);

        const dockButtonLabels = [
          'Dwellings & Shops',
          'Roads & Walls',
          'Trees & Rocks',
          'Shrines & Courtyards',
          'Demolish',
          'Undo',
        ];
        for (final label in dockButtonLabels) {
          final btn = find
              .ancestor(
                of: find.text(label),
                matching: find.byType(GestureDetector),
              )
              .first;
          expect(
            tester.getSize(btn).height,
            equals(32.0),
            reason: 'Expected 32px height for bottom dock button "$label"',
          );
        }

        for (final textWidget in tester.widgetList<Text>(
          find.descendant(
            of: find.byType(ShukubaHud),
            matching: find.byType(Text),
          ),
        )) {
          final data = textWidget.data ?? '';
          expect(data, isNot(contains('[')));
          expect(data, isNot(contains(']')));
        }
      },
    );

    testWidgets(
      'Tapping category tabs opens one drawer at a time and collapses cleanly',
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

        await tester.tap(find.text('Dwellings & Shops'));
        await tester.pump();

        expect(find.text('Townhouse'), findsOneWidget);
        expect(find.text('Farmhouse'), findsOneWidget);
        expect(find.text('Road'), findsNothing);
        expect(find.text('Bell Pavilion'), findsNothing);

        await tester.tap(find.text('Roads & Walls'));
        await tester.pump();

        expect(find.text('Townhouse'), findsNothing);
        expect(find.text('Road'), findsOneWidget);
        expect(find.text('Courtyard Wall'), findsOneWidget);

        await tester.tap(find.text('Roads & Walls'));
        await tester.pump();

        expect(find.text('Road'), findsNothing);
      },
    );

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

      await tester.tap(find.text('Shrines & Courtyards'));
      await tester.pump();

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

      await tester.tap(find.text('Dwellings & Shops'));
      await tester.pump();

      await tester.tap(find.text('Farmhouse'));
      await tester.pump();
      expect(
        controller.activeTool,
        equals(const StampStructureTool(kind: StructureKind.minka)),
      );

      expect(find.textContaining('Style:'), findsOneWidget);
      await tester.tap(find.textContaining('Style:'));
      await tester.pump();
      expect(
        controller.activeTool,
        equals(const StampStructureTool(kind: StructureKind.minka, variant: 1)),
      );

      await tester.tap(find.text('Roads & Walls'));
      await tester.pump();

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

        await tester.tap(find.text('Shrines & Courtyards'));
        await tester.pump();
        await tester.tap(find.text('Bell Pavilion'));
        await tester.pump();

        expect(find.text('Rotate'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);

        final rotateBtn = find
            .ancestor(
              of: find.text('Rotate'),
              matching: find.byType(GestureDetector),
            )
            .first;
        final doneBtn = find
            .ancestor(
              of: find.text('Done'),
              matching: find.byType(GestureDetector),
            )
            .first;
        expect(tester.getSize(rotateBtn).height, equals(32.0));
        expect(tester.getSize(doneBtn).height, equals(32.0));

        final viewsBtn = find
            .ancestor(
              of: find.text('Views'),
              matching: find.byType(GestureDetector),
            )
            .first;
        expect(tester.getSize(viewsBtn).height, equals(32.0));

        final wardBox = find
            .ancestor(
              of: find.text('KAGE NO MACHI'),
              matching: find.byType(DecoratedBox),
            )
            .first;
        final atmoBox = find
            .ancestor(
              of: find.byType(Slider),
              matching: find.byType(DecoratedBox),
            )
            .first;
        expect(tester.getSize(wardBox).height, equals(44.0));
        expect(tester.getSize(atmoBox).height, equals(44.0));

        final cardBtn = find
            .ancestor(
              of: find.text('Bell Pavilion'),
              matching: find.byType(GestureDetector),
            )
            .first;
        expect(tester.getSize(cardBtn).height, equals(42.0));

        await tester.tap(find.text('Rotate'));
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
