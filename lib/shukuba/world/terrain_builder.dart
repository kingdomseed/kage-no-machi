import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart'
    show GeometryBuilder, Mesh, MeshGeometry, Node;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        CourtyardWall,
        GroundHeightSampler,
        PlacedStructure,
        RoadSpline,
        RoadStyle,
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
  static const double gridStep = 0.5;

  static const double bridgeMinX = -5.2;
  static const double bridgeMaxX = 5.2;
  static const double bridgeMinZ = -1.8;
  static const double bridgeMaxZ = 1.8;
  static const double bridgeWestElevation = 0.40;
  static const double bridgeEastElevation = 1.80;
  static const double bridgeArchCamber = 0.48;

  static const double riverBedElevation = -1.85;
  static const double waterSurfaceElevation = -0.55;
  static const double riverBankHalfWidth = 2.15;
  static const double riverTransitionWidth = 1.85;

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

class _RoadTerraceCrossing {
  const new({
    required this.segIndex,
    required this.segT,
    required this.point,
    required this.along,
    required this.platNormal,
    required this.roadWidth,
    required this.isBridgeApproach,
    required this.lowY,
    required this.topY,
  });

  final int segIndex;
  final double segT;
  final Vec3 point;
  final Vec3 along;
  final Vec3 platNormal;
  final double roadWidth;
  final bool isBridgeApproach;
  final double lowY;
  final double topY;

  double get halfWallGap => roadWidth * 0.5 + (isBridgeApproach ? 0.88 : 0.42);
}

class TerrainBuilder {
  const new();

  static double _quintic(double t) {
    final c = t < 0 ? 0.0 : (t > 1 ? 1.0 : t);
    return c * c * c * (c * (c * 6 - 15) + 10);
  }

  double sampleRawTerrain(double x, double z) {
    final rivX = TerrainConfig.riverCenterX(z);
    final signed = x - rivX;
    final dist = signed.abs();

    final bridgeWestAnchor = math.exp(
      -(math.pow((x + 5.2) / 3.4, 2) + math.pow(z / 3.2, 2)),
    );
    final westUndulation =
        0.15 * math.sin(x * 0.11 + 0.35) * math.cos(z * 0.12 - 0.25) +
        0.07 * math.sin(z * 0.21 - x * 0.08);
    final westPlain = 0.40 + westUndulation * (1.0 - bridgeWestAnchor);

    final eastHillFrac = ((x - 5.4) / 26.5).clamp(0.0, 1.0);
    final eastHillBase =
        0.34 +
        2.95 * _quintic(eastHillFrac) +
        0.22 * math.sin(z * 0.10 + x * 0.06) * _quintic(eastHillFrac);
    final causewayX = 1.0 - _quintic(((x - 8.2).abs() - 3.2) / 3.8);
    final causewayZ = 1.0 - _quintic((z.abs() - 2.1) / 2.6);
    final bridgeEastMound = causewayX * causewayZ;
    final eastSlope =
        eastHillBase * (1.0 - bridgeEastMound) + 1.80 * bridgeEastMound;

    if (dist <= TerrainConfig.riverBankHalfWidth) {
      final shoal = 0.11 * math.sin(z * 0.34) * math.cos(x * 0.44);
      return TerrainConfig.riverBedElevation + shoal;
    }

    final bankTarget = signed < 0 ? westPlain : eastSlope;
    final rampFrac =
        (dist - TerrainConfig.riverBankHalfWidth) /
        TerrainConfig.riverTransitionWidth;
    if (rampFrac >= 1) {
      return bankTarget;
    }

    const benchY = -0.34;
    if (rampFrac < 0.42) {
      final u = _quintic(rampFrac / 0.42);
      return TerrainConfig.riverBedElevation +
          (benchY - TerrainConfig.riverBedElevation) * u;
    }
    final u = _quintic((rampFrac - 0.42) / 0.58);
    return benchY + (bankTarget - benchY) * u;
  }

  List<_RoadTerraceCrossing> _findCrossingsForTerrace(
    TerraceCourse terrace,
    List<RoadSpline> roads,
    List<TerraceCourse> allTerraces,
  ) {
    if (roads.isEmpty) {
      return const [];
    }
    final results = <_RoadTerraceCrossing>[];
    for (var i = 0; i < terrace.crestPoints.length - 1; i++) {
      final a = terrace.crestPoints[i];
      final b = terrace.crestPoints[i + 1];
      final abX = b.x - a.x;
      final abZ = b.z - a.z;
      final segLen = math.sqrt(abX * abX + abZ * abZ);
      if (segLen <= 1e-6) {
        continue;
      }
      final along = Vec3(abX / segLen, 0, abZ / segLen);
      final platN = terrace.platformNormalBetween(a, b);

      for (final road in roads) {
        final pts = road.smoothCenterline(stepMeters: 0.85);
        for (var j = 0; j < pts.length - 1; j++) {
          final r0 = pts[j];
          final r1 = pts[j + 1];
          final rx = r1.x - r0.x;
          final rz = r1.z - r0.z;
          final denom = abX * rz - abZ * rx;
          if (denom.abs() <= 1e-7) {
            continue;
          }
          final u = ((r0.x - a.x) * rz - (r0.z - a.z) * rx) / denom;
          final v = ((r0.x - a.x) * abZ - (r0.z - a.z) * abX) / denom;
          if (u < -0.02 || u > 1.02 || v < -0.02 || v > 1.02) {
            continue;
          }
          final clampedU = u.clamp(0.0, 1.0);
          final pt = Vec3.lerp(a, b, clampedU);
          final duplicate = results.any(
            (c) => c.point.horizontalDistanceTo(pt) < 2.2,
          );
          if (duplicate) {
            continue;
          }

          final footX = pt.x - platN.x * 1.95;
          final footZ = pt.z - platN.z * 1.95;
          var lowY = sampleRawTerrain(footX, footZ);
          for (final other in allTerraces) {
            if (identical(other, terrace) ||
                other.topElevation >= terrace.topElevation - 0.20) {
              continue;
            }
            lowY = other.sampleGradedElevation(footX, footZ, lowY);
          }
          lowY = math.min(lowY, terrace.topElevation - 0.35);

          results.add(
            _RoadTerraceCrossing(
              segIndex: i,
              segT: clampedU,
              point: pt,
              along: along,
              platNormal: platN,
              roadWidth: road.widthMeters,
              isBridgeApproach: road.isBridgeApproach,
              lowY: lowY,
              topY: terrace.topElevation,
            ),
          );
        }
      }
    }
    return results;
  }

  double _evaluateGradedPoint(
    double x,
    double z, {
    required List<TerraceCourse> sortedTerraces,
    required Map<TerraceCourse, List<_RoadTerraceCrossing>> crossingsByTerrace,
    required bool recessUnderStairs,
  }) {
    var height = sampleRawTerrain(x, z);
    for (var i = 0; i < sortedTerraces.length; i++) {
      final terrace = sortedTerraces[i];
      height = terrace.sampleGradedElevation(x, z, height);

      final crossings = crossingsByTerrace[terrace];
      if (crossings == null || crossings.isEmpty) {
        continue;
      }
      for (var k = 0; k < crossings.length; k++) {
        final c = crossings[k];
        if (c.isBridgeApproach) {
          continue;
        }
        final relX = x - c.point.x;
        final relZ = z - c.point.z;
        final uAlong = (relX * c.along.x + relZ * c.along.z).abs();
        final outerLat = c.halfWallGap + 0.65;
        if (uAlong >= outerLat) {
          continue;
        }
        final inward = relX * c.platNormal.x + relZ * c.platNormal.z;
        const inStart = -1.72;
        const inEnd = 0.94;
        if (inward < inStart - 0.45 || inward > inEnd + 0.45) {
          continue;
        }
        final latFrac =
            ((uAlong - (c.roadWidth * 0.5 + 0.06)) /
                    (outerLat - (c.roadWidth * 0.5 + 0.06)))
                .clamp(0.0, 1.0);
        final wLat = 1.0 - _quintic(latFrac);
        final endFade = inward < inStart
            ? 1.0 - _quintic((inStart - inward) / 0.45)
            : (inward > inEnd ? 1.0 - _quintic((inward - inEnd) / 0.45) : 1.0);
        final weight = wLat * endFade;
        if (weight <= 1e-5) {
          continue;
        }
        final f = ((inward - inStart) / (inEnd - inStart)).clamp(0.0, 1.0);
        var stairY = c.lowY + (c.topY - c.lowY) * (f * f * (3 - 2 * f));
        if (recessUnderStairs && uAlong <= c.halfWallGap) {
          stairY -= 0.16 * math.sin(f * math.pi);
        }
        height = height + (stairY - height) * weight;
      }
    }
    return height;
  }

  double sampleGroundHeight(
    double x,
    double z, {
    Iterable<TerraceCourse> terraces = const [],
    Iterable<RoadSpline> roads = const [],
  }) {
    if (TerrainConfig.isInsideBridgeFootprint(x, z)) {
      return TerrainConfig.bridgeDeckHeightAt(x);
    }

    final terraceList = terraces.toList();
    if (terraceList.isEmpty) {
      return sampleRawTerrain(x, z);
    }
    terraceList.sort((a, b) => a.topElevation.compareTo(b.topElevation));
    final roadList = roads.toList();
    final crossings = <TerraceCourse, List<_RoadTerraceCrossing>>{
      if (roadList.isNotEmpty)
        for (final t in terraceList)
          t: _findCrossingsForTerrace(t, roadList, terraceList),
    };
    return _evaluateGradedPoint(
      x,
      z,
      sortedTerraces: terraceList,
      crossingsByTerrace: crossings,
      recessUnderStairs: false,
    );
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

  ({
    int cols,
    int rows,
    Float64List heights,
    Float32List normals,
    Float32List colors,
  })
  _computeTerrainField({
    Iterable<TerraceCourse> terraces = const [],
    Iterable<RoadSpline> roads = const [],
    Iterable<PlacedStructure> structures = const [],
  }) {
    const minX = TerrainConfig.minX;
    const maxX = TerrainConfig.maxX;
    const minZ = TerrainConfig.minZ;
    const maxZ = TerrainConfig.maxZ;
    const step = TerrainConfig.gridStep;

    final cols = ((maxX - minX) / step).round() + 1;
    final rows = ((maxZ - minZ) / step).round() + 1;
    final count = rows * cols;

    final terraceList = terraces.toList()
      ..sort((a, b) => a.topElevation.compareTo(b.topElevation));
    final roadList = roads.toList();
    final crossings = <TerraceCourse, List<_RoadTerraceCrossing>>{
      if (roadList.isNotEmpty)
        for (final t in terraceList)
          t: _findCrossingsForTerrace(t, roadList, terraceList),
    };

    final roadSegAx = <double>[];
    final roadSegAz = <double>[];
    final roadSegBx = <double>[];
    final roadSegBz = <double>[];
    final roadSegHw = <double>[];
    for (final road in roadList) {
      final pts = road.smoothCenterline(stepMeters: 1.4);
      final hw = road.widthMeters * 0.5;
      for (var i = 0; i < pts.length - 1; i++) {
        roadSegAx.add(pts[i].x);
        roadSegAz.add(pts[i].z);
        roadSegBx.add(pts[i + 1].x);
        roadSegBz.add(pts[i + 1].z);
        roadSegHw.add(hw);
      }
    }

    final terSegAx = <double>[];
    final terSegAz = <double>[];
    final terSegBx = <double>[];
    final terSegBz = <double>[];
    for (final t in terraceList) {
      for (var i = 0; i < t.crestPoints.length - 1; i++) {
        terSegAx.add(t.crestPoints[i].x);
        terSegAz.add(t.crestPoints[i].z);
        terSegBx.add(t.crestPoints[i + 1].x);
        terSegBz.add(t.crestPoints[i + 1].z);
      }
    }

    final buildingList = <PlacedStructure>[
      for (final s in structures)
        if (!s.kind.isNaturalFeature) s,
    ];
    final naturalList = <PlacedStructure>[
      for (final s in structures)
        if (s.kind.isNaturalFeature) s,
    ];

    final heights = Float64List(count);
    final colors = Float32List(count * 4);

    for (var r = 0; r < rows; r++) {
      final z = minZ + r * step;
      final rivX = TerrainConfig.riverCenterX(z);
      for (var c = 0; c < cols; c++) {
        final idx = r * cols + c;
        final x = minX + c * step;
        final y = _evaluateGradedPoint(
          x,
          z,
          sortedTerraces: terraceList,
          crossingsByTerrace: crossings,
          recessUnderStairs: true,
        );
        heights[idx] = y;

        final rivDist = (x - rivX).abs();
        var roadWear = 0.0;
        for (var s = 0; s < roadSegAx.length; s++) {
          final ax = roadSegAx[s];
          final az = roadSegAz[s];
          final bx = roadSegBx[s];
          final bz = roadSegBz[s];
          final hw = roadSegHw[s];
          if (x < math.min(ax, bx) - hw - 3.0 ||
              x > math.max(ax, bx) + hw + 3.0 ||
              z < math.min(az, bz) - hw - 3.0 ||
              z > math.max(az, bz) + hw + 3.0) {
            continue;
          }
          final vx = bx - ax;
          final vz = bz - az;
          final lenSq = vx * vx + vz * vz;
          final t = lenSq <= 1e-8
              ? 0.0
              : (((x - ax) * vx + (z - az) * vz) / lenSq).clamp(0.0, 1.0);
          final dx = x - (ax + vx * t);
          final dz = z - (az + vz * t);
          final d = math.sqrt(dx * dx + dz * dz);
          final w = 1.0 - ((d - hw) / 2.6).clamp(0.0, 1.0);
          if (w > roadWear) {
            roadWear = w;
          }
        }

        var yardWear = 0.0;
        var plinthDamp = 0.0;
        for (var bIdx = 0; bIdx < buildingList.length; bIdx++) {
          final b = buildingList[bIdx];
          final dx = x - b.position.x;
          final dz = z - b.position.z;
          if (dx * dx + dz * dz > 42) {
            continue;
          }
          final margin = signedFootprintMargin(x, z, b);
          final yw = 1.0 - (margin / 2.5).clamp(0.0, 1.0);
          if (yw > yardWear) {
            yardWear = yw;
          }
          if (margin > -0.3 && margin < 0.78) {
            final pd = 1.0 - margin.abs() / 0.78;
            if (pd > plinthDamp) {
              plinthDamp = pd;
            }
          }
        }

        var habitatMoss = 0.0;
        for (var tIdx = 0; tIdx < terSegAx.length; tIdx++) {
          final ax = terSegAx[tIdx];
          final az = terSegAz[tIdx];
          final bx = terSegBx[tIdx];
          final bz = terSegBz[tIdx];
          if (x < math.min(ax, bx) - 2.8 ||
              x > math.max(ax, bx) + 2.8 ||
              z < math.min(az, bz) - 2.8 ||
              z > math.max(az, bz) + 2.8) {
            continue;
          }
          final vx = bx - ax;
          final vz = bz - az;
          final lenSq = vx * vx + vz * vz;
          final t = lenSq <= 1e-8
              ? 0.0
              : (((x - ax) * vx + (z - az) * vz) / lenSq).clamp(0.0, 1.0);
          final dx = x - (ax + vx * t);
          final dz = z - (az + vz * t);
          final tm = 1.0 - (math.sqrt(dx * dx + dz * dz) / 2.4).clamp(0.0, 1.0);
          if (tm > habitatMoss) {
            habitatMoss = tm;
          }
        }

        for (var nIdx = 0; nIdx < naturalList.length; nIdx++) {
          final n = naturalList[nIdx];
          final dx = x - n.position.x;
          final dz = z - n.position.z;
          final dSq = dx * dx + dz * dz;
          if (dSq < 11.5) {
            final nm = 1.0 - (math.sqrt(dSq) / 3.35).clamp(0.0, 1.0);
            if (nm > habitatMoss) {
              habitatMoss = nm;
            }
          }
        }

        final bankWet = 1.0 - ((rivDist - 2.2) / 2.8).clamp(0.0, 1.0);
        final wx = x + 2.2 * math.sin(z * 0.14 + 0.5);
        final wz = z + 2.2 * math.cos(x * 0.15 - 0.3);
        final warmWash =
            0.5 + 0.5 * math.sin(wx * 0.16 + wz * 0.13) * math.cos(wz * 0.19);

        var rCol = 0.88 + 0.18 * warmWash;
        var gCol = 0.86 + 0.14 * warmWash;
        var bCol = 0.78 + 0.12 * warmWash;

        final mossBlend = habitatMoss * 0.42;
        rCol = rCol * (1 - mossBlend) + 0.62 * mossBlend;
        gCol = gCol * (1 - mossBlend) + 0.84 * mossBlend;
        bCol = bCol * (1 - mossBlend) + 0.54 * mossBlend;

        final totalWear = math.max(roadWear * 0.88, yardWear * 0.80);
        rCol = rCol * (1 - totalWear) + 1.08 * totalWear;
        gCol = gCol * (1 - totalWear) + 0.94 * totalWear;
        bCol = bCol * (1 - totalWear) + 0.78 * totalWear;

        final dampShade = 1.0 - 0.26 * plinthDamp;
        rCol *= dampShade;
        gCol *= dampShade;
        bCol *= dampShade;

        final wetMix = bankWet * 0.58;
        final finalR = rCol * (1 - wetMix) + 0.48 * wetMix;
        final finalG = gCol * (1 - wetMix) + 0.54 * wetMix;
        final finalB = bCol * (1 - wetMix) + 0.56 * wetMix;
        final wearAlpha =
            (math.max(totalWear, bankWet * 0.55) * (1.0 - habitatMoss * 0.45))
                .clamp(0.0, 1.0);

        final cBase = idx * 4;
        colors[cBase] = finalR;
        colors[cBase + 1] = finalG;
        colors[cBase + 2] = finalB;
        colors[cBase + 3] = wearAlpha;
      }
    }

    final normals = Float32List(count * 3);
    for (var r = 0; r < rows; r++) {
      final rDown = r > 0 ? r - 1 : r;
      final rUp = r < rows - 1 ? r + 1 : r;
      final dzSpan = (rUp - rDown) * step;
      for (var c = 0; c < cols; c++) {
        final cLeft = c > 0 ? c - 1 : c;
        final cRight = c < cols - 1 ? c + 1 : c;
        final dxSpan = (cRight - cLeft) * step;

        final hL = heights[r * cols + cLeft];
        final hR = heights[r * cols + cRight];
        final hD = heights[rDown * cols + c];
        final hU = heights[rUp * cols + c];

        final nx = (hL - hR) / dxSpan;
        const ny = 1.0;
        final nz = (hD - hU) / dzSpan;
        final invLen = 1.0 / math.sqrt(nx * nx + ny * ny + nz * nz);

        final nBase = (r * cols + c) * 3;
        normals[nBase] = nx * invLen;
        normals[nBase + 1] = ny * invLen;
        normals[nBase + 2] = nz * invLen;
      }
    }

    return (
      cols: cols,
      rows: rows,
      heights: heights,
      normals: normals,
      colors: colors,
    );
  }

  MeshGeometry _buildTileGeometryFromField({
    required int globalCols,
    required Float64List heights,
    required Float32List normals,
    required Float32List colors,
    required int rStart,
    required int rEnd,
    required int cStart,
    required int cEnd,
  }) {
    final builder = GeometryBuilder();
    const minX = TerrainConfig.minX;
    const maxX = TerrainConfig.maxX;
    const minZ = TerrainConfig.minZ;
    const maxZ = TerrainConfig.maxZ;
    const step = TerrainConfig.gridStep;

    final localCols = cEnd - cStart + 1;
    final localRows = rEnd - rStart + 1;

    for (var lr = 0; lr < localRows; lr++) {
      final r = rStart + lr;
      final z = minZ + r * step;
      final v = (z - minZ) / (maxZ - minZ);
      for (var lc = 0; lc < localCols; lc++) {
        final c = cStart + lc;
        final x = minX + c * step;
        final u = (x - minX) / (maxX - minX);
        final gIdx = r * globalCols + c;
        final nBase = gIdx * 3;
        final cBase = gIdx * 4;

        builder
          ..normal(
            Vector3(normals[nBase], normals[nBase + 1], normals[nBase + 2]),
          )
          ..color(
            Vector4(
              colors[cBase],
              colors[cBase + 1],
              colors[cBase + 2],
              colors[cBase + 3],
            ),
          )
          ..texCoord(Vector2(u * 16.0, v * 16.0))
          ..addVertex(Vector3(x, heights[gIdx], z));
      }
    }

    for (var lr = 0; lr < localRows - 1; lr++) {
      final r = rStart + lr;
      for (var lc = 0; lc < localCols - 1; lc++) {
        final c = cStart + lc;
        final v00 = lr * localCols + lc;
        final v10 = v00 + 1;
        final v01 = v00 + localCols;
        final v11 = v01 + 1;

        final h00 = heights[r * globalCols + c];
        final h10 = heights[r * globalCols + c + 1];
        final h01 = heights[(r + 1) * globalCols + c];
        final h11 = heights[(r + 1) * globalCols + c + 1];

        if ((h00 - h11).abs() < (h10 - h01).abs()) {
          builder
            ..addTriangle(v00, v01, v11)
            ..addTriangle(v00, v11, v10);
        } else {
          builder
            ..addTriangle(v00, v01, v10)
            ..addTriangle(v10, v01, v11);
        }
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
    final root = Node(name: 'terrain_tiled_root');
    final mat = resolveMaterial(ShukubaSurfaceRole.packedEarth);
    final field = _computeTerrainField(
      terraces: terraces,
      roads: roads,
      structures: structures,
    );

    const tileDivs = 3;
    final rowSplits = [
      for (var i = 0; i <= tileDivs; i++)
        ((field.rows - 1) * i / tileDivs).round(),
    ];
    final colSplits = [
      for (var i = 0; i <= tileDivs; i++)
        ((field.cols - 1) * i / tileDivs).round(),
    ];

    for (var tr = 0; tr < tileDivs; tr++) {
      for (var tc = 0; tc < tileDivs; tc++) {
        final geo = _buildTileGeometryFromField(
          globalCols: field.cols,
          heights: field.heights,
          normals: field.normals,
          colors: field.colors,
          rStart: rowSplits[tr],
          rEnd: rowSplits[tr + 1],
          cStart: colSplits[tc],
          cEnd: colSplits[tc + 1],
        );
        root.add(Node(name: 'terrain_tile_${tr}_$tc', mesh: Mesh(geo, mat)));
      }
    }
    return root;
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

    const gorgeStrataSpecs = [
      (-4.6, 3.05, 1.25, 0.92, 1.35, -0.25),
      (-7.2, 3.35, 1.45, 1.15, 1.55, 0.35),
      (4.8, 3.10, 1.32, 1.04, 1.42, -0.45),
      (7.6, 3.42, 1.52, 1.18, 1.60, 0.22),
      (-4.2, -3.15, 1.18, 0.78, 1.22, 0.55),
      (4.4, -3.10, 1.22, 0.82, 1.28, -0.38),
      (-18.6, 3.30, 1.58, 1.16, 1.48, 0.42),
      (-21.2, 3.65, 1.36, 0.94, 1.32, -0.28),
      (16.8, 3.38, 1.62, 1.22, 1.54, -0.52),
      (19.6, 3.72, 1.38, 0.96, 1.34, 0.18),
      (-15.4, -3.35, 1.42, 0.92, 1.38, 0.64),
      (14.8, -3.30, 1.46, 0.96, 1.40, -0.62),
    ];
    for (final c in gorgeStrataSpecs) {
      final z = c.$1;
      final x = TerrainConfig.riverCenterX(z) + c.$2;
      final gy = sampleRawTerrain(x, z);
      EdoKitBuilder.addStratifiedCliffBlock(
        rockBuilder,
        Vector3(x, gy - 0.24, z),
        Vector3(c.$3, c.$4 * 0.5, c.$5),
        yaw: c.$6,
        tiltX: c.$2 > 0 ? -0.10 : 0.10,
        seed: z * 0.41 + c.$2,
      );
    }

    const bankSpecs = [
      (-24.0, -3.45, 1.18, 0.66, 0.98, 0.5, true),
      (-11.8, -3.28, 0.96, 0.54, 0.84, 1.7, false),
      (10.8, -3.32, 1.02, 0.58, 0.88, 2.1, true),
      (23.2, -3.50, 1.22, 0.68, 1.02, 1.2, true),
      (-12.6, 3.32, 0.98, 0.56, 0.86, 2.6, false),
      (11.6, 3.36, 1.06, 0.60, 0.90, 0.3, true),
      (24.4, 3.48, 1.20, 0.68, 1.00, 1.9, false),
    ];

    for (final b in bankSpecs) {
      final z = b.$1;
      final x = TerrainConfig.riverCenterX(z) + b.$2;
      final groundY = sampleRawTerrain(x, z);
      EdoKitBuilder.addRockBoulder(
        rockBuilder,
        Vector3(x, groundY + 0.12, z),
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
          Vector3(0.84, 0.36, 0.78),
          color: Vector4(0.80, 0.94, 0.70, 1),
          phase: b.$6,
        );
      }
    }

    const meadowOutcrops = [
      (-24.2, -21.0, 1.48, 0.96, 1.28, 0.6),
      (-25.4, 20.5, 1.42, 0.88, 1.22, 1.9),
      (23.8, -21.5, 1.46, 0.94, 1.26, 1.1),
      (24.8, 22.0, 1.54, 1.02, 1.34, 2.4),
    ];
    for (final m in meadowOutcrops) {
      final mx = m.$1;
      final mz = m.$2;
      final my = sampleRawTerrain(mx, mz);
      EdoKitBuilder.addStratifiedCliffBlock(
        rockBuilder,
        Vector3(mx, my - 0.14, mz),
        Vector3(m.$3, m.$4 * 0.5, m.$5),
        yaw: m.$6,
        seed: mx * 0.3 + mz * 0.2,
      );
      EdoKitBuilder.addRockBoulder(
        rockBuilder,
        Vector3(mx + 1.05, my + 0.06, mz + 0.68),
        Vector3(m.$3 * 0.48, m.$4 * 0.46, m.$5 * 0.46),
        yaw: m.$6 + 1.2,
        seed: mx * 0.5 - mz * 0.4,
      );
      EdoKitBuilder.addShrubRosette(
        shrubBuilder,
        Vector3(mx - 0.92, my + 0.06, mz + 0.58),
        Vector3(0.88, 0.38, 0.82),
        color: Vector4(0.82, 0.96, 0.72, 1),
        phase: m.$6,
      );
    }

    const shigaramiSpans = [
      (-10.8, -5.6, -2.78),
      (5.6, 11.2, -2.78),
      (-11.4, -6.4, 2.78),
      (6.6, 12.0, 2.78),
    ];
    for (final span in shigaramiSpans) {
      final z0 = span.$1;
      final z1 = span.$2;
      final bankOffset = span.$3;
      final stakeCount = ((z1 - z0) / 0.38).round() + 1;
      Vec3? prevLogA;
      Vec3? prevLogB;
      for (var i = 0; i < stakeCount; i++) {
        final z = z0 + (z1 - z0) * (i / (stakeCount - 1));
        final x = TerrainConfig.riverCenterX(z) + bankOffset;
        final y = sampleRawTerrain(x, z);
        final topJitter = 0.05 * math.sin(i * 2.1 + z0);
        final topY = math.max(y + 0.44, -0.18) + topJitter;
        EdoKitBuilder.addBox(
          timberBuilder,
          Vector3(x - 0.044, y - 0.52, z - 0.044),
          Vector3(x + 0.044, topY, z + 0.044),
        );
        final logBackX = x + (bankOffset < 0 ? -0.095 : 0.095);
        final curA = Vec3(logBackX, topY - 0.14, z);
        final curB = Vec3(logBackX, topY - 0.28, z);
        if (prevLogA != null && prevLogB != null) {
          EdoKitBuilder.addCordSegment(
            timberBuilder,
            prevLogA,
            curA,
            halfThick: 0.038,
          );
          EdoKitBuilder.addCordSegment(
            timberBuilder,
            prevLogB,
            curB,
            halfThick: 0.038,
          );
        }
        prevLogA = curA;
        prevLogB = curB;
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

  static void _addOrientedStoneBlock(
    GeometryBuilder builder, {
    required Vec3 center,
    required Vec3 along,
    required Vec3 normal,
    required double halfLength,
    required double halfWidth,
    required double bottomY,
    required double topY,
    Vector4? color,
  }) {
    final p00 = center - along * halfLength - normal * halfWidth;
    final p10 = center + along * halfLength - normal * halfWidth;
    final p11 = center + along * halfLength + normal * halfWidth;
    final p01 = center - along * halfLength + normal * halfWidth;

    final b00 = Vector3(p00.x, bottomY, p00.z);
    final b10 = Vector3(p10.x, bottomY, p10.z);
    final b11 = Vector3(p11.x, bottomY, p11.z);
    final b01 = Vector3(p01.x, bottomY, p01.z);

    final t00 = Vector3(p00.x, topY, p00.z);
    final t10 = Vector3(p10.x, topY, p10.z);
    final t11 = Vector3(p11.x, topY, p11.z);
    final t01 = Vector3(p01.x, topY, p01.z);

    final nLeft = Vector3(-normal.x, 0.08, -normal.z);
    final nRight = Vector3(normal.x, 0.08, normal.z);
    final nBack = Vector3(-along.x, 0.08, -along.z);
    final nFront = Vector3(along.x, 0.08, along.z);
    final nTop = Vector3(0, 1, 0);

    EdoKitBuilder.addQuadOutward(
      builder,
      b00,
      b10,
      t10,
      t00,
      nLeft,
      color: color,
    );
    EdoKitBuilder.addQuadOutward(
      builder,
      b11,
      b01,
      t01,
      t11,
      nRight,
      color: color,
    );
    EdoKitBuilder.addQuadOutward(
      builder,
      b01,
      b00,
      t00,
      t01,
      nBack,
      color: color,
    );
    EdoKitBuilder.addQuadOutward(
      builder,
      b10,
      b11,
      t11,
      t10,
      nFront,
      color: color,
    );
    EdoKitBuilder.addQuadOutward(
      builder,
      t00,
      t10,
      t11,
      t01,
      nTop,
      color: color,
    );
  }

  static void _addSteppingStoneSlab(
    GeometryBuilder builder, {
    required double cx,
    required double cz,
    required double bottomY,
    required double topY,
    required double radiusX,
    required double radiusZ,
    required double yaw,
    required double seed,
  }) {
    const sides = 8;
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final tone = 0.94 + 0.22 * ((math.sin(seed * 9.7) * 413.1).abs() % 1.0);
    final slabColor = Vector4(tone * 1.08, tone * 0.98, tone * 0.84, 0.50);

    Vector2 ringPt(int i, double scale) {
      final a = (i / sides) * math.pi * 2;
      final wob = 0.88 + 0.20 * math.sin(a * 3 + seed * 4.3);
      final lx = math.cos(a) * radiusX * wob * scale;
      final lz = math.sin(a) * radiusZ * wob * scale;
      return Vector2(cx + lx * cy - lz * sy, cz + lx * sy + lz * cy);
    }

    final topCenter = Vector3(cx, topY + 0.004, cz);
    for (var i = 0; i < sides; i++) {
      final next = (i + 1) % sides;
      final bA2 = ringPt(i, 1.04);
      final bB2 = ringPt(next, 1.04);
      final tA2 = ringPt(i, 0.96);
      final tB2 = ringPt(next, 0.96);

      final bA = Vector3(bA2.x, bottomY, bA2.y);
      final bB = Vector3(bB2.x, bottomY, bB2.y);
      final tA = Vector3(tA2.x, topY, tA2.y);
      final tB = Vector3(tB2.x, topY, tB2.y);
      final outN = Vector3(
        (tA.x + tB.x) * 0.5 - cx,
        0.25,
        (tA.z + tB.z) * 0.5 - cz,
      );
      EdoKitBuilder.addQuadOutward(
        builder,
        bA,
        bB,
        tB,
        tA,
        outN,
        color: slabColor,
      );
      EdoKitBuilder.addTriangleOutward(
        builder,
        topCenter,
        tA,
        tB,
        Vector3(0, 1, 0),
        color: slabColor,
      );
    }
  }

  Node buildRoadNode(
    RoadSpline road,
    ShukubaMaterialResolver resolveMaterial,
    GroundHeightSampler sampleGroundY, {
    Iterable<RoadSpline> allRoads = const [],
    Iterable<TerraceCourse> terraces = const [],
  }) {
    final root = Node(name: 'road_${road.id.value}');
    final ribbonBuilder = GeometryBuilder();
    final stoneBuilder = GeometryBuilder();
    final halfWidth = road.widthMeters * 0.5;
    final isGarden = road.style == RoadStyle.gardenPath;

    final samples = road.smoothCenterline(stepMeters: 0.55);
    if (samples.length < 2) {
      return root;
    }

    final allRoadList = allRoads.toList();
    final selfIndex = allRoadList.indexWhere((r) => r.id == road.id);
    final earlierRoads = selfIndex > 0
        ? allRoadList.sublist(0, selfIndex)
        : const <RoadSpline>[];
    final otherRoads = [
      for (final r in allRoadList)
        if (r.id != road.id) r,
    ];

    final terraceList = terraces.toList();
    final stairCrossings = <_RoadTerraceCrossing>[];
    if (terraceList.isNotEmpty) {
      final probeRoads = allRoadList.isEmpty ? [road] : allRoadList;
      for (final t in terraceList) {
        for (final c in _findCrossingsForTerrace(t, probeRoads, terraceList)) {
          if (!c.isBridgeApproach) {
            stairCrossings.add(c);
          }
        }
      }
    }

    bool isInsideStairFlight(double x, double z) {
      for (var i = 0; i < stairCrossings.length; i++) {
        final c = stairCrossings[i];
        final rx = x - c.point.x;
        final rz = z - c.point.z;
        final uAlong = (rx * c.along.x + rz * c.along.z).abs();
        final inward = rx * c.platNormal.x + rz * c.platNormal.z;
        if (uAlong <= c.halfWallGap + 0.12 &&
            inward >= -1.78 &&
            inward <= 0.98) {
          return true;
        }
      }
      return false;
    }

    const crossFracs = [-1.0, -0.58, 0.0, 0.58, 1.0];
    const crossU = [0.0, 0.21, 0.50, 0.79, 1.0];
    final camberLifts = isGarden
        ? const [0.016, 0.030, 0.036, 0.030, 0.016]
        : const [0.018, 0.042, 0.052, 0.042, 0.018];
    final styleAlpha = isGarden ? 0.35 : 1.0;

    final normals2D = <Vec3>[];
    final tangents2D = <Vec3>[];
    final arcLengths = <double>[0];

    for (var i = 0; i < samples.length; i++) {
      if (i > 0) {
        arcLengths.add(
          arcLengths.last + samples[i].horizontalDistanceTo(samples[i - 1]),
        );
      }
      final current = samples[i];
      final Vec3 tangent;
      if (i == 0) {
        tangent = (samples[1] - current).normalizedHorizontal();
      } else if (i == samples.length - 1) {
        tangent = (current - samples[i - 1]).normalizedHorizontal();
      } else {
        tangent = (samples[i + 1] - samples[i - 1]).normalizedHorizontal();
      }
      final normal = Vec3(-tangent.z, 0, tangent.x);
      tangents2D.add(tangent);
      normals2D.add(normal);

      final vCoord = arcLengths[i] * 0.45;
      for (var col = 0; col < 5; col++) {
        final frac = crossFracs[col];
        final px = current.x + normal.x * (halfWidth * frac);
        final pz = current.z + normal.z * (halfWidth * frac);
        final py = sampleGroundY(px, pz) + camberLifts[col];
        final tilt = -frac * 0.08;
        final edgeTone = (col == 0 || col == 4) ? 0.92 : 1.0;
        ribbonBuilder
          ..normal(Vector3(normal.x * tilt, 1, normal.z * tilt).normalized())
          ..color(Vector4(edgeTone, edgeTone, edgeTone * 0.98, styleAlpha))
          ..texCoord(Vector2(crossU[col], vCoord))
          ..addVertex(Vector3(px, py, pz));
      }
    }

    var emittedQuads = 0;
    for (var i = 0; i < samples.length - 1; i++) {
      final mid = Vec3.lerp(samples[i], samples[i + 1], 0.5);
      if (TerrainConfig.isInsideBridgeFootprint(mid.x, mid.z) ||
          isInsideStairFlight(mid.x, mid.z)) {
        continue;
      }
      var overlapsEarlier = false;
      for (var e = 0; e < earlierRoads.length; e++) {
        final er = earlierRoads[e];
        if (er.nearestSample(mid).horizontalDistance < er.widthMeters * 0.44) {
          overlapsEarlier = true;
          break;
        }
      }
      if (overlapsEarlier) {
        continue;
      }

      final row0 = i * 5;
      final row1 = (i + 1) * 5;
      for (var col = 0; col < 4; col++) {
        final v00 = row0 + col;
        final v01 = v00 + 1;
        final v10 = row1 + col;
        final v11 = v10 + 1;
        ribbonBuilder
          ..addTriangle(v00, v01, v10)
          ..addTriangle(v01, v11, v10);
      }
      emittedQuads++;
    }

    if (emittedQuads > 0) {
      root.add(
        Node(
          name: 'road_surface_${road.id.value}',
          mesh: Mesh(
            ribbonBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.laneOverlay),
          ),
        ),
      );
    }

    bool isNearOtherRoadOrTerrace(double x, double z) {
      if (TerrainConfig.isInsideBridgeFootprint(x, z) ||
          isInsideStairFlight(x, z)) {
        return true;
      }
      for (var o = 0; o < otherRoads.length; o++) {
        final or = otherRoads[o];
        if (or.nearestSample(Vec3(x, 0, z)).horizontalDistance <
            or.widthMeters * 0.5 + 0.36) {
          return true;
        }
      }
      for (var t = 0; t < terraceList.length; t++) {
        final ter = terraceList[t];
        for (var s = 0; s < ter.crestPoints.length - 1; s++) {
          if (horizontalDistanceToSegment(
                x,
                z,
                ter.crestPoints[s],
                ter.crestPoints[s + 1],
              ) <
              1.15) {
            return true;
          }
        }
      }
      return false;
    }

    var stoneCount = 0;
    final curbSpacing = isGarden ? 0.62 : 0.72;
    final totalLen = arcLengths.last;
    final curbSlots = (totalLen / curbSpacing).floor();

    int sampleIdxAtArc(double targetArc) {
      var lo = 0;
      var hi = arcLengths.length - 1;
      while (lo < hi) {
        final mid = (lo + hi) >> 1;
        if (arcLengths[mid] < targetArc) {
          lo = mid + 1;
        } else {
          hi = mid;
        }
      }
      return lo.clamp(0, samples.length - 1);
    }

    for (var slot = 0; slot < curbSlots; slot++) {
      final arc = (slot + 0.5) * curbSpacing;
      final sIdx = sampleIdxAtArc(arc);
      final base = samples[sIdx];
      final tang = tangents2D[sIdx];
      final norm = normals2D[sIdx];

      for (final side in const [-1.0, 1.0]) {
        final hash =
            (math.sin((slot * 2 + (side > 0 ? 1 : 0)) * 17.3 + halfWidth) *
                    4913.7)
                .abs() %
            1.0;
        final runWave = math.sin(slot * 0.68 + (side > 0 ? 1.8 : 0.3));
        if (!isGarden && (runWave < -0.18 || hash < 0.14)) {
          continue;
        }
        if (isGarden && hash < 0.06) {
          continue;
        }
        final curbOffset = halfWidth - (isGarden ? 0.02 : 0.03);
        final cx = base.x + norm.x * side * curbOffset;
        final cz = base.z + norm.z * side * curbOffset;
        if (isNearOtherRoadOrTerrace(cx, cz)) {
          continue;
        }
        final gy = sampleGroundY(cx, cz);
        final topProud = isGarden
            ? (0.048 + 0.018 * hash)
            : (0.052 + 0.022 * hash);
        final halfLen = isGarden ? (0.28 + 0.03 * hash) : (0.33 + 0.03 * hash);
        final halfWid = isGarden ? 0.072 : 0.088;
        final shade = 0.92 + 0.22 * hash;
        _addOrientedStoneBlock(
          stoneBuilder,
          center: Vec3(cx, gy, cz),
          along: tang,
          normal: norm,
          halfLength: halfLen,
          halfWidth: halfWid,
          bottomY: gy - 0.18,
          topY: gy + topProud,
          color: Vector4(shade * 1.12, shade * 1.00, shade * 0.84, 0.50),
        );
        stoneCount++;
      }
    }

    if (isGarden) {
      const stepSpacing = 0.68;
      final stepSlots = (totalLen / stepSpacing).floor();
      for (var s = 0; s < stepSlots; s++) {
        final arc = (s + 0.5) * stepSpacing;
        final sIdx = sampleIdxAtArc(arc);
        final base = samples[sIdx];
        final norm = normals2D[sIdx];
        final h = (math.sin(s * 23.7 + 1.9) * 3719.3).abs() % 1.0;
        final sideJitter = (s.isEven ? -1.0 : 1.0) * (0.14 + 0.08 * h);
        final sx = base.x + norm.x * sideJitter;
        final sz = base.z + norm.z * sideJitter;
        if (isNearOtherRoadOrTerrace(sx, sz)) {
          continue;
        }
        final gy = sampleGroundY(sx, sz);
        final isAccentStone = s % 5 == 2;
        _addSteppingStoneSlab(
          stoneBuilder,
          cx: sx,
          cz: sz,
          bottomY: gy - 0.08,
          topY: gy + (isAccentStone ? 0.078 : 0.066) + 0.010 * h,
          radiusX: isAccentStone ? 0.31 : (0.23 + 0.05 * h),
          radiusZ: isAccentStone ? 0.26 : (0.19 + 0.04 * (1 - h)),
          yaw: h * math.pi * 2,
          seed: s * 1.3 + 0.4,
        );
        stoneCount++;
      }
    }

    if (stoneCount > 0) {
      root.add(
        Node(
          name: 'road_stones_${road.id.value}',
          mesh: Mesh(
            stoneBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.ishigakiStone),
          ),
        ),
      );
    }

    return root;
  }

  Node buildTerraceNode(
    TerraceCourse terrace,
    ShukubaMaterialResolver resolveMaterial, {
    Iterable<RoadSpline> roads = const [],
    Iterable<TerraceCourse> allTerraces = const [],
  }) {
    final root = Node(name: 'terrace_${terrace.id.value}');
    final stoneMaterial = resolveMaterial(ShukubaSurfaceRole.ishigakiStone);
    final timberMaterial = resolveMaterial(ShukubaSurfaceRole.charredTimber);
    const frontLip = 0.20;
    const backSetback = 1.08;

    final roadList = roads.toList();
    final terraceList = allTerraces.isEmpty ? [terrace] : allTerraces.toList();
    final crossings = roadList.isNotEmpty
        ? _findCrossingsForTerrace(terrace, roadList, terraceList)
        : const <_RoadTerraceCrossing>[];

    final quoinAndCapBuilder = GeometryBuilder();
    final stairStoneBuilder = GeometryBuilder();
    final stairTimberBuilder = GeometryBuilder();
    var hasQuoinsOrCaps = false;
    var hasStairStone = false;
    var hasStairTimber = false;

    void emitSangiZumiCorner(
      Vec3 vertex,
      Vec3 dirA,
      Vec3 dropN, {
      required double topY,
      required double baseY,
      required double batter,
      required int seed,
      required double verticalStagger,
    }) {
      const courses = 4;
      final totalH = topY - baseY;
      final courseH = totalH / courses;
      for (var c = 0; c < courses; c++) {
        final y0 = baseY + c * courseH + 0.01 + verticalStagger;
        final y1 = y0 + courseH - 0.032;
        final fracMid = (c + 0.5) / courses;
        final outShift = frontLip + batter * (1.0 - fracMid) + 0.032;
        final longAlong = c.isEven ? 0.34 : 0.21;
        final deepIn = c.isEven ? 0.24 : 0.38;
        final center =
            Vec3(vertex.x, (y0 + y1) * 0.5, vertex.z) +
            dirA * (longAlong * 0.88) +
            dropN * (outShift - deepIn * 0.5);
        final shade = 0.92 + 0.16 * (((seed + c) * 0.37) % 1.0);
        _addOrientedStoneBlock(
          quoinAndCapBuilder,
          center: center,
          along: dirA,
          normal: dropN,
          halfLength: longAlong,
          halfWidth: deepIn * 0.5,
          bottomY: y0,
          topY: y1,
          color: Vector4(shade, shade * 0.99, shade * 0.96, 1),
        );
        hasQuoinsOrCaps = true;
      }
    }

    void emitWallSpan(
      Vec3 spanA,
      Vec3 spanB, {
      required int segIdx,
      required int spanSeed,
      required bool quoinStart,
      required bool quoinEnd,
    }) {
      final delta = spanB - spanA;
      final segLen = delta.horizontalLength;
      if (segLen <= 0.25) {
        return;
      }
      final along = Vec3(delta.x / segLen, 0, delta.z / segLen);
      final dropNormal = terrace.dropNormalBetween(spanA, spanB);

      final segStep = segIdx.isOdd ? 0.034 : 0.0;
      final topY = terrace.topElevation + segStep;
      final wallTopY = topY + 0.04;
      final baseY = topY - terrace.riseMeters - 0.48;
      final backBaseY = topY - 0.38;
      final batter = (wallTopY - baseY) * 0.23;

      final nFront = Vector3(dropNormal.x, 0.23, dropNormal.z);
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
        final fcA = (Vec3(cA.x, wallTopY, cA.z) + dropNormal * frontLip)
            .toVector3();
        final fcB = (Vec3(cB.x, wallTopY, cB.z) + dropNormal * frontLip)
            .toVector3();
        final bcA = (Vec3(cA.x, wallTopY, cA.z) - dropNormal * backSetback)
            .toVector3();
        final bcB = (Vec3(cB.x, wallTopY, cB.z) - dropNormal * backSetback)
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

      final capCount = math.max(1, (segLen / 0.88).round());
      final capSlotLen = segLen / capCount;
      for (var c = 0; c < capCount; c++) {
        final h =
            (math.sin((spanSeed * 37 + c) * 13.9 + 0.7) * 2917.3).abs() % 1.0;
        final mid = Vec3.lerp(spanA, spanB, (c + 0.5) / capCount);
        final capCenter = mid - dropNormal * 0.22;
        final capTop = topY + 0.125 + 0.038 * h;
        final shade = 0.88 + 0.22 * h;
        _addOrientedStoneBlock(
          quoinAndCapBuilder,
          center: capCenter,
          along: along,
          normal: dropNormal,
          halfLength: math.max(0.18, capSlotLen * 0.5 - 0.022),
          halfWidth: 0.46 + 0.04 * (h - 0.5),
          bottomY: wallTopY - 0.04,
          topY: capTop,
          color: Vector4(shade, shade * 0.99, shade * 0.96, 1),
        );
        hasQuoinsOrCaps = true;

        if (c % 4 == 1 && c > 0 && c < capCount - 1) {
          final toeX = mid.x + dropNormal.x * (frontLip + batter * 0.78);
          final toeZ = mid.z + dropNormal.z * (frontLip + batter * 0.78);
          final toeY = sampleRawTerrain(toeX, toeZ);
          if (toeY < topY - 0.45 &&
              (toeX - TerrainConfig.riverCenterX(toeZ)).abs() > 3.2) {
            EdoKitBuilder.addRockBoulder(
              quoinAndCapBuilder,
              Vector3(toeX, toeY + 0.08, toeZ),
              Vector3(0.32 + 0.14 * h, 0.22 + 0.08 * h, 0.28 + 0.12 * h),
              yaw: h * math.pi * 2,
              seed: spanSeed + c * 0.9,
            );
          }
        }
      }

      if (quoinStart && segLen > 1.2) {
        emitSangiZumiCorner(
          spanA,
          along,
          dropNormal,
          topY: wallTopY - 0.02,
          baseY: topY - terrace.riseMeters - 0.15,
          batter: batter,
          seed: spanSeed * 7 + 1,
          verticalStagger: 0,
        );
      }
      if (quoinEnd && segLen > 1.2) {
        emitSangiZumiCorner(
          spanB,
          along * -1,
          dropNormal,
          topY: wallTopY - 0.02,
          baseY: topY - terrace.riseMeters - 0.15,
          batter: batter,
          seed: spanSeed * 7 + 4,
          verticalStagger: 0.048,
        );
      }
    }

    void emitKaidanStaircase(_RoadTerraceCrossing c) {
      final dropN = c.platNormal * -1;
      if (c.isBridgeApproach) {
        for (final side in const [-1.0, 1.0]) {
          final cheekCenter =
              c.point +
              c.along * (side * (c.halfWallGap - 0.16)) +
              dropN * 0.22;
          _addOrientedStoneBlock(
            stairStoneBuilder,
            center: cheekCenter,
            along: c.platNormal,
            normal: c.along,
            halfLength: 0.78,
            halfWidth: 0.18,
            bottomY: c.topY - terrace.riseMeters - 0.35,
            topY: c.topY + 0.22,
          );
        }
        hasStairStone = true;
        return;
      }

      final rise = (c.topY - c.lowY).clamp(0.35, 4.2);
      final stepCount = math.max(5, (rise / 0.205).round());
      const inStart = -1.70;
      const inEnd = 0.90;
      final stepRun = (inEnd - inStart) / stepCount;
      final stepRise = rise / stepCount;
      final treadHalfW = c.roadWidth * 0.5 + 0.04;

      for (var s = 0; s < stepCount; s++) {
        final inA = inStart + s * stepRun;
        final inB =
            inStart + (s + 1) * stepRun + (s == stepCount - 1 ? 0.18 : 0.04);
        final midIn = (inA + 0.05 + inB) * 0.5;
        final halfDepth = (inB - (inA + 0.05)) * 0.5;
        final yTop = c.lowY + (s + 1) * stepRise;
        final yBot = c.lowY + s * stepRise - 0.34;
        final shade = 0.90 + 0.16 * ((s * 0.37) % 1.0);

        final stoneCenter = c.point + c.platNormal * midIn;
        _addOrientedStoneBlock(
          stairStoneBuilder,
          center: stoneCenter,
          along: c.platNormal,
          normal: c.along,
          halfLength: halfDepth,
          halfWidth: treadHalfW,
          bottomY: yBot,
          topY: yTop - 0.008,
          color: Vector4(shade, shade * 0.99, shade * 0.97, 1),
        );
        hasStairStone = true;

        final nosingCenter = c.point + c.platNormal * (inA + 0.025);
        _addOrientedStoneBlock(
          stairTimberBuilder,
          center: nosingCenter,
          along: c.platNormal,
          normal: c.along,
          halfLength: 0.052,
          halfWidth: treadHalfW + 0.012,
          bottomY: yTop - 0.088,
          topY: yTop + 0.004,
        );
        hasStairTimber = true;
      }

      const cheekSegments = 3;
      for (final side in const [-1.0, 1.0]) {
        final latOffset = treadHalfW + 0.19;
        for (var b = 0; b < cheekSegments; b++) {
          final f0 = b / cheekSegments;
          final f1 = (b + 1) / cheekSegments;
          final in0 = inStart - 0.06 + (inEnd + 0.14 - (inStart - 0.06)) * f0;
          final in1 = inStart - 0.06 + (inEnd + 0.14 - (inStart - 0.06)) * f1;
          final midIn = (in0 + in1) * 0.5;
          final yTop =
              c.lowY + rise * ((b + 1) / cheekSegments) + 0.16 - 0.02 * b;
          final yBot = c.lowY + rise * f0 - 0.42;
          final center =
              c.point + c.along * (side * latOffset) + c.platNormal * midIn;
          _addOrientedStoneBlock(
            stairStoneBuilder,
            center: center,
            along: c.platNormal,
            normal: c.along,
            halfLength: (in1 - in0) * 0.5 - 0.012,
            halfWidth: 0.15,
            bottomY: yBot,
            topY: yTop,
          );
        }
      }
    }

    for (var i = 0; i < terrace.crestPoints.length - 1; i++) {
      final pA = terrace.crestPoints[i];
      final pB = terrace.crestPoints[i + 1];
      final segLen = pA.horizontalDistanceTo(pB);
      if (segLen <= 1e-4) {
        continue;
      }

      final segCrossings = [
        for (final c in crossings)
          if (c.segIndex == i) c,
      ]..sort((a, b) => a.segT.compareTo(b.segT));

      if (segCrossings.isEmpty) {
        emitWallSpan(
          pA,
          pB,
          segIdx: i,
          spanSeed: i * 11 + 3,
          quoinStart: true,
          quoinEnd: true,
        );
        continue;
      }

      var cursorT = 0.0;
      for (var k = 0; k < segCrossings.length; k++) {
        final c = segCrossings[k];
        final dtGap = c.halfWallGap / segLen;
        final gapStart = (c.segT - dtGap).clamp(0.0, 1.0);
        final gapEnd = (c.segT + dtGap).clamp(0.0, 1.0);
        if (gapStart > cursorT + 0.02) {
          emitWallSpan(
            Vec3.lerp(pA, pB, cursorT),
            Vec3.lerp(pA, pB, gapStart),
            segIdx: i,
            spanSeed: i * 17 + k * 3 + 1,
            quoinStart: cursorT <= 1e-4,
            quoinEnd: false,
          );
        }
        emitKaidanStaircase(c);
        cursorT = math.max(cursorT, gapEnd);
      }
      if (cursorT < 0.98) {
        emitWallSpan(
          Vec3.lerp(pA, pB, cursorT),
          pB,
          segIdx: i,
          spanSeed: i * 17 + 9,
          quoinStart: false,
          quoinEnd: true,
        );
      }
    }

    if (hasQuoinsOrCaps) {
      root.add(Node(mesh: Mesh(quoinAndCapBuilder.build(), stoneMaterial)));
    }
    if (hasStairStone) {
      root.add(Node(mesh: Mesh(stairStoneBuilder.build(), stoneMaterial)));
    }
    if (hasStairTimber) {
      root.add(Node(mesh: Mesh(stairTimberBuilder.build(), timberMaterial)));
    }

    return root;
  }

  Node buildWallNode(
    CourtyardWall wall,
    ShukubaMaterialResolver resolveMaterial,
    GroundHeightSampler sampleGroundY,
  ) {
    final root = Node(name: 'wall_${wall.id.value}');
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
