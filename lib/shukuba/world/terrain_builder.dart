import 'dart:math' as math;

import 'package:flutter_scene/scene.dart'
    show GeometryBuilder, Mesh, MeshGeometry, Node;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        GroundHeightSampler,
        RoadSpline,
        ShukubaMaterialResolver,
        ShukubaSurfaceRole,
        TerraceCourse,
        Vec3;
import 'package:vector_math/vector_math.dart' show Vector2, Vector3;

class TerrainConfig {
  const new();

  static const double minX = -38;
  static const double maxX = 38;
  static const double minZ = -38;
  static const double maxZ = 38;
  static const double gridStep = 1;

  static const double bridgeMinX = -5.2;
  static const double bridgeMaxX = 5.2;
  static const double bridgeMinZ = -1.8;
  static const double bridgeMaxZ = 1.8;
  static const double bridgeWestElevation = 0.40;
  static const double bridgeEastElevation = 1.80;
  static const double bridgeArchCamber = 0.45;

  static const double riverBedElevation = -1.85;
  static const double waterSurfaceElevation = -0.55;
  static const double riverBankHalfWidth = 2.80;
  static const double riverTransitionWidth = 2.40;

  static double riverCenterX(double z) =>
      1.80 * math.sin(z * 0.09) + 0.40 * math.sin(z * 0.22);

  static double bridgeDeckHeightAt(double x) {
    final t = (x - bridgeMinX) / (bridgeMaxX - bridgeMinX);
    final clampedT = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
    final baseline =
        bridgeWestElevation +
        (bridgeEastElevation - bridgeWestElevation) * clampedT;
    final arch = 4 * bridgeArchCamber * clampedT * (1 - clampedT);
    return baseline + arch;
  }

  static bool isInsideBridgeFootprint(double x, double z) =>
      x >= bridgeMinX && x <= bridgeMaxX && z >= bridgeMinZ && z <= bridgeMaxZ;
}

class TerrainBuilder {
  const new();

  double sampleRawTerrain(double x, double z) {
    final rivX = TerrainConfig.riverCenterX(z);
    final dist = (x - rivX).abs();

    final westFlat = 0.40 + 0.12 * math.sin(x * 0.12) * math.cos(z * 0.14);
    final eastTerrace = x < 13.5 ? 1.80 : 3.40;

    if (dist <= TerrainConfig.riverBankHalfWidth) {
      final shoal = 0.08 * math.sin(z * 0.35) * math.cos(x * 0.45);
      return TerrainConfig.riverBedElevation + shoal;
    }

    final ramp =
        (dist - TerrainConfig.riverBankHalfWidth) /
        TerrainConfig.riverTransitionWidth;
    final t = ramp >= 1 ? 1.0 : ramp * ramp * (3 - 2 * ramp);

    final bankTarget = x < rivX ? westFlat : eastTerrace;
    return TerrainConfig.riverBedElevation +
        (bankTarget - TerrainConfig.riverBedElevation) * t;
  }

  double sampleGroundHeight(
    double x,
    double z, {
    Iterable<TerraceCourse> terraces = const [],
  }) {
    if (TerrainConfig.isInsideBridgeFootprint(x, z)) {
      return TerrainConfig.bridgeDeckHeightAt(x);
    }

    var height = sampleRawTerrain(x, z);
    final probe = Vec3(x, height, z);
    for (final terrace in terraces) {
      final platY = terrace.samplePlatformElevation(probe);
      if (platY != null && platY > height) {
        height = platY;
      }
    }
    return height;
  }

  MeshGeometry buildTerrainGeometry({
    Iterable<TerraceCourse> terraces = const [],
  }) {
    final builder = GeometryBuilder();
    const minX = TerrainConfig.minX;
    const maxX = TerrainConfig.maxX;
    const minZ = TerrainConfig.minZ;
    const maxZ = TerrainConfig.maxZ;
    const step = TerrainConfig.gridStep;

    final cols = ((maxX - minX) / step).round() + 1;
    final rows = ((maxZ - minZ) / step).round() + 1;

    for (var r = 0; r < rows; r++) {
      final z = minZ + r * step;
      final v = (z - minZ) / (maxZ - minZ);
      for (var c = 0; c < cols; c++) {
        final x = minX + c * step;
        final u = (x - minX) / (maxX - minX);
        final y = sampleRawTerrain(x, z);
        builder
          ..texCoord(Vector2(u * 16.0, v * 16.0))
          ..addVertex(Vector3(x, y, z));
      }
    }

    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final v00 = r * cols + c;
        final v10 = v00 + 1;
        final v01 = v00 + cols;
        final v11 = v01 + 1;
        builder
          ..addTriangle(v00, v01, v10)
          ..addTriangle(v10, v01, v11);
      }
    }

    return builder.build();
  }

  Node buildTerrainNode(
    ShukubaMaterialResolver resolveMaterial, {
    Iterable<TerraceCourse> terraces = const [],
  }) {
    final mesh = Mesh(
      buildTerrainGeometry(terraces: terraces),
      resolveMaterial(ShukubaSurfaceRole.packedEarth),
    );
    return Node(mesh: mesh);
  }

  Node buildWaterNode(ShukubaMaterialResolver resolveMaterial) {
    final builder = GeometryBuilder();
    const minZ = TerrainConfig.minZ;
    const maxZ = TerrainConfig.maxZ;
    const segments = 48;
    const zStep = (maxZ - minZ) / segments;
    const waterY = TerrainConfig.waterSurfaceElevation;
    const halfWidth = 3.40;

    for (var i = 0; i <= segments; i++) {
      final z = minZ + i * zStep;
      final cX = TerrainConfig.riverCenterX(z);
      final leftX = cX - halfWidth;
      final rightX = cX + halfWidth;
      final v = i / segments;

      builder
        ..texCoord(Vector2(0, v * 8))
        ..addVertex(Vector3(leftX, waterY, z))
        ..texCoord(Vector2(1, v * 8))
        ..addVertex(Vector3(rightX, waterY, z));
    }

    for (var i = 0; i < segments; i++) {
      final v00 = i * 2;
      final v01 = v00 + 1;
      final v10 = v00 + 2;
      final v11 = v00 + 3;
      builder
        ..addTriangle(v00, v10, v01)
        ..addTriangle(v01, v10, v11);
    }

    final mesh = Mesh(
      builder.build(),
      resolveMaterial(ShukubaSurfaceRole.riverWater),
    );
    return Node(mesh: mesh);
  }

  Node buildBridgeNode(ShukubaMaterialResolver resolveMaterial) {
    final root = Node();
    final timberMat = resolveMaterial(ShukubaSurfaceRole.charredTimber);
    final accentMat = resolveMaterial(ShukubaSurfaceRole.fabricAwning);

    final deckBuilder = GeometryBuilder();
    const segs = 20;
    const x0 = TerrainConfig.bridgeMinX;
    const x1 = TerrainConfig.bridgeMaxX;
    const dx = (x1 - x0) / segs;
    const zLeft = -1.74;
    const zRight = 1.74;
    const deckThick = 0.12;

    for (var i = 0; i <= segs; i++) {
      final x = x0 + i * dx;
      final yTop = TerrainConfig.bridgeDeckHeightAt(x);
      final yBot = yTop - deckThick;
      final u = i / segs;

      deckBuilder
        ..texCoord(Vector2(u * 6.0, 0))
        ..addVertex(Vector3(x, yTop, zLeft))
        ..texCoord(Vector2(u * 6.0, 1))
        ..addVertex(Vector3(x, yTop, zRight))
        ..texCoord(Vector2(u * 6.0, 0))
        ..addVertex(Vector3(x, yBot, zLeft))
        ..texCoord(Vector2(u * 6.0, 1))
        ..addVertex(Vector3(x, yBot, zRight));
    }

    for (var i = 0; i < segs; i++) {
      final top0 = i * 4;
      final top1 = top0 + 1;
      final top2 = top0 + 4;
      final top3 = top0 + 5;
      deckBuilder
        ..addTriangle(top0, top1, top2)
        ..addTriangle(top1, top3, top2);

      final bot0 = i * 4 + 2;
      final bot1 = i * 4 + 3;
      final bot2 = i * 4 + 6;
      final bot3 = i * 4 + 7;
      deckBuilder
        ..addTriangle(bot0, bot2, bot1)
        ..addTriangle(bot1, bot2, bot3);
    }

    root.add(Node(mesh: Mesh(deckBuilder.build(), timberMat)));

    final structureBuilder = GeometryBuilder();
    void addBeam(Vector3 pMin, Vector3 pMax) {
      final x0 = pMin.x;
      final y0 = pMin.y;
      final z0 = pMin.z;
      final x1 = pMax.x;
      final y1 = pMax.y;
      final z1 = pMax.z;

      final v000 = structureBuilder.addVertex(Vector3(x0, y0, z0));
      final v100 = structureBuilder.addVertex(Vector3(x1, y0, z0));
      final v110 = structureBuilder.addVertex(Vector3(x1, y1, z0));
      final v010 = structureBuilder.addVertex(Vector3(x0, y1, z0));
      final v001 = structureBuilder.addVertex(Vector3(x0, y0, z1));
      final v101 = structureBuilder.addVertex(Vector3(x1, y0, z1));
      final v111 = structureBuilder.addVertex(Vector3(x1, y1, z1));
      final v011 = structureBuilder.addVertex(Vector3(x0, y1, z1));

      structureBuilder
        ..addTriangle(v000, v010, v110)
        ..addTriangle(v000, v110, v100)
        ..addTriangle(v001, v101, v111)
        ..addTriangle(v001, v111, v011)
        ..addTriangle(v000, v001, v011)
        ..addTriangle(v000, v011, v010)
        ..addTriangle(v100, v110, v111)
        ..addTriangle(v100, v111, v101)
        ..addTriangle(v010, v011, v111)
        ..addTriangle(v010, v111, v110)
        ..addTriangle(v000, v100, v101)
        ..addTriangle(v000, v101, v001);
    }

    final postXList = [-5.0, -3.3, -1.6, 0.0, 1.6, 3.3, 5.0];
    for (final px in postXList) {
      final yDeck = TerrainConfig.bridgeDeckHeightAt(px);
      for (final side in [-1.86, 1.86]) {
        addBeam(
          Vector3(px - 0.06, yDeck - 0.16, side - 0.05),
          Vector3(px + 0.06, yDeck + 0.85, side + 0.05),
        );
      }
    }

    for (var i = 0; i < postXList.length - 1; i++) {
      final pxA = postXList[i];
      final pxB = postXList[i + 1];
      final yA = TerrainConfig.bridgeDeckHeightAt(pxA);
      final yB = TerrainConfig.bridgeDeckHeightAt(pxB);
      final midY = (yA + yB) * 0.5;

      for (final side in [-1.86, 1.86]) {
        addBeam(
          Vector3(pxA + 0.07, midY + 0.70, side - 0.03),
          Vector3(pxB - 0.07, midY + 0.78, side + 0.03),
        );
        addBeam(
          Vector3(pxA + 0.07, midY + 0.32, side - 0.03),
          Vector3(pxB - 0.07, midY + 0.40, side + 0.03),
        );
      }
    }

    for (final pierX in [-2.2, 2.2]) {
      final yUnderside = TerrainConfig.bridgeDeckHeightAt(pierX) - 0.14;
      for (final pZ in [-1.2, 0.0, 1.2]) {
        addBeam(
          Vector3(pierX - 0.10, TerrainConfig.riverBedElevation, pZ - 0.10),
          Vector3(pierX + 0.10, yUnderside, pZ + 0.10),
        );
      }
      addBeam(
        Vector3(pierX - 0.08, yUnderside - 0.16, -1.30),
        Vector3(pierX + 0.08, yUnderside, 1.30),
      );
    }

    root.add(Node(mesh: Mesh(structureBuilder.build(), timberMat)));

    final finialBuilder = GeometryBuilder();
    for (final px in postXList) {
      final yDeck = TerrainConfig.bridgeDeckHeightAt(px);
      for (final side in [-1.86, 1.86]) {
        final x0 = px - 0.04;
        final x1 = px + 0.04;
        final y0 = yDeck + 0.86;
        final y1 = yDeck + 0.94;
        final z0 = side - 0.04;
        final z1 = side + 0.04;

        final v000 = finialBuilder.addVertex(Vector3(x0, y0, z0));
        final v100 = finialBuilder.addVertex(Vector3(x1, y0, z0));
        final v110 = finialBuilder.addVertex(Vector3(x1, y1, z0));
        final v010 = finialBuilder.addVertex(Vector3(x0, y1, z0));
        final v001 = finialBuilder.addVertex(Vector3(x0, y0, z1));
        final v101 = finialBuilder.addVertex(Vector3(x1, y0, z1));
        final v111 = finialBuilder.addVertex(Vector3(x1, y1, z1));
        final v011 = finialBuilder.addVertex(Vector3(x0, y1, z1));

        finialBuilder
          ..addTriangle(v000, v010, v110)
          ..addTriangle(v000, v110, v100)
          ..addTriangle(v001, v101, v111)
          ..addTriangle(v001, v111, v011)
          ..addTriangle(v000, v001, v011)
          ..addTriangle(v000, v011, v010)
          ..addTriangle(v100, v110, v111)
          ..addTriangle(v100, v111, v101)
          ..addTriangle(v010, v011, v111)
          ..addTriangle(v010, v111, v110)
          ..addTriangle(v000, v100, v101)
          ..addTriangle(v000, v101, v001);
      }
    }

    root.add(Node(mesh: Mesh(finialBuilder.build(), accentMat)));
    return root;
  }

  Node buildRoadNode(
    RoadSpline road,
    ShukubaMaterialResolver resolveMaterial,
    GroundHeightSampler sampleGroundY,
  ) {
    final builder = GeometryBuilder();
    final halfWidth = road.widthMeters * 0.5;
    const liftY = 0.025;

    final samples = <Vec3>[];
    for (var i = 0; i < road.controlPoints.length - 1; i++) {
      final pA = road.controlPoints[i];
      final pB = road.controlPoints[i + 1];
      final delta = pB - pA;
      final dist = delta.horizontalLength;
      final steps = math.max(1, (dist / 1.0).ceil());

      final startK = i == 0 ? 0 : 1;
      for (var k = startK; k <= steps; k++) {
        final t = k / steps;
        samples.add(Vec3.lerp(pA, pB, t));
      }
    }

    if (samples.length < 2) {
      return Node();
    }

    for (var i = 0; i < samples.length; i++) {
      final current = samples[i];
      final Vec3 tangent;
      if (i == 0) {
        tangent = (samples[1] - current).normalizedHorizontal();
      } else if (i == samples.length - 1) {
        tangent = (current - samples[i - 1]).normalizedHorizontal();
      } else {
        final prev = samples[i - 1];
        final next = samples[i + 1];
        tangent = (next - prev).normalizedHorizontal();
      }

      final normal = Vec3(-tangent.z, 0, tangent.x);
      final leftPos = current - normal * halfWidth;
      final rightPos = current + normal * halfWidth;

      final yLeft = sampleGroundY(leftPos.x, leftPos.z) + liftY;
      final yRight = sampleGroundY(rightPos.x, rightPos.z) + liftY;

      final u = i.toDouble();
      builder
        ..texCoord(Vector2(0, u * 0.5))
        ..addVertex(Vector3(leftPos.x, yLeft, leftPos.z))
        ..texCoord(Vector2(1, u * 0.5))
        ..addVertex(Vector3(rightPos.x, yRight, rightPos.z));
    }

    for (var i = 0; i < samples.length - 1; i++) {
      final v00 = i * 2;
      final v01 = v00 + 1;
      final v10 = v00 + 2;
      final v11 = v00 + 3;
      builder
        ..addTriangle(v00, v01, v10)
        ..addTriangle(v01, v11, v10);
    }

    final mesh = Mesh(
      builder.build(),
      resolveMaterial(ShukubaSurfaceRole.laneOverlay),
    );
    return Node(mesh: mesh);
  }

  Node buildTerraceNode(
    TerraceCourse terrace,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final builder = GeometryBuilder();
    const copingLift = 0.06;
    const copingThickness = 0.10;
    const copingWidth = 0.35;

    for (var i = 0; i < terrace.crestPoints.length - 1; i++) {
      final pA = terrace.crestPoints[i];
      final pB = terrace.crestPoints[i + 1];
      final delta = pB - pA;
      final segLen = delta.horizontalLength;
      if (segLen <= 1e-6) continue;

      final tx = delta.x / segLen;
      final tz = delta.z / segLen;
      final dropNormal = Vec3(-tz, 0, tx);

      final topElevation = terrace.topElevation;
      final baseElevation = topElevation - terrace.riseMeters;
      final batterOffset = terrace.riseMeters * 0.35;

      final wallTopA = Vec3(pA.x, topElevation, pA.z);
      final wallTopB = Vec3(pB.x, topElevation, pB.z);
      final wallBaseA =
          wallTopA +
          dropNormal * batterOffset +
          Vec3(0, baseElevation - topElevation, 0);
      final wallBaseB =
          wallTopB +
          dropNormal * batterOffset +
          Vec3(0, baseElevation - topElevation, 0);

      final w0 = builder.addVertex(wallBaseA.toVector3());
      final w1 = builder.addVertex(wallBaseB.toVector3());
      final w2 = builder.addVertex(wallTopB.toVector3());
      final w3 = builder.addVertex(wallTopA.toVector3());

      builder
        ..addTriangle(w0, w1, w2)
        ..addTriangle(w0, w2, w3);

      final copTopA =
          wallTopA + const Vec3(0, copingLift, 0) + dropNormal * 0.08;
      final copTopB =
          wallTopB + const Vec3(0, copingLift, 0) + dropNormal * 0.08;
      final copInA = copTopA - dropNormal * copingWidth;
      final copInB = copTopB - dropNormal * copingWidth;
      final copBotA = copTopA - const Vec3(0, copingThickness, 0);
      final copBotB = copTopB - const Vec3(0, copingThickness, 0);
      final copBotInA = copInA - const Vec3(0, copingThickness, 0);
      final copBotInB = copInB - const Vec3(0, copingThickness, 0);

      final ct0 = builder.addVertex(copTopA.toVector3());
      final ct1 = builder.addVertex(copTopB.toVector3());
      final ct2 = builder.addVertex(copInB.toVector3());
      final ct3 = builder.addVertex(copInA.toVector3());

      builder
        ..addTriangle(ct0, ct1, ct2)
        ..addTriangle(ct0, ct2, ct3);

      final cf0 = builder.addVertex(copBotA.toVector3());
      final cf1 = builder.addVertex(copBotB.toVector3());
      final cf2 = builder.addVertex(copTopB.toVector3());
      final cf3 = builder.addVertex(copTopA.toVector3());

      builder
        ..addTriangle(cf0, cf1, cf2)
        ..addTriangle(cf0, cf2, cf3);

      final ci0 = builder.addVertex(copInA.toVector3());
      final ci1 = builder.addVertex(copInB.toVector3());
      final ci2 = builder.addVertex(copBotInB.toVector3());
      final ci3 = builder.addVertex(copBotInA.toVector3());

      builder
        ..addTriangle(ci0, ci1, ci2)
        ..addTriangle(ci0, ci2, ci3);
    }

    final mesh = Mesh(
      builder.build(),
      resolveMaterial(ShukubaSurfaceRole.ishigakiStone),
    );
    return Node(mesh: mesh);
  }
}
