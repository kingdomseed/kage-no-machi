import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter_scene/kit.dart' show Steering;
import 'package:flutter_scene/scene.dart'
    show
        GeometryBuilder,
        Material,
        Mesh,
        Node,
        PhysicallyBasedMaterial,
        Scene,
        ShadowCastingMode,
        loadScene,
        releaseScene;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        AmbientLoopKind,
        BootStageId,
        BuildPreview,
        CourtyardWall,
        EntityId,
        LanternSpan,
        NoBuildPreview,
        PlacedStructure,
        RoadSpline,
        ShowcaseRealm,
        ShukubaGraph,
        ShukubaMaterialResolver,
        ShukubaSurfaceRole,
        ShukubaWorldDriver,
        StreetAgentRole,
        StreetAgentSnapshot,
        StructureKind,
        TerraceCourse,
        TimeOfDayRig,
        Vec3,
        WatchSightcone,
        defaultShukubaMaterial;
import 'package:kage_no_machi/shukuba/world/agent_navigation.dart';
import 'package:kage_no_machi/shukuba/world/atmosphere_builder.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';
import 'package:kage_no_machi/shukuba/world/flora_scatter_builder.dart';
import 'package:kage_no_machi/shukuba/world/minato_jo_ward.dart';
import 'package:kage_no_machi/shukuba/world/scene_shadow_helper.dart';
import 'package:kage_no_machi/shukuba/world/starter_ward.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';
import 'package:vector_math/vector_math.dart'
    show Aabb2, Quaternion, Vector2, Vector3;

class _AgentRig {
  new({required this.legL, required this.legR, required this.upper})
    : baseLegLRot = legL?.rotation.clone() ?? Quaternion.identity(),
      baseLegRRot = legR?.rotation.clone() ?? Quaternion.identity(),
      baseUpperRot = upper?.rotation.clone() ?? Quaternion.identity();

  final Node? legL;
  final Node? legR;
  final Node? upper;
  final Quaternion baseLegLRot;
  final Quaternion baseLegRRot;
  final Quaternion baseUpperRot;
}

class _SimAgent {
  new({
    required this.id,
    required this.role,
    required this.position,
    required this.waypoints,
    this.carriesLantern = false,
    this.speed = 1.7,
    this.bobPhase = 0,
  }) : currentWaypointIndex = 0,
       yawRadians = 0,
       dwellSeconds = 0,
       stuckSeconds = 0,
       directionSign = 1,
       velocity = Vector3.zero() {
    for (var i = 0; i < waypoints.length; i++) {
      if (waypoints[i].horizontalDistanceTo(position) <= 0.65) {
        currentWaypointIndex = (i + 1) % waypoints.length;
        break;
      }
    }
    if (waypoints.isNotEmpty) {
      var target = waypoints[currentWaypointIndex];
      if (target.horizontalDistanceTo(position) <= 0.65) {
        for (var i = 0; i < waypoints.length; i++) {
          if (waypoints[i].horizontalDistanceTo(position) > 0.65) {
            currentWaypointIndex = i;
            target = waypoints[i];
            break;
          }
        }
      }
      final dx = target.x - position.x;
      final dz = target.z - position.z;
      if (dx * dx + dz * dz > 1e-6) {
        yawRadians = math.atan2(dx, dz);
      }
    }
  }

  final EntityId id;
  final StreetAgentRole role;
  Vec3 position;
  final List<Vec3> waypoints;
  final bool carriesLantern;
  final double speed;
  final double bobPhase;
  int currentWaypointIndex;
  double yawRadians;
  double dwellSeconds;
  double stuckSeconds;
  int directionSign;
  Vector3 velocity;

  StreetAgentSnapshot toSnapshot() => StreetAgentSnapshot(
    id: id,
    role: role,
    position: position,
    yawRadians: yawRadians,
    carriesLantern: carriesLantern,
  );
}

class EdoWorldDriver implements ShukubaWorldDriver {
  new({ShowcaseRealm initialRealm = ShowcaseRealm.shukubaValley})
    : _realm = initialRealm;

  ShowcaseRealm _realm;

  ShowcaseRealm get realm => _realm;

  Scene? _scene;
  ShukubaMaterialResolver _resolveMaterial = defaultShukubaMaterial;
  late final TerrainBuilder _terrainBuilder = TerrainBuilder(realm: _realm);
  late final EdoKitBuilder _kitBuilder = const EdoKitBuilder();

  TerrainBuilder get terrainBuilder => _terrainBuilder;
  late final FloraScatterBuilder _floraBuilder = const FloraScatterBuilder();
  late final AtmosphereBuilder _atmosphereBuilder = const AtmosphereBuilder();

  late ShukubaGraph _graph = ShukubaGraph.empty;
  BuildPreview _activePreview = const NoBuildPreview();

  Node? _worldRoot;
  late final Node _terrainContainerNode = Node(name: 'terrain_tiled_root');
  late Node _horizonRidgesNode;
  late Node _waterNode;
  late final Node _gorgeDressingNode = Node(name: 'gorge_dressing_container');
  late Node _bridgeNode;
  late final Node _floraNode = Node(name: 'flora_scatter_root');
  late final Node _roadsNode = Node(name: 'roads_root');
  late final Node _terracesNode = Node(name: 'terraces_root');
  late final Node _wallsNode = Node(name: 'walls_root');
  late final Node _structuresNode = Node(name: 'structures_root');
  late final Node _lanternSpansNode = Node(name: 'lantern_spans_root');
  late final Node _agentsNode = Node(name: 'agents_root');
  late final Node _atmosphereNode = Node(name: 'atmosphere_root');
  late final Node _atmosphereMistNode = Node(name: 'atmosphere_mist_ribbons');
  late final Node _previewNode = Node(name: 'preview_root');
  late final Node _heroPropsNode = Node(name: 'hero_glb_props');
  Node? _vistaMountainsNode;
  Node? _skyCloudDomeNode;
  Node? _minatoSeawallNode;
  Node? _outerApronNode;
  bool _heroBridgeAttached = false;
  int _attachEpoch = 0;

  bool _isStaleAttach(int epoch, ShowcaseRealm realm, Scene? scene) =>
      _scene == null ||
      _worldRoot == null ||
      _attachEpoch != epoch ||
      _realm != realm ||
      !identical(_scene, scene);
  final Map<String, Node> _heroStructurePrototypes = <String, Node>{};
  final List<String> _loadedScenePaths = <String>[];
  final Set<PhysicallyBasedMaterial> _seenEmissives =
      Set<PhysicallyBasedMaterial>.identity();
  final List<PhysicallyBasedMaterial> _cachedShojiEmissives =
      <PhysicallyBasedMaterial>[];
  final List<PhysicallyBasedMaterial> _cachedLanternEmissives =
      <PhysicallyBasedMaterial>[];
  TimeOfDayRig _lastEmissiveRig = TimeOfDayRig.goldenDusk;
  double _lastSyncedEmissiveNightFactor = double.nan;

  final Set<int> _dirtyFloraChunkIndices = <int>{
    for (var i = 0; i < TerrainConfig.chunkCount; i++) i,
  };
  final Map<int, Node> _floraChunkNodes = <int, Node>{};
  final Map<int, Node> _terrainChunkNodes = <int, Node>{};
  Node? _tanadaNode;
  Node? _mitsukeNode;
  final Map<EntityId, ({PlacedStructure data, Node node})> _structureNodes = {};
  List<RoadSpline>? _builtRoads;
  List<TerraceCourse>? _builtTerraces;
  List<CourtyardWall>? _builtWalls;
  List<LanternSpan>? _builtLanternSpans;
  List<Node> _riverMistNodes = const [];
  List<Node> _wardSteamNodes = const [];
  Node? _lanternHalosNode;
  Node? _airborneMotesNode;
  ShukubaGraph? _lastAtmosphereGraph;

  Set<int> get dirtyFloraChunkIndices =>
      Set<int>.unmodifiable(_dirtyFloraChunkIndices);

  void clearDirtyFlora() => _dirtyFloraChunkIndices.clear();

  final List<_SimAgent> _simAgents = [];
  final Map<EntityId, Node> _agentNodes = {};
  final Map<EntityId, _AgentRig> _agentRigs = {};
  AgentObstacleMap? _agentObstacles;
  double _walkTime = 0;

  @visibleForTesting
  AgentObstacleMap get agentObstacles =>
      _agentObstacles ??= AgentObstacleMap.build(
        graph: _graph,
        realm: _realm,
        sampleGroundHeight: sampleGroundHeight,
      );

  void _rebuildAgentObstacles() {
    _agentObstacles = AgentObstacleMap.build(
      graph: _graph,
      realm: _realm,
      sampleGroundHeight: sampleGroundHeight,
    );
  }

  @override
  ShukubaGraph get graph => _graph;

  @override
  List<WatchSightcone> get activeSightcones => _graph.structuralSightcones;

  @override
  List<Vec3> get activeLanternOrigins {
    final origins = <Vec3>[];
    for (final agent in _simAgents) {
      if (agent.carriesLantern) {
        final heldOffset = EdoKitBuilder.heldLanternLocalOffset.rotateY(
          agent.yawRadians,
        );
        origins.add(agent.position + heldOffset);
      }
    }

    for (final span in _graph.lanternSpans) {
      origins.add(span.midpoint);
    }

    for (final structure in _graph.structures.values) {
      for (final local in EdoKitBuilder.structureLanternLocalOffsets(
        structure,
      )) {
        origins.add(structure.position + local.rotateY(structure.yawRadians));
      }
    }
    if (_realm == ShowcaseRealm.minatoJo) {
      origins.addAll(buildMinatoExtraLanternOrigins());
    }
    return origins;
  }

  @override
  Map<AmbientLoopKind, Vec3> get ambientLoopAnchors => {
    AmbientLoopKind.riverMurmur: const Vec3(
      0,
      TerrainConfig.waterSurfaceElevation,
      0,
    ),
    AmbientLoopKind.bambooWind: Vec3(
      -12.6,
      sampleGroundHeight(-12.6, 11.8),
      11.8,
    ),
    AmbientLoopKind.nightCrickets: Vec3(
      14.5,
      sampleGroundHeight(14.5, -5.5),
      -5.5,
    ),
  };

  @override
  List<StreetAgentSnapshot> get agents => [
    for (final agent in _simAgents) agent.toSnapshot(),
  ];

  @override
  double sampleGroundHeight(double x, double z) => _terrainBuilder
      .sampleGroundHeight(x, z, terraces: _graph.terraces, roads: _graph.roads);

  void _mountInitialWorldRoot() {
    _terrainBuilder.realm = _realm;
    _worldRoot = Node();
    _horizonRidgesNode = _terrainBuilder.buildHorizonMountainRidgesNode(
      _resolveMaterial,
    );
    _waterNode = _realm == ShowcaseRealm.minatoJo
        ? _terrainBuilder.buildMinatoHarborWaterNode(_resolveMaterial)
        : markSubtreeShadowStatic(
            _terrainBuilder.buildWaterNode(_resolveMaterial),
          );
    _bridgeNode = markSubtreeShadowStatic(
      _terrainBuilder.buildBridgeNode(_resolveMaterial),
    )..visible = _realm == ShowcaseRealm.shukubaValley;
    _heroBridgeAttached = false;

    _worldRoot!
      ..add(_terrainContainerNode)
      ..add(_horizonRidgesNode)
      ..add(_waterNode)
      ..add(_gorgeDressingNode)
      ..add(_bridgeNode)
      ..add(_floraNode)
      ..add(_roadsNode)
      ..add(_terracesNode)
      ..add(_wallsNode)
      ..add(_structuresNode)
      ..add(_heroPropsNode)
      ..add(_lanternSpansNode)
      ..add(_agentsNode)
      ..add(_atmosphereNode)
      ..add(_previewNode);

    _scene!.add(_worldRoot!);
  }

  /// Detaches the world root and all persistent container nodes from any active
  /// [Scene] so this driver can cleanly re-attach to a new [Scene] later.
  void detach() {
    _attachEpoch++;
    final oldRoot = _worldRoot;
    final oldScene = _scene;
    if (oldRoot != null) {
      oldRoot.removeAll();
      if (oldScene != null && identical(oldRoot.parent, oldScene.root)) {
        oldScene.remove(oldRoot);
      } else {
        oldRoot.parent?.remove(oldRoot);
      }
    }
    _worldRoot = null;
    _scene = null;
    _heroBridgeAttached = false;
    _previewNode.removeAll();
    _clearIncrementalCaches();
  }

  @override
  Future<void> attach(
    Scene scene, {
    ShukubaMaterialResolver resolveMaterial = defaultShukubaMaterial,
    ShukubaGraph? initialGraph,
  }) async {
    if (_worldRoot != null || _scene != null) {
      detach();
    }
    final epoch = ++_attachEpoch;
    final capturedRealm = _realm;
    _scene = scene;
    _resolveMaterial = resolveMaterial;

    _mountInitialWorldRoot();

    initSimulation(initialGraph: initialGraph);
    _rebuildGraphNodes();
    _rebuildPreviewNode();
    if (_isStaleAttach(epoch, capturedRealm, scene)) {
      return;
    }
    await _attachHeroGlbModels();
  }

  Future<void> attachStaged(
    Scene scene, {
    ShukubaMaterialResolver resolveMaterial = defaultShukubaMaterial,
    ShukubaGraph? initialGraph,
    Future<void> Function(BootStageId stage, double elapsedMs)? onStage,
  }) async {
    if (_worldRoot != null || _scene != null) {
      detach();
    }
    final epoch = ++_attachEpoch;
    final capturedRealm = _realm;
    _scene = scene;
    _resolveMaterial = resolveMaterial;

    final stopwatch = Stopwatch()..start();

    _mountInitialWorldRoot();

    initSimulation(initialGraph: initialGraph, rebuildAgentNodes: false);
    _rebuildTerrainAndWayNodes();

    if (onStage != null) {
      await onStage(
        BootStageId.valleyTerrain,
        stopwatch.elapsedMicroseconds / 1000.0,
      );
    }
    await Future<void>.delayed(Duration.zero);
    if (_isStaleAttach(epoch, capturedRealm, scene)) {
      return;
    }

    stopwatch.reset();
    _rebuildArchitectureAndAgentNodes();
    if (onStage != null) {
      await onStage(
        BootStageId.townArchitecture,
        stopwatch.elapsedMicroseconds / 1000.0,
      );
    }
    await Future<void>.delayed(Duration.zero);
    if (_isStaleAttach(epoch, capturedRealm, scene)) {
      return;
    }

    stopwatch.reset();
    _rebuildFloraAtmosphereAndPreviewNodes();
    if (onStage != null) {
      await onStage(
        BootStageId.floraAndAir,
        stopwatch.elapsedMicroseconds / 1000.0,
      );
    }
    if (_isStaleAttach(epoch, capturedRealm, scene)) {
      return;
    }
    await _attachHeroGlbModels();
  }

  Future<void> switchRealm(ShowcaseRealm nextRealm) async {
    if (_realm == nextRealm) {
      return;
    }
    _realm = nextRealm;
    _terrainBuilder.realm = nextRealm;
    if (_scene == null || _worldRoot == null) {
      initSimulation(rebuildAgentNodes: false);
      return;
    }

    _attachEpoch++;
    _worldRoot!.remove(_waterNode);
    _horizonRidgesNode.visible = true;
    _waterNode = _realm == ShowcaseRealm.minatoJo
        ? _terrainBuilder.buildMinatoHarborWaterNode(_resolveMaterial)
        : markSubtreeShadowStatic(
            _terrainBuilder.buildWaterNode(_resolveMaterial),
          );
    _worldRoot!.add(_waterNode);
    _bridgeNode.visible = _realm == ShowcaseRealm.shukubaValley;

    initSimulation();
    _rebuildGraphNodes();
    _rebuildPreviewNode();
    await _attachHeroGlbModels();
  }

  void initSimulation({
    ShukubaGraph? initialGraph,
    bool rebuildAgentNodes = true,
  }) {
    _clearIncrementalCaches();
    _graph =
        initialGraph ??
        (_realm == ShowcaseRealm.minatoJo
            ? buildMinatoJoGraph(_terrainBuilder.sampleGroundHeight)
            : buildStarterShukubaGraph(_terrainBuilder.sampleGroundHeight));
    _initAgents(rebuildNodes: rebuildAgentNodes);
  }

  void _clearIncrementalCaches() {
    _terrainBuilder.markAllDirty();
    _terrainChunkNodes.clear();
    _tanadaNode = null;
    _mitsukeNode = null;
    _terrainContainerNode.removeAll();
    _gorgeDressingNode.removeAll();
    _roadsNode.removeAll();
    _terracesNode.removeAll();
    _wallsNode.removeAll();
    _structuresNode.removeAll();
    _heroPropsNode.removeAll();
    if (_minatoSeawallNode != null) {
      _worldRoot?.remove(_minatoSeawallNode!);
      _minatoSeawallNode = null;
    }
    if (_outerApronNode != null) {
      _worldRoot?.remove(_outerApronNode!);
      _outerApronNode = null;
    }
    if (_vistaMountainsNode != null) {
      _worldRoot?.remove(_vistaMountainsNode!);
      _vistaMountainsNode = null;
    }
    if (_skyCloudDomeNode != null) {
      _worldRoot?.remove(_skyCloudDomeNode!);
      _skyCloudDomeNode = null;
    }
    _structureNodes.clear();
    _lanternSpansNode.removeAll();
    _builtRoads = null;
    _builtTerraces = null;
    _builtWalls = null;
    _builtLanternSpans = null;
    _dirtyFloraChunkIndices
      ..clear()
      ..addAll(Iterable<int>.generate(TerrainConfig.chunkCount));
    _floraChunkNodes.clear();
    _floraNode.removeAll();
    _atmosphereMistNode.removeAll();
    _atmosphereNode.removeAll();
    _atmosphereMistNode.parent?.remove(_atmosphereMistNode);
    _riverMistNodes = const [];
    _wardSteamNodes = const [];
    _lanternHalosNode = null;
    _airborneMotesNode = null;
    _lastAtmosphereGraph = null;
    _agentNodes.clear();
    _agentRigs.clear();
    _agentObstacles = null;
    _agentsNode.removeAll();
    _seenEmissives.clear();
    _cachedShojiEmissives.clear();
    _cachedLanternEmissives.clear();
    _lastSyncedEmissiveNightFactor = double.nan;
  }

  void _initAgents({bool rebuildNodes = true}) {
    _rebuildAgentObstacles();
    if (_realm == ShowcaseRealm.minatoJo) {
      final minatoAgents = buildMinatoStreetAgents(sampleGroundHeight);
      _simAgents
        ..clear()
        ..addAll([
          for (final a in minatoAgents)
            _SimAgent(
              id: a.id,
              role: a.role,
              position: a.position,
              waypoints: a.waypoints,
              carriesLantern: a.carriesLantern,
              speed: a.speed,
              bobPhase: a.bobPhase,
            ),
        ]);
      if (rebuildNodes) {
        _rebuildAgentNodes();
      }
      return;
    }

    _simAgents
      ..clear()
      ..addAll([
        _SimAgent(
          id: EntityId.validated('townsfolk_kaido_1'),
          role: StreetAgentRole.townsfolk,
          position: Vec3(-16, sampleGroundHeight(-16, 0.08), 0.08),
          waypoints: [
            Vec3(-18, sampleGroundHeight(-18, 0.22), 0.22),
            Vec3(-6, sampleGroundHeight(-6, -0.05), -0.05),
            Vec3(0, sampleGroundHeight(0, 0), 0),
            Vec3(12.6, sampleGroundHeight(12.6, -0.12), -0.12),
            Vec3(15.3, sampleGroundHeight(15.3, -0.15), -0.15),
            Vec3(20.2, sampleGroundHeight(20.2, 0.30), 0.30),
            Vec3(15.3, sampleGroundHeight(15.3, -0.15), -0.15),
            Vec3(12.6, sampleGroundHeight(12.6, -0.12), -0.12),
            Vec3(0, sampleGroundHeight(0, 0), 0),
            Vec3(-6, sampleGroundHeight(-6, -0.05), -0.05),
          ],
          speed: 1.65,
        ),
        _SimAgent(
          id: EntityId.validated('lantern_innkeeper'),
          role: StreetAgentRole.lanternWatchman,
          position: Vec3(-9.5, sampleGroundHeight(-9.5, -0.16), -0.16),
          waypoints: [
            Vec3(-9.5, sampleGroundHeight(-9.5, -0.16), -0.16),
            Vec3(0, sampleGroundHeight(0, 0.15), 0.15),
            Vec3(10.6, sampleGroundHeight(10.6, 0.25), 0.25),
            Vec3(10.6, sampleGroundHeight(10.6, 3.6), 3.6),
            Vec3(9.2, sampleGroundHeight(9.2, 6.2), 6.2),
            Vec3(9.2, sampleGroundHeight(9.2, 8.8), 8.8),
            Vec3(9.2, sampleGroundHeight(9.2, 6.2), 6.2),
            Vec3(10.6, sampleGroundHeight(10.6, 3.6), 3.6),
            Vec3(10.6, sampleGroundHeight(10.6, 0.25), 0.25),
            Vec3(0, sampleGroundHeight(0, 0.15), 0.15),
          ],
          carriesLantern: true,
          speed: 1.35,
          bobPhase: 1.4,
        ),
        _SimAgent(
          id: EntityId.validated('merchant_traveler'),
          role: StreetAgentRole.nightSmuggler,
          position: Vec3(9.1, sampleGroundHeight(9.1, 12.2), 12.2),
          waypoints: [
            Vec3(9.1, sampleGroundHeight(9.1, 12.2), 12.2),
            Vec3(9.2, sampleGroundHeight(9.2, 8.8), 8.8),
            Vec3(9.2, sampleGroundHeight(9.2, 6.2), 6.2),
            Vec3(10.6, sampleGroundHeight(10.6, 3.6), 3.6),
            Vec3(10.6, sampleGroundHeight(10.6, 0.2), 0.2),
            Vec3(0, sampleGroundHeight(0, -0.2), -0.2),
            Vec3(-8.2, sampleGroundHeight(-8.2, -0.4), -0.4),
            Vec3(-8.3, sampleGroundHeight(-8.3, -5.4), -5.4),
            Vec3(-8.9, sampleGroundHeight(-8.9, -8.9), -8.9),
            Vec3(-10.4, sampleGroundHeight(-10.4, -10.8), -10.8),
            Vec3(-8.9, sampleGroundHeight(-8.9, -8.9), -8.9),
            Vec3(-8.3, sampleGroundHeight(-8.3, -5.4), -5.4),
            Vec3(-8.2, sampleGroundHeight(-8.2, -0.4), -0.4),
            Vec3(0, sampleGroundHeight(0, -0.2), -0.2),
            Vec3(10.6, sampleGroundHeight(10.6, 0.2), 0.2),
            Vec3(10.6, sampleGroundHeight(10.6, 3.6), 3.6),
            Vec3(9.2, sampleGroundHeight(9.2, 6.2), 6.2),
            Vec3(9.2, sampleGroundHeight(9.2, 8.8), 8.8),
          ],
          speed: 1.55,
          bobPhase: 2.8,
        ),
      ]);

    if (rebuildNodes) {
      _rebuildAgentNodes();
    }
  }

  static Node? _findNodeByName(Node root, String targetName) {
    if (root.name == targetName || root.name.contains(targetName)) {
      return root;
    }
    for (final child in root.children) {
      final found = _findNodeByName(child, targetName);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  static const List<String> _heroAgentAssetPaths = <String>[
    'assets/models/edo_person_merchant.glb',
    'assets/models/edo_person_townswoman.glb',
    'assets/models/edo_person_porter.glb',
    'assets/models/edo_person_watchman.glb',
    'assets/models/edo_person_samurai.glb',
    'assets/models/edo_person_monk.glb',
  ];

  static String _heroAgentAssetFor(_SimAgent agent) {
    if (agent.role == StreetAgentRole.lanternWatchman || agent.carriesLantern) {
      return 'assets/models/edo_person_watchman.glb';
    }
    final name = agent.id.value.toLowerCase();
    if (name.contains('samurai') ||
        name.contains('courier') ||
        name.contains('guard')) {
      return 'assets/models/edo_person_samurai.glb';
    }
    if (name.contains('monk') || name.contains('shrine')) {
      return 'assets/models/edo_person_monk.glb';
    }
    if (name.contains('porter') || name.contains('dock')) {
      return 'assets/models/edo_person_porter.glb';
    }
    if (name.contains('townswoman') || name.contains('shopper')) {
      return 'assets/models/edo_person_townswoman.glb';
    }
    if (name.contains('merchant')) {
      return 'assets/models/edo_person_merchant.glb';
    }
    if (agent.role == StreetAgentRole.nightSmuggler) {
      return agent.id.value.hashCode.abs().isEven
          ? 'assets/models/edo_person_samurai.glb'
          : 'assets/models/edo_person_porter.glb';
    }
    return switch (agent.id.value.hashCode.abs() % 4) {
      0 => 'assets/models/edo_person_merchant.glb',
      1 => 'assets/models/edo_person_townswoman.glb',
      2 => 'assets/models/edo_person_porter.glb',
      _ => 'assets/models/edo_person_monk.glb',
    };
  }

  void _rebuildAgentNodes() {
    if (_scene == null) {
      return;
    }
    _agentsNode.removeAll();
    _agentNodes.clear();
    _agentRigs.clear();

    for (final agent in _simAgents) {
      final heroAsset = _heroAgentAssetFor(agent);
      final proto = _heroStructurePrototypes[heroAsset];
      late final Node node;
      if (proto != null) {
        final cloned = proto.clone();
        _agentRigs[agent.id] = _AgentRig(
          legL: _findNodeByName(cloned, 'person_leg_l'),
          legR: _findNodeByName(cloned, 'person_leg_r'),
          upper: _findNodeByName(cloned, 'person_upper'),
        );
        node = Node(name: 'hero_agent_${agent.id.value}')
          ..position = agent.position.toVector3()
          ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), agent.yawRadians)
          ..add(cloned);
      } else {
        node = _kitBuilder.buildStreetAgentNode(agent.role, _resolveMaterial)
          ..position = agent.position.toVector3()
          ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), agent.yawRadians);
      }

      _agentNodes[agent.id] = node;
      _agentsNode.add(node);
    }
  }

  @override
  void applyGraph(ShukubaGraph nextGraph) {
    if (identical(_graph, nextGraph) && _roadsNode.children.isNotEmpty) {
      return;
    }

    _markGraphDeltaDirty(_graph, nextGraph);
    _graph = nextGraph;
    _rebuildAgentObstacles();
    _rebuildGraphNodes();
  }

  void _markFloraDirty(Aabb2 bounds) {
    const margin = 3.5;
    final minCx =
        ((bounds.min.x - margin - TerrainConfig.minX) / TerrainConfig.chunkSpan)
            .floor()
            .clamp(0, TerrainConfig.gridDimension - 1);
    final maxCx =
        ((bounds.max.x + margin - TerrainConfig.minX) / TerrainConfig.chunkSpan)
            .floor()
            .clamp(0, TerrainConfig.gridDimension - 1);
    final minCz =
        ((bounds.min.y - margin - TerrainConfig.minZ) / TerrainConfig.chunkSpan)
            .floor()
            .clamp(0, TerrainConfig.gridDimension - 1);
    final maxCz =
        ((bounds.max.y + margin - TerrainConfig.minZ) / TerrainConfig.chunkSpan)
            .floor()
            .clamp(0, TerrainConfig.gridDimension - 1);

    for (var cz = minCz; cz <= maxCz; cz++) {
      for (var cx = minCx; cx <= maxCx; cx++) {
        _dirtyFloraChunkIndices.add(cz * TerrainConfig.gridDimension + cx);
      }
    }
  }

  void _markGraphDeltaDirty(ShukubaGraph prev, ShukubaGraph next) {
    Aabb2? boundsForPoints(List<Vec3> pts, double pad) {
      if (pts.isEmpty) return null;
      var minX = pts.first.x;
      var maxX = pts.first.x;
      var minZ = pts.first.z;
      var maxZ = pts.first.z;
      for (var i = 1; i < pts.length; i++) {
        final p = pts[i];
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.z < minZ) minZ = p.z;
        if (p.z > maxZ) maxZ = p.z;
      }
      return Aabb2.minMax(
        Vector2(minX - pad, minZ - pad),
        Vector2(maxX + pad, maxZ + pad),
      );
    }

    void markPoints(List<Vec3> pts, double pad) {
      final box = boundsForPoints(pts, pad);
      if (box == null) return;
      _terrainBuilder.markDirty(box);
      _markFloraDirty(box);
    }

    void markFloraOnlyPoints(List<Vec3> pts, double pad) {
      final box = boundsForPoints(pts, pad);
      if (box == null) return;
      _markFloraDirty(box);
    }

    void markStructure(PlacedStructure s) {
      final halfR =
          math.max(s.spec.footprintWidth, s.spec.footprintDepth) * 0.5 + 0.5;
      final box = Aabb2.minMax(
        Vector2(s.position.x - halfR, s.position.z - halfR),
        Vector2(s.position.x + halfR, s.position.z + halfR),
      );
      _terrainBuilder.markDirty(box);
      _markFloraDirty(box);
    }

    final prevRoads = <EntityId, RoadSpline>{
      for (final r in prev.roads) r.id: r,
    };
    final nextRoads = <EntityId, RoadSpline>{
      for (final r in next.roads) r.id: r,
    };
    for (final entry in prevRoads.entries) {
      if (nextRoads[entry.key] != entry.value) {
        markPoints(
          entry.value.controlPoints,
          entry.value.widthMeters * 0.5 + 3.0,
        );
      }
    }
    for (final entry in nextRoads.entries) {
      if (prevRoads[entry.key] != entry.value) {
        markPoints(
          entry.value.controlPoints,
          entry.value.widthMeters * 0.5 + 3.0,
        );
      }
    }

    final prevTerraces = <EntityId, TerraceCourse>{
      for (final t in prev.terraces) t.id: t,
    };
    final nextTerraces = <EntityId, TerraceCourse>{
      for (final t in next.terraces) t.id: t,
    };
    for (final entry in prevTerraces.entries) {
      if (nextTerraces[entry.key] != entry.value) {
        markPoints(entry.value.crestPoints, entry.value.depthMeters + 6.0);
      }
    }
    for (final entry in nextTerraces.entries) {
      if (prevTerraces[entry.key] != entry.value) {
        markPoints(entry.value.crestPoints, entry.value.depthMeters + 6.0);
      }
    }

    final prevWalls = <EntityId, CourtyardWall>{
      for (final w in prev.walls) w.id: w,
    };
    final nextWalls = <EntityId, CourtyardWall>{
      for (final w in next.walls) w.id: w,
    };
    for (final entry in prevWalls.entries) {
      if (nextWalls[entry.key] != entry.value) {
        markFloraOnlyPoints(
          entry.value.controlPoints,
          entry.value.thicknessMeters * 0.5 + 2.5,
        );
      }
    }
    for (final entry in nextWalls.entries) {
      if (prevWalls[entry.key] != entry.value) {
        markFloraOnlyPoints(
          entry.value.controlPoints,
          entry.value.thicknessMeters * 0.5 + 2.5,
        );
      }
    }

    for (final entry in prev.structures.entries) {
      if (next.structures[entry.key] != entry.value) {
        markStructure(entry.value);
      }
    }
    for (final entry in next.structures.entries) {
      if (prev.structures[entry.key] != entry.value) {
        markStructure(entry.value);
      }
    }
  }

  @override
  void syncPreview(BuildPreview preview) {
    if (_activePreview == preview) {
      return;
    }
    _activePreview = preview;
    _rebuildPreviewNode();
  }

  void _rebuildPreviewNode() {
    if (_scene == null) {
      return;
    }
    _previewNode.removeAll();
    if (_activePreview is! NoBuildPreview) {
      _previewNode.add(
        _kitBuilder.buildPreviewNode(
          _activePreview,
          _resolveMaterial,
          sampleGroundHeight,
        ),
      );
    }
  }

  void _rebuildTerrainAndWayNodes() {
    if (_scene == null) {
      return;
    }

    if (_minatoSeawallNode == null && _realm == ShowcaseRealm.minatoJo) {
      _minatoSeawallNode = _terrainBuilder.buildMinatoSeawallNode(
        _resolveMaterial,
      );
      _worldRoot?.add(_minatoSeawallNode!);
    }
    if (_outerApronNode == null) {
      _outerApronNode = _terrainBuilder.buildOuterTerrainApronNode(
        _resolveMaterial,
        terraces: _graph.terraces,
        roads: _graph.roads,
      );
      _worldRoot?.add(_outerApronNode!);
    }

    if (_terrainChunkNodes.isEmpty) {
      _terrainContainerNode.removeAll();
      for (var cz = 0; cz < TerrainConfig.gridDimension; cz++) {
        for (var cx = 0; cx < TerrainConfig.gridDimension; cx++) {
          final idx = cz * TerrainConfig.gridDimension + cx;
          final chunkNode = _terrainBuilder.buildTerrainChunkNode(
            cx,
            cz,
            _resolveMaterial,
            terraces: _graph.terraces,
            roads: _graph.roads,
            structures: _graph.structures.values,
          );
          _terrainChunkNodes[idx] = chunkNode;
          _terrainContainerNode.add(chunkNode);
        }
      }
      if (_realm == ShowcaseRealm.shukubaValley) {
        _tanadaNode = markSubtreeShadowStatic(
          _terrainBuilder.buildTanadaPaddiesNode(_resolveMaterial),
        );
        _mitsukeNode = markSubtreeShadowStatic(
          _terrainBuilder.buildMitsukeCheckpointsNode(_resolveMaterial),
        );
        _terrainContainerNode
          ..add(_tanadaNode!)
          ..add(_mitsukeNode!);
      }
      _terrainContainerNode.shadowStatic = true;
    } else if (_terrainBuilder.dirtyChunkIndices.isNotEmpty) {
      final dirty = _terrainBuilder.dirtyChunkIndices.toList()..sort();
      for (final idx in dirty) {
        final prevNode = _terrainChunkNodes.remove(idx);
        if (prevNode != null) {
          _terrainContainerNode.remove(prevNode);
        }
        final cx = idx % TerrainConfig.gridDimension;
        final cz = idx ~/ TerrainConfig.gridDimension;
        final nextNode = _terrainBuilder.buildTerrainChunkNode(
          cx,
          cz,
          _resolveMaterial,
          terraces: _graph.terraces,
          roads: _graph.roads,
          structures: _graph.structures.values,
        );
        _terrainChunkNodes[idx] = nextNode;
        _terrainContainerNode.add(nextNode);
      }
    }

    final roadsChanged =
        _builtRoads == null || !listEquals(_builtRoads, _graph.roads);
    final terracesChanged =
        _builtTerraces == null || !listEquals(_builtTerraces, _graph.terraces);
    final wallsChanged =
        _builtWalls == null || !listEquals(_builtWalls, _graph.walls);

    if (roadsChanged || terracesChanged) {
      _gorgeDressingNode.removeAll();
      if (_realm == ShowcaseRealm.shukubaValley) {
        _gorgeDressingNode.add(
          markSubtreeShadowStatic(
            _terrainBuilder.buildGorgeDressingNode(
              _resolveMaterial,
              roads: _graph.roads,
            ),
          ),
        );
      }

      _roadsNode.removeAll();
      for (final road in _graph.roads) {
        _roadsNode.add(
          markSubtreeShadowStatic(
            _terrainBuilder.buildRoadNode(
              road,
              _resolveMaterial,
              sampleGroundHeight,
              allRoads: _graph.roads,
              terraces: _graph.terraces,
            ),
          ),
        );
      }

      _terracesNode.removeAll();
      for (final terrace in _graph.terraces) {
        _terracesNode.add(
          markSubtreeShadowStatic(
            _terrainBuilder.buildTerraceNode(
              terrace,
              _resolveMaterial,
              roads: _graph.roads,
              allTerraces: _graph.terraces,
            ),
          ),
        );
      }
    }

    if (wallsChanged || roadsChanged || terracesChanged) {
      _wallsNode.removeAll();
      for (final wall in _graph.walls) {
        _wallsNode.add(
          markSubtreeShadowStatic(
            _terrainBuilder.buildWallNode(
              wall,
              _resolveMaterial,
              sampleGroundHeight,
            ),
          ),
        );
      }
    }

    _builtRoads = _graph.roads;
    _builtTerraces = _graph.terraces;
    _builtWalls = _graph.walls;
  }

  void _rebuildArchitectureAndAgentNodes() {
    if (_scene == null) {
      return;
    }

    final staleIds = <EntityId>[];
    for (final entry in _structureNodes.entries) {
      final next = _graph.structures[entry.key];
      if (next == null || next != entry.value.data) {
        staleIds.add(entry.key);
      }
    }
    for (final id in staleIds) {
      final removed = _structureNodes.remove(id)!;
      _structuresNode.remove(removed.node);
    }
    for (final entry in _graph.structures.entries) {
      if (_structureNodes.containsKey(entry.key)) {
        continue;
      }
      final built = _buildStructureOrHeroNode(entry.value);
      _structureNodes[entry.key] = (data: entry.value, node: built);
      _structuresNode.add(built);
    }

    if (_builtLanternSpans == null ||
        !listEquals(_builtLanternSpans, _graph.lanternSpans)) {
      _lanternSpansNode.removeAll();
      for (final span in _graph.lanternSpans) {
        _lanternSpansNode.add(
          markSubtreeShadowStatic(
            _kitBuilder.buildLanternSpanNode(span, _resolveMaterial),
          ),
        );
      }
      _builtLanternSpans = _graph.lanternSpans;
    }

    if (_agentNodes.isEmpty) {
      _rebuildAgentNodes();
    }
  }

  static bool _isSteamStructure(StructureKind kind) => switch (kind) {
    StructureKind.chaya ||
    StructureKind.marketStall ||
    StructureKind.minka => true,
    _ => false,
  };

  static bool _isLanternStructure(StructureKind kind) => switch (kind) {
    StructureKind.chaya ||
    StructureKind.machiya ||
    StructureKind.minka ||
    StructureKind.marketStall ||
    StructureKind.toriiGate ||
    StructureKind.karesansuiGarden => true,
    _ => false,
  };

  bool _anyMatchingStructureChanged(
    ShukubaGraph prev,
    ShukubaGraph next,
    bool Function(StructureKind kind) predicate,
  ) {
    for (final entry in prev.structures.entries) {
      if (predicate(entry.value.kind) &&
          next.structures[entry.key] != entry.value) {
        return true;
      }
    }
    for (final entry in next.structures.entries) {
      if (predicate(entry.value.kind) &&
          prev.structures[entry.key] != entry.value) {
        return true;
      }
    }
    return false;
  }

  void _rebuildFloraAtmosphereAndPreviewNodes() {
    if (_scene == null) {
      return;
    }

    final rebuildAll = _floraChunkNodes.isEmpty;
    if (rebuildAll || _dirtyFloraChunkIndices.isNotEmpty) {
      final targetChunks = rebuildAll
          ? null
          : Set<int>.of(_dirtyFloraChunkIndices);
      if (rebuildAll) {
        _floraNode.removeAll();
      } else {
        for (final idx in targetChunks!) {
          final prevNode = _floraChunkNodes.remove(idx);
          if (prevNode != null) {
            _floraNode.remove(prevNode);
          }
        }
      }
      final rebuilt = _floraBuilder.buildFloraChunkNodes(
        graph: _graph,
        resolveMaterial: _resolveMaterial,
        sampleGroundY: sampleGroundHeight,
        realm: _realm,
        onlyChunks: targetChunks,
      );
      final orderedKeys = rebuilt.keys.toList()..sort();
      for (final idx in orderedKeys) {
        final chunkNode = markSubtreeShadowStatic(rebuilt[idx]!);
        _floraChunkNodes[idx] = chunkNode;
        _floraNode.add(chunkNode);
      }
      _dirtyFloraChunkIndices.clear();
    }

    final prevAtmosGraph = _lastAtmosphereGraph;
    if (prevAtmosGraph == null) {
      _atmosphereNode.removeAll();
      _atmosphereMistNode.removeAll();
      _riverMistNodes = _realm == ShowcaseRealm.shukubaValley
          ? _atmosphereBuilder.buildRiverMistNodes(_resolveMaterial)
          : const [];
      _riverMistNodes.forEach(_atmosphereMistNode.add);
      _wardSteamNodes = _atmosphereBuilder.buildWardSteamAndHazeNodes(
        graph: _graph,
        resolveMaterial: _resolveMaterial,
        sampleGroundY: sampleGroundHeight,
      );
      _wardSteamNodes.forEach(_atmosphereMistNode.add);
      _atmosphereNode.add(_atmosphereMistNode);

      _lanternHalosNode = _atmosphereBuilder.buildLanternHalosNode(
        graph: _graph,
        resolveMaterial: _resolveMaterial,
      );
      if (_lanternHalosNode != null) {
        _atmosphereNode.add(_lanternHalosNode!);
      }

      _airborneMotesNode = _atmosphereBuilder.buildAirborneMotesNode(
        graph: _graph,
        resolveMaterial: _resolveMaterial,
        sampleGroundY: sampleGroundHeight,
      );
      if (_airborneMotesNode != null) {
        _atmosphereNode.add(_airborneMotesNode!);
      }
    } else {
      final steamChanged =
          !listEquals(prevAtmosGraph.walls, _graph.walls) ||
          !listEquals(prevAtmosGraph.roads, _graph.roads) ||
          _anyMatchingStructureChanged(
            prevAtmosGraph,
            _graph,
            _isSteamStructure,
          );
      if (steamChanged) {
        _wardSteamNodes.forEach(_atmosphereMistNode.remove);
        _wardSteamNodes = _atmosphereBuilder.buildWardSteamAndHazeNodes(
          graph: _graph,
          resolveMaterial: _resolveMaterial,
          sampleGroundY: sampleGroundHeight,
        );
        _wardSteamNodes.forEach(_atmosphereMistNode.add);
      }

      final halosChanged =
          !listEquals(prevAtmosGraph.lanternSpans, _graph.lanternSpans) ||
          _anyMatchingStructureChanged(
            prevAtmosGraph,
            _graph,
            _isLanternStructure,
          );
      if (halosChanged) {
        if (_lanternHalosNode != null) {
          _atmosphereNode.remove(_lanternHalosNode!);
        }
        _lanternHalosNode = _atmosphereBuilder.buildLanternHalosNode(
          graph: _graph,
          resolveMaterial: _resolveMaterial,
        );
        if (_lanternHalosNode != null) {
          _atmosphereNode.add(_lanternHalosNode!);
        }
      }

      final motesChanged = _anyMatchingStructureChanged(
        prevAtmosGraph,
        _graph,
        (kind) => kind == StructureKind.mapleCluster,
      );
      if (motesChanged) {
        if (_airborneMotesNode != null) {
          _atmosphereNode.remove(_airborneMotesNode!);
        }
        _airborneMotesNode = _atmosphereBuilder.buildAirborneMotesNode(
          graph: _graph,
          resolveMaterial: _resolveMaterial,
          sampleGroundY: sampleGroundHeight,
        );
        if (_airborneMotesNode != null) {
          _atmosphereNode.add(_airborneMotesNode!);
        }
      }
    }
    _lastAtmosphereGraph = _graph;

    _rebuildPreviewNode();
  }

  void _rebuildGraphNodes() {
    if (_scene == null) {
      return;
    }
    _rebuildTerrainAndWayNodes();
    _rebuildArchitectureAndAgentNodes();
    _rebuildFloraAtmosphereAndPreviewNodes();
  }

  static double _lerpAngle(double a, double b, double t) {
    var diff = (b - a) % (math.pi * 2);
    if (diff > math.pi) {
      diff -= math.pi * 2;
    } else if (diff < -math.pi) {
      diff += math.pi * 2;
    }
    return a + diff * t;
  }

  @override
  void step(double dtSeconds, {required TimeOfDayRig rig}) {
    syncEmissives(rig);
    if (_simAgents.isEmpty) return;
    _walkTime += dtSeconds;
    final obstacles = agentObstacles;

    for (final agent in _simAgents) {
      final target = agent.waypoints[agent.currentWaypointIndex];
      final prevX = agent.position.x;
      final prevZ = agent.position.z;

      if (agent.dwellSeconds > 0) {
        agent.dwellSeconds = math.max(0, agent.dwellSeconds - dtSeconds);
        agent.velocity *= (1.0 - dtSeconds * 6.0).clamp(0.0, 1.0);
        final resolved = obstacles.resolvePosition(prevX, prevZ, prevX, prevZ);
        if (resolved.hit) {
          agent.position = Vec3(
            resolved.x,
            sampleGroundHeight(resolved.x, resolved.z),
            resolved.z,
          );
        }
      } else {
        final currentPosV = Vector3(prevX, agent.position.y, prevZ);
        final targetPosV = Vector3(target.x, agent.position.y, target.z);
        final steering = Steering.arrive(
          currentPosV,
          agent.velocity,
          targetPosV,
          slowingRadius: 1.35,
          maxSpeed: agent.speed,
          maxForce: 14,
        );
        final avoid = obstacles.computeAvoidanceForce(
          prevX,
          prevZ,
          target.x,
          target.z,
        );

        agent.velocity = Vector3(
          agent.velocity.x + (steering.x + avoid.fx) * dtSeconds,
          0,
          agent.velocity.z + (steering.z + avoid.fz) * dtSeconds,
        );
        final velLen = agent.velocity.length;
        if (velLen > agent.speed) {
          agent.velocity *= agent.speed / velLen;
        }

        final candX = prevX + agent.velocity.x * dtSeconds;
        final candZ = prevZ + agent.velocity.z * dtSeconds;
        final resolved = obstacles.resolvePosition(prevX, prevZ, candX, candZ);
        final groundY = sampleGroundHeight(resolved.x, resolved.z);
        agent.position = Vec3(resolved.x, groundY, resolved.z);

        final dx = resolved.x - prevX;
        final dz = resolved.z - prevZ;
        final moveDist = math.sqrt(dx * dx + dz * dz);
        if (resolved.hit && dtSeconds > 1e-6) {
          agent.velocity = Vector3(dx / dtSeconds, 0, dz / dtSeconds);
        }

        if (moveDist < agent.speed * dtSeconds * 0.18) {
          agent.stuckSeconds += dtSeconds;
          if (agent.stuckSeconds > 1.4) {
            final len = agent.waypoints.length;
            final nextSign = -agent.directionSign;
            agent
              ..directionSign = nextSign
              ..currentWaypointIndex =
                  (agent.currentWaypointIndex + nextSign + len) % len
              ..stuckSeconds = 0
              ..velocity = Vector3.zero();
          }
        } else {
          agent.stuckSeconds = math.max(0, agent.stuckSeconds - dtSeconds * 2);
        }

        if (dtSeconds > 1e-6 && moveDist / dtSeconds > 0.08) {
          final desiredYaw = math.atan2(dx, dz);
          agent.yawRadians = _lerpAngle(
            agent.yawRadians,
            desiredYaw,
            (dtSeconds * 8.5).clamp(0.0, 1.0),
          );
        }

        if (agent.position.horizontalDistanceTo(target) < 0.65) {
          final len = agent.waypoints.length;
          agent.currentWaypointIndex =
              (agent.currentWaypointIndex + agent.directionSign + len) % len;
          if ((agent.currentWaypointIndex + agent.id.value.hashCode).isEven) {
            agent.dwellSeconds =
                0.9 +
                ((agent.id.value.hashCode + agent.currentWaypointIndex * 13)
                            .abs() %
                        5) *
                    0.45;
          }
        }
      }

      final velLen = agent.velocity.length;
      final node = _agentNodes[agent.id];
      if (node != null) {
        final speedRatio = agent.speed > 0
            ? (velLen / agent.speed).clamp(0.0, 1.0)
            : 0.0;
        final phase = _walkTime * 7.2 + agent.bobPhase;
        final bob = math.sin(phase).abs() * 0.028 * speedRatio;
        final strideRoll = math.sin(phase) * 0.036 * speedRatio;
        final yawRot = Quaternion.axisAngle(Vector3(0, 1, 0), agent.yawRadians);
        final cadenceRot = Quaternion.axisAngle(Vector3(0, 0, 1), strideRoll);
        node
          ..position = Vector3(
            agent.position.x,
            agent.position.y + bob,
            agent.position.z,
          )
          ..rotation = yawRot * cadenceRot;

        final rigState = _agentRigs[agent.id];
        if (rigState != null) {
          if (speedRatio > 0.05) {
            final legSwing = math.sin(phase) * 0.40 * speedRatio;
            rigState.legL?.rotation =
                rigState.baseLegLRot *
                Quaternion.axisAngle(Vector3(1, 0, 0), legSwing);
            rigState.legR?.rotation =
                rigState.baseLegRRot *
                Quaternion.axisAngle(Vector3(1, 0, 0), -legSwing);
            rigState.upper?.rotation =
                rigState.baseUpperRot *
                Quaternion.axisAngle(Vector3(0, 1, 0), legSwing * 0.14) *
                Quaternion.axisAngle(Vector3(0, 0, 1), strideRoll * 0.55);
          } else {
            final idleSway = math.sin(_walkTime * 1.8 + agent.bobPhase) * 0.025;
            rigState.legL?.rotation = rigState.baseLegLRot;
            rigState.legR?.rotation = rigState.baseLegRRot;
            rigState.upper?.rotation =
                rigState.baseUpperRot *
                Quaternion.axisAngle(Vector3(0, 0, 1), idleSway);
          }
        }
      }
    }
  }

  static const List<String> _heroStructureAssetPaths = <String>[
    'assets/models/tree_maple_hero.glb',
    'assets/models/tree_maple_gold.glb',
    'assets/models/tree_pine_bonsai.glb',
    'assets/models/tree_willow_weeping.glb',
    'assets/models/tree_bamboo_clump.glb',
    'assets/models/machiya_hero.glb',
    'assets/models/machiya_hero_v1.glb',
    'assets/models/machiya_hero_v2.glb',
    'assets/models/machiya_hero_v3.glb',
    'assets/models/kura_warehouse_hero.glb',
    'assets/models/kura_warehouse_hero_v1.glb',
    'assets/models/teahouse_hero.glb',
    'assets/models/teahouse_hero_v1.glb',
    'assets/models/teahouse_hero_v2.glb',
    'assets/models/minka_hero_v0.glb',
    'assets/models/minka_hero_v1.glb',
    'assets/models/yatai_stall_v0.glb',
    'assets/models/yatai_stall_v1.glb',
    'assets/models/yatai_stall_v2.glb',
    'assets/models/yatai_stall_v3.glb',
    'assets/models/rock_cliff_a.glb',
    'assets/models/rock_cliff_b.glb',
  ];

  static String? _heroStructureAssetFor(PlacedStructure structure) {
    final hash = structure.id.value.hashCode.abs();
    return switch (structure.kind) {
      StructureKind.mapleCluster =>
        ((structure.variant + hash) & 1) == 0
            ? 'assets/models/tree_maple_hero.glb'
            : 'assets/models/tree_maple_gold.glb',
      StructureKind.pineTree => 'assets/models/tree_pine_bonsai.glb',
      StructureKind.weepingWillow => 'assets/models/tree_willow_weeping.glb',
      StructureKind.bambooGrove => 'assets/models/tree_bamboo_clump.glb',
      StructureKind.machiya => switch ((structure.variant + hash) & 3) {
        0 => 'assets/models/machiya_hero.glb',
        1 => 'assets/models/machiya_hero_v1.glb',
        2 => 'assets/models/machiya_hero_v2.glb',
        _ => 'assets/models/machiya_hero_v3.glb',
      },
      StructureKind.kura =>
        ((structure.variant + hash) & 1) == 0
            ? 'assets/models/kura_warehouse_hero.glb'
            : 'assets/models/kura_warehouse_hero_v1.glb',
      StructureKind.chaya => switch ((structure.variant + hash) % 3) {
        0 => 'assets/models/teahouse_hero.glb',
        1 => 'assets/models/teahouse_hero_v1.glb',
        _ => 'assets/models/teahouse_hero_v2.glb',
      },
      StructureKind.minka =>
        ((structure.variant + hash) & 1) == 0
            ? 'assets/models/minka_hero_v0.glb'
            : 'assets/models/minka_hero_v1.glb',
      StructureKind.marketStall => switch ((structure.variant + hash) & 3) {
        0 => 'assets/models/yatai_stall_v0.glb',
        1 => 'assets/models/yatai_stall_v1.glb',
        2 => 'assets/models/yatai_stall_v2.glb',
        _ => 'assets/models/yatai_stall_v3.glb',
      },
      StructureKind.rockOutcrop =>
        ((structure.variant + hash) & 1) == 0
            ? 'assets/models/rock_cliff_a.glb'
            : 'assets/models/rock_cliff_b.glb',
      _ => null,
    };
  }

  static void _overrideSubtreeMaterial(
    Node root,
    Material material, {
    bool skipPineNodes = false,
  }) {
    if (skipPineNodes && root.name.contains('IslandPine')) {
      return;
    }
    final mesh = root.mesh;
    if (mesh != null) {
      for (final prim in mesh.primitives) {
        prim.material = material;
      }
    }
    for (final child in root.children) {
      _overrideSubtreeMaterial(child, material, skipPineNodes: skipPineNodes);
    }
  }

  /// Registers mutable GLTF emissive materials (paper shoji panels vs glowing
  /// paper lanterns) so dusk frames do not blast full midnight HDR emission.
  void _collectEmissiveMaterials(Node root, {String hintName = ''}) {
    final mesh = root.mesh;
    final combinedHint = '${hintName}_${root.name}'.toLowerCase();
    if (mesh != null) {
      for (final prim in mesh.primitives) {
        final mat = prim.material;
        if (mat is PhysicallyBasedMaterial &&
            mat.emissiveFactor.length2 > 1e-4 &&
            mat.emissiveStrength > 0 &&
            _seenEmissives.add(mat)) {
          final isLantern =
              combinedHint.contains('lantern') ||
              combinedHint.contains('chochin') ||
              combinedHint.contains('beacon') ||
              combinedHint.contains('fire') ||
              (mat.emissiveFactor.x > 0.70 && mat.emissiveFactor.y < 0.48) ||
              mat.emissiveStrength >= 2.2;
          if (isLantern) {
            _cachedLanternEmissives.add(mat);
          } else {
            _cachedShojiEmissives.add(mat);
          }
          _lastSyncedEmissiveNightFactor = double.nan;
        }
      }
    }
    for (final child in root.children) {
      _collectEmissiveMaterials(child, hintName: combinedHint);
    }
  }

  /// Scales cached GLTF shoji window and lantern emissives with [rig].
  void syncEmissives(TimeOfDayRig rig) {
    _lastEmissiveRig = rig;
    if ((_lastSyncedEmissiveNightFactor - rig.nightFactor).abs() < 1e-4 &&
        _seenEmissives.isNotEmpty) {
      return;
    }
    _lastSyncedEmissiveNightFactor = rig.nightFactor;
    final shojiStrength = 0.36 + 1.88 * rig.nightFactor;
    final lanternStrength = 1.15 + 2.35 * rig.nightFactor;
    for (final mat in _cachedShojiEmissives) {
      mat.emissiveStrength = shojiStrength;
    }
    for (final mat in _cachedLanternEmissives) {
      mat.emissiveStrength = lanternStrength;
    }
  }

  static void _setSubtreeShadowCasting(Node root, ShadowCastingMode mode) {
    root.shadowCastingMode = mode;
    for (final child in root.children) {
      _setSubtreeShadowCasting(child, mode);
    }
  }

  Node _buildStructureOrHeroNode(PlacedStructure structure) {
    final assetPath = _heroStructureAssetFor(structure);
    final proto = assetPath == null
        ? null
        : _heroStructurePrototypes[assetPath];
    if (proto != null) {
      if (structure.kind.isBotanicalTree) {
        final hash = structure.id.value.hashCode.abs();
        final isBamboo = structure.kind == StructureKind.bambooGrove;
        final uniformScale = isBamboo
            ? 0.90 + (hash % 29) * 0.01
            : 0.78 + (hash % 59) * 0.01;
        final heightScale = isBamboo
            ? uniformScale
            : uniformScale * (0.94 + ((hash >> 4) % 13) * 0.01);
        final yaw = structure.yawRadians + ((hash % 628) * 0.01);
        final wrapper = Node(name: 'hero_tree_${structure.id.value}')
          ..position = structure.position.toVector3()
          ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), yaw)
          ..scale = Vector3(uniformScale, heightScale, uniformScale)
          ..add(proto.clone());
        return markSubtreeShadowStatic(wrapper);
      }
      if (structure.kind == StructureKind.rockOutcrop) {
        final hash = structure.id.value.hashCode.abs();
        final uniformScale = 0.92 + (hash % 24) * 0.01;
        final wrapper = Node(name: 'hero_rock_${structure.id.value}')
          ..position = structure.position.toVector3()
          ..rotation = Quaternion.axisAngle(
            Vector3(0, 1, 0),
            structure.yawRadians,
          )
          ..scale = Vector3(uniformScale, uniformScale, uniformScale)
          ..add(proto.clone());
        return markSubtreeShadowStatic(wrapper);
      }
      final wrapper = Node(name: 'hero_structure_${structure.id.value}')
        ..position = structure.position.toVector3()
        ..rotation = Quaternion.axisAngle(
          Vector3(0, 1, 0),
          structure.yawRadians,
        )
        ..scale = Vector3(1, 1, 1)
        ..add(proto.clone());
      _collectEmissiveMaterials(wrapper, hintName: structure.id.value);
      syncEmissives(_lastEmissiveRig);
      return markSubtreeShadowStatic(wrapper);
    }
    return markSubtreeShadowStatic(
      _kitBuilder.buildStructureNode(structure, _resolveMaterial),
    );
  }

  Future<Node?> _tryLoadHeroScene(String assetPath) async {
    try {
      final loaded = await loadScene(assetPath);
      if (_scene == null || _worldRoot == null) {
        unawaited(releaseScene(assetPath).then((_) {}, onError: (_) {}));
        return null;
      }
      _loadedScenePaths.add(assetPath);
      return loaded;
    } on Object catch (_) {
      return null;
    }
  }

  Future<Node?> _loadCachedGlbPrototype(String assetPath) async {
    final cached = _heroStructurePrototypes[assetPath];
    if (cached != null) {
      return cached;
    }
    final loaded = await _tryLoadHeroScene(assetPath);
    if (loaded != null) {
      _heroStructurePrototypes[assetPath] = loaded;
    }
    return loaded;
  }

  Future<bool> _preloadGlbPrototypes(
    Iterable<String> assetPaths, {
    required int capturedEpoch,
    required ShowcaseRealm capturedRealm,
    required Scene? capturedScene,
    int batchSize = 6,
  }) async {
    final pending = <String>[];
    final seen = <String>{};
    for (final path in assetPaths) {
      if (seen.add(path) && !_heroStructurePrototypes.containsKey(path)) {
        pending.add(path);
      }
    }
    for (var i = 0; i < pending.length; i += batchSize) {
      final end = math.min(i + batchSize, pending.length);
      final batch = pending.sublist(i, end);
      await Future.wait([
        for (final path in batch) _loadCachedGlbPrototype(path),
      ]);
      if (_isStaleAttach(capturedEpoch, capturedRealm, capturedScene)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _attachHeroGlbModels() async {
    if (_scene == null || _worldRoot == null) {
      return;
    }
    final capturedEpoch = _attachEpoch;
    final capturedRealm = _realm;
    final capturedScene = _scene;

    final vistaAsset = _realm == ShowcaseRealm.minatoJo
        ? 'assets/models/minato_coastal_islands.glb'
        : 'assets/models/vista_mountains.glb';
    final minatoPlacements = _realm == ShowcaseRealm.minatoJo
        ? buildMinatoCastleAndHarborPlacements(sampleGroundHeight)
        : null;
    final heroPlacements = _realm == ShowcaseRealm.minatoJo
        ? null
        : buildShukubaHeroPropPlacements(sampleGroundHeight);
    final assetsToPreload = <String>[
      vistaAsset,
      'assets/models/sky_cloud_dome.glb',
      ..._heroStructureAssetPaths,
      ..._heroAgentAssetPaths,
      if (_realm == ShowcaseRealm.shukubaValley && !_heroBridgeAttached)
        'assets/models/edo_arched_bridge.glb',
      'assets/models/edo_torii_gate.glb',
      if (minatoPlacements != null)
        for (final item in minatoPlacements) item.assetPath,
      if (heroPlacements != null)
        for (final item in heroPlacements) item.assetPath,
    ];
    final keepLoading = await _preloadGlbPrototypes(
      assetsToPreload,
      capturedEpoch: capturedEpoch,
      capturedRealm: capturedRealm,
      capturedScene: capturedScene,
    );
    if (!keepLoading) {
      return;
    }

    final vistaProto = await _loadCachedGlbPrototype(vistaAsset);
    if (_isStaleAttach(capturedEpoch, capturedRealm, capturedScene)) {
      return;
    }
    if (vistaProto != null) {
      final vistaMountains = vistaProto.clone();
      _overrideSubtreeMaterial(
        vistaMountains,
        _resolveMaterial(ShukubaSurfaceRole.mountainVista),
        skipPineNodes: true,
      );
      _setSubtreeShadowCasting(vistaMountains, ShadowCastingMode.off);
      _horizonRidgesNode.visible = false;
      if (_vistaMountainsNode != null) {
        _worldRoot!.remove(_vistaMountainsNode!);
      }
      _vistaMountainsNode = vistaMountains;
      _worldRoot!.add(vistaMountains);
    }

    final skyCloudProto = await _loadCachedGlbPrototype(
      'assets/models/sky_cloud_dome.glb',
    );
    if (_isStaleAttach(capturedEpoch, capturedRealm, capturedScene)) {
      return;
    }
    if (skyCloudProto != null) {
      final skyCloudDome = skyCloudProto.clone();
      _overrideSubtreeMaterial(
        skyCloudDome,
        _resolveMaterial(ShukubaSurfaceRole.paintedClouds),
      );
      _setSubtreeShadowCasting(skyCloudDome, ShadowCastingMode.off);
      if (_skyCloudDomeNode != null) {
        _worldRoot!.remove(_skyCloudDomeNode!);
      }
      _skyCloudDomeNode = skyCloudDome;
      _worldRoot!.add(skyCloudDome);
    }

    for (final structureAsset in _heroStructureAssetPaths) {
      await _loadCachedGlbPrototype(structureAsset);
      if (_isStaleAttach(capturedEpoch, capturedRealm, capturedScene)) {
        return;
      }
    }

    for (final agentAsset in _heroAgentAssetPaths) {
      await _loadCachedGlbPrototype(agentAsset);
      if (_isStaleAttach(capturedEpoch, capturedRealm, capturedScene)) {
        return;
      }
    }
    if (_scene != null) {
      _rebuildAgentNodes();
    }

    if (_heroStructurePrototypes.isNotEmpty) {
      for (final structure in _graph.structures.values) {
        final assetPath = _heroStructureAssetFor(structure);
        if (assetPath == null ||
            !_heroStructurePrototypes.containsKey(assetPath) ||
            _scene == null) {
          continue;
        }
        final heroNode = _buildStructureOrHeroNode(structure);
        final existing = _structureNodes[structure.id];
        if (existing != null) {
          _structuresNode.remove(existing.node);
        }
        _structureNodes[structure.id] = (data: structure, node: heroNode);
        _structuresNode.add(heroNode);
      }
    }

    if (_realm == ShowcaseRealm.shukubaValley && !_heroBridgeAttached) {
      final heroBridgeProto = await _loadCachedGlbPrototype(
        'assets/models/edo_arched_bridge.glb',
      );
      if (_isStaleAttach(capturedEpoch, capturedRealm, capturedScene)) {
        return;
      }
      if (heroBridgeProto != null) {
        _worldRoot!.remove(_bridgeNode);
        _bridgeNode = markSubtreeShadowStatic(heroBridgeProto.clone())
          ..visible = _realm == ShowcaseRealm.shukubaValley;
        _heroBridgeAttached = true;
        _worldRoot!.add(_bridgeNode);
      }
    } else {
      _bridgeNode.visible = _realm == ShowcaseRealm.shukubaValley;
    }

    final heroToriiProto = await _loadCachedGlbPrototype(
      'assets/models/edo_torii_gate.glb',
    );
    if (_isStaleAttach(capturedEpoch, capturedRealm, capturedScene)) {
      return;
    }
    if (heroToriiProto != null) {
      for (final structure in _graph.structures.values) {
        if (structure.kind != StructureKind.toriiGate) {
          continue;
        }
        final lanternBuilder = GeometryBuilder();
        final hookBuilder = GeometryBuilder();
        EdoKitBuilder.addLanternBody(
          lanternBuilder,
          hookBuilder,
          Vector3(-1.38, 3.38, 0),
          radius: 0.18,
          height: 0.42,
        );
        EdoKitBuilder.addLanternBody(
          lanternBuilder,
          hookBuilder,
          Vector3(1.38, 3.38, 0),
          radius: 0.18,
          height: 0.42,
        );
        final wrapper = Node(name: 'hero_torii_${structure.id.value}')
          ..position = structure.position.toVector3()
          ..rotation = Quaternion.axisAngle(
            Vector3(0, 1, 0),
            structure.yawRadians,
          )
          ..add(heroToriiProto.clone())
          ..add(
            Node(
              mesh: Mesh(
                lanternBuilder.build(),
                _resolveMaterial(ShukubaSurfaceRole.chochinLantern),
              ),
            ),
          )
          ..add(
            Node(
              mesh: Mesh(
                hookBuilder.build(),
                _resolveMaterial(ShukubaSurfaceRole.charredTimber),
              ),
            ),
          );
        final markedWrapper = markSubtreeShadowStatic(wrapper);
        final existing = _structureNodes[structure.id];
        if (existing != null) {
          _structuresNode.remove(existing.node);
        }
        _structureNodes[structure.id] = (data: structure, node: markedWrapper);
        _structuresNode.add(markedWrapper);
      }
    }

    if (_isStaleAttach(capturedEpoch, capturedRealm, capturedScene)) {
      return;
    }

    _heroPropsNode.removeAll();
    if (minatoPlacements != null) {
      for (final item in minatoPlacements) {
        final proto = await _loadCachedGlbPrototype(item.assetPath);
        if (_isStaleAttach(capturedEpoch, capturedRealm, capturedScene)) {
          return;
        }
        if (proto == null) {
          continue;
        }
        final propNode = Node(name: item.name)
          ..position = Vector3(item.x, item.y, item.z)
          ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), item.yaw)
          ..add(proto.clone());
        _heroPropsNode.add(propNode);
      }
    } else if (heroPlacements != null) {
      for (final item in heroPlacements) {
        final proto = await _loadCachedGlbPrototype(item.assetPath);
        if (_isStaleAttach(capturedEpoch, capturedRealm, capturedScene)) {
          return;
        }
        if (proto == null) {
          continue;
        }
        final y = sampleGroundHeight(item.x, item.z) + item.yOffset;
        final propNode = Node(name: item.name)
          ..position = Vector3(item.x, y, item.z)
          ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), item.yaw)
          ..scale = Vector3.all(item.scale)
          ..add(proto.clone());
        _heroPropsNode.add(propNode);
      }
    }

    if (_heroPropsNode.children.isNotEmpty) {
      markSubtreeShadowStatic(_heroPropsNode);
    }
    for (final proto in _heroStructurePrototypes.entries) {
      _collectEmissiveMaterials(proto.value, hintName: proto.key);
    }
    _collectEmissiveMaterials(_structuresNode, hintName: 'structures');
    _collectEmissiveMaterials(_heroPropsNode, hintName: 'hero_props');
    _collectEmissiveMaterials(_agentsNode, hintName: 'agents');
    syncEmissives(_lastEmissiveRig);
  }

  @override
  void dispose() {
    detach();
    _simAgents.clear();
    _heroStructurePrototypes.clear();
    for (final path in _loadedScenePaths) {
      unawaited(releaseScene(path).then((_) {}, onError: (_) {}));
    }
    _loadedScenePaths.clear();
  }
}
