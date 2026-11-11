import 'dart:math' as math;

import 'package:flutter_scene/kit.dart' show Steering;
import 'package:flutter_scene/scene.dart' show Node, Scene;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        AmbientLoopKind,
        BuildPreview,
        EntityId,
        NoBuildPreview,
        ShukubaGraph,
        ShukubaMaterialResolver,
        ShukubaWorldDriver,
        StreetAgentRole,
        StreetAgentSnapshot,
        StructureKind,
        TimeOfDayRig,
        Vec3,
        WatchSightcone,
        defaultShukubaMaterial;
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';
import 'package:kage_no_machi/shukuba/world/starter_ward.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';
import 'package:vector_math/vector_math.dart' show Quaternion, Vector3;

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

  Vec3 get forward => Vec3(math.sin(yawRadians), 0, math.cos(yawRadians));

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
  late final TerrainBuilder _terrainBuilder = const TerrainBuilder();
  late final EdoKitBuilder _kitBuilder = const EdoKitBuilder();

  late ShukubaGraph _graph = ShukubaGraph.empty;
  BuildPreview _activePreview = const NoBuildPreview();

  Node? _worldRoot;
  late Node _terrainNode;
  late Node _waterNode;
  late Node _gorgeDressingNode;
  late Node _bridgeNode;
  late final Node _roadsNode = Node();
  late final Node _terracesNode = Node();
  late final Node _wallsNode = Node();
  late final Node _structuresNode = Node();
  late final Node _lanternSpansNode = Node();
  late final Node _agentsNode = Node();
  late final Node _previewNode = Node();

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
    for (final span in _graph.lanternSpans) {
      origins.add(span.midpoint);
    }

    for (final agent in _simAgents) {
      if (agent.carriesLantern) {
        origins.add(agent.position + Vec3.up + agent.forward * 0.45);
      }
    }

    for (final structure in _graph.structures.values) {
      switch (structure.kind) {
        case StructureKind.chaya:
          final left = const Vec3(
            -1.58,
            2.05,
            2.95,
          ).rotateY(structure.yawRadians);
          final right = const Vec3(
            1.58,
            2.05,
            2.95,
          ).rotateY(structure.yawRadians);
          origins
            ..add(structure.position + left)
            ..add(structure.position + right);
        case StructureKind.toriiGate:
          final gateGlow = const Vec3(0, 3.05, 0).rotateY(structure.yawRadians);
          origins.add(structure.position + gateGlow);
        case StructureKind.marketStall:
          final stallGlow = const Vec3(
            1.12,
            1.96,
            1.08,
          ).rotateY(structure.yawRadians);
          origins.add(structure.position + stallGlow);
        case StructureKind.machiya:
          final porchGlow = const Vec3(
            0,
            1.95,
            3.55,
          ).rotateY(structure.yawRadians);
          origins.add(structure.position + porchGlow);
        case StructureKind.kura ||
            StructureKind.yaguraTower ||
            StructureKind.mapleCluster ||
            StructureKind.bambooGrove:
          break;
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
  double sampleGroundHeight(double x, double z) =>
      _terrainBuilder.sampleGroundHeight(x, z, terraces: _graph.terraces);

  @override
  Future<void> attach(
    Scene scene, {
    ShukubaMaterialResolver resolveMaterial = defaultShukubaMaterial,
    ShukubaGraph? initialGraph,
  }) async {
    _scene = scene;
    _resolveMaterial = resolveMaterial;

    _worldRoot = Node();
    _terrainNode = _terrainBuilder.buildTerrainNode(
      _resolveMaterial,
      terraces: initialGraph?.terraces ?? const [],
    );
    _waterNode = _terrainBuilder.buildWaterNode(_resolveMaterial);
    _gorgeDressingNode = _terrainBuilder.buildGorgeDressingNode(
      _resolveMaterial,
    );
    _bridgeNode = _terrainBuilder.buildBridgeNode(_resolveMaterial);

    _worldRoot!
      ..add(_terrainNode)
      ..add(_waterNode)
      ..add(_gorgeDressingNode)
      ..add(_bridgeNode)
      ..add(_roadsNode)
      ..add(_terracesNode)
      ..add(_wallsNode)
      ..add(_structuresNode)
      ..add(_lanternSpansNode)
      ..add(_agentsNode)
      ..add(_previewNode);

    _scene!.add(_worldRoot!);

    initSimulation(initialGraph: initialGraph);
    _rebuildGraphNodes();
    _rebuildPreviewNode();
  }

  void initSimulation({ShukubaGraph? initialGraph}) {
    _graph = initialGraph ?? buildStarterShukubaGraph(sampleGroundHeight);
    _initAgents();
  }

  void _initAgents() {
    _simAgents
      ..clear()
      ..addAll([
        _SimAgent(
          id: EntityId.validated('townsfolk_kaido_1'),
          role: StreetAgentRole.townsfolk,
          position: Vec3(-16, sampleGroundHeight(-16, 0.4), 0.4),
          waypoints: [
            Vec3(-18, sampleGroundHeight(-18, 0.4), 0.4),
            Vec3(-6, sampleGroundHeight(-6, -0.3), -0.3),
            Vec3(0, sampleGroundHeight(0, 0), 0),
            Vec3(8.5, sampleGroundHeight(8.5, 0.6), 0.6),
            Vec3(17, sampleGroundHeight(17, -0.4), -0.4),
          ],
          speed: 1.65,
        ),
        _SimAgent(
          id: EntityId.validated('lantern_innkeeper'),
          role: StreetAgentRole.lanternWatchman,
          position: Vec3(-9.5, sampleGroundHeight(-9.5, -0.2), -0.2),
          waypoints: [
            Vec3(-9.5, sampleGroundHeight(-9.5, -0.2), -0.2),
            Vec3(0, sampleGroundHeight(0, 0.2), 0.2),
            Vec3(9, sampleGroundHeight(9, 0.3), 0.3),
            Vec3(9, sampleGroundHeight(9, 7.6), 7.6),
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
          position: Vec3(9, sampleGroundHeight(9, 11.5), 11.5),
          waypoints: [
            Vec3(9, sampleGroundHeight(9, 12), 12),
            Vec3(9, sampleGroundHeight(9, 1.5), 1.5),
            Vec3(0, sampleGroundHeight(0, -0.3), -0.3),
            Vec3(-7.8, sampleGroundHeight(-7.8, -2), -2),
            Vec3(-8.4, sampleGroundHeight(-8.4, -9.2), -9.2),
            Vec3(-7.8, sampleGroundHeight(-7.8, -2), -2),
          ],
          speed: 1.55,
          bobPhase: 2.8,
        ),
      ]);

    _rebuildAgentNodes();
  }

  void _rebuildAgentNodes() {
    if (_scene == null) {
      return;
    }
    _agentsNode.children.clear();
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

    _graph = nextGraph;
    _rebuildGraphNodes();
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
    _previewNode.children.clear();
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

  void _rebuildGraphNodes() {
    if (_scene == null) {
      return;
    }

    _roadsNode.children.clear();
    for (final road in _graph.roads) {
      _roadsNode.add(
        _terrainBuilder.buildRoadNode(
          road,
          _resolveMaterial,
          sampleGroundHeight,
        ),
      );
    }

    _terracesNode.children.clear();
    for (final terrace in _graph.terraces) {
      _terracesNode.add(
        _terrainBuilder.buildTerraceNode(terrace, _resolveMaterial),
      );
    }

    _wallsNode.children.clear();
    for (final wall in _graph.walls) {
      _wallsNode.add(
        _terrainBuilder.buildWallNode(
          wall,
          _resolveMaterial,
          sampleGroundHeight,
        ),
      );
    }

    _structuresNode.children.clear();
    for (final structure in _graph.structures.values) {
      _structuresNode.add(
        _kitBuilder.buildStructureNode(structure, _resolveMaterial),
      );
    }

    _lanternSpansNode.children.clear();
    for (final span in _graph.lanternSpans) {
      _lanternSpansNode.add(
        _kitBuilder.buildLanternSpanNode(span, _resolveMaterial),
      );
    }
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
      if (agent.velocity.length > agent.speed) {
        agent.velocity = agent.velocity.normalized() * agent.speed;
      }

      final nextPosV = currentPosV + agent.velocity * dtSeconds;
      final groundY = sampleGroundHeight(nextPosV.x, nextPosV.z);
      agent.position = Vec3(nextPosV.x, groundY, nextPosV.z);

      if (agent.velocity.length2 > 1e-4) {
        agent.yawRadians = math.atan2(agent.velocity.x, agent.velocity.z);
      }

      if (agent.position.horizontalDistanceTo(target) < 1) {
        agent.currentWaypointIndex =
            (agent.currentWaypointIndex + 1) % agent.waypoints.length;
      }

      final node = _agentNodes[agent.id];
      if (node != null) {
        final speedRatio = (agent.velocity.length / agent.speed).clamp(
          0.0,
          1.0,
        );
        final bob =
            math.sin(_walkTime * 7.2 + agent.bobPhase).abs() *
            0.032 *
            speedRatio;
        node
          ..position = Vector3(
            agent.position.x,
            agent.position.y + bob,
            agent.position.z,
          )
          ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), agent.yawRadians);
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
    _worldRoot = null;
    _scene = null;
  }
}
