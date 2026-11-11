import 'dart:math' as math;

import 'package:flutter_scene/scene.dart'
    show
        GeometryBuilder,
        InstancedMesh,
        InstancedMeshComponent,
        MeshGeometry,
        Node,
        ShadowCastingMode;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        GroundHeightSampler,
        ShukubaGraph,
        ShukubaMaterialResolver,
        ShukubaSurfaceRole,
        StructureKind;
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart'
    show TerrainBuilder, TerrainConfig;
import 'package:vector_math/vector_math.dart'
    show Matrix4, Vector2, Vector3, Vector4;

class FloraScatterBuilder {
  const new();

  static bool isClearForGroundFlora(
    double x,
    double z,
    ShukubaGraph graph, {
    double roadMargin = 0.42,
    double footprintMargin = 0.36,
  }) {
    if (x < TerrainConfig.minX + 1.5 ||
        x > TerrainConfig.maxX - 1.5 ||
        z < TerrainConfig.minZ + 1.5 ||
        z > TerrainConfig.maxZ - 1.5) {
      return false;
    }

    final rivDist = (x - TerrainConfig.riverCenterX(z)).abs();
    if (rivDist < 2.38) {
      return false;
    }

    if (x >= -6.0 && x <= 6.0 && z >= -2.45 && z <= 2.45) {
      return false;
    }

    for (final road in graph.roads) {
      final minClear = road.widthMeters * 0.5 + roadMargin;
      for (var i = 0; i < road.controlPoints.length - 1; i++) {
        final d = TerrainBuilder.horizontalDistanceToSegment(
          x,
          z,
          road.controlPoints[i],
          road.controlPoints[i + 1],
        );
        if (d < minClear) {
          return false;
        }
      }
    }

    for (final wall in graph.walls) {
      final minClear = wall.thicknessMeters * 0.5 + 0.44;
      for (var i = 0; i < wall.controlPoints.length - 1; i++) {
        final d = TerrainBuilder.horizontalDistanceToSegment(
          x,
          z,
          wall.controlPoints[i],
          wall.controlPoints[i + 1],
        );
        if (d < minClear) {
          return false;
        }
      }
    }

    for (final terrace in graph.terraces) {
      for (var i = 0; i < terrace.crestPoints.length - 1; i++) {
        final d = TerrainBuilder.horizontalDistanceToSegment(
          x,
          z,
          terrace.crestPoints[i],
          terrace.crestPoints[i + 1],
        );
        if (d < 0.78) {
          return false;
        }
      }
    }

    for (final s in graph.structures.values) {
      if (s.kind == StructureKind.mapleCluster ||
          s.kind == StructureKind.bambooGrove) {
        final dx = x - s.position.x;
        final dz = z - s.position.z;
        if (dx * dx + dz * dz < 0.16) {
          return false;
        }
        continue;
      }
      if (TerrainBuilder.signedFootprintMargin(x, z, s) < footprintMargin) {
        return false;
      }
    }

    return true;
  }

  Node buildFloraScatterNode({
    required ShukubaGraph graph,
    required ShukubaMaterialResolver resolveMaterial,
    required GroundHeightSampler sampleGroundY,
  }) {
    final root = Node(name: 'flora_scatter_root');
    final meadowMat = resolveMaterial(ShukubaSurfaceRole.groundMeadow);

    final tuftInstanced = InstancedMesh(
      geometry: _buildTuftPrototypeGeometry(),
      material: meadowMat,
    );
    final fallenLeafInstanced = InstancedMesh(
      geometry: _buildFallenLeafPatchGeometry(),
      material: meadowMat,
    );

    final xform = Matrix4.identity();

    void addSurfaceAlignedInstance(
      InstancedMesh target, {
      required double x,
      required double z,
      required double yaw,
      required double sx,
      required double sy,
      required double sz,
      required Vector4 color,
      double yLift = 0,
      double slopeFollow = 0.35,
    }) {
      final gy = sampleGroundY(x, z);
      final hx =
          (sampleGroundY(x + 0.25, z) - sampleGroundY(x - 0.25, z)) / 0.5;
      final hz =
          (sampleGroundY(x, z + 0.25) - sampleGroundY(x, z - 0.25)) / 0.5;
      if (hx.abs() > 1.35 || hz.abs() > 1.35) {
        return;
      }
      final up = Vector3(-hx * slopeFollow, 1, -hz * slopeFollow).normalized();
      final rawFwd = Vector3(math.sin(yaw), 0, math.cos(yaw));
      final right = up.cross(rawFwd).normalized();
      final fwd = right.cross(up).normalized();

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
        gy + yLift,
        z,
        1,
      );
      target.addInstance(xform, color: color);
    }

    const span = 71.0;
    const meadowCandidates = 2100;
    for (var i = 0; i < meadowCandidates; i++) {
      final ux = ((i + 1) * 0.7548776662466927) % 1.0;
      final uz = ((i + 1) * 0.5698402909980532) % 1.0;
      final x = -35.5 + ux * span;
      final z = -35.5 + uz * span;

      final clumpField =
          0.5 +
          0.5 *
              math.sin(x * 0.26 + z * 0.19 + 0.7) *
              math.cos(z * 0.31 - x * 0.14);
      final microHash = (math.sin(i * 12.9898 + 4.1) * 43758.5453).abs() % 1.0;
      if (clumpField * 0.72 + microHash * 0.28 < 0.40) {
        continue;
      }
      if (!isClearForGroundFlora(x, z, graph)) {
        continue;
      }

      final strawBlend = (0.5 + 0.5 * math.cos(x * 0.14 - z * 0.16)).clamp(
        0.0,
        1.0,
      );
      final tone = 0.86 + 0.28 * microHash;
      final r = (0.19 + 0.24 * strawBlend) * tone;
      final g = (0.36 + 0.05 * strawBlend) * tone;
      final b = (0.10 + 0.05 * strawBlend) * tone;

      final width = 0.46 + 0.30 * microHash;
      final height = 0.26 + 0.28 * clumpField * (0.75 + 0.5 * microHash);
      addSurfaceAlignedInstance(
        tuftInstanced,
        x: x,
        z: z,
        yaw: microHash * math.pi * 2,
        sx: width,
        sy: height,
        sz: width,
        color: Vector4(r, g, b, 1),
        yLift: -0.02,
      );
    }

    const reedCandidates = 720;
    for (var i = 0; i < reedCandidates; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final u = ((i + 1) * 0.6180339887498949) % 1.0;
      final z = -35.5 + (i / reedCandidates) * 71.0 + (u - 0.5) * 0.65;
      final standMask = 0.5 + 0.5 * math.sin(z * 0.34 + side * 1.4);
      if (standMask < 0.24 && (i % 3 != 0)) {
        continue;
      }
      final bankDist = 2.40 + 1.95 * ((i * 0.38196601125) % 1.0);
      final x = TerrainConfig.riverCenterX(z) + side * bankDist;
      if (!isClearForGroundFlora(x, z, graph, roadMargin: 0.35)) {
        continue;
      }

      final goldenMix = ((bankDist - 2.40) / 1.95).clamp(0.0, 1.0);
      final hSeed = (math.sin(i * 7.73 + 1.9) * 917.3).abs() % 1.0;
      final r = 0.42 + 0.30 * (1 - goldenMix * 0.50) + 0.08 * hSeed;
      final g = 0.41 + 0.07 * hSeed;
      final b = 0.13 + 0.04 * hSeed;

      final width = 0.56 + 0.28 * hSeed;
      final height =
          0.68 + 0.48 * (1 - goldenMix * 0.42) * (0.75 + 0.4 * hSeed);
      addSurfaceAlignedInstance(
        tuftInstanced,
        x: x,
        z: z,
        yaw: hSeed * math.pi * 2,
        sx: width,
        sy: height,
        sz: width,
        color: Vector4(r, g, b, 1),
        yLift: -0.03,
        slopeFollow: 0.22,
      );
    }

    final shrubInstanced = InstancedMesh(
      geometry: _buildShrubMoundPrototypeGeometry(),
      material: resolveMaterial(ShukubaSurfaceRole.bambooCanopy),
    );
    const shrubCandidates = 260;
    for (var i = 0; i < shrubCandidates; i++) {
      final ux = ((i + 17) * 0.7548776662466927) % 1.0;
      final uz = ((i + 17) * 0.5698402909980532) % 1.0;
      final x = -34.0 + ux * 68.0;
      final z = -34.0 + uz * 68.0;
      final cluster =
          0.5 + 0.5 * math.sin(x * 0.21 - z * 0.27) * math.cos(z * 0.18);
      if (cluster < 0.52) {
        continue;
      }
      if (!isClearForGroundFlora(
        x,
        z,
        graph,
        roadMargin: 0.78,
        footprintMargin: 0.68,
      )) {
        continue;
      }
      final sHash = (math.sin(i * 17.3 + 2.7) * 613.9).abs() % 1.0;
      final russet = sHash > 0.74;
      final shColor = russet
          ? Vector4(2.15, 0.92 + 0.35 * sHash, 0.52, 1)
          : Vector4(0.84 + 0.26 * sHash, 0.96 + 0.18 * sHash, 0.72, 1);
      final rad = 0.54 + 0.32 * sHash;
      addSurfaceAlignedInstance(
        shrubInstanced,
        x: x,
        z: z,
        yaw: sHash * math.pi * 2,
        sx: rad,
        sy: 0.34 + 0.22 * sHash,
        sz: rad,
        color: shColor,
        yLift: 0.02,
        slopeFollow: 0.40,
      );
    }

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
        final radius = 0.55 + 2.95 * math.sqrt(frac);
        final x = s.position.x + math.cos(ang) * radius;
        final z = s.position.z + math.sin(ang) * radius;
        if (!isClearForGroundFlora(
          x,
          z,
          graph,
          roadMargin: -0.18,
          footprintMargin: 0.22,
        )) {
          continue;
        }
        final warmGold = (k * 0.37 + mapleIndex * 0.21) % 1.0;
        final r = 0.72 + 0.22 * warmGold;
        final g = 0.09 + 0.26 * warmGold * warmGold;
        final b = 0.035 + 0.03 * warmGold;
        final patchSize = 0.42 + 0.24 * ((k * 0.61) % 1.0);
        addSurfaceAlignedInstance(
          fallenLeafInstanced,
          x: x,
          z: z,
          yaw: ang * 1.7,
          sx: patchSize,
          sy: patchSize,
          sz: patchSize,
          color: Vector4(r, g, b, 1),
          yLift: 0.032,
          slopeFollow: 0.85,
        );
      }
    }

    if (tuftInstanced.instanceCount > 0) {
      root.add(
        Node(name: 'flora_tufts')
          ..addComponent(InstancedMeshComponent(tuftInstanced)),
      );
    }

    if (shrubInstanced.instanceCount > 0) {
      root.add(
        Node(name: 'flora_shrub_mounds')
          ..addComponent(InstancedMeshComponent(shrubInstanced)),
      );
    }

    if (fallenLeafInstanced.instanceCount > 0) {
      root.add(
        Node(name: 'flora_fallen_momiji')
          ..shadowCastingMode = ShadowCastingMode.off
          ..addComponent(InstancedMeshComponent(fallenLeafInstanced)),
      );
    }

    return root;
  }

  static MeshGeometry _buildTuftPrototypeGeometry() {
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
      final lean = (i.isEven ? 1.0 : -1.0) * 0.22;

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

    return builder.build();
  }

  static MeshGeometry _buildShrubMoundPrototypeGeometry() {
    final builder = GeometryBuilder()..color(Vector4(1, 1, 1, 1));

    int emit(Vector3 pos, double u, double v) {
      builder.texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    const fronds = 6;
    for (var i = 0; i < fronds; i++) {
      final yaw = (i / fronds) * math.pi * 2 + 0.35;
      final cy = math.cos(yaw);
      final sy = math.sin(yaw);
      final fwd = Vector3(cy, 0, sy);
      final right = Vector3(-sy, 0, cy);
      final lift = i.isEven ? 0.95 : 0.72;

      final stem = fwd * 0.10;
      final mid = fwd * 0.56 + Vector3(0, lift * 0.78, 0);
      final tip = fwd * 1.0 + Vector3(0, lift * 0.36, 0);

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

    return builder.build();
  }

  static MeshGeometry _buildFallenLeafPatchGeometry() {
    final builder = GeometryBuilder()..color(Vector4(1, 1, 1, 1));

    int emit(Vector3 pos, double u, double v) {
      builder.texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    final v0 = emit(Vector3(-0.5, 0, -0.5), 0, 2);
    final v1 = emit(Vector3(0.5, 0.015, -0.5), 1, 2);
    final v2 = emit(Vector3(0.5, 0.005, 0.5), 1, 3);
    final v3 = emit(Vector3(-0.5, 0.020, 0.5), 0, 3);
    builder
      ..addTriangle(v0, v2, v1)
      ..addTriangle(v0, v3, v2);

    return builder.build();
  }
}
