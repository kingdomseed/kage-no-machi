import 'dart:math' as math;

import 'package:flutter_scene/scene.dart'
    show
        GeometryBuilder,
        InstancedMesh,
        InstancedMeshComponent,
        Mesh,
        Node,
        ShadowCastingMode;
import 'package:kage_no_machi/shukuba/look/edo_look_driver.dart'
    show EdoLookDriver;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        GroundHeightSampler,
        RoadStyle,
        ShukubaGraph,
        ShukubaMaterialResolver,
        ShukubaSurfaceRole,
        StructureKind,
        TimeOfDayRig,
        Vec3;
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart'
    show EdoKitBuilder;
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart'
    show TerrainConfig;
import 'package:vector_math/vector_math.dart'
    show Matrix4, Vector2, Vector3, Vector4;

class AtmosphereBuilder {
  const new();

  Node buildAtmosphereNode({
    required ShukubaGraph graph,
    required ShukubaMaterialResolver resolveMaterial,
    required GroundHeightSampler sampleGroundY,
  }) {
    final root = Node(name: 'atmosphere_root');
    final mistMat = resolveMaterial(ShukubaSurfaceRole.riverMist);
    final sunbeamMat = EdoLookDriver.resolveSunbeamMaterial(resolveMaterial);
    final haloMat = resolveMaterial(ShukubaSurfaceRole.lanternHaze);
    final moteMat = resolveMaterial(ShukubaSurfaceRole.airborneMotes);

    final mistGroup = Node(name: 'atmosphere_mist_ribbons');
    final southRiverMist = GeometryBuilder();
    _emitRiverGorgeMistRibbons(southRiverMist, zMin: -38, zMax: 0);
    mistGroup.add(
      Node(
        name: 'atmosphere_mist_river_south',
        mesh: Mesh(southRiverMist.build(), mistMat),
      )..shadowCastingMode = ShadowCastingMode.off,
    );

    final northRiverMist = GeometryBuilder();
    _emitRiverGorgeMistRibbons(northRiverMist, zMin: 0, zMax: 38);
    mistGroup.add(
      Node(
        name: 'atmosphere_mist_river_north',
        mesh: Mesh(northRiverMist.build(), mistMat),
      )..shadowCastingMode = ShadowCastingMode.off,
    );

    final westMist = GeometryBuilder();
    final eastMist = GeometryBuilder();
    _emitCourtyardAlleyHaze(westMist, eastMist, graph, sampleGroundY);
    _emitStructureSteamWisps(westMist, eastMist, graph);
    if (westMist.vertexCount > 0) {
      mistGroup.add(
        Node(
          name: 'atmosphere_mist_west_ward',
          mesh: Mesh(westMist.build(), mistMat),
        )..shadowCastingMode = ShadowCastingMode.off,
      );
    }
    if (eastMist.vertexCount > 0) {
      mistGroup.add(
        Node(
          name: 'atmosphere_mist_east_ward',
          mesh: Mesh(eastMist.build(), mistMat),
        )..shadowCastingMode = ShadowCastingMode.off,
      );
    }

    final sunbeams = GeometryBuilder();
    _emitKomorebiSunbeamCurtains(sunbeams, graph);
    if (sunbeams.vertexCount > 0) {
      mistGroup.add(
        Node(
            name: 'atmosphere_komorebi_sunbeams',
            mesh: Mesh(sunbeams.build(), sunbeamMat),
          )
          ..shadowCastingMode = ShadowCastingMode.off
          ..raycastable = false,
      );
    }
    root.add(mistGroup);

    final quadGeo = EdoKitBuilder.buildUnitBillboardQuad();
    final haloInstanced = InstancedMesh(geometry: quadGeo, material: haloMat);
    _populateLanternHalos(haloInstanced, graph);
    if (haloInstanced.instanceCount > 0) {
      root.add(
        Node(name: 'atmosphere_lantern_halos')
          ..shadowCastingMode = ShadowCastingMode.off
          ..addComponent(InstancedMeshComponent(haloInstanced)),
      );
    }

    final moteInstanced = InstancedMesh(geometry: quadGeo, material: moteMat);
    _populateAirborneMotes(moteInstanced, graph, sampleGroundY);
    if (moteInstanced.instanceCount > 0) {
      root.add(
        Node(name: 'atmosphere_airborne_motes')
          ..shadowCastingMode = ShadowCastingMode.off
          ..addComponent(InstancedMeshComponent(moteInstanced)),
      );
    }

    return root;
  }

  static void _emitRiverGorgeMistRibbons(
    GeometryBuilder builder, {
    required double zMin,
    required double zMax,
  }) {
    const segs = 30;
    final dz = (zMax - zMin) / segs;

    const tiers = [
      (-0.36, 3.65, 0.86, 0.0, 0.0),
      (-0.02, 4.85, 0.72, 0.34, 0.17),
      (0.36, 6.10, 0.54, -0.44, 0.13),
    ];

    for (var tierIdx = 0; tierIdx < tiers.length; tierIdx++) {
      final tier = tiers[tierIdx];
      final baseY = tier.$1;
      final halfW = tier.$2;
      final peakAlpha = tier.$3;
      final swayAmp = tier.$4;
      final swayFreq = tier.$5;

      final baseVertex = <int>[];
      for (var i = 0; i <= segs; i++) {
        final z = zMin + i * dz;
        final endDist = math.min(z - (-38.0), 38.0 - z);
        final endFade = (endDist / 8.0).clamp(0.0, 1.0);
        final cX =
            TerrainConfig.riverCenterX(z) +
            swayAmp * math.sin(z * swayFreq + tierIdx);
        final v = 0.2 + ((z + 38.0) / 76.0) * 9.0 + tierIdx * 3.1;
        final crownY = baseY + 0.08 * math.cos(z * 0.21 + tierIdx);

        builder
          ..color(Vector4(1, 1, 1, 0))
          ..texCoord(Vector2(0, v));
        final vL = builder.addVertex(Vector3(cX - halfW, baseY - 0.06, z));

        builder
          ..color(Vector4(1, 1, 1, peakAlpha * endFade))
          ..texCoord(Vector2(0.5, v));
        final vC = builder.addVertex(Vector3(cX, crownY, z));

        builder
          ..color(Vector4(1, 1, 1, 0))
          ..texCoord(Vector2(1, v));
        final vR = builder.addVertex(Vector3(cX + halfW, baseY - 0.06, z));

        baseVertex
          ..add(vL)
          ..add(vC)
          ..add(vR);
      }

      for (var i = 0; i < segs; i++) {
        final r0 = i * 3;
        final r1 = (i + 1) * 3;
        builder
          ..addTriangle(baseVertex[r0], baseVertex[r1], baseVertex[r0 + 1])
          ..addTriangle(baseVertex[r0 + 1], baseVertex[r1], baseVertex[r1 + 1])
          ..addTriangle(
            baseVertex[r0 + 1],
            baseVertex[r1 + 1],
            baseVertex[r0 + 2],
          )
          ..addTriangle(
            baseVertex[r0 + 2],
            baseVertex[r1 + 1],
            baseVertex[r1 + 2],
          );
      }
    }
  }

  static void _emitCourtyardAlleyHaze(
    GeometryBuilder westBuilder,
    GeometryBuilder eastBuilder,
    ShukubaGraph graph,
    GroundHeightSampler sampleGroundY,
  ) {
    for (final wall in graph.walls) {
      if (wall.controlPoints.length < 2) {
        continue;
      }
      var cx = 0.0;
      var cz = 0.0;
      for (final p in wall.controlPoints) {
        cx += p.x;
        cz += p.z;
      }
      cx /= wall.controlPoints.length;
      cz /= wall.controlPoints.length;
      final gy = sampleGroundY(cx, cz) + 0.42;
      _emitSoftHazePillow(
        cx < 0 ? westBuilder : eastBuilder,
        Vector3(cx, gy, cz),
        4.2,
        3.4,
        0.42,
      );
    }

    for (final road in graph.roads) {
      if (road.controlPoints.length < 2 || road.style == RoadStyle.gardenPath) {
        continue;
      }
      final mid = Vec3.lerp(
        road.controlPoints.first,
        road.controlPoints.last,
        0.5,
      );
      if (mid.x.abs() > 7.0) {
        final gy = sampleGroundY(mid.x, mid.z) + 0.36;
        _emitSoftHazePillow(
          mid.x < 0 ? westBuilder : eastBuilder,
          Vector3(mid.x, gy, mid.z),
          4.6,
          3.6,
          0.34,
        );
      }
    }
  }

  static void _emitSoftHazePillow(
    GeometryBuilder builder,
    Vector3 center,
    double halfX,
    double halfZ,
    double peakAlpha,
  ) {
    int emit(Vector3 p, double u, double v, double a) {
      builder
        ..color(Vector4(1, 1, 1, a))
        ..texCoord(Vector2(u, v));
      return builder.addVertex(p);
    }

    final vC = emit(center + Vector3(0, 0.12, 0), 0.5, 1.5, peakAlpha);
    final v0 = emit(center + Vector3(-halfX, 0, -halfZ), 0, 1, 0);
    final v1 = emit(center + Vector3(halfX, 0, -halfZ), 1, 1, 0);
    final v2 = emit(center + Vector3(halfX, 0, halfZ), 1, 2, 0);
    final v3 = emit(center + Vector3(-halfX, 0, halfZ), 0, 2, 0);

    builder
      ..addTriangle(vC, v0, v1)
      ..addTriangle(vC, v1, v2)
      ..addTriangle(vC, v2, v3)
      ..addTriangle(vC, v3, v0);
  }

  static void _emitStructureSteamWisps(
    GeometryBuilder westBuilder,
    GeometryBuilder eastBuilder,
    ShukubaGraph graph,
  ) {
    for (final s in graph.structures.values) {
      final Vec3 localVent;
      final double width;
      final double height;
      switch (s.kind) {
        case StructureKind.chaya:
          localVent = const Vec3(-1.45, 2.25, 1.85);
          width = 0.95;
          height = 2.05;
        case StructureKind.marketStall:
          localVent = const Vec3(0.25, 1.28, 0.15);
          width = 0.78;
          height = 1.65;
        case StructureKind.minka:
          localVent = const Vec3(0, 3.2, -0.8);
          width = 0.85;
          height = 1.85;
        case StructureKind.machiya ||
            StructureKind.kura ||
            StructureKind.toriiGate ||
            StructureKind.shoroBell ||
            StructureKind.stoneWell ||
            StructureKind.karesansuiGarden ||
            StructureKind.yaguraTower ||
            StructureKind.rockOutcrop ||
            StructureKind.mapleCluster ||
            StructureKind.bambooGrove ||
            StructureKind.pineTree ||
            StructureKind.weepingWillow:
          continue;
      }

      final origin = (s.position + localVent.rotateY(s.yawRadians)).toVector3();
      final targetBuilder = origin.x < 0 ? westBuilder : eastBuilder;
      for (final planeYaw in const [0.35, 1.92]) {
        final rx = math.cos(planeYaw) * width * 0.5;
        final rz = math.sin(planeYaw) * width * 0.5;

        int emit(Vector3 p, double u, double v, double a) {
          targetBuilder
            ..color(Vector4(1, 0.96, 0.90, a))
            ..texCoord(Vector2(u, v));
          return targetBuilder.addVertex(p);
        }

        final v0 = emit(origin + Vector3(-rx, 0, -rz), 0, -0.02, 0);
        final v1 = emit(origin + Vector3(rx, 0, rz), 1, -0.02, 0);
        final v2 = emit(
          origin + Vector3(-rx * 1.25 + 0.10, height * 0.5, -rz * 1.25 + 0.08),
          0,
          -0.5,
          0.78,
        );
        final v3 = emit(
          origin + Vector3(rx * 1.25 + 0.10, height * 0.5, rz * 1.25 + 0.08),
          1,
          -0.5,
          0.78,
        );
        final v4 = emit(
          origin + Vector3(-rx * 1.55 + 0.24, height, -rz * 1.55 + 0.20),
          0,
          -0.98,
          0,
        );
        final v5 = emit(
          origin + Vector3(rx * 1.55 + 0.24, height, rz * 1.55 + 0.20),
          1,
          -0.98,
          0,
        );

        targetBuilder
          ..addTriangle(v0, v1, v3)
          ..addTriangle(v0, v3, v2)
          ..addTriangle(v2, v3, v5)
          ..addTriangle(v2, v5, v4);
      }
    }
  }

  static void _emitKomorebiSunbeamCurtains(
    GeometryBuilder builder,
    ShukubaGraph graph,
  ) {
    final ray = TimeOfDayRig.goldenDusk.celestialRayDirection
        .toVector3()
        .normalized();
    final side0 = Vector3(0, 1, 0).cross(ray).normalized();
    final upPerp = ray.cross(side0).normalized();
    const tStops = [0.0, 0.34, 0.70, 1.0];

    for (final s in graph.structures.values) {
      final double crownHeight;
      final double shaftLength;
      final double halfWidthTop;
      final double halfWidthBottom;
      final double peakAlpha;
      final Vector3 tint;

      switch (s.kind) {
        case StructureKind.bambooGrove:
          crownHeight = 5.5;
          shaftLength = 13.6;
          halfWidthTop = 1.65;
          halfWidthBottom = 2.55;
          peakAlpha = 0.88;
          tint = Vector3(1, 0.86, 0.52);
        case StructureKind.pineTree:
          crownHeight = 4.9;
          shaftLength = 12.2;
          halfWidthTop = 1.50;
          halfWidthBottom = 2.35;
          peakAlpha = 0.82;
          tint = Vector3(1, 0.82, 0.46);
        case StructureKind.mapleCluster:
          crownHeight = 4.3;
          shaftLength = 10.8;
          halfWidthTop = 1.40;
          halfWidthBottom = 2.15;
          peakAlpha = 0.78;
          tint = Vector3(1, 0.76, 0.42);
        case StructureKind.machiya ||
            StructureKind.minka ||
            StructureKind.chaya ||
            StructureKind.kura ||
            StructureKind.marketStall ||
            StructureKind.toriiGate ||
            StructureKind.shoroBell ||
            StructureKind.stoneWell ||
            StructureKind.karesansuiGarden ||
            StructureKind.yaguraTower ||
            StructureKind.rockOutcrop ||
            StructureKind.weepingWillow:
          continue;
      }

      var hash = 0x811c9dc5;
      for (final unit in s.id.value.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x01000193) & 0xffffffff;
      }
      final jitter = ((hash & 0xffff) / 65535.0 - 0.5) * 0.14;
      final baseOrigin =
          s.position.toVector3() + Vector3(0, crownHeight, 0) - ray * 1.35;

      for (final curtain in [(0.58 + jitter, -0.42), (-0.64 + jitter, 0.42)]) {
        final theta = curtain.$1;
        final lateralShift = curtain.$2;
        final cosT = math.cos(theta);
        final sinT = math.sin(theta);
        final across = (side0 * cosT + upPerp * sinT).normalized();
        final faceNormal = (upPerp * cosT - side0 * sinT).normalized();
        final origin = baseOrigin + side0 * lateralShift;

        final rows = <int>[];
        for (final tY in tStops) {
          final halfW = halfWidthTop + (halfWidthBottom - halfWidthTop) * tY;
          final centerPos = origin + ray * (shaftLength * tY);

          int emitVertex(double sideSign, double u, double edgeScale) {
            builder
              ..normal(faceNormal)
              ..color(Vector4(tint.x, tint.y, tint.z, peakAlpha * edgeScale))
              ..texCoord(Vector2(u, tY));
            return builder.addVertex(centerPos + across * (sideSign * halfW));
          }

          rows
            ..add(emitVertex(-1, 0, 0.25))
            ..add(emitVertex(0, 0.5, 1))
            ..add(emitVertex(1, 1, 0.25));
        }

        for (var r = 0; r < tStops.length - 1; r++) {
          final a = r * 3;
          final b = (r + 1) * 3;
          builder
            ..addTriangle(rows[a], rows[b], rows[a + 1])
            ..addTriangle(rows[a + 1], rows[b], rows[b + 1])
            ..addTriangle(rows[a + 1], rows[b + 1], rows[a + 2])
            ..addTriangle(rows[a + 2], rows[b + 1], rows[b + 2]);
        }
      }
    }
  }

  static void _populateLanternHalos(InstancedMesh target, ShukubaGraph graph) {
    final xform = Matrix4.identity();
    void addHalo(Vec3 pos, double size, Vector4 tint) {
      xform.setValues(
        size,
        0,
        0,
        0,
        0,
        size,
        0,
        0,
        0,
        0,
        size,
        0,
        pos.x,
        pos.y,
        pos.z,
        1,
      );
      target.addInstance(xform, color: tint);
    }

    final warmHalo = Vector4(1, 0.86, 0.62, 0.92);
    for (final span in graph.lanternSpans) {
      for (final hp in span.lanternHangPoints()) {
        addHalo(hp + const Vec3(0, -0.18, 0), 1.80, warmHalo);
      }
    }

    for (final s in graph.structures.values) {
      final isGate = s.kind == StructureKind.toriiGate;
      final size = switch (s.kind) {
        StructureKind.chaya => 1.65,
        StructureKind.machiya => 1.45,
        StructureKind.minka => 1.45,
        StructureKind.marketStall => 1.45,
        StructureKind.toriiGate => 1.75,
        StructureKind.karesansuiGarden => 1.05,
        StructureKind.shoroBell ||
        StructureKind.stoneWell ||
        StructureKind.kura ||
        StructureKind.yaguraTower ||
        StructureKind.rockOutcrop ||
        StructureKind.mapleCluster ||
        StructureKind.bambooGrove ||
        StructureKind.pineTree ||
        StructureKind.weepingWillow => 0.0,
      };
      final tint = isGate ? Vector4(1, 0.78, 0.52, 0.88) : warmHalo;
      for (final local in EdoKitBuilder.structureLanternLocalOffsets(s)) {
        addHalo(s.position + local.rotateY(s.yawRadians), size, tint);
      }
    }
  }

  static void _populateAirborneMotes(
    InstancedMesh target,
    ShukubaGraph graph,
    GroundHeightSampler sampleGroundY,
  ) {
    final xform = Matrix4.identity();
    void addMote(double x, double y, double z, double size, Vector4 color) {
      xform.setValues(size, 0, 0, 0, 0, size, 0, 0, 0, 0, size, 0, x, y, z, 1);
      target.addInstance(xform, color: color);
    }

    const pollenCount = 150;
    for (var i = 0; i < pollenCount; i++) {
      final ux = ((i + 5) * 0.7548776662466927) % 1.0;
      final uz = ((i + 5) * 0.5698402909980532) % 1.0;
      final x = -28.0 + ux * 56.0;
      final z = -26.0 + uz * 52.0;
      final gy = math.max(-0.2, sampleGroundY(x, z));
      final hSeed = (math.sin(i * 11.7 + 0.9) * 517.3).abs() % 1.0;
      final y = gy + 0.85 + 3.4 * hSeed;
      final size = 0.075 + 0.045 * hSeed;
      addMote(x, y, z, size, Vector4(0.96, 0.82, 0.46, 0.16));
    }

    var mapleSeed = 0;
    for (final s in graph.structures.values) {
      if (s.kind != StructureKind.mapleCluster) {
        continue;
      }
      mapleSeed++;
      const petalsPerTree = 20;
      for (var k = 0; k < petalsPerTree; k++) {
        final ang = k * 2.39996323 + mapleSeed * 1.3;
        final rad = 0.4 + 2.4 * ((k * 0.37) % 1.0);
        final x = s.position.x + math.cos(ang) * rad;
        final z = s.position.z + math.sin(ang) * rad;
        final y = s.position.y + 2.1 + 1.4 * ((k * 0.61) % 1.0);
        final gold = (k * 0.29 + mapleSeed * 0.17) % 1.0;
        final size = 0.135 + 0.045 * gold;
        addMote(x, y, z, size, Vector4(0.88, 0.16 + 0.26 * gold, 0.04, 0.50));
      }
    }

    const fireflyCount = 96;
    for (var i = 0; i < fireflyCount; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final z = -30.0 + (i / fireflyCount) * 60.0;
      final hSeed = (math.sin(i * 9.13 + 3.4) * 733.1).abs() % 1.0;
      final bankDist = 2.25 + 2.25 * hSeed;
      final x = TerrainConfig.riverCenterX(z) + side * bankDist;
      final gy = math.max(-0.35, sampleGroundY(x, z));
      final y = gy + 0.45 + 0.95 * ((i * 0.47) % 1.0);
      final size = 0.10 + 0.045 * hSeed;
      addMote(x, y, z, size, Vector4(0.92, 0.88, 0.24, 0.85));
    }

    const dewCount = 84;
    for (var i = 0; i < dewCount; i++) {
      final ux = ((i + 31) * 0.7548776662466927) % 1.0;
      final uz = ((i + 31) * 0.5698402909980532) % 1.0;
      final x = -26.0 + ux * 52.0;
      final z = -24.0 + uz * 48.0;
      final gy = math.max(-0.2, sampleGroundY(x, z));
      final hSeed = (math.sin(i * 15.1 + 2.2) * 389.7).abs() % 1.0;
      final y = gy + 1.4 + 2.6 * hSeed;
      final size = 0.055 + 0.030 * hSeed;
      addMote(x, y, z, size, Vector4(0.58, 0.74, 0.92, 0.85));
    }
  }
}
