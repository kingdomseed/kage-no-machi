import 'dart:math' as math;

import 'package:flutter_scene/kit.dart' show Steering;
import 'package:flutter_scene/scene.dart' show Node, Scene;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        AmbientLoopKind,
        EntityId,
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
    this.speed = 2,
  }) : currentWaypointIndex = 0,
       yawRadians = 0,
       velocity = Vector3.zero();

  final EntityId id;
  final StreetAgentRole role;
  Vec3 position;
  final List<Vec3> waypoints;
  final bool carriesLantern;
  final double speed;
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

  Node? _worldRoot;
  late Node _terrainNode;
  late Node _waterNode;
  late Node _bridgeNode;
  late final Node _roadsNode = Node();
  late final Node _terracesNode = Node();
  late final Node _structuresNode = Node();
  late final Node _lanternSpansNode = Node();
  late final Node _agentsNode = Node();

  final List<_SimAgent> _simAgents = [];
  final Map<EntityId, Node> _agentNodes = {};

  final Map<EntityId, double> _towerAlerts = {};
  double _watchmanAlert = 0;

  @override
  ShukubaGraph get graph => _graph;

  @override
  List<WatchSightcone> get activeSightcones {
    final list = <WatchSightcone>[];
    for (final structure in _graph.structures.values) {
      if (structure.kind == StructureKind.yaguraTower) {
        final alert = _towerAlerts[structure.id] ?? 0;
        final cone = structure.toStructuralSightcone(alertLevel: alert);
        if (cone != null) {
          list.add(cone);
        }
      }
    }

    final watchman = _simAgents.cast<_SimAgent?>().firstWhere(
      (a) => a?.role == StreetAgentRole.lanternWatchman,
      orElse: () => null,
    );
    if (watchman != null) {
      list.add(
        WatchSightcone(
          sourceId: watchman.id,
          origin: watchman.position + const Vec3(0, 1.2, 0),
          yawRadians: watchman.yawRadians,
          rangeMeters: 8.5,
          halfAngleRadians: 0.38,
          alertLevel: _watchmanAlert,
        ),
      );
    }
    return list;
  }

  @override
  List<Vec3> get activeLanternOrigins {
    final origins = <Vec3>[];
    for (final span in _graph.lanternSpans) {
      origins.add(span.midpoint);
    }

    final watchman = _simAgents.cast<_SimAgent?>().firstWhere(
      (a) => a?.role == StreetAgentRole.lanternWatchman,
      orElse: () => null,
    );
    if (watchman != null) {
      origins.add(
        watchman.position + const Vec3(0, 0.9, 0) + watchman.forward * 0.4,
      );
    }

    for (final structure in _graph.structures.values) {
      if (structure.kind == StructureKind.marketStall) {
        final lanternLocal = const Vec3(
          1.11,
          2.03,
          1.06,
        ).rotateY(structure.yawRadians);
        origins.add(structure.position + lanternLocal);
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
    AmbientLoopKind.bambooWind: Vec3(-12, sampleGroundHeight(-12, 10), 10),
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
    _bridgeNode = _terrainBuilder.buildBridgeNode(_resolveMaterial);

    _worldRoot!
      ..add(_terrainNode)
      ..add(_waterNode)
      ..add(_bridgeNode)
      ..add(_roadsNode)
      ..add(_terracesNode)
      ..add(_structuresNode)
      ..add(_lanternSpansNode)
      ..add(_agentsNode);

    _scene!.add(_worldRoot!);

    initSimulation(initialGraph: initialGraph);
    applyGraph(_graph);
  }

  void initSimulation({ShukubaGraph? initialGraph}) {
    _initAgents();
    _graph = initialGraph ?? buildStarterShukubaGraph(sampleGroundHeight);
  }

  void _initAgents() {
    _simAgents
      ..clear()
      ..addAll([
        _SimAgent(
          id: EntityId.validated('townsfolk_1'),
          role: StreetAgentRole.townsfolk,
          position: Vec3(-14, sampleGroundHeight(-14, 0.5), 0.5),
          waypoints: [
            Vec3(-14, sampleGroundHeight(-14, 0.5), 0.5),
            Vec3(-6, sampleGroundHeight(-6, -0.3), -0.3),
            Vec3(0, sampleGroundHeight(0, 0), 0),
            Vec3(7, sampleGroundHeight(7, 0.8), 0.8),
            Vec3(13, sampleGroundHeight(13, -0.5), -0.5),
          ],
          speed: 1.8,
        ),
        _SimAgent(
          id: EntityId.validated('lantern_watchman'),
          role: StreetAgentRole.lanternWatchman,
          position: Vec3(-8.5, sampleGroundHeight(-8.5, 0), 0),
          waypoints: [
            Vec3(-8.5, sampleGroundHeight(-8.5, 0), 0),
            Vec3(0, sampleGroundHeight(0, 0), 0),
            Vec3(8.5, sampleGroundHeight(8.5, 0), 0),
            Vec3(0, sampleGroundHeight(0, 0), 0),
          ],
          carriesLantern: true,
          speed: 1.4,
        ),
        _SimAgent(
          id: EntityId.validated('night_smuggler'),
          role: StreetAgentRole.nightSmuggler,
          position: Vec3(-7, sampleGroundHeight(-7, 4), 4),
          waypoints: [
            Vec3(-7, sampleGroundHeight(-7, 4), 4),
            Vec3(-2, sampleGroundHeight(-2, 2.5), 2.5),
            Vec3(2, sampleGroundHeight(2, 2.5), 2.5),
            Vec3(8, sampleGroundHeight(8, 3.5), 3.5),
            Vec3(13, sampleGroundHeight(13, -4.5), -4.5),
          ],
          speed: 2.2,
        ),
      ]);

    _rebuildAgentNodes();
  }

  void _rebuildAgentNodes() {
    _agentsNode.children.clear();
    _agentNodes.clear();

    for (final agent in _simAgents) {
      final node = Node()
        ..position = agent.position.toVector3()
        ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), agent.yawRadians);

      _agentNodes[agent.id] = node;
      _agentsNode.add(node);
    }
  }

  @override
  void applyGraph(ShukubaGraph nextGraph) {
    if (identical(_graph, nextGraph) && _graph != ShukubaGraph.empty) {
      return;
    }

    _graph = nextGraph;

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
        node
          ..position = agent.position.toVector3()
          ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), agent.yawRadians);
      }
    }

    final smuggler = _simAgents.cast<_SimAgent?>().firstWhere(
      (a) => a?.role == StreetAgentRole.nightSmuggler,
      orElse: () => null,
    );

    if (smuggler != null) {
      for (final structure in _graph.structures.values) {
        if (structure.kind == StructureKind.yaguraTower) {
          final cone = structure.toStructuralSightcone();
          if (cone != null) {
            final intruded = cone.containsPoint(smuggler.position);
            final currentAlert = _towerAlerts[structure.id] ?? 0;
            final targetAlert = intruded ? 1.0 : 0.0;
            final blendSpeed = intruded ? 4.0 : 1.5;
            _towerAlerts[structure.id] =
                currentAlert +
                (targetAlert - currentAlert) *
                    math.min(1.0, dtSeconds * blendSpeed);
          }
        }
      }

      final watchman = _simAgents.cast<_SimAgent?>().firstWhere(
        (a) => a?.role == StreetAgentRole.lanternWatchman,
        orElse: () => null,
      );
      if (watchman != null) {
        final cone = WatchSightcone(
          sourceId: watchman.id,
          origin: watchman.position + const Vec3(0, 1.2, 0),
          yawRadians: watchman.yawRadians,
          rangeMeters: 8.5,
          halfAngleRadians: 0.38,
        );
        final intruded = cone.containsPoint(smuggler.position);
        final targetAlert = intruded ? 1.0 : 0.0;
        final blendSpeed = intruded ? 4.0 : 1.5;
        _watchmanAlert =
            _watchmanAlert +
            (targetAlert - _watchmanAlert) *
                math.min(1.0, dtSeconds * blendSpeed);
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
