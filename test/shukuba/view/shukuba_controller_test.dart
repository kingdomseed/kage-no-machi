import 'dart:ui' show Offset, Size;

import 'package:flutter_scene/scene.dart' show Material, Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
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
  void step(double dtSeconds, {required TimeOfDayRig rig}) {}

  @override
  double sampleGroundHeight(double x, double z) => 0;

  @override
  void dispose() {}
}

class _FakeAudioDriver implements ShukubaAudioDriver {
  final List<PlacementNoteEvent> notes = [];

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
  group('ShukubaController and TacticalCameraRig', () {
    test(
      'stamping lane and facing machiya derives spans and switches Yo/In-sen',
      () async {
        final look = _FakeLookDriver();
        final world = _FakeWorldDriver();
        final audio = _FakeAudioDriver();
        final controller = ShukubaController(
          look: look,
          world: world,
          audio: audio,
        );
        await controller.initialize(Scene());

        controller
          ..selectTool(const DrawLaneTool())
          ..handlePrimaryPlotTap(const Vec3(-12, 0, 0))
          ..handlePrimaryPlotTap(const Vec3(12, 0, 0));
        expect(controller.commitActiveStroke(), isTrue);
        expect(controller.graph.roads, hasLength(1));

        controller
          ..setTimeOfDay(0.20)
          ..selectTool(const StampStructureTool(kind: StructureKind.machiya))
          ..handlePrimaryPlotTap(const Vec3(0, 0, -2.5));
        expect(audio.notes.last.scale, PentatonicScale.yo);
        expect(audio.notes.last.instrument, EdoInstrument.koto);

        controller
          ..setTimeOfDay(0.85)
          ..handlePrimaryPlotTap(const Vec3(0, 0, 2.5));
        expect(audio.notes.last.scale, PentatonicScale.inSen);
        expect(controller.graph.structures, hasLength(2));

        controller.selectTool(
          const StampStructureTool(kind: StructureKind.yaguraTower),
        );
        expect(
          controller.effectiveVision,
          MagistrateVisionState.watchtowerPreview,
        );

        controller.toggleMagistrateEye();
        expect(controller.effectiveVision, MagistrateVisionState.fullOverlay);
        expect(look.lastVision, MagistrateVisionState.fullOverlay);

        controller.dispose();
      },
    );

    test('TacticalCameraRig raycasts viewport center onto target ground', () {
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
    });
  });
}
