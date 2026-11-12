import 'dart:math' as math;

import 'package:flutter_scene/scene.dart'
    show
        GeometryBuilder,
        InstancedMesh,
        InstancedMeshComponent,
        Material,
        Mesh,
        MeshGeometry,
        Node,
        ShadowCastingMode;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        GroundHeightSampler,
        PlacedStructure,
        RoadStyle,
        ShukubaGraph,
        ShukubaMaterialResolver,
        ShukubaSurfaceRole,
        StructureKind,
        Vec3;
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart'
    show EdoKitBuilder;
import 'package:kage_no_machi/shukuba/world/scene_shadow_helper.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart'
    show TerrainBuilder, TerrainConfig;
import 'package:vector_math/vector_math.dart'
    show Aabb3, Matrix4, Vector2, Vector3, Vector4;

class FloraChunkSummary {
  const new({
    required this.row,
    required this.col,
    required this.bounds,
    required this.instanceCount,
    required this.cobbleCount,
  });

  final int row;
  final int col;
  final Aabb3 bounds;
  final int instanceCount;
  final int cobbleCount;

  int get chunkIndex => row * TerrainConfig.gridDimension + col;
  String get nodeName => 'flora_tile_${row}_$col';
  double get spanX => bounds.max.x - bounds.min.x;
  double get spanY => bounds.max.y - bounds.min.y;
  double get spanZ => bounds.max.z - bounds.min.z;
}

class _SegBox {
  const new(
    this.ax,
    this.az,
    this.bx,
    this.bz,
    this.minX,
    this.maxX,
    this.minZ,
    this.maxZ,
    this.clearance,
  );

  final double ax;
  final double az;
  final double bx;
  final double bz;
  final double minX;
  final double maxX;
  final double minZ;
  final double maxZ;
  final double clearance;

  bool containsWithin(double x, double z, double extraMargin) {
    final limit = clearance + extraMargin;
    if (limit <= 0) {
      return false;
    }
    if (x < minX - limit ||
        x > maxX + limit ||
        z < minZ - limit ||
        z > maxZ + limit) {
      return false;
    }
    final vx = bx - ax;
    final vz = bz - az;
    final lenSq = vx * vx + vz * vz;
    final double px;
    final double pz;
    if (lenSq <= 1e-9) {
      px = ax;
      pz = az;
    } else {
      final rawT = ((x - ax) * vx + (z - az) * vz) / lenSq;
      final t = rawT < 0 ? 0.0 : (rawT > 1 ? 1.0 : rawT);
      px = ax + vx * t;
      pz = az + vz * t;
    }
    final dx = x - px;
    final dz = z - pz;
    return dx * dx + dz * dz < limit * limit;
  }

  double signedDistanceOutside(double x, double z) {
    final vx = bx - ax;
    final vz = bz - az;
    final lenSq = vx * vx + vz * vz;
    final double px;
    final double pz;
    if (lenSq <= 1e-9) {
      px = ax;
      pz = az;
    } else {
      final rawT = ((x - ax) * vx + (z - az) * vz) / lenSq;
      final t = rawT < 0 ? 0.0 : (rawT > 1 ? 1.0 : rawT);
      px = ax + vx * t;
      pz = az + vz * t;
    }
    final dx = x - px;
    final dz = z - pz;
    return math.sqrt(dx * dx + dz * dz) - clearance;
  }
}

class _NaturalAnchor {
  const new({
    required this.x,
    required this.z,
    required this.coreRadius,
    required this.haloRadius,
  });

  final double x;
  final double z;
  final double coreRadius;
  final double haloRadius;
}

class _FloraExclusionIndex {
  factory fromGraph(ShukubaGraph graph) {
    final roadSegs = <_SegBox>[];
    for (final road in graph.roads) {
      final halfW = road.widthMeters * 0.5;
      final pts = road.smoothCenterline(stepMeters: 1);
      for (var i = 0; i < pts.length - 1; i++) {
        final a = pts[i];
        final b = pts[i + 1];
        roadSegs.add(
          _SegBox(
            a.x,
            a.z,
            b.x,
            b.z,
            math.min(a.x, b.x),
            math.max(a.x, b.x),
            math.min(a.z, b.z),
            math.max(a.z, b.z),
            halfW,
          ),
        );
      }
    }

    final wallSegs = <_SegBox>[];
    for (final wall in graph.walls) {
      final halfW = wall.thicknessMeters * 0.5 + 0.36;
      for (var i = 0; i < wall.controlPoints.length - 1; i++) {
        final a = wall.controlPoints[i];
        final b = wall.controlPoints[i + 1];
        wallSegs.add(
          _SegBox(
            a.x,
            a.z,
            b.x,
            b.z,
            math.min(a.x, b.x),
            math.max(a.x, b.x),
            math.min(a.z, b.z),
            math.max(a.z, b.z),
            halfW,
          ),
        );
      }
    }

    final terraceSegs = <_SegBox>[];
    for (final terrace in graph.terraces) {
      for (var i = 0; i < terrace.crestPoints.length - 1; i++) {
        final a = terrace.crestPoints[i];
        final b = terrace.crestPoints[i + 1];
        terraceSegs.add(
          _SegBox(
            a.x,
            a.z,
            b.x,
            b.z,
            math.min(a.x, b.x),
            math.max(a.x, b.x),
            math.min(a.z, b.z),
            math.max(a.z, b.z),
            0.82,
          ),
        );
      }
    }

    final buildings = <PlacedStructure>[];
    final naturalAnchors = <_NaturalAnchor>[];
    for (final s in graph.structures.values) {
      if (s.kind.isNaturalFeature) {
        final isRock = s.kind == StructureKind.rockOutcrop;
        naturalAnchors.add(
          _NaturalAnchor(
            x: s.position.x,
            z: s.position.z,
            coreRadius: isRock ? 1.05 : 0.44,
            haloRadius: isRock ? 3.55 : 3.85,
          ),
        );
      } else {
        buildings.add(s);
      }
    }

    return _FloraExclusionIndex._(
      roadSegs: roadSegs,
      wallSegs: wallSegs,
      terraceSegs: terraceSegs,
      buildings: buildings,
      naturalAnchors: naturalAnchors,
    );
  }

  const new _({
    required this.roadSegs,
    required this.wallSegs,
    required this.terraceSegs,
    required this.buildings,
    required this.naturalAnchors,
  });

  final List<_SegBox> roadSegs;
  final List<_SegBox> wallSegs;
  final List<_SegBox> terraceSegs;
  final List<PlacedStructure> buildings;
  final List<_NaturalAnchor> naturalAnchors;

  bool isNearRoad(double x, double z, double extraMargin) {
    for (var i = 0; i < roadSegs.length; i++) {
      if (roadSegs[i].containsWithin(x, z, extraMargin)) {
        return true;
      }
    }
    return false;
  }

  double minRoadEdgeDistance(double x, double z) {
    var best = 99.0;
    for (var i = 0; i < roadSegs.length; i++) {
      final s = roadSegs[i];
      if (x < s.minX - 4.5 ||
          x > s.maxX + 4.5 ||
          z < s.minZ - 4.5 ||
          z > s.maxZ + 4.5) {
        continue;
      }
      final d = s.signedDistanceOutside(x, z);
      if (d < best) {
        best = d;
      }
    }
    return best;
  }

  bool isClear(
    double x,
    double z, {
    double roadMargin = 0.42,
    double footprintMargin = 0.34,
    double minRiverDist = 2.40,
  }) {
    if (x < TerrainConfig.minX + 1.1 ||
        x > TerrainConfig.maxX - 1.1 ||
        z < TerrainConfig.minZ + 1.1 ||
        z > TerrainConfig.maxZ - 1.1) {
      return false;
    }

    if ((x - TerrainConfig.riverCenterX(z)).abs() < minRiverDist) {
      return false;
    }

    if (TerrainBuilder.isInsideTanadaFloodedBasin(x, z)) {
      return false;
    }

    if (x >= TerrainConfig.bridgeMinX - 0.85 &&
        x <= TerrainConfig.bridgeMaxX + 0.85 &&
        z >= TerrainConfig.bridgeMinZ - 0.72 &&
        z <= TerrainConfig.bridgeMaxZ + 0.72) {
      return false;
    }

    if ((x.abs() - 66.0).abs() < 3.6 && z.abs() < 6.9) {
      return false;
    }

    if (isNearRoad(x, z, roadMargin)) {
      return false;
    }

    for (var i = 0; i < wallSegs.length; i++) {
      if (wallSegs[i].containsWithin(x, z, 0)) {
        return false;
      }
    }

    for (var i = 0; i < terraceSegs.length; i++) {
      if (terraceSegs[i].containsWithin(x, z, 0)) {
        return false;
      }
    }

    for (var i = 0; i < naturalAnchors.length; i++) {
      final a = naturalAnchors[i];
      final dx = x - a.x;
      final dz = z - a.z;
      if (dx * dx + dz * dz < a.coreRadius * a.coreRadius) {
        return false;
      }
    }

    for (var i = 0; i < buildings.length; i++) {
      final b = buildings[i];
      final dx = x - b.position.x;
      final dz = z - b.position.z;
      if (dx * dx + dz * dz > 36) {
        continue;
      }
      if (TerrainBuilder.signedFootprintMargin(x, z, b) < footprintMargin) {
        return false;
      }
    }

    return true;
  }

  double minWallOrTerraceDistance(double x, double z) {
    var best = 99.0;
    for (var i = 0; i < terraceSegs.length; i++) {
      final s = terraceSegs[i];
      if (x < s.minX - 5 ||
          x > s.maxX + 5 ||
          z < s.minZ - 5 ||
          z > s.maxZ + 5) {
        continue;
      }
      final d = TerrainBuilder.horizontalDistanceToSegment(
        x,
        z,
        Vec3(s.ax, 0, s.az),
        Vec3(s.bx, 0, s.bz),
      );
      if (d < best) {
        best = d;
      }
    }
    for (var i = 0; i < wallSegs.length; i++) {
      final s = wallSegs[i];
      if (x < s.minX - 5 ||
          x > s.maxX + 5 ||
          z < s.minZ - 5 ||
          z > s.maxZ + 5) {
        continue;
      }
      final d = TerrainBuilder.horizontalDistanceToSegment(
        x,
        z,
        Vec3(s.ax, 0, s.az),
        Vec3(s.bx, 0, s.bz),
      );
      if (d < best) {
        best = d;
      }
    }
    return best;
  }

  double sampleHabitatAffinity(double x, double z) {
    final wallDist = minWallOrTerraceDistance(x, z);
    final wallPocket = wallDist < 3.6
        ? math.exp(-math.pow((wallDist - 1.15) / 1.15, 2)) * 0.94
        : 0.0;

    final rivDist = (x - TerrainConfig.riverCenterX(z)).abs();
    final bankPocket = rivDist < 7.2
        ? math.exp(-math.pow((rivDist - 3.55) / 1.95, 2)) * 0.92
        : 0.0;

    final roadEdge = minRoadEdgeDistance(x, z);
    final vergePocket = roadEdge >= 0.08 && roadEdge < 2.65
        ? math.exp(-math.pow((roadEdge - 0.72) / 1.05, 2)) * 0.86
        : 0.0;

    var anchorPocket = 0.0;
    for (var i = 0; i < naturalAnchors.length; i++) {
      final a = naturalAnchors[i];
      final dx = x - a.x;
      final dz = z - a.z;
      final maxR = a.haloRadius + 1.4;
      final dSq = dx * dx + dz * dz;
      if (dSq > maxR * maxR) {
        continue;
      }
      final d = math.sqrt(dSq);
      final ring = math
          .exp(-math.pow((d - (a.coreRadius + 0.55)) / 1.65, 2))
          .clamp(0.0, 1.0);
      if (ring > anchorPocket) {
        anchorPocket = ring;
      }
    }

    final wx =
        x + 2.7 * math.sin(z * 0.13 + 0.8) + 1.4 * math.cos(x * 0.21 - 0.5);
    final wz =
        z + 2.7 * math.cos(x * 0.14 - 0.4) + 1.4 * math.sin(z * 0.19 + 1.1);
    final organicDrift =
        0.5 +
        0.28 * math.sin(wx * 0.23 + wz * 0.17) +
        0.22 * math.cos(wz * 0.31 - wx * 0.19);
    final radialOut = math.sqrt(x * x + z * z);
    final countryMargin = ((radialOut - 13.5) / 12.5).clamp(0.0, 1.0);
    final outerClump = (0.36 + 0.62 * organicDrift) * countryMargin;
    final tanadaPocket = TerrainBuilder.sampleTanadaMossAffinity(x, z) * 0.94;

    final primary = math.max(
      math.max(
        math.max(wallPocket, vergePocket),
        math.max(bankPocket, tanadaPocket),
      ),
      math.max(anchorPocket * 0.98, outerClump),
    );
    return (primary * (0.82 + 0.30 * organicDrift)).clamp(0.0, 1.0);
  }
}

enum _FloraBatchKind {
  sward(protoRadiusXZ: 0.54, protoMinY: 0, protoMaxY: 0.78),
  overgrowthRosettes(protoRadiusXZ: 0.58, protoMinY: -0.02, protoMaxY: 0.42),
  nogiku(protoRadiusXZ: 0.42, protoMinY: 0, protoMaxY: 1.12),
  susuki(protoRadiusXZ: 0.54, protoMinY: 0, protoMaxY: 1.25),
  higanbana(protoRadiusXZ: 0.44, protoMinY: 0, protoMaxY: 1.15),
  reeds(protoRadiusXZ: 0.72, protoMinY: 0, protoMaxY: 1.02),
  shrubs(protoRadiusXZ: 1.02, protoMinY: 0, protoMaxY: 0.80),
  wallDrapes(protoRadiusXZ: 0.54, protoMinY: -1.02, protoMaxY: 0.02),
  fallenMomiji(protoRadiusXZ: 0.72, protoMinY: 0, protoMaxY: 0.03);

  new({
    required this.protoRadiusXZ,
    required this.protoMinY,
    required this.protoMaxY,
  });

  final double protoRadiusXZ;
  final double protoMinY;
  final double protoMaxY;
}

class _FloraInstanceRecord {
  const new({required this.transform, required this.color});

  final Matrix4 transform;
  final Vector4 color;
}

class _CobbleRecord {
  const new({
    required this.center,
    required this.radii,
    required this.yaw,
    required this.seed,
  });

  final Vector3 center;
  final Vector3 radii;
  final double yaw;
  final double seed;
}

class _ChunkFloraBucket {
  new(this.row, this.col);

  final int row;
  final int col;
  final Map<_FloraBatchKind, List<_FloraInstanceRecord>> batches = {
    for (final kind in _FloraBatchKind.values) kind: <_FloraInstanceRecord>[],
  };
  final List<_CobbleRecord> cobbles = <_CobbleRecord>[];

  double _minX = double.infinity;
  double _maxX = -double.infinity;
  double _minY = double.infinity;
  double _maxY = -double.infinity;
  double _minZ = double.infinity;
  double _maxZ = -double.infinity;
  int _instanceCount = 0;

  void addInstance(
    _FloraBatchKind kind, {
    required Matrix4 transform,
    required Vector4 color,
    required double x,
    required double y,
    required double z,
    required double scaleXZ,
    required double scaleY,
  }) {
    batches[kind]!.add(
      _FloraInstanceRecord(transform: transform.clone(), color: color),
    );
    _instanceCount++;
    final rxz = kind.protoRadiusXZ * scaleXZ;
    final y0 = y + kind.protoMinY * scaleY;
    final y1 = y + kind.protoMaxY * scaleY;
    if (x - rxz < _minX) _minX = x - rxz;
    if (x + rxz > _maxX) _maxX = x + rxz;
    if (y0 < _minY) _minY = y0;
    if (y1 > _maxY) _maxY = y1;
    if (z - rxz < _minZ) _minZ = z - rxz;
    if (z + rxz > _maxZ) _maxZ = z + rxz;
  }

  void addCobble(_CobbleRecord cobble) {
    cobbles.add(cobble);
    final rxz = math.max(cobble.radii.x, cobble.radii.z);
    final ry = cobble.radii.y;
    if (cobble.center.x - rxz < _minX) _minX = cobble.center.x - rxz;
    if (cobble.center.x + rxz > _maxX) _maxX = cobble.center.x + rxz;
    if (cobble.center.y - ry < _minY) _minY = cobble.center.y - ry;
    if (cobble.center.y + ry > _maxY) _maxY = cobble.center.y + ry;
    if (cobble.center.z - rxz < _minZ) _minZ = cobble.center.z - rxz;
    if (cobble.center.z + rxz > _maxZ) _maxZ = cobble.center.z + rxz;
  }

  bool get isEmpty => _instanceCount == 0 && cobbles.isEmpty;

  FloraChunkSummary toSummary() {
    final bounds = isEmpty
        ? Aabb3.minMax(
            Vector3(
              TerrainConfig.chunkMinX(col),
              0,
              TerrainConfig.chunkMinZ(row),
            ),
            Vector3(
              TerrainConfig.chunkMinX(col),
              0,
              TerrainConfig.chunkMinZ(row),
            ),
          )
        : Aabb3.minMax(
            Vector3(_minX, _minY, _minZ),
            Vector3(_maxX, _maxY, _maxZ),
          );
    return FloraChunkSummary(
      row: row,
      col: col,
      bounds: bounds,
      instanceCount: _instanceCount,
      cobbleCount: cobbles.length,
    );
  }
}

class FloraScatterBuilder {
  const new();

  static int chunkColForX(double x) =>
      ((x - TerrainConfig.minX) / TerrainConfig.chunkSpan).floor().clamp(
        0,
        TerrainConfig.gridDimension - 1,
      );

  static int chunkRowForZ(double z) =>
      ((z - TerrainConfig.minZ) / TerrainConfig.chunkSpan).floor().clamp(
        0,
        TerrainConfig.gridDimension - 1,
      );

  static int chunkIndexFor(double x, double z) =>
      chunkRowForZ(z) * TerrainConfig.gridDimension + chunkColForX(x);

  static bool isClearForGroundFlora(
    double x,
    double z,
    ShukubaGraph graph, {
    double roadMargin = 0.42,
    double footprintMargin = 0.34,
  }) => _FloraExclusionIndex.fromGraph(graph)
      .isClear(x, z, roadMargin: roadMargin, footprintMargin: footprintMargin);

  Map<int, FloraChunkSummary> computeChunkSummaries({
    required ShukubaGraph graph,
    required GroundHeightSampler sampleGroundY,
    Set<int>? onlyChunks,
  }) {
    final buckets = _generateChunkBuckets(
      graph: graph,
      sampleGroundY: sampleGroundY,
      onlyChunks: onlyChunks,
    );
    return {
      for (final entry in buckets.entries)
        if (!entry.value.isEmpty) entry.key: entry.value.toSummary(),
    };
  }

  Map<int, Node> buildFloraChunkNodes({
    required ShukubaGraph graph,
    required ShukubaMaterialResolver resolveMaterial,
    required GroundHeightSampler sampleGroundY,
    Set<int>? onlyChunks,
  }) {
    final buckets = _generateChunkBuckets(
      graph: graph,
      sampleGroundY: sampleGroundY,
      onlyChunks: onlyChunks,
    );

    final livingMat = resolveMaterial(ShukubaSurfaceRole.livingMeadow);
    final groundCutoutMat = resolveMaterial(ShukubaSurfaceRole.groundMeadow);
    final bambooCutoutMat = resolveMaterial(ShukubaSurfaceRole.bambooCanopy);
    final willowCutoutMat = resolveMaterial(ShukubaSurfaceRole.willowCanopy);
    final stoneMat = resolveMaterial(ShukubaSurfaceRole.ishigakiStone);

    final prototypes = <_FloraBatchKind, MeshGeometry>{
      _FloraBatchKind.sward: _buildMeadowSwardPrototypeGeometry(bladeCount: 12),
      _FloraBatchKind.overgrowthRosettes:
          _buildBroadleafRosettePrototypeGeometry(),
      _FloraBatchKind.nogiku: _buildWildflowerClumpGeometry(
        isSpiderLily: false,
      ),
      _FloraBatchKind.susuki: _buildSusukiClumpGeometry(),
      _FloraBatchKind.higanbana: _buildWildflowerClumpGeometry(
        isSpiderLily: true,
      ),
      _FloraBatchKind.reeds: _buildReedTuftPrototypeGeometry(),
      _FloraBatchKind.shrubs: _buildShrubMoundPrototypeGeometry(),
      _FloraBatchKind.wallDrapes: _buildWallDrapePrototypeGeometry(),
      _FloraBatchKind.fallenMomiji: _buildFallenLeafPatchGeometry(),
    };

    final result = <int, Node>{};
    for (final entry in buckets.entries) {
      final bucket = entry.value;
      final row = bucket.row;
      final col = bucket.col;
      final tileNode = Node(name: 'flora_tile_${row}_$col');

      void attachKind(
        _FloraBatchKind kind,
        String prefix,
        Material material, {
        bool castShadows = true,
      }) {
        final records = bucket.batches[kind]!;
        if (records.isEmpty) {
          return;
        }
        final batch = InstancedMesh(
          geometry: prototypes[kind]!,
          material: material,
          cullInstances: records.length >= 32,
        );
        for (var i = 0; i < records.length; i++) {
          final rec = records[i];
          batch.addInstance(rec.transform, color: rec.color);
        }
        final node = Node(name: '${prefix}_${row}_$col')
          ..addComponent(InstancedMeshComponent(batch));
        if (!castShadows) {
          node.shadowCastingMode = ShadowCastingMode.off;
        }
        tileNode.add(node);
      }

      attachKind(
        _FloraBatchKind.sward,
        'flora_sward',
        livingMat,
        castShadows: false,
      );
      attachKind(
        _FloraBatchKind.overgrowthRosettes,
        'flora_overgrowth',
        bambooCutoutMat,
        castShadows: false,
      );
      attachKind(
        _FloraBatchKind.nogiku,
        'flora_nogiku',
        livingMat,
        castShadows: false,
      );
      attachKind(_FloraBatchKind.susuki, 'flora_susuki', livingMat);
      attachKind(
        _FloraBatchKind.higanbana,
        'flora_higanbana',
        livingMat,
        castShadows: false,
      );
      attachKind(_FloraBatchKind.reeds, 'flora_reeds', groundCutoutMat);
      attachKind(_FloraBatchKind.shrubs, 'flora_shrubs', bambooCutoutMat);
      attachKind(
        _FloraBatchKind.wallDrapes,
        'flora_drapes',
        willowCutoutMat,
        castShadows: false,
      );
      attachKind(
        _FloraBatchKind.fallenMomiji,
        'flora_momiji',
        groundCutoutMat,
        castShadows: false,
      );

      if (bucket.cobbles.isNotEmpty) {
        final cobbleBuilder = GeometryBuilder();
        for (var i = 0; i < bucket.cobbles.length; i++) {
          final c = bucket.cobbles[i];
          EdoKitBuilder.addRockBoulder(
            cobbleBuilder,
            c.center,
            c.radii,
            yaw: c.yaw,
            seed: c.seed,
          );
        }
        tileNode.add(
          Node(
            name: 'flora_cobbles_${row}_$col',
            mesh: Mesh(cobbleBuilder.build(), stoneMat),
          ),
        );
      }

      result[entry.key] = markSubtreeShadowStatic(tileNode);
    }

    return result;
  }

  Node buildFloraScatterNode({
    required ShukubaGraph graph,
    required ShukubaMaterialResolver resolveMaterial,
    required GroundHeightSampler sampleGroundY,
  }) {
    final root = Node(name: 'flora_scatter_root');
    final chunkNodes = buildFloraChunkNodes(
      graph: graph,
      resolveMaterial: resolveMaterial,
      sampleGroundY: sampleGroundY,
    );
    for (var chunkIdx = 0; chunkIdx < TerrainConfig.chunkCount; chunkIdx++) {
      final tileNode = chunkNodes[chunkIdx];
      if (tileNode != null && tileNode.children.isNotEmpty) {
        root.add(tileNode);
      }
    }
    return markSubtreeShadowStatic(root);
  }

  Map<int, _ChunkFloraBucket> _generateChunkBuckets({
    required ShukubaGraph graph,
    required GroundHeightSampler sampleGroundY,
    Set<int>? onlyChunks,
  }) {
    final buckets = <int, _ChunkFloraBucket>{
      for (var cz = 0; cz < TerrainConfig.gridDimension; cz++)
        for (var cx = 0; cx < TerrainConfig.gridDimension; cx++)
          if (onlyChunks == null ||
              onlyChunks.contains(cz * TerrainConfig.gridDimension + cx))
            cz * TerrainConfig.gridDimension + cx: _ChunkFloraBucket(cz, cx),
    };
    if (buckets.isEmpty) {
      return buckets;
    }

    final index = _FloraExclusionIndex.fromGraph(graph);
    final xform = Matrix4.identity();

    bool addAlignedInstance(
      _FloraBatchKind kind, {
      required double x,
      required double z,
      required double yaw,
      required double sx,
      required double sy,
      required double sz,
      required Vector4 color,
      double yLift = 0,
      double slopeFollow = 0.38,
    }) {
      final chunkIdx = chunkIndexFor(x, z);
      final bucket = buckets[chunkIdx];
      if (bucket == null) {
        return false;
      }
      final gy = sampleGroundY(x, z);
      final hx =
          (sampleGroundY(x + 0.25, z) - sampleGroundY(x - 0.25, z)) / 0.5;
      final hz =
          (sampleGroundY(x, z + 0.25) - sampleGroundY(x, z - 0.25)) / 0.5;
      if (hx.abs() > 1.35 || hz.abs() > 1.35) {
        return false;
      }
      final up = Vector3(-hx * slopeFollow, 1, -hz * slopeFollow).normalized();
      final rawFwd = Vector3(math.sin(yaw), 0, math.cos(yaw));
      final right = up.cross(rawFwd).normalized();
      final fwd = right.cross(up).normalized();
      final yPos = gy + yLift;

      xform.setValues(
        right.x * sx,
        right.y * sx,
        right.z * sx,
        0,
        up.x * sy,
        up.y * sy,
        up.z * sy,
        0,
        fwd.x * sz,
        fwd.y * sz,
        fwd.z * sz,
        0,
        x,
        yPos,
        z,
        1,
      );
      bucket.addInstance(
        kind,
        transform: xform,
        color: color,
        x: x,
        y: yPos,
        z: z,
        scaleXZ: math.max(sx, sz),
        scaleY: sy,
      );
      return true;
    }

    const span = 170.0;
    const swardCandidates = 32000;
    for (var i = 0; i < swardCandidates; i++) {
      final ux = ((i + 1) * 0.7548776662466927) % 1.0;
      final uz = ((i + 1) * 0.5698402909980532) % 1.0;
      final jx = (math.sin(i * 7.13 + 1.7) * 1973.3).abs() % 1.0 - 0.5;
      final jz = (math.sin(i * 11.41 + 3.2) * 2411.9).abs() % 1.0 - 0.5;
      final x = -85.0 + ux * span + jx * 0.65;
      final z = -85.0 + uz * span + jz * 0.65;
      if (!buckets.containsKey(chunkIndexFor(x, z))) {
        continue;
      }

      final h = (math.sin(i * 12.9898 + 4.1) * 43758.5453).abs() % 1.0;
      final habitat = index.sampleHabitatAffinity(x, z);
      final countryBoost = ((math.sqrt(x * x + z * z) - 14.0) / 13.0).clamp(
        0.0,
        1.0,
      );
      if (habitat < (0.34 - 0.14 * countryBoost) || h > habitat * 1.28) {
        continue;
      }
      if (!index.isClear(x, z)) {
        continue;
      }

      final radiusScale = (0.86 + 0.48 * h) * (1.0 + 0.26 * countryBoost);
      final heightScale =
          (0.36 + 0.48 * habitat) *
          (0.82 + 0.36 * h) *
          (1.0 + 0.24 * countryBoost);
      final tint = 0.88 + 0.22 * h;
      final dryStrawBias = (1.0 - habitat).clamp(0.0, 1.0);
      addAlignedInstance(
        _FloraBatchKind.sward,
        x: x,
        z: z,
        yaw: (i * 2.39996323) % (math.pi * 2),
        sx: radiusScale,
        sy: heightScale,
        sz: radiusScale,
        color: Vector4(
          tint * (0.90 + 0.16 * dryStrawBias),
          tint * (0.98 + 0.08 * habitat),
          tint * 0.84,
          1,
        ),
        yLift: -0.015,
      );
    }

    if (index.roadSegs.isNotEmpty) {
      const vergeCandidates = 5200;
      for (var i = 0; i < vergeCandidates; i++) {
        final seg = index.roadSegs[i % index.roadSegs.length];
        final t = ((i * 0.6180339887498949) + 0.13) % 1.0;
        final h = (math.sin(i * 15.73 + 0.9) * 28411.7).abs() % 1.0;
        final side = (i + (i ~/ index.roadSegs.length)).isEven ? 1.0 : -1.0;
        final vx = seg.bx - seg.ax;
        final vz = seg.bz - seg.az;
        final segLen = math.sqrt(vx * vx + vz * vz);
        if (segLen < 0.25) {
          continue;
        }
        final nx = -vz / segLen;
        final nz = vx / segLen;
        final uBand = (i * 0.38196601125) % 1.0;
        final outFromEdge = 0.22 + 1.92 * (uBand * uBand * 0.65 + uBand * 0.35);
        final offset = seg.clearance + outFromEdge;
        final x = seg.ax + vx * t + nx * side * offset;
        final z = seg.az + vz * t + nz * side * offset;
        if (!buckets.containsKey(chunkIndexFor(x, z))) {
          continue;
        }
        if (!index.isClear(
          x,
          z,
          roadMargin: 0.20,
          footprintMargin: 0.24,
          minRiverDist: 2.30,
        )) {
          continue;
        }
        final nearFactor = ((outFromEdge - 0.18) / 1.85).clamp(0.0, 1.0);
        if (i % 5 != 0) {
          final rosetteScale = (0.36 + 0.26 * h) * (0.76 + 0.36 * nearFactor);
          final rosetteHeight = (0.20 + 0.22 * h) * (0.68 + 0.48 * nearFactor);
          final richMoss = h < 0.45;
          final cloverColor = richMoss
              ? Vector4(0.56 + 0.18 * h, 0.92 + 0.18 * h, 0.44 + 0.10 * h, 1)
              : Vector4(0.74 + 0.22 * h, 1.02 + 0.12 * h, 0.52 + 0.10 * h, 1);
          addAlignedInstance(
            _FloraBatchKind.overgrowthRosettes,
            x: x,
            z: z,
            yaw: (i * 2.39996323 + 0.4) % (math.pi * 2),
            sx: rosetteScale,
            sy: rosetteHeight,
            sz: rosetteScale,
            color: cloverColor,
            yLift: 0.008,
            slopeFollow: 0.55,
          );
        } else {
          final tuftScale = 0.56 + 0.34 * nearFactor + 0.16 * h;
          final tuftHeight = 0.24 + 0.36 * nearFactor + 0.16 * h;
          addAlignedInstance(
            _FloraBatchKind.sward,
            x: x,
            z: z,
            yaw: (i * 2.39996323) % (math.pi * 2),
            sx: tuftScale,
            sy: tuftHeight,
            sz: tuftScale,
            color: Vector4(0.78 + 0.14 * h, 1.04 + 0.10 * h, 0.72, 1),
            yLift: -0.012,
          );
        }
      }
    }

    const rosetteGladeCandidates = 8600;
    for (var i = 0; i < rosetteGladeCandidates; i++) {
      final ux = ((i + 19) * 0.7548776662466927) % 1.0;
      final uz = ((i + 19) * 0.5698402909980532) % 1.0;
      final x = -85.0 + ux * 170.0;
      final z = -85.0 + uz * 170.0;
      if (!buckets.containsKey(chunkIndexFor(x, z))) {
        continue;
      }

      final habitat = index.sampleHabitatAffinity(x, z);
      final h = (math.sin(i * 21.37 + 1.4) * 35917.3).abs() % 1.0;
      if (habitat < 0.38 || h > habitat * 1.12) {
        continue;
      }
      if (!index.isClear(
        x,
        z,
        roadMargin: 0.28,
        footprintMargin: 0.26,
        minRiverDist: 2.32,
      )) {
        continue;
      }

      final rad = (0.44 + 0.34 * h) * (0.85 + 0.28 * habitat);
      final height = (0.22 + 0.24 * h) * (0.80 + 0.35 * habitat);
      final autumnFern = h > 0.84;
      final color = autumnFern
          ? Vector4(1.22, 0.86 + 0.20 * h, 0.46, 1)
          : Vector4(
              0.62 + 0.24 * h,
              0.94 + 0.18 * habitat,
              0.48 + 0.12 * (1 - h),
              1,
            );
      addAlignedInstance(
        _FloraBatchKind.overgrowthRosettes,
        x: x,
        z: z,
        yaw: (i * 2.39996323 + 1.1) % (math.pi * 2),
        sx: rad,
        sy: height,
        sz: rad,
        color: color,
        yLift: 0.010,
        slopeFollow: 0.50,
      );
    }

    const nogikuCandidates = 3400;
    for (var i = 0; i < nogikuCandidates; i++) {
      final ux = ((i + 37) * 0.7548776662466927) % 1.0;
      final uz = ((i + 37) * 0.5698402909980532) % 1.0;
      final x = -84.0 + ux * 168.0;
      final z = -84.0 + uz * 168.0;
      if (!buckets.containsKey(chunkIndexFor(x, z))) {
        continue;
      }

      final habitat = index.sampleHabitatAffinity(x, z);
      final h = (math.sin(i * 19.17 + 2.3) * 31741.7).abs() % 1.0;
      if (habitat < 0.46 || h > habitat * 0.98) {
        continue;
      }
      if (!index.isClear(x, z, roadMargin: 0.50, footprintMargin: 0.42)) {
        continue;
      }

      final scaleXZ = 0.78 + 0.36 * h;
      final scaleY = 0.30 + 0.22 * habitat * (0.82 + 0.32 * h);
      final warmCream = 0.88 + 0.12 * h;
      addAlignedInstance(
        _FloraBatchKind.nogiku,
        x: x,
        z: z,
        yaw: (i * 2.39996323 + 0.7) % (math.pi * 2),
        sx: scaleXZ,
        sy: scaleY,
        sz: scaleXZ,
        color: Vector4(warmCream, 0.95, 0.88 + 0.10 * (1 - h), 1),
        yLift: -0.01,
      );
    }

    const susukiCandidates = 3200;
    for (var i = 0; i < susukiCandidates; i++) {
      final ux = ((i + 91) * 0.7548776662466927) % 1.0;
      final uz = ((i + 91) * 0.5698402909980532) % 1.0;
      final x = -84.5 + ux * 169.0;
      final z = -84.5 + uz * 169.0;
      if (!buckets.containsKey(chunkIndexFor(x, z))) {
        continue;
      }

      final rivDist = (x - TerrainConfig.riverCenterX(z)).abs();
      final bankRibbon = math.exp(-math.pow((rivDist - 3.9) / 1.9, 2));
      final habitat = index.sampleHabitatAffinity(x, z);
      final outerBluff = math.sqrt(x * x + z * z) > 18.0 ? habitat * 0.86 : 0.0;
      final h = (math.sin(i * 31.7 + 0.9) * 18913.3).abs() % 1.0;
      final affinity = math.max(bankRibbon, outerBluff);
      if (affinity < 0.42 || h > affinity * 0.98) {
        continue;
      }
      if (!index.isClear(x, z, roadMargin: 0.68, footprintMargin: 0.60)) {
        continue;
      }

      final scaleXZ = 0.82 + 0.36 * h;
      final scaleY = 0.68 + 0.38 * (0.55 + 0.45 * h);
      addAlignedInstance(
        _FloraBatchKind.susuki,
        x: x,
        z: z,
        yaw: (i * 2.39996323 + 1.4) % (math.pi * 2),
        sx: scaleXZ,
        sy: scaleY,
        sz: scaleXZ,
        color: Vector4(1, 0.94 + 0.08 * h, 0.80 + 0.12 * h, 1),
        yLift: -0.02,
        slopeFollow: 0.24,
      );
    }

    const higanbanaCandidates = 1350;
    for (var i = 0; i < higanbanaCandidates; i++) {
      final ux = ((i + 151) * 0.7548776662466927) % 1.0;
      final uz = ((i + 151) * 0.5698402909980532) % 1.0;
      final x = -83.0 + ux * 166.0;
      final z = -83.0 + uz * 166.0;
      if (!buckets.containsKey(chunkIndexFor(x, z))) {
        continue;
      }

      final rivDist = (x - TerrainConfig.riverCenterX(z)).abs();
      final wallDist = index.minWallOrTerraceDistance(x, z);
      final nearBank = rivDist >= 2.55 && rivDist <= 4.8;
      final nearStone = wallDist >= 0.86 && wallDist <= 2.25;
      final nearTanada = TerrainBuilder.sampleTanadaMossAffinity(x, z) > 0.40;
      if (!nearBank && !nearStone && !nearTanada) {
        continue;
      }
      final h = (math.sin(i * 23.1 + 5.1) * 15731.9).abs() % 1.0;
      final colony =
          0.5 + 0.5 * math.sin(x * 0.39 + z * 0.43 + 0.8) * math.cos(z * 0.29);
      if (colony * 0.76 + h * 0.24 < 0.65) {
        continue;
      }
      if (!index.isClear(x, z, roadMargin: 0.54, footprintMargin: 0.48)) {
        continue;
      }

      addAlignedInstance(
        _FloraBatchKind.higanbana,
        x: x,
        z: z,
        yaw: h * math.pi * 2,
        sx: 0.74 + 0.26 * h,
        sy: 0.34 + 0.16 * h,
        sz: 0.74 + 0.26 * h,
        color: Vector4(1.02, 0.86 + 0.12 * h, 0.82, 1),
        yLift: -0.01,
        slopeFollow: 0.26,
      );
    }

    const reedCandidates = 1480;
    final placedReeds = <Vector2>[];
    for (var i = 0; i < reedCandidates; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final u = ((i + 1) * 0.6180339887498949) % 1.0;
      final z = -84.5 + (i / reedCandidates) * 169.0 + (u - 0.5) * 0.64;
      final standMask =
          0.5 +
          0.32 * math.sin(z * 0.31 + side * 1.4) +
          0.18 * math.cos(z * 0.57 - side * 0.8);
      if (standMask < 0.40) {
        continue;
      }
      final goldenMix = (i * 0.38196601125) % 1.0;
      final bankDist = 2.34 + 1.85 * goldenMix;
      final x = TerrainConfig.riverCenterX(z) + side * bankDist;
      if (!index.isClear(x, z, roadMargin: 0.44, minRiverDist: 2.28)) {
        continue;
      }
      var tooCloseReed = false;
      for (var rIdx = placedReeds.length - 1; rIdx >= 0; rIdx--) {
        final prev = placedReeds[rIdx];
        if ((z - prev.y).abs() > 1.2) {
          break;
        }
        final dx = x - prev.x;
        final dz = z - prev.y;
        if (dx * dx + dz * dz < 0.34) {
          tooCloseReed = true;
          break;
        }
      }
      if (tooCloseReed) {
        continue;
      }
      placedReeds.add(Vector2(x, z));
      if (!buckets.containsKey(chunkIndexFor(x, z))) {
        continue;
      }

      final hSeed = (math.sin(i * 7.73 + 1.9) * 917.3).abs() % 1.0;
      final r = 0.40 + 0.28 * (1 - goldenMix * 0.48) + 0.08 * hSeed;
      final g = 0.39 + 0.08 * hSeed;
      final b = 0.13 + 0.04 * hSeed;

      final width = 0.54 + 0.26 * hSeed;
      final height =
          0.66 + 0.44 * (1 - goldenMix * 0.40) * (0.75 + 0.38 * hSeed);
      addAlignedInstance(
        _FloraBatchKind.reeds,
        x: x,
        z: z,
        yaw: (i * 2.39996323) % (math.pi * 2),
        sx: width,
        sy: height,
        sz: width,
        color: Vector4(r, g, b, 1),
        yLift: -0.03,
        slopeFollow: 0.20,
      );
    }

    const shrubCandidates = 3800;
    for (var i = 0; i < shrubCandidates; i++) {
      final ux = ((i + 17) * 0.7548776662466927) % 1.0;
      final uz = ((i + 17) * 0.5698402909980532) % 1.0;
      final x = -84.0 + ux * 168.0;
      final z = -84.0 + uz * 168.0;
      if (!buckets.containsKey(chunkIndexFor(x, z))) {
        continue;
      }
      final habitat = index.sampleHabitatAffinity(x, z);
      final sHash = (math.sin(i * 17.3 + 2.7) * 613.9).abs() % 1.0;
      if (habitat < 0.44 || sHash > habitat * 0.98) {
        continue;
      }
      if (!index.isClear(x, z, roadMargin: 0.72, footprintMargin: 0.54)) {
        continue;
      }
      final russet = sHash > 0.72;
      final shColor = russet
          ? Vector4(1.95, 0.88 + 0.32 * sHash, 0.48, 1)
          : Vector4(0.74 + 0.24 * sHash, 0.94 + 0.18 * sHash, 0.64, 1);
      final rad = 0.52 + 0.36 * sHash;
      addAlignedInstance(
        _FloraBatchKind.shrubs,
        x: x,
        z: z,
        yaw: sHash * math.pi * 2,
        sx: rad,
        sy: 0.34 + 0.24 * sHash,
        sz: rad,
        color: shColor,
        yLift: 0.02,
      );
    }

    _populateTerraceWallDrapes(buckets, graph, index);

    final placedGroundLeaves = <Vector2>[];
    var mapleIndex = 0;
    for (final s in graph.structures.values) {
      if (s.kind != StructureKind.mapleCluster) {
        continue;
      }
      mapleIndex++;
      const patchCount = 34;
      for (var k = 0; k < patchCount; k++) {
        final frac = (k + 0.5) / patchCount;
        final ang = k * 2.39996323 + mapleIndex * 1.1;
        final downwindBias = 0.35 * math.max(0, math.cos(ang - 0.67)) * frac;
        final radius = 0.56 + (3.10 + downwindBias * 2.0) * math.sqrt(frac);
        final x = s.position.x + math.cos(ang) * radius;
        final z = s.position.z + math.sin(ang) * radius;
        if (((x.abs() - 66.0).abs() < 6.4 && z.abs() < 9.5) ||
            !index.isClear(x, z, roadMargin: 0.28, footprintMargin: 0.28)) {
          continue;
        }
        final patchSize = 0.36 + 0.20 * ((k * 0.61) % 1.0);
        final minSep = patchSize * 1.65 + 0.18;
        var overlapsLeaf = false;
        for (var pIdx = 0; pIdx < placedGroundLeaves.length; pIdx++) {
          final prev = placedGroundLeaves[pIdx];
          final dx = x - prev.x;
          final dz = z - prev.y;
          if (dx * dx + dz * dz < minSep * minSep) {
            overlapsLeaf = true;
            break;
          }
        }
        if (overlapsLeaf) {
          continue;
        }
        final gy = sampleGroundY(x, z);
        const probeR = 0.48;
        final yPx = sampleGroundY(x + probeR, z);
        final yMx = sampleGroundY(x - probeR, z);
        final yPz = sampleGroundY(x, z + probeR);
        final yMz = sampleGroundY(x, z - probeR);
        final gx = (yPx - yMx) / (2 * probeR);
        final gz = (yPz - yMz) / (2 * probeR);
        if (gx.abs() > 0.35 || gz.abs() > 0.35) {
          continue;
        }
        var nonPlanar = false;
        const diagR = 0.36;
        const offsets = <(double, double)>[
          (probeR, 0),
          (-probeR, 0),
          (0, probeR),
          (0, -probeR),
          (diagR, diagR),
          (diagR, -diagR),
          (-diagR, diagR),
          (-diagR, -diagR),
        ];
        for (final (dx, dz) in offsets) {
          final sampleY = sampleGroundY(x + dx, z + dz);
          final planeY = gy + gx * dx + gz * dz;
          if ((sampleY - planeY).abs() > 0.012) {
            nonPlanar = true;
            break;
          }
        }
        if (nonPlanar) {
          continue;
        }
        placedGroundLeaves.add(Vector2(x, z));
        if (!buckets.containsKey(chunkIndexFor(x, z))) {
          continue;
        }
        final warmGold = (k * 0.37 + mapleIndex * 0.29) % 1.0;
        final r = 0.68 + 0.26 * warmGold;
        final g = 0.07 + 0.30 * warmGold * warmGold;
        final b = 0.03 + 0.03 * warmGold;
        addAlignedInstance(
          _FloraBatchKind.fallenMomiji,
          x: x,
          z: z,
          yaw: ang * 1.7,
          sx: patchSize,
          sy: patchSize,
          sz: patchSize,
          color: Vector4(r, g, b, 1),
          yLift: 0.056,
          slopeFollow: 1,
        );
      }
    }

    const riverLeafCount = 72;
    for (var i = 0; i < riverLeafCount; i++) {
      final z = -80.0 + (i / riverLeafCount) * 160.0;
      if (z >= TerrainConfig.bridgeMinZ - 0.9 &&
          z <= TerrainConfig.bridgeMaxZ + 0.9) {
        continue;
      }
      final h = (math.sin(i * 14.3 + 0.8) * 4913.7).abs() % 1.0;
      final offset = (h - 0.5) * 3.0;
      final x = TerrainConfig.riverCenterX(z) + offset;
      final bucket = buckets[chunkIndexFor(x, z)];
      if (bucket == null) {
        continue;
      }
      final patchSize = 0.30 + 0.14 * h;
      final yaw = h * math.pi * 2;
      final cy = math.cos(yaw) * patchSize;
      final sy = math.sin(yaw) * patchSize;
      const yPos = TerrainConfig.waterSurfaceElevation + 0.036;
      xform.setValues(
        cy,
        0,
        -sy,
        0,
        0,
        patchSize,
        0,
        0,
        sy,
        0,
        cy,
        0,
        x,
        yPos,
        z,
        1,
      );
      final warm = (i * 0.43) % 1.0;
      bucket.addInstance(
        _FloraBatchKind.fallenMomiji,
        transform: xform,
        color: Vector4(0.76 + 0.20 * warm, 0.10 + 0.24 * warm, 0.035, 1),
        x: x,
        y: yPos,
        z: z,
        scaleXZ: patchSize,
        scaleY: patchSize,
      );
    }

    _populateRoadsideCobbles(
      buckets: buckets,
      graph: graph,
      index: index,
      sampleGroundY: sampleGroundY,
    );

    return buckets;
  }

  static void _populateTerraceWallDrapes(
    Map<int, _ChunkFloraBucket> buckets,
    ShukubaGraph graph,
    _FloraExclusionIndex index,
  ) {
    final xform = Matrix4.identity();
    var seedIdx = 0;

    for (final terrace in graph.terraces) {
      for (var i = 0; i < terrace.crestPoints.length - 1; i++) {
        final a = terrace.crestPoints[i];
        final b = terrace.crestPoints[i + 1];
        final drop = terrace.dropNormalBetween(a, b);
        final yaw = math.atan2(drop.x, drop.z);
        final cy = math.cos(yaw);
        final sy = math.sin(yaw);
        final segLen = (b - a).horizontalLength;
        final steps = math.max(1, (segLen / 2.85).floor());

        for (var k = 0; k < steps; k++) {
          seedIdx++;
          final h = (math.sin(seedIdx * 13.7 + 2.1) * 7919.3).abs() % 1.0;
          if (h < 0.54) {
            continue;
          }
          final t = (k + 0.25 + 0.5 * h) / steps;
          final crest = Vec3.lerp(a, b, t);
          if (index.isNearRoad(crest.x, crest.z, 1.45)) {
            continue;
          }
          final proudX = crest.x + drop.x * 0.36;
          final proudZ = crest.z + drop.z * 0.36;
          final bucket = buckets[chunkIndexFor(proudX, proudZ)];
          if (bucket == null) {
            continue;
          }
          final topY = terrace.topElevation + 0.08 - 0.22 * (1.0 - h);
          final width = 0.54 + 0.34 * h;
          final hang = 0.44 + 0.38 * ((seedIdx * 0.41) % 1.0);

          xform.setValues(
            cy * width,
            0,
            -sy * width,
            0,
            0,
            hang,
            0,
            0,
            sy * width,
            0,
            cy * width,
            0,
            proudX,
            topY,
            proudZ,
            1,
          );
          final shade = 0.62 + 0.24 * h;
          bucket.addInstance(
            _FloraBatchKind.wallDrapes,
            transform: xform,
            color: Vector4(shade * 0.62, shade * 0.78, shade * 0.46, 1),
            x: proudX,
            y: topY,
            z: proudZ,
            scaleXZ: width,
            scaleY: hang,
          );
        }
      }
    }
  }

  static void _populateRoadsideCobbles({
    required Map<int, _ChunkFloraBucket> buckets,
    required ShukubaGraph graph,
    required _FloraExclusionIndex index,
    required GroundHeightSampler sampleGroundY,
  }) {
    var seedIdx = 0;

    for (final road in graph.roads) {
      if (road.style == RoadStyle.gardenPath) {
        continue;
      }
      final halfW = road.widthMeters * 0.5;
      final pts = road.smoothCenterline(stepMeters: 2.2);
      for (var i = 0; i < pts.length - 1; i++) {
        final pA = pts[i];
        final pB = pts[i + 1];
        final seg = pB - pA;
        final len = seg.horizontalLength;
        if (len < 0.8) {
          continue;
        }
        seedIdx++;
        if (seedIdx % 3 != 0) {
          continue;
        }
        final tangent = seg.normalizedHorizontal();
        final normal = Vec3(-tangent.z, 0, tangent.x);
        final base = Vec3.lerp(pA, pB, 0.5);
        final side = seedIdx.isEven ? 1.0 : -1.0;
        final h = (math.sin(seedIdx * 19.7 + 1.3) * 541.3).abs() % 1.0;
        final offset = halfW + 0.84 + 0.32 * h;
        final px = base.x + normal.x * side * offset;
        final pz = base.z + normal.z * side * offset;

        final bucket = buckets[chunkIndexFor(px, pz)];
        if (bucket == null) {
          continue;
        }
        if ((px - TerrainConfig.riverCenterX(pz)).abs() < 7.4) {
          continue;
        }
        if (!index.isClear(px, pz, roadMargin: 0.65, footprintMargin: 0.90)) {
          continue;
        }

        final gy = sampleGroundY(px, pz);
        final slope =
            (sampleGroundY(px + 0.25, pz) - sampleGroundY(px - 0.25, pz))
                .abs() +
            (sampleGroundY(px, pz + 0.25) - sampleGroundY(px, pz - 0.25)).abs();
        if (slope > 0.16) {
          continue;
        }

        final rx = 0.16 + 0.10 * h;
        final ry = 0.085 + 0.038 * ((seedIdx * 0.37) % 1.0);
        final rz = 0.14 + 0.08 * ((seedIdx * 0.61) % 1.0);
        bucket.addCobble(
          _CobbleRecord(
            center: Vector3(px, gy + ry * 0.65, pz),
            radii: Vector3(rx, ry, rz),
            yaw: h * math.pi * 2,
            seed: seedIdx * 0.7,
          ),
        );
      }
    }
  }

  static void _addCurvedGrassBlade(
    GeometryBuilder builder, {
    required Vector3 rootOffset,
    required double yaw,
    required double height,
    required double baseHalfWidth,
    required double archOut,
    required Vector4 color,
  }) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final right = Vector3(cy, 0, sy);
    final fwd = Vector3(-sy, 0, cy);
    final n0 = Vector3(-sy * 0.28, 0.96, cy * 0.28).normalized();
    final n1 = Vector3(-sy * 0.44, 0.90, cy * 0.44).normalized();
    final n2 = Vector3(-sy * 0.58, 0.81, cy * 0.58).normalized();

    builder.color(color);

    int emit(Vector3 pos, Vector3 n, double u, double v) {
      builder
        ..normal(n)
        ..texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    final midPos =
        rootOffset + fwd * (archOut * 0.46) + Vector3(0, height * 0.56, 0);
    final tipPos = rootOffset + fwd * archOut + Vector3(0, height, 0);
    final midHalfW = baseHalfWidth * 0.68;

    final v0 = emit(rootOffset - right * baseHalfWidth, n0, 0, 0);
    final v1 = emit(rootOffset + right * baseHalfWidth, n0, 1, 0);
    final v2 = emit(midPos - right * midHalfW, n1, 0, 0.56);
    final v3 = emit(midPos + right * midHalfW, n1, 1, 0.56);
    final v4 = emit(tipPos, n2, 0.5, 1);

    builder
      ..addTriangle(v0, v1, v3)
      ..addTriangle(v0, v3, v2)
      ..addTriangle(v2, v3, v4);
  }

  static MeshGeometry _buildBroadleafRosettePrototypeGeometry() {
    final builder = GeometryBuilder();

    int emit(Vector3 pos, Vector3 n, double u, double v, Vector4 c) {
      builder
        ..color(c)
        ..normal(n)
        ..texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    const outerFronds = 6;
    for (var i = 0; i < outerFronds; i++) {
      final yaw = (i / outerFronds) * math.pi * 2 + 0.19;
      final cy = math.cos(yaw);
      final sy = math.sin(yaw);
      final fwd = Vector3(cy, 0, sy);
      final right = Vector3(-sy, 0, cy);
      final reach = i.isEven ? 0.52 : 0.44;
      final crest = i.isEven ? 0.24 : 0.18;
      final tipY = i.isEven ? 0.08 : 0.05;
      final shade = 0.86 + 0.18 * ((i * 0.37) % 1.0);
      final frondColor = Vector4(shade * 0.94, shade * 1.04, shade * 0.90, 1);
      final normal = Vector3(cy * 0.26, 0.96, sy * 0.26).normalized();

      final stem = fwd * 0.04 + Vector3(0, 0.02, 0);
      final mid = fwd * (reach * 0.56) + Vector3(0, crest, 0);
      final tip = fwd * reach + Vector3(0, tipY, 0);

      final v0 = emit(stem - right * 0.16, normal, 0, 0, frondColor);
      final v1 = emit(stem + right * 0.16, normal, 1, 0, frondColor);
      final v2 = emit(mid - right * 0.26, normal, 0, 0.54, frondColor);
      final v3 = emit(mid + right * 0.26, normal, 1, 0.54, frondColor);
      final v4 = emit(tip - right * 0.20, normal, 0, 1, frondColor);
      final v5 = emit(tip + right * 0.20, normal, 1, 1, frondColor);

      builder
        ..addTriangle(v0, v1, v3)
        ..addTriangle(v0, v3, v2)
        ..addTriangle(v2, v3, v5)
        ..addTriangle(v2, v5, v4);
    }

    const innerClover = 3;
    for (var i = 0; i < innerClover; i++) {
      final yaw = (i / innerClover) * math.pi * 2 + 0.72;
      final cy = math.cos(yaw);
      final sy = math.sin(yaw);
      final fwd = Vector3(cy, 0, sy);
      final right = Vector3(-sy, 0, cy);
      final normal = Vector3(cy * 0.18, 0.98, sy * 0.18).normalized();
      final crownColor = Vector4(1.04, 1.10, 0.96, 1);

      final stem = Vector3(0, 0.05, 0);
      final mid = fwd * 0.18 + Vector3(0, 0.34, 0);
      final tip = fwd * 0.32 + Vector3(0, 0.22, 0);

      final v0 = emit(stem - right * 0.14, normal, 0, 0, crownColor);
      final v1 = emit(stem + right * 0.14, normal, 1, 0, crownColor);
      final v2 = emit(mid - right * 0.22, normal, 0, 0.52, crownColor);
      final v3 = emit(mid + right * 0.22, normal, 1, 0.52, crownColor);
      final v4 = emit(tip - right * 0.16, normal, 0, 1, crownColor);
      final v5 = emit(tip + right * 0.16, normal, 1, 1, crownColor);

      builder
        ..addTriangle(v0, v1, v3)
        ..addTriangle(v0, v3, v2)
        ..addTriangle(v2, v3, v5)
        ..addTriangle(v2, v5, v4);
    }

    return builder.build(retainCpuData: false);
  }

  static MeshGeometry _buildMeadowSwardPrototypeGeometry({
    required int bladeCount,
  }) {
    final builder = GeometryBuilder();
    for (var i = 0; i < bladeCount; i++) {
      final frac = (i + 0.5) / bladeCount;
      final ang = i * 2.39996323;
      final r = 0.26 * math.sqrt(frac);
      final hHash = (math.sin(i * 17.13 + 0.9) * 937.1).abs() % 1.0;
      final isTallStalk = i % 4 == 0;
      final bladeYaw = ang + (hHash - 0.5) * 0.95;
      final height = isTallStalk
          ? (0.60 + 0.18 * hHash)
          : (0.38 + 0.24 * hHash);
      final arch = 0.12 + 0.16 * (1 - frac * 0.30) * (0.65 + 0.55 * hHash);
      final shade = 0.86 + 0.28 * hHash;
      _addCurvedGrassBlade(
        builder,
        rootOffset: Vector3(math.cos(ang) * r, 0, math.sin(ang) * r),
        yaw: bladeYaw,
        height: height,
        baseHalfWidth: isTallStalk ? 0.021 : (0.023 + 0.006 * (1 - hHash)),
        archOut: arch,
        color: Vector4(shade * 0.97, shade * 1.02, shade * 0.88, 0.10),
      );
    }
    return builder.build(retainCpuData: false);
  }

  static MeshGeometry _buildWildflowerClumpGeometry({
    required bool isSpiderLily,
  }) {
    final builder = GeometryBuilder();
    final stemCount = isSpiderLily ? 6 : 9;
    for (var i = 0; i < stemCount; i++) {
      final frac = (i + 0.5) / stemCount;
      final ang = i * 2.39996323 + 0.4;
      final r = 0.24 * math.sqrt(frac);
      final h = (math.sin(i * 11.7 + 2.4) * 513.7).abs() % 1.0;
      _addCurvedGrassBlade(
        builder,
        rootOffset: Vector3(math.cos(ang) * r, 0, math.sin(ang) * r),
        yaw: ang + (h - 0.5) * 0.7,
        height: 0.44 + 0.30 * h,
        baseHalfWidth: 0.020,
        archOut: 0.10 + 0.12 * h,
        color: Vector4(0.88 + 0.18 * h, 0.98, 0.84, 0.10),
      );
    }

    final flowerCount = isSpiderLily ? 4 : 5;
    final subKindAlpha = isSpiderLily ? 0.90 : 0.68;
    final baseHalf = isSpiderLily ? 0.140 : 0.095;
    final upN = Vector3(0, 1, 0);

    int emit(Vector3 p, double u, double v) {
      builder
        ..normal(upN)
        ..texCoord(Vector2(u, v));
      return builder.addVertex(p);
    }

    for (var f = 0; f < flowerCount; f++) {
      final ang = f * (math.pi * 2 / flowerCount) + 0.35;
      final r = 0.05 + 0.18 * ((f * 0.618) % 1.0);
      final hSeed = ((f + 1) * 0.37) % 1.0;
      final cardHalf = baseHalf * (0.80 + 0.34 * hSeed);
      final topY = 0.56 + 0.42 * hSeed;
      final cx = math.cos(ang) * (r + 0.07);
      final cz = math.sin(ang) * (r + 0.07);
      final center = Vector3(cx, topY, cz);

      builder.color(Vector4(0.88 + 0.12 * hSeed, 0.94, 0.90, subKindAlpha));

      for (var plane = 0; plane < 2; plane++) {
        final tiltYaw = ang + 0.45 + plane * 1.48;
        final cy = math.cos(tiltYaw);
        final sy = math.sin(tiltYaw);
        final right = Vector3(cy, 0, sy) * cardHalf;
        final tiltedUp = Vector3(-sy * 0.72, 0.69, cy * 0.72) * cardHalf;

        final v0 = emit(center - right - tiltedUp, 0, 0);
        final v1 = emit(center + right - tiltedUp, 1, 0);
        final v2 = emit(center + right + tiltedUp, 1, 1);
        final v3 = emit(center - right + tiltedUp, 0, 1);
        builder
          ..addTriangle(v0, v1, v2)
          ..addTriangle(v0, v2, v3);
      }
    }

    return builder.build(retainCpuData: false);
  }

  static MeshGeometry _buildSusukiClumpGeometry() {
    final builder = GeometryBuilder();
    const bladeCount = 9;
    for (var i = 0; i < bladeCount; i++) {
      final frac = (i + 0.5) / bladeCount;
      final ang = i * 2.39996323;
      final r = 0.22 * math.sqrt(frac);
      final h = (math.sin(i * 15.9 + 1.2) * 733.1).abs() % 1.0;
      _addCurvedGrassBlade(
        builder,
        rootOffset: Vector3(math.cos(ang) * r, 0, math.sin(ang) * r),
        yaw: ang,
        height: 0.56 + 0.26 * h,
        baseHalfWidth: 0.024,
        archOut: 0.20 + 0.16 * h,
        color: Vector4(0.98, 0.94, 0.78, 0.10),
      );
    }

    const plumeCount = 4;
    final upN = Vector3(0, 1, 0);
    for (var p = 0; p < plumeCount; p++) {
      final ang = p * (math.pi * 2 / plumeCount) + 0.28;
      final cy = math.cos(ang);
      final sy = math.sin(ang);
      final right = Vector3(-sy, 0, cy) * 0.145;
      final outDir = Vector3(cy, 0, sy);
      final base = outDir * 0.13 + Vector3(0, 0.54 + 0.06 * p, 0);
      final tip = outDir * 0.38 + Vector3(0, 1.02 + 0.07 * p, 0);

      builder.color(Vector4(1.02, 0.95, 0.84, 0.40));

      int emit(Vector3 pos, double u, double v) {
        builder
          ..normal(upN)
          ..texCoord(Vector2(u, v));
        return builder.addVertex(pos);
      }

      final v0 = emit(base - right, 0, 0);
      final v1 = emit(base + right, 1, 0);
      final v2 = emit(tip + right * 0.85, 1, 1);
      final v3 = emit(tip - right * 0.85, 0, 1);
      builder
        ..addTriangle(v0, v1, v2)
        ..addTriangle(v0, v2, v3);
    }

    return builder.build(retainCpuData: false);
  }

  static MeshGeometry _buildReedTuftPrototypeGeometry() {
    final builder = GeometryBuilder()..color(Vector4(1, 1, 1, 1));

    int emit(Vector3 pos, double u, double v) {
      builder.texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    const planes = 3;
    for (var i = 0; i < planes; i++) {
      final yaw = (i / planes) * math.pi + 0.22;
      final cy = math.cos(yaw);
      final sy = math.sin(yaw);
      final right = Vector3(cy, 0, sy);
      final splay = Vector3(-sy, 0, cy);
      final lean = (i.isEven ? 1.0 : -1.0) * 0.20;

      final bL = -right * 0.46 + splay * (lean * 0.12);
      final bR = right * 0.46 + splay * (lean * 0.12);
      final mL = -right * 0.52 + splay * (lean * 0.52) + Vector3(0, 0.52, 0);
      final mR = right * 0.52 + splay * (lean * 0.52) + Vector3(0, 0.52, 0);
      final tL = -right * 0.50 + splay * lean + Vector3(0, 1, 0);
      final tR = right * 0.50 + splay * lean + Vector3(0, 1, 0);

      final v0 = emit(bL, 0, 0);
      final v1 = emit(bR, 1, 0);
      final v2 = emit(mL, 0, 0.52);
      final v3 = emit(mR, 1, 0.52);
      final v4 = emit(tL, 0, 1);
      final v5 = emit(tR, 1, 1);

      builder
        ..addTriangle(v0, v1, v3)
        ..addTriangle(v0, v3, v2)
        ..addTriangle(v2, v3, v5)
        ..addTriangle(v2, v5, v4);
    }

    return builder.build(retainCpuData: false);
  }

  static MeshGeometry _buildWallDrapePrototypeGeometry() {
    final builder = GeometryBuilder()..color(Vector4(1, 1, 1, 1));

    int emit(Vector3 pos, double u, double v) {
      builder
        ..normal(Vector3(0, 0.35, 0.94).normalized())
        ..texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    final v0 = emit(Vector3(-0.5, 0, 0), 0, 1);
    final v1 = emit(Vector3(0.5, 0, 0), 1, 1);
    final v2 = emit(Vector3(-0.52, -0.5, 0.05), 0, 0.5);
    final v3 = emit(Vector3(0.52, -0.5, 0.05), 1, 0.5);
    final v4 = emit(Vector3(-0.46, -1, 0.08), 0, 0);
    final v5 = emit(Vector3(0.46, -1, 0.08), 1, 0);

    builder
      ..addTriangle(v0, v2, v1)
      ..addTriangle(v1, v2, v3)
      ..addTriangle(v2, v4, v3)
      ..addTriangle(v3, v4, v5);

    return builder.build(retainCpuData: false);
  }

  static MeshGeometry _buildShrubMoundPrototypeGeometry() {
    final builder = GeometryBuilder()..color(Vector4(1, 1, 1, 1));

    int emit(Vector3 pos, double u, double v) {
      builder.texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    const fronds = 7;
    for (var i = 0; i < fronds; i++) {
      final yaw = (i / fronds) * math.pi * 2 + 0.35;
      final cy = math.cos(yaw);
      final sy = math.sin(yaw);
      final fwd = Vector3(cy, 0, sy);
      final right = Vector3(-sy, 0, cy);
      final lift = i.isEven ? 0.96 : 0.70;

      final stem = fwd * 0.10;
      final mid = fwd * 0.56 + Vector3(0, lift * 0.78, 0);
      final tip = fwd * 1.0 + Vector3(0, lift * 0.34, 0);

      final v0 = emit(stem - right * 0.42, 0, 0);
      final v1 = emit(stem + right * 0.42, 1, 0);
      final v2 = emit(mid - right * 0.54, 0, 0.52);
      final v3 = emit(mid + right * 0.54, 1, 0.52);
      final v4 = emit(tip - right * 0.46, 0, 1);
      final v5 = emit(tip + right * 0.46, 1, 1);

      builder
        ..addTriangle(v0, v1, v3)
        ..addTriangle(v0, v3, v2)
        ..addTriangle(v2, v3, v5)
        ..addTriangle(v2, v5, v4);
    }

    return builder.build(retainCpuData: false);
  }

  static MeshGeometry _buildFallenLeafPatchGeometry() {
    final builder = GeometryBuilder()..color(Vector4(1, 1, 1, 1));

    int emit(Vector3 pos, double u, double v) {
      builder.texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    final v0 = emit(Vector3(-0.5, 0, -0.5), 0, 2);
    final v1 = emit(Vector3(0, 0.068, -0.5), 0.5, 2);
    final v2 = emit(Vector3(0.5, 0.012, -0.5), 1, 2);
    final v3 = emit(Vector3(-0.5, 0.016, 0.5), 0, 3);
    final v4 = emit(Vector3(0, 0.072, 0.5), 0.5, 3);
    final v5 = emit(Vector3(0.5, 0.006, 0.5), 1, 3);
    builder
      ..addTriangle(v0, v4, v1)
      ..addTriangle(v0, v3, v4)
      ..addTriangle(v1, v5, v2)
      ..addTriangle(v1, v4, v5);

    return builder.build(retainCpuData: false);
  }
}
