import 'package:flutter_scene/scene.dart' show Material, Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_shell_overlays.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';
import 'package:material_ui/material_ui.dart' hide Material, Matrix4;

class _FakeLookDriver implements ShukubaLookDriver {
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
    syncCount++;
  }

  @override
  void dispose() {}
}

class _FakeAudioDriver implements ShukubaAudioDriver {
  @override
  bool get isMuted => false;

  @override
  double get masterVolume => 1;

  @override
  Future<void> prewarm() async {}

  @override
  void setMuted(bool muted) {}

  @override
  void setMasterVolume(double volume) {}

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
  void playPlacementNote(PlacementNoteEvent event) {}

  @override
  void dispose() {}
}

bool _isFiniteVec3(Vec3 v) => v.x.isFinite && v.y.isFinite && v.z.isFinite;

void main() {
  group('ShowcaseRealm and Minato-jo camera presets', () {
    test(
      'ShowcaseRealm.fromId parses minato variants and defaults to shukuba',
      () {
        expect(ShowcaseRealm.fromId('minato'), ShowcaseRealm.minatoJo);
        expect(ShowcaseRealm.fromId('MINATO_JO'), ShowcaseRealm.minatoJo);
        expect(ShowcaseRealm.fromId('minato-jo'), ShowcaseRealm.minatoJo);
        expect(ShowcaseRealm.fromId('shukuba'), ShowcaseRealm.shukubaValley);
        expect(ShowcaseRealm.fromId(''), ShowcaseRealm.shukubaValley);
      },
    );

    test(
      'verificationPresets unchanged and minatoVerificationPresets has 6',
      () {
        expect(CameraPreset.verificationPresets.length, equals(6));
        expect(
          CameraPreset.verificationPresets.last,
          equals(CameraPreset.countrysideVista),
        );
        expect(CameraPreset.minatoVerificationPresets.length, equals(6));
        expect(
          ShowcaseRealm.minatoJo.defaultPreset,
          equals(CameraPreset.minatoCitadelOverview),
        );
        expect(
          ShowcaseRealm.minatoJo.hudPresets,
          equals(CameraPreset.minatoVerificationPresets),
        );
      },
    );
  });

  group('Minato-jo terrain and ward topology', () {
    test(
      'TerrainBuilder in minatoJo creates castle peak, flat quay, and bay',
      () {
        final terrain = TerrainBuilder(realm: ShowcaseRealm.minatoJo);
        final summitY = terrain.sampleGroundHeight(11.5, -27.5);
        final quayY = terrain.sampleGroundHeight(2.2, 5.5);
        final bayFloorY = terrain.sampleGroundHeight(22, 5.5);
        final spitY = terrain.sampleGroundHeight(23.5, 32.5);

        expect(summitY, greaterThan(6.0));
        expect(quayY, closeTo(0.78, 0.12));
        expect(bayFloorY, lessThan(-2.0));
        expect(spitY, greaterThan(0.5));

        for (final coveZ in const [-56.0, 52.0]) {
          final cx = TerrainBuilder.minatoCoastlineX(coveZ);
          final slope =
              ((terrain.sampleGroundHeight(cx - 2.5, coveZ) -
                          terrain.sampleGroundHeight(cx + 2.5, coveZ)) /
                      5.0)
                  .abs();
          expect(slope, lessThan(0.45));
        }
      },
    );

    test(
      'buildMinatoJoGraph populates finite roads, buildings, and lantern spans',
      () {
        final terrain = TerrainBuilder(realm: ShowcaseRealm.minatoJo);
        final graph = buildMinatoJoGraph(terrain.sampleGroundHeight);

        expect(graph.roads.length, greaterThanOrEqualTo(5));
        expect(graph.terraces.length, greaterThanOrEqualTo(2));
        expect(graph.walls.length, greaterThanOrEqualTo(4));
        expect(graph.structures.length, greaterThanOrEqualTo(30));
        expect(graph.lanternSpans.length, greaterThanOrEqualTo(8));
        expect(graph.structuralSightcones, isEmpty);
        expect(
          graph.structures.values.where((s) => s.kind.isBotanicalTree).length,
          greaterThanOrEqualTo(90),
        );
        expect(
          graph.structures.values.any((s) => s.kind == StructureKind.minka),
          isTrue,
        );

        for (final road in graph.roads) {
          expect(road.controlPoints.every(_isFiniteVec3), isTrue);
        }
        for (final s in graph.structures.values) {
          expect(_isFiniteVec3(s.position), isTrue);
          expect(s.yawRadians.isFinite, isTrue);
        }
      },
    );

    test(
      'buildMinatoCastleAndHarborPlacements includes castle and harbor assets',
      () {
        final terrain = TerrainBuilder(realm: ShowcaseRealm.minatoJo);
        final placements = buildMinatoCastleAndHarborPlacements(
          terrain.sampleGroundHeight,
        );
        final paths = placements.map((p) => p.assetPath).toSet();

        expect(paths, contains('assets/models/castle_tenshukaku.glb'));
        expect(paths, contains('assets/models/castle_otemon_gate.glb'));
        expect(paths, contains('assets/models/harbor_pier.glb'));
        expect(paths, contains('assets/models/harbor_todai.glb'));
        expect(paths, contains('assets/models/ship_sengokubune.glb'));
        expect(paths, contains('assets/models/boat_wasen.glb'));
        expect(paths, contains('assets/models/rock_coastal_shelf.glb'));
        expect(paths, contains('assets/models/tree_shrub_cluster.glb'));

        for (final p in placements) {
          expect(p.x.isFinite && p.y.isFinite && p.z.isFinite, isTrue);
          expect(p.yaw.isFinite, isTrue);
        }
      },
    );
  });

  group('Headless realm switching in EdoWorldDriver & ShukubaController', () {
    test(
      'EdoWorldDriver initializes in minatoJo and switches cleanly',
      () async {
        final world = EdoWorldDriver(initialRealm: ShowcaseRealm.minatoJo)
          ..initSimulation(rebuildAgentNodes: false);

        expect(world.realm, ShowcaseRealm.minatoJo);
        expect(
          world.graph.structures.containsKey(
            const EntityId('torii_harbor_quay'),
          ),
          isTrue,
        );
        expect(world.agents.length, greaterThanOrEqualTo(8));
        expect(world.activeLanternOrigins.length, greaterThan(10));

        for (var i = 0; i < 40; i++) {
          world.step(0.05, rig: TimeOfDayRig.goldenDusk);
        }
        expect(
          world.agents.every(
            (a) => _isFiniteVec3(a.position) && a.yawRadians.isFinite,
          ),
          isTrue,
        );

        await world.switchRealm(ShowcaseRealm.shukubaValley);
        expect(world.realm, ShowcaseRealm.shukubaValley);
        expect(
          world.graph.structures.containsKey(const EntityId('torii_west_gate')),
          isTrue,
        );
      },
    );

    test(
      'ShukubaController.switchRealm swaps realm, timeOfDay, and syncs look',
      () async {
        final look = _FakeLookDriver();
        final world = EdoWorldDriver()
          ..initSimulation(rebuildAgentNodes: false);
        final audio = _FakeAudioDriver();
        final controller = ShukubaController(
          look: look,
          world: world,
          audio: audio,
        );
        await controller.initialize();
        final initialSyncs = look.syncCount;

        expect(controller.activeRealm, ShowcaseRealm.shukubaValley);
        await controller.switchRealm(ShowcaseRealm.minatoJo);

        expect(controller.activeRealm, ShowcaseRealm.minatoJo);
        expect(
          controller.timeOfDay,
          ShowcaseRealm.minatoJo.defaultPreset.timeOfDay,
        );
        expect(look.syncCount, greaterThan(initialSyncs));
      },
    );

    testWidgets(
      'ShukubaHud realm button and TitleMenuOverlay CTA invoke callbacks',
      (tester) async {
        ShowcaseRealm? hudRealm;
        ShowcaseRealm? titleRealm;
        final look = _FakeLookDriver();
        final world = EdoWorldDriver()
          ..initSimulation(rebuildAgentNodes: false);
        final controller = ShukubaController(
          look: look,
          world: world,
          audio: _FakeAudioDriver(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ShukubaHud(
                controller: controller,
                onSelectPreset: (_) {},
                onSwitchRealm: (r) => hudRealm = r,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Shukuba 宿場'));
        await tester.pump();
        expect(hudRealm, ShowcaseRealm.minatoJo);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TitleMenuOverlay(
                onEnterValley: () {},
                onEnterRealm: (r) => titleRealm = r,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Minato-jō (港城 · Castle Port)'));
        await tester.pump();
        expect(titleRealm, ShowcaseRealm.minatoJo);
      },
    );
  });
}
