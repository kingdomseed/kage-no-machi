import 'dart:math' as math;

import 'package:flutter_scene/scene.dart'
    show GeometryBuilder, Mesh, MeshGeometry, Node;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        CourtyardWall,
        GroundHeightSampler,
        PlacedStructure,
        RoadSpline,
        ShukubaMaterialResolver,
        ShukubaSurfaceRole,
        TerraceCourse,
        Vec3;
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart'
    show EdoKitBuilder;
import 'package:vector_math/vector_math.dart' show Vector2, Vector3, Vector4;

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
  static const double bridgeArchCamber = 0.48;

  static const double riverBedElevation = -1.85;
  static const double waterSurfaceElevation = -0.55;
  static const double riverBankHalfWidth = 2.25;
  static const double riverTransitionWidth = 1.25;

  static double riverCenterX(double z) =>
      1.05 * math.sin(z * 0.09) + 0.25 * math.sin(z * 0.22);

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
    final kaidoRamp = 1.0 - ((z.abs() - 2.0) / 1.2).clamp(0.0, 1.0);
    final eastForeshore = 0.05 + (1.80 - 0.05) * kaidoRamp;
    final eastTerrace = x < 6.50 ? eastForeshore : (x < 15.5 ? 1.80 : 3.40);

    if (dist <= TerrainConfig.riverBankHalfWidth) {
      final shoal = 0.09 * math.sin(z * 0.35) * math.cos(x * 0.45);
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

  static double horizontalDistanceToSegment(
    double px,
    double pz,
    Vec3 a,
    Vec3 b,
  ) {
    final abx = b.x - a.x;
    final abz = b.z - a.z;
    final lenSq = abx * abx + abz * abz;
    if (lenSq <= 1e-8) {
      final dx = px - a.x;
      final dz = pz - a.z;
      return math.sqrt(dx * dx + dz * dz);
    }
    final t = (((px - a.x) * abx + (pz - a.z) * abz) / lenSq).clamp(0.0, 1.0);
    final cx = a.x + abx * t;
    final cz = a.z + abz * t;
    final dx = px - cx;
    final dz = pz - cz;
    return math.sqrt(dx * dx + dz * dz);
  }

  static double signedFootprintMargin(double px, double pz, PlacedStructure s) {
    final dx = px - s.position.x;
    final dz = pz - s.position.z;
    final cy = math.cos(-s.yawRadians);
    final sy = math.sin(-s.yawRadians);
    final lx = (dx * cy + dz * sy).abs();
    final lz = (-dx * sy + dz * cy).abs();
    final spec = s.kind.spec;
    final mx = lx - spec.footprintWidth * 0.5;
    final mz = lz - spec.footprintDepth * 0.5;
    if (mx <= 0 && mz <= 0) {
      return math.max(mx, mz);
    }
    final ox = math.max<double>(0, mx);
    final oz = math.max<double>(0, mz);
    return math.sqrt(ox * ox + oz * oz);
  }

  MeshGeometry buildTerrainGeometry({
    Iterable<TerraceCourse> terraces = const [],
    Iterable<RoadSpline> roads = const [],
    Iterable<PlacedStructure> structures = const [],
  }) {
    final builder = GeometryBuilder();
    const minX = TerrainConfig.minX;
    const maxX = TerrainConfig.maxX;
    const minZ = TerrainConfig.minZ;
    const maxZ = TerrainConfig.maxZ;
    const step = TerrainConfig.gridStep;

    final roadList = roads.toList();
    final terraceList = terraces.toList();
    final buildingList = [
      for (final s in structures)
        if (!s.kind.isBotanicalTree) s,
    ];

    final cols = ((maxX - minX) / step).round() + 1;
    final rows = ((maxZ - minZ) / step).round() + 1;

    for (var r = 0; r < rows; r++) {
      final z = minZ + r * step;
      final v = (z - minZ) / (maxZ - minZ);
      for (var c = 0; c < cols; c++) {
        final x = minX + c * step;
        final u = (x - minX) / (maxX - minX);
        final y = sampleRawTerrain(x, z);
        final rivX = TerrainConfig.riverCenterX(z);
        final rivDist = (x - rivX).abs();

        var roadWear = 0.0;
        if (roadList.isEmpty) {
          roadWear = 1.0 - (z.abs() - 1.8).clamp(0.0, 4.6) / 4.6;
        } else {
          for (final road in roadList) {
            final hw = road.widthMeters * 0.5;
            for (var i = 0; i < road.controlPoints.length - 1; i++) {
              final d = horizontalDistanceToSegment(
                x,
                z,
                road.controlPoints[i],
                road.controlPoints[i + 1],
              );
              final w = 1.0 - ((d - hw) / 2.8).clamp(0.0, 1.0);
              if (w > roadWear) {
                roadWear = w;
              }
            }
          }
        }

        var yardWear = 0.0;
        var plinthDamp = 0.0;
        for (final s in buildingList) {
          final margin = signedFootprintMargin(x, z, s);
          final yw = 1.0 - (margin / 2.4).clamp(0.0, 1.0);
          if (yw > yardWear) {
            yardWear = yw;
          }
          if (margin > -0.3 && margin < 0.75) {
            final pd = 1.0 - margin.abs() / 0.75;
            if (pd > plinthDamp) {
              plinthDamp = pd;
            }
          }
        }

        var terraceMoss = 0.0;
        for (final t in terraceList) {
          for (var i = 0; i < t.crestPoints.length - 1; i++) {
            final d = horizontalDistanceToSegment(
              x,
              z,
              t.crestPoints[i],
              t.crestPoints[i + 1],
            );
            final tm = 1.0 - (d / 2.2).clamp(0.0, 1.0);
            if (tm > terraceMoss) {
              terraceMoss = tm;
            }
          }
        }

        final bankWet = 1.0 - ((rivDist - 2.3) / 2.7).clamp(0.0, 1.0);
        final patch =
            0.5 + 0.5 * math.sin(x * 0.22 + z * 0.17) * math.cos(z * 0.29);
        final meadow =
            0.5 + 0.5 * math.cos(x * 0.11 - z * 0.13) * math.sin(x * 0.19);

        var rCol = 0.48 + 0.24 * patch + 0.12 * meadow;
        var gCol = 0.84 + 0.20 * patch - 0.05 * meadow;
        var bCol = 0.40 + 0.14 * patch;

        rCol = rCol * (1 - terraceMoss * 0.45) + 0.30 * terraceMoss * 0.45;
        gCol = gCol * (1 - terraceMoss * 0.45) + 0.74 * terraceMoss * 0.45;
        bCol = bCol * (1 - terraceMoss * 0.45) + 0.28 * terraceMoss * 0.45;

        final totalWear = math.max(roadWear * 0.84, yardWear * 0.76);
        rCol = rCol * (1 - totalWear) + 1.18 * totalWear;
        gCol = gCol * (1 - totalWear) + 0.88 * totalWear;
        bCol = bCol * (1 - totalWear) + 0.62 * totalWear;

        final dampShade = 1.0 - 0.28 * plinthDamp;
        rCol *= dampShade;
        gCol *= dampShade;
        bCol *= dampShade;

        final finalR = rCol * (1 - bankWet * 0.62) + 0.34 * bankWet * 0.62;
        final finalG = gCol * (1 - bankWet * 0.62) + 0.44 * bankWet * 0.62;
        final finalB = bCol * (1 - bankWet * 0.62) + 0.48 * bankWet * 0.62;
        final wearAlpha = math.max(totalWear, bankWet * 0.65);

        builder
          ..color(Vector4(finalR, finalG, finalB, wearAlpha))
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
    Iterable<RoadSpline> roads = const [],
    Iterable<PlacedStructure> structures = const [],
  }) {
    final mesh = Mesh(
      buildTerrainGeometry(
        terraces: terraces,
        roads: roads,
        structures: structures,
      ),
      resolveMaterial(ShukubaSurfaceRole.packedEarth),
    );
    return Node(mesh: mesh);
  }

  Node buildWaterNode(ShukubaMaterialResolver resolveMaterial) {
    final builder = GeometryBuilder();
    const minZ = TerrainConfig.minZ;
    const maxZ = TerrainConfig.maxZ;
    const lengthSegs = 64;
    const crossSegs = 4;
    const zStep = (maxZ - minZ) / lengthSegs;
    const waterY = TerrainConfig.waterSurfaceElevation;
    const halfWidth = 3.40;
    const cols = crossSegs + 1;

    for (var i = 0; i <= lengthSegs; i++) {
      final z = minZ + i * zStep;
      final cX = TerrainConfig.riverCenterX(z);
      final v = i / lengthSegs;
      for (var c = 0; c <= crossSegs; c++) {
        final u = c / crossSegs;
        final x = cX + (u * 2 - 1) * halfWidth;
        builder
          ..texCoord(Vector2(u, v * 8.5))
          ..addVertex(Vector3(x, waterY, z));
      }
    }

    for (var i = 0; i < lengthSegs; i++) {
      for (var c = 0; c < crossSegs; c++) {
        final v00 = i * cols + c;
        final v01 = v00 + 1;
        final v10 = v00 + cols;
        final v11 = v10 + 1;
        builder
          ..addTriangle(v00, v10, v01)
          ..addTriangle(v01, v10, v11);
      }
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
    final stoneMat = resolveMaterial(ShukubaSurfaceRole.ishigakiStone);
    final lacquerMat = resolveMaterial(ShukubaSurfaceRole.vermilionLacquer);

    final plankBuilder = GeometryBuilder();
    const plankCount = 26;
    const x0 = TerrainConfig.bridgeMinX;
    const x1 = TerrainConfig.bridgeMaxX;
    const step = (x1 - x0) / plankCount;
    const zLeft = -1.74;
    const zRight = 1.74;
    const plankThick = 0.09;

    for (var i = 0; i < plankCount; i++) {
      final pxA = x0 + i * step + 0.022;
      final pxB = x0 + (i + 1) * step - 0.022;
      final pxMid = (pxA + pxB) * 0.5;
      final jitter = 0.008 * math.sin(i * 2.3 + 0.7);
      final yTop = TerrainConfig.bridgeDeckHeightAt(pxMid) + jitter;
      final yBot = yTop - plankThick;
      final tone = 0.90 + 0.22 * (0.5 + 0.5 * math.sin(i * 3.7 + 1.1));
      EdoKitBuilder.addBox(
        plankBuilder,
        Vector3(pxA, yBot, zLeft),
        Vector3(pxB, yTop, zRight),
        color: Vector4(tone * 1.06, tone, tone * 0.92, 1),
      );
    }
    root.add(Node(mesh: Mesh(plankBuilder.build(), timberMat)));

    final structureBuilder = GeometryBuilder();
    const stringerSegs = 16;
    const sStep = (x1 - x0) / stringerSegs;
    for (final sZ in const [-1.34, 0.0, 1.34]) {
      for (var i = 0; i < stringerSegs; i++) {
        final sxA = x0 + i * sStep;
        final sxB = sxA + sStep - 0.015;
        final yA = TerrainConfig.bridgeDeckHeightAt(sxA) - 0.11;
        final yB = TerrainConfig.bridgeDeckHeightAt(sxB) - 0.11;
        final pA = Vec3(sxA, yA - 0.08, sZ);
        final pB = Vec3(sxB, yB - 0.08, sZ);
        EdoKitBuilder.addCordSegment(structureBuilder, pA, pB, halfThick: 0.07);
      }
    }

    const postXList = [-5.0, -3.35, -1.68, 0.0, 1.68, 3.35, 5.0];
    final finialBuilder = GeometryBuilder();
    for (final px in postXList) {
      final yDeck = TerrainConfig.bridgeDeckHeightAt(px);
      for (final side in const [-1.85, 1.85]) {
        EdoKitBuilder.addBox(
          structureBuilder,
          Vector3(px - 0.065, yDeck - 0.22, side - 0.065),
          Vector3(px + 0.065, yDeck + 0.88, side + 0.065),
        );
        EdoKitBuilder.addBox(
          finialBuilder,
          Vector3(px - 0.08, yDeck + 0.90, side - 0.08),
          Vector3(px + 0.08, yDeck + 0.95, side + 0.08),
        );
        EdoKitBuilder.addBox(
          finialBuilder,
          Vector3(px - 0.05, yDeck + 0.96, side - 0.05),
          Vector3(px + 0.05, yDeck + 1.07, side + 0.05),
        );
      }
    }

    for (var i = 0; i < postXList.length - 1; i++) {
      final pxA = postXList[i] + 0.08;
      final pxB = postXList[i + 1] - 0.08;
      final yA = TerrainConfig.bridgeDeckHeightAt(pxA);
      final yB = TerrainConfig.bridgeDeckHeightAt(pxB);
      for (final side in const [-1.85, 1.85]) {
        EdoKitBuilder.addCordSegment(
          structureBuilder,
          Vec3(pxA, yA + 0.74, side),
          Vec3(pxB, yB + 0.74, side),
          halfThick: 0.036,
        );
        EdoKitBuilder.addCordSegment(
          structureBuilder,
          Vec3(pxA, yA + 0.38, side),
          Vec3(pxB, yB + 0.38, side),
          halfThick: 0.030,
        );
      }
    }

    final footingBuilder = GeometryBuilder();
    for (final pierX in const [-2.25, 2.25]) {
      final yUnderside = TerrainConfig.bridgeDeckHeightAt(pierX) - 0.20;
      EdoKitBuilder.addBox(
        structureBuilder,
        Vector3(pierX - 0.11, yUnderside - 0.16, -1.52),
        Vector3(pierX + 0.11, yUnderside, 1.52),
      );
      for (final pZ in const [-1.25, 0.0, 1.25]) {
        EdoKitBuilder.addRockBoulder(
          footingBuilder,
          Vector3(pierX, -1.10, pZ),
          Vector3(0.36, 0.68, 0.42),
          yaw: pierX * 0.4 + pZ * 0.3,
          seed: pierX + pZ,
        );
        EdoKitBuilder.addBox(
          structureBuilder,
          Vector3(pierX - 0.095, -0.38, pZ - 0.095),
          Vector3(pierX + 0.095, yUnderside - 0.18, pZ + 0.095),
        );
      }
    }

    for (final abutmentX in const [-5.28, 5.28]) {
      final yEnd = TerrainConfig.bridgeDeckHeightAt(abutmentX);
      EdoKitBuilder.addBox(
        footingBuilder,
        Vector3(abutmentX - 0.26, yEnd - 1.35, -1.96),
        Vector3(abutmentX + 0.26, yEnd - 0.12, 1.96),
      );
    }

    root
      ..add(Node(mesh: Mesh(footingBuilder.build(), stoneMat)))
      ..add(Node(mesh: Mesh(structureBuilder.build(), timberMat)))
      ..add(Node(mesh: Mesh(finialBuilder.build(), lacquerMat)));
    return root;
  }

  Node buildGorgeDressingNode(ShukubaMaterialResolver resolveMaterial) {
    final root = Node();
    final rockBuilder = GeometryBuilder();
    final timberBuilder = GeometryBuilder();
    final shrubBuilder = GeometryBuilder();

    const shoalSpecs = [
      (-24.5, -1.45, 0.88, 0.56, 0.72, 0.4),
      (-16.2, 1.55, 0.96, 0.58, 0.80, 1.3),
      (-9.4, -1.35, 0.78, 0.50, 0.68, 2.2),
      (8.2, 1.40, 0.86, 0.54, 0.74, 0.9),
      (15.6, -1.55, 1.04, 0.60, 0.84, 1.8),
      (23.8, 1.30, 0.82, 0.52, 0.70, 2.7),
    ];

    for (final s in shoalSpecs) {
      final z = s.$1;
      final x = TerrainConfig.riverCenterX(z) + s.$2;
      EdoKitBuilder.addRockBoulder(
        rockBuilder,
        Vector3(x, -0.68, z),
        Vector3(s.$3, s.$4, s.$5),
        yaw: s.$6,
        seed: z * 0.3,
      );
      final sideShift = s.$2 < 0 ? 0.96 : -0.96;
      EdoKitBuilder.addRockBoulder(
        rockBuilder,
        Vector3(x + sideShift * 0.55, -0.78, z + 1.05),
        Vector3(s.$3 * 0.56, s.$4 * 0.68, s.$5 * 0.58),
        yaw: s.$6 + 1.4,
        seed: z * 0.5 + 1.7,
      );
    }

    const bankSpecs = [
      (-21.0, -3.55, 1.25, 0.72, 1.05, 0.5, true),
      (-13.2, -3.40, 1.08, 0.62, 0.92, 1.7, false),
      (-6.2, -3.30, 0.92, 0.56, 0.82, 2.4, true),
      (6.4, -3.45, 1.02, 0.60, 0.88, 0.8, true),
      (13.8, -3.50, 1.18, 0.68, 0.98, 2.1, false),
      (22.0, -3.60, 1.28, 0.74, 1.08, 1.2, true),
      (-19.5, 3.45, 1.16, 0.68, 0.96, 1.1, true),
      (-11.0, 3.35, 0.96, 0.58, 0.86, 2.6, false),
      (9.8, 3.40, 1.10, 0.64, 0.94, 0.3, true),
      (18.4, 3.50, 1.22, 0.70, 1.02, 1.9, false),
    ];

    for (final b in bankSpecs) {
      final z = b.$1;
      final x = TerrainConfig.riverCenterX(z) + b.$2;
      final groundY = sampleRawTerrain(x, z);
      EdoKitBuilder.addRockBoulder(
        rockBuilder,
        Vector3(x, groundY + 0.14, z),
        Vector3(b.$3, b.$4, b.$5),
        yaw: b.$6,
        seed: z * 0.5 + b.$2,
      );
      if (b.$7) {
        final sx = x + (b.$2 < 0 ? -0.95 : 0.95);
        final sz = z + 0.72;
        final sy = sampleRawTerrain(sx, sz);
        EdoKitBuilder.addShrubRosette(
          shrubBuilder,
          Vector3(sx, sy + 0.06, sz),
          Vector3(0.86, 0.38, 0.80),
          color: Vector4(0.84, 0.98, 0.74, 1),
          phase: b.$6,
        );
      }
    }

    const meadowOutcrops = [
      (-23.5, -20.0, 1.45, 0.78, 1.18, 0.6),
      (-24.8, 19.5, 1.38, 0.72, 1.10, 1.9),
      (22.5, -19.5, 1.42, 0.76, 1.15, 1.1),
      (23.8, 21.0, 1.50, 0.82, 1.22, 2.4),
    ];
    for (final m in meadowOutcrops) {
      final mx = m.$1;
      final mz = m.$2;
      final my = sampleRawTerrain(mx, mz);
      EdoKitBuilder.addRockBoulder(
        rockBuilder,
        Vector3(mx, my + 0.16, mz),
        Vector3(m.$3, m.$4, m.$5),
        yaw: m.$6,
        seed: mx * 0.3 + mz * 0.2,
      );
      EdoKitBuilder.addRockBoulder(
        rockBuilder,
        Vector3(mx + 0.95, my + 0.08, mz + 0.65),
        Vector3(m.$3 * 0.58, m.$4 * 0.62, m.$5 * 0.56),
        yaw: m.$6 + 1.2,
        seed: mx * 0.5 - mz * 0.4,
      );
      EdoKitBuilder.addShrubRosette(
        shrubBuilder,
        Vector3(mx - 0.85, my + 0.06, mz + 0.55),
        Vector3(0.92, 0.40, 0.86),
        color: Vector4(0.86, 1.02, 0.76, 1),
        phase: m.$6,
      );
    }

    for (final span in const [(-5.4, -3.4), (3.4, 5.4)]) {
      const count = 6;
      for (var i = 0; i < count; i++) {
        final z = span.$1 + (span.$2 - span.$1) * (i / (count - 1));
        final x = TerrainConfig.riverCenterX(z) - 2.92;
        final y = sampleRawTerrain(x, z);
        EdoKitBuilder.addBox(
          timberBuilder,
          Vector3(x - 0.045, y - 0.45, z - 0.045),
          Vector3(x + 0.045, y + 0.46 + (i.isEven ? 0.06 : 0.0), z + 0.045),
        );
      }
    }

    root
      ..add(
        Node(
          mesh: Mesh(
            rockBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.ishigakiStone),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            timberBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.charredTimber),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            shrubBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.bambooCanopy),
          ),
        ),
      );
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
    final root = Node();
    final stoneMaterial = resolveMaterial(ShukubaSurfaceRole.ishigakiStone);
    const copingProud = 0.14;
    const frontLip = 0.20;
    const backSetback = 1.15;

    void emitWallSpan(Vec3 spanA, Vec3 spanB) {
      final delta = spanB - spanA;
      final segLen = delta.horizontalLength;
      if (segLen <= 1e-4) {
        return;
      }
      final along = Vec3(delta.x / segLen, 0, delta.z / segLen);
      final dropNormal = terrace.dropNormalBetween(spanA, spanB);

      final topY = terrace.topElevation;
      final copTopY = topY + copingProud;
      final baseY = topY - terrace.riseMeters - 0.45;
      final backBaseY = topY - 0.35;
      final batter = (copTopY - baseY) * 0.22;

      final nFront = Vector3(dropNormal.x, 0.22, dropNormal.z);
      final nBack = Vector3(-dropNormal.x, 0, -dropNormal.z);
      final nTop = Vector3(0, 1, 0);
      final nStart = Vector3(-along.x, 0, -along.z);
      final nEnd = Vector3(along.x, 0, along.z);

      final chunks = math.max(1, (segLen / 4.2).ceil());
      for (var k = 0; k < chunks; k++) {
        final cA = Vec3.lerp(spanA, spanB, k / chunks);
        final cB = Vec3.lerp(spanA, spanB, (k + 1) / chunks);
        final builder = GeometryBuilder();

        final fbA = (Vec3(cA.x, baseY, cA.z) + dropNormal * (frontLip + batter))
            .toVector3();
        final fbB = (Vec3(cB.x, baseY, cB.z) + dropNormal * (frontLip + batter))
            .toVector3();
        final fcA = (Vec3(cA.x, copTopY, cA.z) + dropNormal * frontLip)
            .toVector3();
        final fcB = (Vec3(cB.x, copTopY, cB.z) + dropNormal * frontLip)
            .toVector3();
        final bcA = (Vec3(cA.x, copTopY, cA.z) - dropNormal * backSetback)
            .toVector3();
        final bcB = (Vec3(cB.x, copTopY, cB.z) - dropNormal * backSetback)
            .toVector3();
        final bbA = (Vec3(cA.x, backBaseY, cA.z) - dropNormal * backSetback)
            .toVector3();
        final bbB = (Vec3(cB.x, backBaseY, cB.z) - dropNormal * backSetback)
            .toVector3();

        EdoKitBuilder.addQuadOutward(
          builder,
          fbA,
          fbB,
          fcB,
          fcA,
          nFront,
          uvScale: 0.45,
        );
        EdoKitBuilder.addQuadOutward(
          builder,
          fcA,
          fcB,
          bcB,
          bcA,
          nTop,
          uvScale: 0.45,
        );
        EdoKitBuilder.addQuadOutward(
          builder,
          bbA,
          bbB,
          bcB,
          bcA,
          nBack,
          uvScale: 0.45,
        );
        if (k == 0) {
          EdoKitBuilder.addQuadOutward(
            builder,
            fbA,
            fcA,
            bcA,
            bbA,
            nStart,
            uvScale: 0.45,
          );
        }
        if (k == chunks - 1) {
          EdoKitBuilder.addQuadOutward(
            builder,
            fbB,
            fcB,
            bcB,
            bbB,
            nEnd,
            uvScale: 0.45,
          );
        }
        root.add(Node(mesh: Mesh(builder.build(), stoneMaterial)));
      }
    }

    const gapHalfZ = 3.60;
    for (var i = 0; i < terrace.crestPoints.length - 1; i++) {
      final pA = terrace.crestPoints[i];
      final pB = terrace.crestPoints[i + 1];
      final crossesKaidoCorridor =
          (pA.x.abs() < 16 && pB.x.abs() < 16) &&
          ((pA.z < -gapHalfZ && pB.z > gapHalfZ) ||
              (pB.z < -gapHalfZ && pA.z > gapHalfZ));
      if (!crossesKaidoCorridor) {
        emitWallSpan(pA, pB);
        continue;
      }
      final tNeg = (-gapHalfZ - pA.z) / (pB.z - pA.z);
      final tPos = (gapHalfZ - pA.z) / (pB.z - pA.z);
      final tFirst = math.min(tNeg, tPos).clamp(0.0, 1.0);
      final tSecond = math.max(tNeg, tPos).clamp(0.0, 1.0);
      emitWallSpan(pA, Vec3.lerp(pA, pB, tFirst));
      emitWallSpan(Vec3.lerp(pA, pB, tSecond), pB);
    }

    return root;
  }

  Node buildWallNode(
    CourtyardWall wall,
    ShukubaMaterialResolver resolveMaterial,
    GroundHeightSampler sampleGroundY,
  ) {
    final root = Node();
    final stoneMat = resolveMaterial(ShukubaSurfaceRole.ishigakiStone);
    final plasterMat = resolveMaterial(ShukubaSurfaceRole.kuraPlaster);
    final timberMat = resolveMaterial(ShukubaSurfaceRole.charredTimber);
    final roofMat = resolveMaterial(ShukubaSurfaceRole.kawaraTile);

    final postHalf = wall.thicknessMeters * 0.62;
    final postClear = wall.thicknessMeters * 0.68;

    final postTimber = GeometryBuilder();
    final postCaps = GeometryBuilder();
    for (final cp in wall.controlPoints) {
      final gy = sampleGroundY(cp.x, cp.z);
      final topY = gy + wall.heightMeters;
      EdoKitBuilder.addBox(
        postTimber,
        Vector3(cp.x - postHalf, gy - 0.55, cp.z - postHalf),
        Vector3(cp.x + postHalf, topY - 0.14, cp.z + postHalf),
      );
      final capHalf = postHalf + 0.09;
      EdoKitBuilder.addBox(
        postCaps,
        Vector3(cp.x - capHalf, topY - 0.12, cp.z - capHalf),
        Vector3(cp.x + capHalf, topY + 0.05, cp.z + capHalf),
      );
    }
    root
      ..add(Node(mesh: Mesh(postTimber.build(), timberMat)))
      ..add(Node(mesh: Mesh(postCaps.build(), roofMat)));

    void emitPrismBay(
      GeometryBuilder builder,
      Vec3 a,
      Vec3 b,
      Vec3 rightN, {
      required double halfWidth,
      required double yBotA,
      required double yTopA,
      required double yBotB,
      required double yTopB,
      required bool capStart,
      required bool capEnd,
    }) {
      final along = (b - a).normalizedHorizontal();
      final nLeft = Vector3(-rightN.x, 0, -rightN.z);
      final nRight = Vector3(rightN.x, 0, rightN.z);
      final nTop = Vector3(0, 1, 0);
      final nStart = Vector3(-along.x, 0, -along.z);
      final nEnd = Vector3(along.x, 0, along.z);

      final lbA = (Vec3(a.x, yBotA, a.z) - rightN * halfWidth).toVector3();
      final lbB = (Vec3(b.x, yBotB, b.z) - rightN * halfWidth).toVector3();
      final ltA = (Vec3(a.x, yTopA, a.z) - rightN * halfWidth).toVector3();
      final ltB = (Vec3(b.x, yTopB, b.z) - rightN * halfWidth).toVector3();
      final rbA = (Vec3(a.x, yBotA, a.z) + rightN * halfWidth).toVector3();
      final rbB = (Vec3(b.x, yBotB, b.z) + rightN * halfWidth).toVector3();
      final rtA = (Vec3(a.x, yTopA, a.z) + rightN * halfWidth).toVector3();
      final rtB = (Vec3(b.x, yTopB, b.z) + rightN * halfWidth).toVector3();

      EdoKitBuilder.addQuadOutward(builder, lbA, lbB, ltB, ltA, nLeft);
      EdoKitBuilder.addQuadOutward(builder, rbA, rbB, rtB, rtA, nRight);
      EdoKitBuilder.addQuadOutward(builder, ltA, ltB, rtB, rtA, nTop);
      if (capStart) {
        EdoKitBuilder.addQuadOutward(builder, lbA, ltA, rtA, rbA, nStart);
      }
      if (capEnd) {
        EdoKitBuilder.addQuadOutward(builder, lbB, ltB, rtB, rbB, nEnd);
      }
    }

    for (var i = 0; i < wall.controlPoints.length - 1; i++) {
      final rawA = wall.controlPoints[i];
      final rawB = wall.controlPoints[i + 1];
      final delta = rawB - rawA;
      final rawLen = delta.horizontalLength;
      if (rawLen <= postClear * 2 + 0.08) {
        continue;
      }
      final along = Vec3(delta.x / rawLen, 0, delta.z / rawLen);
      final rightN = Vec3(-along.z, 0, along.x);
      final spanA = rawA + along * postClear;
      final spanB = rawB - along * postClear;
      final clearLen = rawLen - postClear * 2;
      final chunks = math.max(1, (clearLen / 3.2).ceil());

      for (var k = 0; k < chunks; k++) {
        final cA = Vec3.lerp(spanA, spanB, k / chunks);
        final cB = Vec3.lerp(spanA, spanB, (k + 1) / chunks);
        final gyA = sampleGroundY(cA.x, cA.z);
        final gyB = sampleGroundY(cB.x, cB.z);
        final capStart = k == 0;
        final capEnd = k == chunks - 1;

        final bayStone = GeometryBuilder();
        emitPrismBay(
          bayStone,
          cA,
          cB,
          rightN,
          halfWidth: wall.thicknessMeters * 0.56,
          yBotA: gyA - 0.55,
          yTopA: gyA + 0.42,
          yBotB: gyB - 0.55,
          yTopB: gyB + 0.42,
          capStart: capStart,
          capEnd: capEnd,
        );

        final bayPlaster = GeometryBuilder();
        emitPrismBay(
          bayPlaster,
          cA,
          cB,
          rightN,
          halfWidth: wall.thicknessMeters * 0.44,
          yBotA: gyA + 0.44,
          yTopA: gyA + wall.heightMeters - 0.28,
          yBotB: gyB + 0.44,
          yTopB: gyB + wall.heightMeters - 0.28,
          capStart: capStart,
          capEnd: capEnd,
        );

        final bayTimber = GeometryBuilder();
        emitPrismBay(
          bayTimber,
          cA,
          cB,
          rightN,
          halfWidth: wall.thicknessMeters * 0.50,
          yBotA: gyA + wall.heightMeters - 0.26,
          yTopA: gyA + wall.heightMeters - 0.18,
          yBotB: gyB + wall.heightMeters - 0.26,
          yTopB: gyB + wall.heightMeters - 0.18,
          capStart: capStart,
          capEnd: capEnd,
        );

        final bayRoof = GeometryBuilder();
        final eaveHalf = wall.thicknessMeters * 0.96;
        final eaveYA = gyA + wall.heightMeters - 0.16;
        final eaveYB = gyB + wall.heightMeters - 0.16;
        final ridgeYA = gyA + wall.heightMeters + 0.08;
        final ridgeYB = gyB + wall.heightMeters + 0.08;

        final lEaveA = (Vec3(cA.x, eaveYA, cA.z) - rightN * eaveHalf)
            .toVector3();
        final lEaveB = (Vec3(cB.x, eaveYB, cB.z) - rightN * eaveHalf)
            .toVector3();
        final rEaveA = (Vec3(cA.x, eaveYA, cA.z) + rightN * eaveHalf)
            .toVector3();
        final rEaveB = (Vec3(cB.x, eaveYB, cB.z) + rightN * eaveHalf)
            .toVector3();
        final ridgeA = Vector3(cA.x, ridgeYA, cA.z);
        final ridgeB = Vector3(cB.x, ridgeYB, cB.z);

        EdoKitBuilder.addQuadOutward(
          bayRoof,
          lEaveA,
          lEaveB,
          ridgeB,
          ridgeA,
          Vector3(-rightN.x * 0.5, 1, -rightN.z * 0.5),
          uvScale: 0.75,
        );
        EdoKitBuilder.addQuadOutward(
          bayRoof,
          ridgeA,
          ridgeB,
          rEaveB,
          rEaveA,
          Vector3(rightN.x * 0.5, 1, rightN.z * 0.5),
          uvScale: 0.75,
        );
        EdoKitBuilder.addQuadOutward(
          bayRoof,
          lEaveA,
          lEaveB,
          rEaveB,
          rEaveA,
          Vector3(0, -1, 0),
        );
        if (capStart) {
          EdoKitBuilder.addTriangleOutward(
            bayRoof,
            lEaveA,
            rEaveA,
            ridgeA,
            Vector3(-along.x, 0, -along.z),
          );
        }
        if (capEnd) {
          EdoKitBuilder.addTriangleOutward(
            bayRoof,
            lEaveB,
            rEaveB,
            ridgeB,
            Vector3(along.x, 0, along.z),
          );
        }

        root
          ..add(Node(mesh: Mesh(bayStone.build(), stoneMat)))
          ..add(Node(mesh: Mesh(bayPlaster.build(), plasterMat)))
          ..add(Node(mesh: Mesh(bayTimber.build(), timberMat)))
          ..add(Node(mesh: Mesh(bayRoof.build(), roofMat)));
      }
    }

    return root;
  }
}
