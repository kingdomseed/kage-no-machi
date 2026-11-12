import 'package:flutter_scene/scene.dart' as scene show Material, Node, Scene;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';

export 'package:kage_no_machi/shukuba/world/scene_shadow_helper.dart'
    show markSubtreeShadowStatic;

class HeadlessTestMaterial extends scene.Material {
  new({
    String name = '',
    int depthLayer = 0,
    double depthBias = 0,
    bool doubleSided = false,
  }) {
    this.name = name;
    this.depthLayer = depthLayer;
    this.depthBias = depthBias;
    this.doubleSided = doubleSided;
  }
}

scene.Material testMaterialResolver(ShukubaSurfaceRole role) {
  return HeadlessTestMaterial(
    name: 'test_${role.name}',
    depthLayer: role.depthLayer,
  );
}

int countNodes(scene.Node root) {
  var count = 1;
  for (final child in root.children) {
    count += countNodes(child);
  }
  return count;
}

scene.Node? findNode(scene.Node root, String name) {
  if (root.name == name) return root;
  for (final child in root.children) {
    final match = findNode(child, name);
    if (match != null) return match;
  }
  return null;
}

List<scene.Node> collectNodesWithPrefix(scene.Node root, String prefix) {
  final matches = <scene.Node>[];
  void traverse(scene.Node current) {
    if (current.name.startsWith(prefix)) {
      matches.add(current);
    }
    current.children.forEach(traverse);
  }

  traverse(root);
  return matches;
}

bool checkImpellerAvailable() {
  try {
    scene.Scene();
    return true;
  } on Object catch (_) {
    return false;
  }
}

class FakeLookDriver implements ShukubaLookDriver {
  MagistrateVisionState lastVision = MagistrateVisionState.hidden;
  TimeOfDayRig lastRig = TimeOfDayRig.goldenDusk;
  int syncCount = 0;
  bool isDisposed = false;

  @override
  Future<void> attach(scene.Scene scene) async {}

  @override
  scene.Material materialFor(ShukubaSurfaceRole role) =>
      testMaterialResolver(role);

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
  void dispose() {
    isDisposed = true;
  }
}

class FakeWorldDriver implements ShukubaWorldDriver {
  ShukubaGraph _graph = ShukubaGraph.empty;
  BuildPreview lastPreview = const NoBuildPreview();
  int stepCount = 0;
  bool isDisposed = false;

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
    scene.Scene scene, {
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
  void step(double dtSeconds, {required TimeOfDayRig rig}) {
    stepCount++;
  }

  @override
  double sampleGroundHeight(double x, double z) => 0;

  @override
  void dispose() {
    isDisposed = true;
  }
}

class FakeAudioDriver implements ShukubaAudioDriver {
  final List<PlacementNoteEvent> notes = [];
  bool _isMuted = false;
  double _masterVolume = 1;
  bool isPrewarmed = false;
  bool isDisposed = false;

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
    _masterVolume = volume;
  }

  @override
  Future<void> prewarm() async {
    isPrewarmed = true;
  }

  @override
  Future<void> attach(
    scene.Scene scene, {
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
  void dispose() {
    isDisposed = true;
  }
}
