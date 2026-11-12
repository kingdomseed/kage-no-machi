import 'dart:math' as math;

import 'package:flutter_scene/kit.dart' show Steering;
import 'package:flutter_scene/scene.dart' show Node, Scene;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        AmbientLoopKind,
        BootStageId,
        BuildPreview,
        CourtyardWall,
        EntityId,
        NoBuildPreview,
        PlacedStructure,
        RoadSpline,
        ShukubaGraph,
        ShukubaMaterialResolver,
        ShukubaWorldDriver,
        StreetAgentRole,
        StreetAgentSnapshot,
        TerraceCourse,
        TimeOfDayRig,
        Vec3,
        WatchSightcone,
        defaultShukubaMaterial;
import 'package:kage_no_machi/shukuba/world/atmosphere_builder.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';
import 'package:kage_no_machi/shukuba/world/flora_scatter_builder.dart';
import 'package:kage_no_machi/shukuba/world/scene_shadow_helper.dart';
import 'package:kage_no_machi/shukuba/world/starter_ward.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';
import 'package:vector_math/vector_math.dart'
    show Aabb2, Quaternion, Vector2, Vector3;

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
       velocity = Vector3.zero();

  final EntityId id;
  final StreetAgentRole role;
  Vec3 position;
  final List<Vec3> waypoints;
  final bool carriesLantern;
  final double speed;
  final double bobPhase;
  int currentWaypointIndex;
  double yawRadians;
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
  new();

  Scene? _scene;
  ShukubaMaterialResolver _resolveMaterial = defaultShukubaMaterial;
  late final TerrainBuilder _terrainBuilder = TerrainBuilder();
  late final EdoKitBuilder _kitBuilder = const EdoKitBuilder();

  TerrainBuilder get terrainBuilder => _terrainBuilder;
  late final FloraScatterBuilder _floraBuilder = const FloraScatterBuilder();
  late final AtmosphereBuilder _atmosphereBuilder = const AtmosphereBuilder();

  late ShukubaGraph _graph = ShukubaGraph.empty;
  BuildPreview _activePreview = const NoBuildPreview();

  Node? _worldRoot;
  late final Node _terrainContainerNode = Node();
  late Node _waterNode;
  late final Node _gorgeDressingNode = Node(name: 'gorge_dressing_container');
  late Node _bridgeNode;
  late final Node _floraNode = Node(name: 'flora_scatter_root');
  late final Node _roadsNode = Node();
  late final Node _terracesNode = Node();
  late final Node _wallsNode = Node();
  late final Node _structuresNode = Node();
  late final Node _lanternSpansNode = Node();
  late final Node _agentsNode = Node();
  late final Node _atmosphereNode = Node();
  late final Node _previewNode = Node();

  final Set<int> _dirtyFloraChunkIndices = <int>{
    for (var i = 0; i < TerrainConfig.chunkCount; i++) i,
  };
  final Map<int, Node> _floraChunkNodes = <int, Node>{};

  Set<int> get dirtyFloraChunkIndices =>
      Set<int>.unmodifiable(_dirtyFloraChunkIndices);

  void clearDirtyFlora() => _dirtyFloraChunkIndices.clear();

  final List<_SimAgent> _simAgents = [];
  final Map<EntityId, Node> _agentNodes = {};
  double _walkTime = 0;

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

  @override
  Future<void> attach(
    Scene scene, {
    ShukubaMaterialResolver resolveMaterial = defaultShukubaMaterial,
    ShukubaGraph? initialGraph,
  }) async {
    _scene = scene;
    _resolveMaterial = resolveMaterial;

    _worldRoot = Node();
    _waterNode = markSubtreeShadowStatic(
      _terrainBuilder.buildWaterNode(_resolveMaterial),
    );
    _bridgeNode = markSubtreeShadowStatic(
      _terrainBuilder.buildBridgeNode(_resolveMaterial),
    );

    _worldRoot!
      ..add(_terrainContainerNode)
      ..add(_waterNode)
      ..add(_gorgeDressingNode)
      ..add(_bridgeNode)
      ..add(_floraNode)
      ..add(_roadsNode)
      ..add(_terracesNode)
      ..add(_wallsNode)
      ..add(_structuresNode)
      ..add(_lanternSpansNode)
      ..add(_agentsNode)
      ..add(_atmosphereNode)
      ..add(_previewNode);

    _scene!.add(_worldRoot!);

    initSimulation(initialGraph: initialGraph);
    _rebuildGraphNodes();
    _rebuildPreviewNode();
  }

  Future<void> attachStaged(
    Scene scene, {
    ShukubaMaterialResolver resolveMaterial = defaultShukubaMaterial,
    ShukubaGraph? initialGraph,
    Future<void> Function(BootStageId stage, double elapsedMs)? onStage,
  }) async {
    _scene = scene;
    _resolveMaterial = resolveMaterial;

    final stopwatch = Stopwatch()..start();

    _worldRoot = Node();
    _waterNode = markSubtreeShadowStatic(
      _terrainBuilder.buildWaterNode(_resolveMaterial),
    );
    _bridgeNode = markSubtreeShadowStatic(
      _terrainBuilder.buildBridgeNode(_resolveMaterial),
    );

    _worldRoot!
      ..add(_terrainContainerNode)
      ..add(_waterNode)
      ..add(_gorgeDressingNode)
      ..add(_bridgeNode)
      ..add(_floraNode)
      ..add(_roadsNode)
      ..add(_terracesNode)
      ..add(_wallsNode)
      ..add(_structuresNode)
      ..add(_lanternSpansNode)
      ..add(_agentsNode)
      ..add(_atmosphereNode)
      ..add(_previewNode);

    _scene!.add(_worldRoot!);

    initSimulation(initialGraph: initialGraph, rebuildAgentNodes: false);
    _rebuildTerrainAndWayNodes();

    if (onStage != null) {
      await onStage(
        BootStageId.valleyTerrain,
        stopwatch.elapsedMicroseconds / 1000.0,
      );
    }
    await Future<void>.delayed(Duration.zero);

    stopwatch.reset();
    _rebuildArchitectureAndAgentNodes();
    if (onStage != null) {
      await onStage(
        BootStageId.townArchitecture,
        stopwatch.elapsedMicroseconds / 1000.0,
      );
    }
    await Future<void>.delayed(Duration.zero);

    stopwatch.reset();
    _rebuildFloraAtmosphereAndPreviewNodes();
    if (onStage != null) {
      await onStage(
        BootStageId.floraAndAir,
        stopwatch.elapsedMicroseconds / 1000.0,
      );
    }
  }

  void initSimulation({
    ShukubaGraph? initialGraph,
    bool rebuildAgentNodes = true,
  }) {
    _terrainBuilder.markAllDirty();
    _dirtyFloraChunkIndices
      ..clear()
      ..addAll(Iterable<int>.generate(TerrainConfig.chunkCount));
    _floraChunkNodes.clear();
    _floraNode.removeAll();
    _graph =
        initialGraph ??
        buildStarterShukubaGraph(_terrainBuilder.sampleGroundHeight);
    _initAgents(rebuildNodes: rebuildAgentNodes);
  }

  void _initAgents({bool rebuildNodes = true}) {
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
          ],
          speed: 1.65,
        ),
        _SimAgent(
          id: EntityId.validated('lantern_innkeeper'),
          role: StreetAgentRole.lanternWatchman,
          position: Vec3(-9.5, sampleGroundHeight(-9.5, -0.16), -0.16),
          waypoints: [
            Vec3(-9.5, sampleGroundHeight(-9.5, -0.16), -0.16),
            Vec3(0, sampleGroundHeight(0, 0.2), 0.2),
            Vec3(9, sampleGroundHeight(9, 0.3), 0.3),
            Vec3(9.3, sampleGroundHeight(9.3, 8.2), 8.2),
            Vec3(9, sampleGroundHeight(9, 0.3), 0.3),
            Vec3(0, sampleGroundHeight(0, 0.2), 0.2),
          ],
          carriesLantern: true,
          speed: 1.35,
          bobPhase: 1.4,
        ),
        _SimAgent(
          id: EntityId.validated('merchant_traveler'),
          role: StreetAgentRole.nightSmuggler,
          position: Vec3(9.2, sampleGroundHeight(9.2, 11.5), 11.5),
          waypoints: [
            Vec3(9, sampleGroundHeight(9, 12), 12),
            Vec3(9, sampleGroundHeight(9, 1.8), 1.8),
            Vec3(0, sampleGroundHeight(0, -0.3), -0.3),
            Vec3(-7.8, sampleGroundHeight(-7.8, -2), -2),
            Vec3(-8.4, sampleGroundHeight(-8.4, -9.2), -9.2),
            Vec3(-7.8, sampleGroundHeight(-7.8, -2), -2),
          ],
          speed: 1.55,
          bobPhase: 2.8,
        ),
      ]);

    if (rebuildNodes) {
      _rebuildAgentNodes();
    }
  }

  void _rebuildAgentNodes() {
    if (_scene == null) {
      return;
    }
    _agentsNode.removeAll();
    _agentNodes.clear();

    for (final agent in _simAgents) {
      final node =
          _kitBuilder.buildStreetAgentNode(agent.role, _resolveMaterial)
            ..position = agent.position.toVector3()
            ..rotation = Quaternion.axisAngle(
              Vector3(0, 1, 0),
              agent.yawRadians,
            );

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
          math.max(s.spec.footprintWidth, s.spec.footprintDepth) + 2.5;
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

    _terrainContainerNode
      ..removeAll()
      ..add(
        markSubtreeShadowStatic(
          _terrainBuilder.buildTerrainNode(
            _resolveMaterial,
            terraces: _graph.terraces,
            roads: _graph.roads,
            structures: _graph.structures.values,
          ),
        ),
      );

    _gorgeDressingNode
      ..removeAll()
      ..add(
        markSubtreeShadowStatic(
          _terrainBuilder.buildGorgeDressingNode(
            _resolveMaterial,
            roads: _graph.roads,
          ),
        ),
      );

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

  void _rebuildArchitectureAndAgentNodes() {
    if (_scene == null) {
      return;
    }

    _structuresNode.removeAll();
    for (final structure in _graph.structures.values) {
      _structuresNode.add(
        markSubtreeShadowStatic(
          _kitBuilder.buildStructureNode(structure, _resolveMaterial),
        ),
      );
    }

    _lanternSpansNode.removeAll();
    for (final span in _graph.lanternSpans) {
      _lanternSpansNode.add(
        markSubtreeShadowStatic(
          _kitBuilder.buildLanternSpanNode(span, _resolveMaterial),
        ),
      );
    }

    _rebuildAgentNodes();
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

    _atmosphereNode
      ..removeAll()
      ..add(
        _atmosphereBuilder.buildAtmosphereNode(
          graph: _graph,
          resolveMaterial: _resolveMaterial,
          sampleGroundY: sampleGroundHeight,
        ),
      );

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

  @override
  void step(double dtSeconds, {required TimeOfDayRig rig}) {
    if (_simAgents.isEmpty) return;
    _walkTime += dtSeconds;

    for (final agent in _simAgents) {
      final target = agent.waypoints[agent.currentWaypointIndex];
      final currentPosV = agent.position.toVector3();
      final targetPosV = target.toVector3();

      final steering = Steering.arrive(
        currentPosV,
        agent.velocity,
        targetPosV,
        slowingRadius: 2,
        maxSpeed: agent.speed,
      );

      agent.velocity += steering * dtSeconds;
      var velLen = agent.velocity.length;
      if (velLen > agent.speed) {
        agent.velocity = agent.velocity * (agent.speed / velLen);
        velLen = agent.speed;
      }

      final nextPosV = currentPosV + agent.velocity * dtSeconds;
      final groundY = sampleGroundHeight(nextPosV.x, nextPosV.z);
      agent.position = Vec3(nextPosV.x, groundY, nextPosV.z);

      if (velLen > 1e-2) {
        agent.yawRadians = math.atan2(agent.velocity.x, agent.velocity.z);
      }

      if (agent.position.horizontalDistanceTo(target) < 1) {
        agent.currentWaypointIndex =
            (agent.currentWaypointIndex + 1) % agent.waypoints.length;
      }

      final node = _agentNodes[agent.id];
      if (node != null) {
        final speedRatio = agent.speed > 0 ? velLen / agent.speed : 0.0;
        final phase = _walkTime * 7.2 + agent.bobPhase;
        final bob = math.sin(phase).abs() * 0.034 * speedRatio;
        final strideRoll = math.sin(phase) * 0.042 * speedRatio;
        final yawRot = Quaternion.axisAngle(Vector3(0, 1, 0), agent.yawRadians);
        final cadenceRot = Quaternion.axisAngle(Vector3(0, 0, 1), strideRoll);
        node
          ..position = Vector3(
            agent.position.x,
            agent.position.y + bob,
            agent.position.z,
          )
          ..rotation = yawRot * cadenceRot;
      }
    }
  }

  @override
  void dispose() {
    if (_worldRoot != null && _scene != null) {
      _scene!.remove(_worldRoot!);
    }
    _simAgents.clear();
    _agentNodes.clear();
    _floraChunkNodes.clear();
    _floraNode.removeAll();
    _gorgeDressingNode.removeAll();
    _worldRoot = null;
    _scene = null;
  }
}
