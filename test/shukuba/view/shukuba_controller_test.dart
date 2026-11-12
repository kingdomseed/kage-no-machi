import 'package:flutter/material.dart' hide Material, Matrix4;
import 'package:flutter_scene/scene.dart' show Material, Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:kage_no_machi/shukuba/view/tactical_camera_rig.dart';

class _FakeLookDriver implements ShukubaLookDriver {
  MagistrateVisionState lastVision = MagistrateVisionState.hidden;
  TimeOfDayRig lastRig = TimeOfDayRig.goldenDusk;
  int syncCount = 0;

  @override
  Future<void> attach(Scene scene) async {}

  @override
  Material materialFor(ShukubaSurfaceRole role) => defaultShukubaMaterial(role);

  @override
  void syncFrame({
    required TimeOfDayRig rig,
    required MagistrateVisionState vision,
    required List<WatchSightcone> sightcones,
    required List<Vec3> lanternOrigins,
    required double elapsedSeconds,
  }) {
    lastRig = rig;
    lastVision = vision;
    syncCount++;
  }

  @override
  void dispose() {}
}

class _FakeWorldDriver implements ShukubaWorldDriver {
  ShukubaGraph _graph = ShukubaGraph.empty;
  BuildPreview lastPreview = const NoBuildPreview();

  @override
  ShukubaGraph get graph => _graph;

  @override
  List<WatchSightcone> get activeSightcones => _graph.structuralSightcones;

  @override
  List<Vec3> get activeLanternOrigins => _graph.catenaryLightOrigins;

  @override
  Map<AmbientLoopKind, Vec3> get ambientLoopAnchors => const {};

  @override
  List<StreetAgentSnapshot> get agents => const [];

  @override
  Future<void> attach(
    Scene scene, {
    ShukubaMaterialResolver resolveMaterial = defaultShukubaMaterial,
    ShukubaGraph? initialGraph,
  }) async {
    if (initialGraph != null) {
      _graph = initialGraph;
    }
  }

  @override
  void applyGraph(ShukubaGraph nextGraph) {
    _graph = nextGraph;
  }

  @override
  void syncPreview(BuildPreview preview) {
    lastPreview = preview;
  }

  @override
  void step(double dtSeconds, {required TimeOfDayRig rig}) {}

  @override
  double sampleGroundHeight(double x, double z) => 0;

  @override
  void dispose() {}
}

class _FakeAudioDriver implements ShukubaAudioDriver {
  final List<PlacementNoteEvent> notes = [];
  bool _isMuted = false;
  double _masterVolume = 1;

  @override
  bool get isMuted => _isMuted;

  @override
  double get masterVolume => _masterVolume;

  @override
  void setMuted(bool muted) {
    _isMuted = muted;
  }

  @override
  void setMasterVolume(double volume) {
    _masterVolume = volume.clamp(0.0, 1.0);
  }

  @override
  Future<void> prewarm() async {}

  @override
  Future<void> attach(
    Scene scene, {
    Map<AmbientLoopKind, Vec3> loopAnchors = const {},
  }) async {}

  @override
  void syncAtmosphere({
    required TimeOfDayRig rig,
    Map<AmbientLoopKind, Vec3>? loopAnchors,
  }) {}

  @override
  void playPlacementNote(PlacementNoteEvent event) {
    notes.add(event);
  }

  @override
  void dispose() {}
}

void main() {
  group('ShukubaController, HUD, and TacticalCameraRig', () {
    test('lane, hover ghost, drag wall, demolish, and undo work', () async {
      final look = _FakeLookDriver();
      final world = _FakeWorldDriver();
      final audio = _FakeAudioDriver();
      final controller = ShukubaController(
        look: look,
        world: world,
        audio: audio,
      );
      await controller.initialize();

      expect(controller.activeTool, isA<ExploreTool>());
      controller.updateHoverPoint(Vec3.zero);
      expect(world.lastPreview, isA<NoBuildPreview>());

      controller
        ..selectTool(const DrawLaneTool())
        ..beginStrokeAt(const Vec3(-12, 0, 0))
        ..extendStrokeTo(const Vec3(-6, 0, 0))
        ..extendStrokeTo(const Vec3(6, 0, 0))
        ..extendStrokeTo(const Vec3(12, 0, 0));
      expect(world.lastPreview, isA<StrokeRibbonPreview>());
      expect(controller.finishDragStroke(), isTrue);
      expect(controller.graph.roads, hasLength(1));
      expect(controller.canUndo, isTrue);

      controller
        ..setTimeOfDay(0.20)
        ..selectTool(const StampStructureTool(kind: StructureKind.machiya))
        ..handlePrimaryPlotTap(const Vec3(0, 0, -2.5));
      expect(audio.notes.last.scale, PentatonicScale.yo);
      expect(audio.notes.last.instrument, EdoInstrument.koto);

      controller
        ..selectTool(const StampStructureTool(kind: StructureKind.chaya))
        ..updateHoverPoint(const Vec3(0, 0, 2.5));
      expect(world.lastPreview, isA<StampGhostPreview>());
      final ghost = world.lastPreview as StampGhostPreview;
      expect(ghost.kind, StructureKind.chaya);
      expect(ghost.lanternSpans, isNotEmpty);

      controller
        ..setTimeOfDay(0.85)
        ..handlePrimaryPlotTap(const Vec3(0, 0, 2.5));
      expect(audio.notes.last.scale, PentatonicScale.inSen);
      expect(controller.graph.structures, hasLength(2));
      expect(controller.graph.lanternSpans, isNotEmpty);

      controller
        ..selectTool(const BuildWallTool())
        ..beginStrokeAt(const Vec3(6, 0, -8))
        ..extendStrokeTo(const Vec3(12, 0, -8));
      expect(controller.finishDragStroke(), isTrue);
      expect(controller.graph.walls, hasLength(1));

      controller
        ..selectTool(const DemolishTool())
        ..updateHoverPoint(const Vec3(9, 0, -8));
      expect(world.lastPreview, isA<DemolishHoverPreview>());
      controller.handlePrimaryPlotTap(const Vec3(9, 0, -8));
      expect(controller.graph.walls, isEmpty);

      expect(controller.undo(), isTrue);
      expect(controller.graph.walls, hasLength(1));

      controller.toggleTool(const DemolishTool());
      expect(controller.activeTool, isA<ExploreTool>());
      expect(world.lastPreview, isA<NoBuildPreview>());

      controller.applyCameraPresetState(CameraPreset.riverCrossing);
      expect(world.lastPreview, isA<NoBuildPreview>());
      expect(look.lastVision, MagistrateVisionState.hidden);

      controller.dispose();
    });

    testWidgets('ShukubaHud shows Edo city-builder tools with zero watch UI', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = ShukubaController(
        look: _FakeLookDriver(),
        world: _FakeWorldDriver(),
        audio: _FakeAudioDriver(),
      );
      await controller.initialize();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShukubaHud(controller: controller, onSelectPreset: (_) {}),
          ),
        ),
      );

      expect(find.text('Townhouse'), findsOneWidget);
      expect(find.text('Teahouse'), findsOneWidget);
      expect(find.text('Storehouse'), findsOneWidget);
      expect(find.text('Market Stall'), findsOneWidget);
      expect(find.text('Lantern Gate'), findsOneWidget);
      expect(find.text('Road'), findsOneWidget);
      expect(find.text('Garden Path'), findsOneWidget);
      expect(find.text('Stone Terrace'), findsOneWidget);
      expect(find.text('Courtyard Wall'), findsOneWidget);
      expect(find.text('Rock Outcrop'), findsOneWidget);
      expect(find.text('Black Pine'), findsOneWidget);
      expect(find.text('Weeping Willow'), findsOneWidget);
      expect(find.text('4 Gorge & Garden'), findsOneWidget);
      expect(find.text('Demolish'), findsOneWidget);
      expect(find.text('Undo [Z]'), findsOneWidget);

      expect(find.textContaining('Magistrate'), findsNothing);
      expect(find.text('Yagura'), findsNothing);
      expect(find.text('Watch'), findsNothing);
      expect(find.text('Done [Esc]'), findsNothing);

      await tester.tap(find.text('Road'));
      await tester.pump();
      expect(controller.activeTool, const DrawLaneTool());

      await tester.tap(find.text('Garden Path'));
      await tester.pump();
      expect(
        controller.activeTool,
        const DrawLaneTool(style: RoadStyle.gardenPath, widthMeters: 1.75),
      );

      await tester.tap(find.text('Townhouse'));
      await tester.pump();
      expect(
        controller.activeTool,
        const StampStructureTool(kind: StructureKind.machiya),
      );
      expect(find.text('Done [Esc]'), findsOneWidget);

      await tester.tap(find.text('Done [Esc]'));
      await tester.pump();
      expect(controller.activeTool, isA<ExploreTool>());
      expect(find.text('Done [Esc]'), findsNothing);
    });

    test('TacticalCameraRig raycasts center and orbits smoothly by delta', () {
      final rig = TacticalCameraRig();
      final hit = rig.raycastGround(
        const Offset(480, 270),
        const Size(960, 540),
        (_, _) => 1.4,
      );
      expect(hit, isNotNull);
      expect(hit!.x, closeTo(0, 0.25));
      expect(hit.z, closeTo(0, 0.25));
      expect(hit.y, closeTo(1.4, 1e-6));

      final yawBefore = rig.yawRadians;
      final pitchBefore = rig.pitchRadians;
      rig.orbitByScreenDelta(const Offset(120, 60), const Size(960, 540));
      expect(rig.yawRadians, isNot(closeTo(yawBefore, 1e-4)));
      expect(rig.pitchRadians, greaterThan(pitchBefore));
      expect(
        rig.pitchRadians,
        inInclusiveRange(
          TacticalCameraRig.minPitchRadians,
          TacticalCameraRig.maxPitchRadians,
        ),
      );

      rig.orbitByScreenDelta(const Offset(0, 5000), const Size(960, 540));
      expect(
        rig.pitchRadians,
        closeTo(TacticalCameraRig.maxPitchRadians, 1e-6),
      );
      rig.orbitByScreenDelta(const Offset(0, -5000), const Size(960, 540));
      expect(
        rig.pitchRadians,
        closeTo(TacticalCameraRig.minPitchRadians, 1e-6),
      );
    });
  });
}
