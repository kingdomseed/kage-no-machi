import 'package:flutter_scene/scene.dart' show Animation, Material, Node, Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/world/edo_world_driver.dart';

class _StubLookDriver implements ShukubaLookDriver {
  int syncCount = 0;

  @override
  Future<void> attach(Scene scene) async {}

  @override
  void dispose() {}

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
    syncCount++;
  }
}

class _StubAudioDriver implements ShukubaAudioDriver {
  final List<PlacementNoteEvent> notes = [];
  double _volume = 1;

  @override
  bool get isMuted => false;

  @override
  double get masterVolume => _volume;

  @override
  void setMasterVolume(double volume) => _volume = volume;

  @override
  Future<void> attach(
    Scene scene, {
    Map<AmbientLoopKind, Vec3> loopAnchors = const {},
  }) async {}

  @override
  void dispose() {}

  @override
  void playPlacementNote(PlacementNoteEvent event) => notes.add(event);

  @override
  Future<void> prewarm() async {}

  @override
  void setMuted(bool muted) {}

  @override
  void syncAtmosphere({
    required TimeOfDayRig rig,
    Map<AmbientLoopKind, Vec3>? loopAnchors,
  }) {}
}

void main() {
  group('House cutaway peeking (EdoWorldDriver)', () {
    test('classifies canonical peek_roof, peek_upper, and interior_ names', () {
      expect(EdoWorldDriver.isPeekRoofNodeName('peek_roof_kawara'), isTrue);
      expect(EdoWorldDriver.isPeekRoofNodeName('peek_upper_plaster'), isTrue);
      expect(EdoWorldDriver.isPeekRoofNodeName('exterior_stone'), isFalse);

      expect(EdoWorldDriver.isInteriorNodeName('interior_room_tatami'), isTrue);
      expect(
        EdoWorldDriver.isInteriorNodeName('interior_props_hearth'),
        isTrue,
      );
      expect(EdoWorldDriver.isInteriorNodeName('exterior_shoji'), isFalse);
    });

    test(
      'toggles visibility and clears shadowStatic on roof and interior trees',
      () {
        final root = Node(name: 'hero_structure_test');
        final exterior = Node(name: 'exterior_walls')..shadowStatic = true;
        final roof = Node(name: 'peek_roof_kawara')..shadowStatic = true;
        final upper = Node(name: 'peek_upper_frame')..shadowStatic = true;
        final room = Node(name: 'interior_room_tatami')..shadowStatic = true;
        final props = Node(name: 'interior_props_hearth')..shadowStatic = true;
        root
          ..add(exterior)
          ..add(roof)
          ..add(upper)
          ..add(room)
          ..add(props);

        expect(
          EdoWorldDriver.applyPeekStateToSubtree(root, peeked: false),
          isTrue,
        );
        expect(exterior.visible, isTrue);
        expect(exterior.shadowStatic, isTrue);
        expect(roof.visible, isTrue);
        expect(upper.visible, isTrue);
        expect(room.visible, isFalse);
        expect(props.visible, isFalse);
        expect(roof.shadowStatic, isFalse);
        expect(upper.shadowStatic, isFalse);
        expect(room.shadowStatic, isFalse);
        expect(props.shadowStatic, isFalse);

        expect(
          EdoWorldDriver.applyPeekStateToSubtree(root, peeked: true),
          isTrue,
        );
        expect(exterior.visible, isTrue);
        expect(roof.visible, isFalse);
        expect(upper.visible, isFalse);
        expect(room.visible, isTrue);
        expect(props.visible, isTrue);
      },
    );

    test(
      'hit-tests peekable buildings and adds interior lantern origin on peek',
      () {
        final world = EdoWorldDriver()
          ..initSimulation(rebuildAgentNodes: false);
        final targetHouse =
            world.graph.structures[const EntityId('machiya_west_s1')]!;
        final baseOrigins = world.activeLanternOrigins.length;

        final hitId = world.findPeekableStructureAt(
          targetHouse.position + const Vec3(0.3, 0, -0.2),
        );
        expect(hitId, equals(targetHouse.id));

        expect(world.findPeekableStructureAt(Vec3.zero), isNull);

        expect(world.togglePeekStructure(targetHouse.id), isTrue);
        expect(world.isStructurePeeked(targetHouse.id), isTrue);
        expect(world.activeLanternOrigins.length, equals(baseOrigins + 1));

        world.clearPeekedStructures();
        expect(world.hasOpenInterior, isFalse);
        expect(world.activeLanternOrigins.length, equals(baseOrigins));
      },
    );

    test(
      'ShukubaController toggles single-house peek and global Interiors toggle',
      () {
        final world = EdoWorldDriver()
          ..initSimulation(rebuildAgentNodes: false);
        final look = _StubLookDriver();
        final audio = _StubAudioDriver();
        final controller = ShukubaController(
          look: look,
          world: world,
          audio: audio,
        );

        final house =
            world.graph.structures[const EntityId('chaya_west_bridgehead')]!;
        expect(controller.activeTool, isA<ExploreTool>());
        expect(controller.hasOpenInterior, isFalse);

        controller.handlePrimaryPlotTap(house.position);
        expect(controller.hasOpenInterior, isTrue);
        expect(controller.peekedStructureIds, contains(house.id));
        expect(audio.notes.length, equals(1));
        expect(audio.notes.first.instrument, equals(EdoInstrument.hyoshigi));

        controller.handlePrimaryPlotTap(house.position);
        expect(controller.hasOpenInterior, isFalse);

        controller.togglePeekAllHouses();
        expect(controller.peekAllHouses, isTrue);
        expect(controller.hasOpenInterior, isTrue);

        controller.clearPeekedHouses();
        expect(controller.peekAllHouses, isFalse);
        expect(controller.hasOpenInterior, isFalse);
      },
    );
  });

  group('Skeletal GLB animation compatibility', () {
    test(
      'selectAgentAnimations picks walk and idle clips for Tripo models',
      () {
        final empty = EdoWorldDriver.selectAgentAnimations(const []);
        expect(empty.walk, isNull);
        expect(empty.idle, isNull);

        final waitClip = Animation(name: 'preset:biped:wait', channels: []);
        final walkClip = Animation(name: 'preset:biped:walk', channels: []);
        final picked = EdoWorldDriver.selectAgentAnimations([
          waitClip,
          walkClip,
        ]);
        expect(picked.walk, same(walkClip));
        expect(picked.idle, same(waitClip));

        final customOnly = Animation(name: 'patrol_loop', channels: []);
        final fallback = EdoWorldDriver.selectAgentAnimations([customOnly]);
        expect(fallback.walk, same(customOnly));
        expect(fallback.idle, isNull);
      },
    );
  });
}
