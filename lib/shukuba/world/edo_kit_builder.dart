import 'dart:math' as math;

import 'package:flutter_scene/scene.dart'
    show GeometryBuilder, Mesh, MeshGeometry, Node, ShadowCastingMode;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        BuildPreview,
        DemolishHoverPreview,
        EntityId,
        GroundHeightSampler,
        LanternSpan,
        NoBuildPreview,
        PlacedStructure,
        RoadSpline,
        ShukubaMaterialResolver,
        ShukubaSurfaceRole,
        StampGhostPreview,
        StreetAgentRole,
        StrokePreviewStyle,
        StrokeRibbonPreview,
        StructureKind,
        Vec3;
import 'package:vector_math/vector_math.dart'
    show Quaternion, Vector2, Vector3, Vector4;

class EdoKitBuilder {
  const new();

  static final Vector4 _whiteColor = Vector4(1, 1, 1, 1);

  static const Vec3 heldLanternLocalOffset = Vec3(0.26, 1.18, 0.76);

  static List<Vec3> structureLanternLocalOffsets(PlacedStructure structure) {
    switch (structure.kind) {
      case StructureKind.chaya:
        return const [Vec3(-1.58, 2.02, 2.84), Vec3(1.58, 2.02, 2.84)];
      case StructureKind.machiya:
        final variant = structure.id.value.hashCode.abs() % 3;
        if (variant == 1) {
          return const [Vec3(1.08, 1.92, 3.86)];
        }
        if (variant == 2) {
          return const [Vec3(-1.08, 1.92, 3.86)];
        }
        return const [];
      case StructureKind.marketStall:
        return const [Vec3(1.12, 1.96, 1.08)];
      case StructureKind.toriiGate:
        return const [Vec3(-1.38, 3.06, 0), Vec3(1.38, 3.06, 0)];
      case StructureKind.kura ||
          StructureKind.yaguraTower ||
          StructureKind.rockOutcrop ||
          StructureKind.mapleCluster ||
          StructureKind.bambooGrove ||
          StructureKind.pineTree ||
          StructureKind.weepingWillow:
        return const [];
    }
  }

  static MeshGeometry buildUnitBillboardQuad({Vector4? color}) {
    final builder = GeometryBuilder()
      ..color(color ?? _whiteColor)
      ..texCoord(Vector2(0, 0))
      ..addVertex(Vector3(-0.5, -0.5, 0))
      ..texCoord(Vector2(1, 0))
      ..addVertex(Vector3(0.5, -0.5, 0))
      ..texCoord(Vector2(1, 1))
      ..addVertex(Vector3(0.5, 0.5, 0))
      ..texCoord(Vector2(0, 1))
      ..addVertex(Vector3(-0.5, 0.5, 0))
      ..addTriangle(0, 1, 2)
      ..addTriangle(0, 2, 3);
    return builder.build();
  }

  static void addBox(
    GeometryBuilder builder,
    Vector3 min,
    Vector3 max, {
    Vector4? color,
  }) {
    final x0 = min.x;
    final y0 = min.y;
    final z0 = min.z;
    final x1 = max.x;
    final y1 = max.y;
    final z1 = max.z;
    final dx = (x1 - x0).abs();
    final dy = (y1 - y0).abs();
    final dz = (z1 - z0).abs();
    builder.color(color ?? _whiteColor);

    int addUvVertex(Vector3 pos, double u, double v) {
      builder.texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    final v0 = addUvVertex(Vector3(x0, y0, z0), 0, 0);
    final v1 = addUvVertex(Vector3(x0, y1, z0), 0, dy);
    final v2 = addUvVertex(Vector3(x1, y1, z0), dx, dy);
    final v3 = addUvVertex(Vector3(x1, y0, z0), dx, 0);
    builder
      ..addTriangle(v0, v1, v2)
      ..addTriangle(v0, v2, v3);

    final v4 = addUvVertex(Vector3(x1, y0, z1), 0, 0);
    final v5 = addUvVertex(Vector3(x1, y1, z1), 0, dy);
    final v6 = addUvVertex(Vector3(x0, y1, z1), dx, dy);
    final v7 = addUvVertex(Vector3(x0, y0, z1), dx, 0);
    builder
      ..addTriangle(v4, v5, v6)
      ..addTriangle(v4, v6, v7);

    final v8 = addUvVertex(Vector3(x0, y0, z1), 0, 0);
    final v9 = addUvVertex(Vector3(x0, y1, z1), 0, dy);
    final v10 = addUvVertex(Vector3(x0, y1, z0), dz, dy);
    final v11 = addUvVertex(Vector3(x0, y0, z0), dz, 0);
    builder
      ..addTriangle(v8, v9, v10)
      ..addTriangle(v8, v10, v11);

    final v12 = addUvVertex(Vector3(x1, y0, z0), 0, 0);
    final v13 = addUvVertex(Vector3(x1, y1, z0), 0, dy);
    final v14 = addUvVertex(Vector3(x1, y1, z1), dz, dy);
    final v15 = addUvVertex(Vector3(x1, y0, z1), dz, 0);
    builder
      ..addTriangle(v12, v13, v14)
      ..addTriangle(v12, v14, v15);

    final v16 = addUvVertex(Vector3(x0, y0, z1), 0, 0);
    final v17 = addUvVertex(Vector3(x0, y0, z0), 0, dz);
    final v18 = addUvVertex(Vector3(x1, y0, z0), dx, dz);
    final v19 = addUvVertex(Vector3(x1, y0, z1), dx, 0);
    builder
      ..addTriangle(v16, v17, v18)
      ..addTriangle(v16, v18, v19);

    final v20 = addUvVertex(Vector3(x0, y1, z0), 0, 0);
    final v21 = addUvVertex(Vector3(x0, y1, z1), 0, dz);
    final v22 = addUvVertex(Vector3(x1, y1, z1), dx, dz);
    final v23 = addUvVertex(Vector3(x1, y1, z0), dx, 0);
    builder
      ..addTriangle(v20, v21, v22)
      ..addTriangle(v20, v22, v23);
  }

  static void addTriangleOutward(
    GeometryBuilder builder,
    Vector3 p0,
    Vector3 p1,
    Vector3 p2,
    Vector3 outwardHint, {
    double uvScale = 0.5,
    Vector4? color,
  }) {
    final e1 = p1 - p0;
    final e2 = p2 - p0;
    final normal = e1.cross(e2);
    if (normal.length2 <= 1e-12) {
      return;
    }
    final uAxis = e1.length2 > 1e-10 ? e1.normalized() : Vector3(1, 0, 0);
    final vRaw = normal.cross(uAxis);
    final vAxis = vRaw.length2 > 1e-10 ? vRaw.normalized() : Vector3(0, 1, 0);
    builder.color(color ?? _whiteColor);

    int emit(Vector3 p) {
      final rel = p - p0;
      builder.texCoord(
        Vector2(rel.dot(uAxis) * uvScale, rel.dot(vAxis) * uvScale),
      );
      return builder.addVertex(p);
    }

    final v0 = emit(p0);
    final v1 = emit(p1);
    final v2 = emit(p2);
    if (normal.dot(outwardHint) >= 0) {
      builder.addTriangle(v0, v1, v2);
    } else {
      builder.addTriangle(v0, v2, v1);
    }
  }

  static void addQuadOutward(
    GeometryBuilder builder,
    Vector3 p0,
    Vector3 p1,
    Vector3 p2,
    Vector3 p3,
    Vector3 outwardHint, {
    double uvScale = 0.5,
    Vector4? color,
  }) {
    final e1 = p1 - p0;
    final e2 = p3 - p0;
    final normal = e1.cross(p2 - p0);
    if (normal.length2 <= 1e-12) {
      return;
    }
    final uAxis = e1.length2 > 1e-10 ? e1.normalized() : Vector3(1, 0, 0);
    final vAxis = e2.length2 > 1e-10 ? e2.normalized() : Vector3(0, 1, 0);
    builder.color(color ?? _whiteColor);

    int emit(Vector3 p) {
      final rel = p - p0;
      builder.texCoord(
        Vector2(rel.dot(uAxis) * uvScale, rel.dot(vAxis) * uvScale),
      );
      return builder.addVertex(p);
    }

    final v0 = emit(p0);
    final v1 = emit(p1);
    final v2 = emit(p2);
    final v3 = emit(p3);
    if (normal.dot(outwardHint) >= 0) {
      builder
        ..addTriangle(v0, v1, v2)
        ..addTriangle(v0, v2, v3);
    } else {
      builder
        ..addTriangle(v0, v3, v2)
        ..addTriangle(v0, v2, v1);
    }
  }

  static void addArchedFoliageCard(
    GeometryBuilder builder,
    Vector3 stem, {
    required double yaw,
    required double pitchUp,
    required double length,
    required double width,
    required double droop,
    required Vector4 color,
  }) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    final fwd = Vector3(cy, 0, sy);
    final right = Vector3(-sy, 0, cy);
    final cp = math.cos(pitchUp);
    final sp = math.sin(pitchUp);

    final pMid =
        stem +
        fwd * (length * 0.52 * cp) +
        Vector3(0, length * 0.52 * sp + droop * 0.16, 0);
    final pTip =
        stem + fwd * (length * cp) + Vector3(0, length * sp - droop, 0);

    builder.color(color);
    int emit(Vector3 pos, double u, double v) {
      builder.texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    final hw0 = width * 0.42;
    final hw1 = width * 0.52;
    final hw2 = width * 0.46;
    final v0 = emit(stem - right * hw0, 0, 0);
    final v1 = emit(stem + right * hw0, 1, 0);
    final v2 = emit(pMid - right * hw1, 0, 0.52);
    final v3 = emit(pMid + right * hw1, 1, 0.52);
    final v4 = emit(pTip - right * hw2, 0, 1);
    final v5 = emit(pTip + right * hw2, 1, 1);

    builder
      ..addTriangle(v0, v1, v3)
      ..addTriangle(v0, v3, v2)
      ..addTriangle(v2, v3, v5)
      ..addTriangle(v2, v5, v4);
  }

  static void addLeafSprayCloud(
    GeometryBuilder builder,
    Vector3 center,
    Vector3 radii, {
    required Vector4 color,
    double phase = 0,
  }) {
    Vector4 tint(double mult, int salt) {
      final jR = 1.0 + 0.06 * math.sin(phase * 1.9 + salt * 2.3);
      final jG = 1.0 + 0.06 * math.cos(phase * 1.3 + salt * 3.1);
      return Vector4(
        (color.x * mult * jR).clamp(0.05, 1.45),
        (color.y * mult * jG).clamp(0.05, 1.45),
        (color.z * mult).clamp(0.05, 1.45),
        color.w,
      );
    }

    const lowerCount = 5;
    for (var i = 0; i < lowerCount; i++) {
      final yaw = phase + (i / lowerCount) * math.pi * 2;
      final stem = Vector3(
        center.x + math.cos(yaw) * radii.x * 0.18,
        center.y - radii.y * 0.18,
        center.z + math.sin(yaw) * radii.z * 0.18,
      );
      addArchedFoliageCard(
        builder,
        stem,
        yaw: yaw,
        pitchUp: 0.24 + 0.05 * math.sin(i * 1.7 + phase),
        length: radii.x * 1.08,
        width: radii.z * 1.06,
        droop: radii.y * 0.48,
        color: tint(0.84, i),
      );
    }

    const midCount = 4;
    for (var i = 0; i < midCount; i++) {
      final yaw = phase + 0.58 + (i / midCount) * math.pi * 2;
      final stem = Vector3(
        center.x + math.cos(yaw) * radii.x * 0.12,
        center.y + radii.y * 0.10,
        center.z + math.sin(yaw) * radii.z * 0.12,
      );
      addArchedFoliageCard(
        builder,
        stem,
        yaw: yaw,
        pitchUp: 0.46 + 0.06 * math.cos(i * 2.1 + phase),
        length: radii.x * 0.98,
        width: radii.z * 0.98,
        droop: radii.y * 0.34,
        color: tint(1.02, i + 7),
      );
    }

    for (var i = 0; i < 2; i++) {
      final yaw = phase + 1.15 + i * 2.15;
      final stem = Vector3(
        center.x - math.cos(yaw) * radii.x * 0.36,
        center.y + radii.y * 0.42,
        center.z - math.sin(yaw) * radii.z * 0.36,
      );
      addArchedFoliageCard(
        builder,
        stem,
        yaw: yaw,
        pitchUp: 0.18,
        length: radii.x * 0.94,
        width: radii.z * 0.94,
        droop: radii.y * 0.26,
        color: tint(1.16, i + 15),
      );
    }
  }

  static void addShrubRosette(
    GeometryBuilder builder,
    Vector3 baseCenter,
    Vector3 radii, {
    required Vector4 color,
    double phase = 0,
  }) {
    const frondCount = 7;
    for (var i = 0; i < frondCount; i++) {
      final yaw = phase + (i / frondCount) * math.pi * 2;
      final lift = (i.isEven ? 0.56 : 0.36) + 0.06 * math.sin(i * 1.9 + phase);
      final shade = 0.88 + 0.22 * (i / frondCount);
      final stem = Vector3(
        baseCenter.x + math.cos(yaw) * 0.08,
        baseCenter.y,
        baseCenter.z + math.sin(yaw) * 0.08,
      );
      addArchedFoliageCard(
        builder,
        stem,
        yaw: yaw,
        pitchUp: lift,
        length: radii.x * (0.94 + 0.14 * (i % 3)),
        width: radii.z * 0.86,
        droop: radii.y * 0.55,
        color: Vector4(
          color.x * shade,
          color.y * (0.94 + 0.10 * (i % 2)),
          color.z * shade,
          color.w,
        ),
      );
    }
  }

  static void addSculptedEllipsoid(
    GeometryBuilder builder,
    Vector3 center,
    Vector3 radii, {
    required Vector4 color,
  }) {
    const sides = 8;
    final top = Vector3(center.x, center.y + radii.y, center.z);
    final bottom = Vector3(center.x, center.y - radii.y, center.z);
    final upper = <Vector3>[];
    final lower = <Vector3>[];
    for (var i = 0; i < sides; i++) {
      final a = (i / sides) * math.pi * 2;
      final ca = math.cos(a);
      final sa = math.sin(a);
      upper.add(
        Vector3(
          center.x + ca * radii.x * 0.86,
          center.y + radii.y * 0.42,
          center.z + sa * radii.z * 0.86,
        ),
      );
      lower.add(
        Vector3(
          center.x + ca * radii.x * 0.86,
          center.y - radii.y * 0.42,
          center.z + sa * radii.z * 0.86,
        ),
      );
    }
    for (var i = 0; i < sides; i++) {
      final next = (i + 1) % sides;
      final u0 = upper[i];
      final u1 = upper[next];
      final l0 = lower[i];
      final l1 = lower[next];
      final outMid = ((u0 + u1 + l0 + l1) * 0.25) - center;
      addTriangleOutward(
        builder,
        u0,
        u1,
        top,
        outMid + Vector3(0, radii.y, 0),
        color: color,
      );
      addQuadOutward(builder, l0, l1, u1, u0, outMid, color: color);
      addTriangleOutward(
        builder,
        l1,
        l0,
        bottom,
        outMid - Vector3(0, radii.y, 0),
        color: color,
      );
    }
  }

  static void addRockBoulder(
    GeometryBuilder builder,
    Vector3 center,
    Vector3 radii, {
    double yaw = 0,
    double seed = 0,
    Vector4? color,
  }) {
    const sides = 7;
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    Vector3 rot(double lx, double ly, double lz) => Vector3(
      center.x + lx * cy + lz * sy,
      center.y + ly,
      center.z - lx * sy + lz * cy,
    );

    final topCenter = rot(
      0.06 * radii.x * math.sin(seed * 1.3),
      radii.y * 0.88,
      0.06 * radii.z * math.cos(seed * 1.7),
    );
    final botCenter = rot(0, -radii.y * 0.92, 0);
    final crownRing = <Vector3>[];
    final bellyRing = <Vector3>[];
    final skirtRing = <Vector3>[];

    for (var i = 0; i < sides; i++) {
      final a = (i / sides) * math.pi * 2;
      final facet = 0.82 + 0.24 * math.sin(a * 2.0 + seed * 2.1 + i * 0.9);
      final ca = math.cos(a) * facet;
      final sa = math.sin(a) * facet;
      final shelfJitter = 0.08 * math.cos(a * 3.0 - seed);
      crownRing.add(
        rot(
          ca * radii.x * 0.62,
          radii.y * (0.62 + shelfJitter),
          sa * radii.z * 0.62,
        ),
      );
      bellyRing.add(
        rot(ca * radii.x, radii.y * (0.04 + shelfJitter * 0.5), sa * radii.z),
      );
      skirtRing.add(
        rot(ca * radii.x * 1.08, -radii.y * 0.72, sa * radii.z * 1.08),
      );
    }

    final baseCol = color ?? Vector4(1, 1, 1, 0.5);
    final midCol = Vector4(baseCol.x, baseCol.y, baseCol.z, 0.5);
    final topCol = Vector4(
      baseCol.x * 1.12,
      baseCol.y * 1.08,
      baseCol.z * 1.02,
      0.5,
    );
    final lowCol = Vector4(
      baseCol.x * 0.80,
      baseCol.y * 0.84,
      baseCol.z * 0.86,
      0.5,
    );

    for (var i = 0; i < sides; i++) {
      final next = (i + 1) % sides;
      final c0 = crownRing[i];
      final c1 = crownRing[next];
      final b0 = bellyRing[i];
      final b1 = bellyRing[next];
      final s0 = skirtRing[i];
      final s1 = skirtRing[next];
      final outUpper = ((c0 + c1 + b0 + b1) * 0.25) - center;
      final outLower = ((b0 + b1 + s0 + s1) * 0.25) - center;

      addTriangleOutward(
        builder,
        c0,
        c1,
        topCenter,
        Vector3(0, 1, 0),
        uvScale: 0.55,
        color: topCol,
      );
      addQuadOutward(
        builder,
        b0,
        b1,
        c1,
        c0,
        outUpper,
        uvScale: 0.55,
        color: midCol,
      );
      addQuadOutward(
        builder,
        s0,
        s1,
        b1,
        b0,
        outLower,
        uvScale: 0.55,
        color: lowCol,
      );
      addTriangleOutward(
        builder,
        s1,
        s0,
        botCenter,
        Vector3(0, -1, 0),
        uvScale: 0.55,
        color: lowCol,
      );
    }
    builder.color(_whiteColor);
  }

  static void addStratifiedCliffBlock(
    GeometryBuilder builder,
    Vector3 baseCenter,
    Vector3 halfExtents, {
    double yaw = 0,
    double tiltX = 0.07,
    double tiltZ = -0.05,
    double seed = 0,
    Vector4? color,
  }) {
    const sides = 8;
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);
    Vector3 rot(double lx, double ly, double lz) => Vector3(
      baseCenter.x + lx * cy + lz * sy,
      baseCenter.y + ly,
      baseCenter.z - lx * sy + lz * cy,
    );

    final h = halfExtents.y * 2;
    final rx = halfExtents.x;
    final rz = halfExtents.z;

    final topCenter = rot(
      0.05 * rx * math.sin(seed * 1.7),
      h + 0.04 * h,
      0.05 * rz * math.cos(seed * 1.3),
    );
    final botCenter = rot(0, -0.58, 0);

    final skirtRing = <Vector3>[];
    final midOuterRing = <Vector3>[];
    final midShelfRing = <Vector3>[];
    final crownRing = <Vector3>[];

    for (var i = 0; i < sides; i++) {
      final a =
          (i / sides) * math.pi * 2 + 0.13 * math.sin(seed * 1.9 + i * 2.3);
      final facet = 0.80 + 0.25 * math.sin(a * 2.0 + seed * 2.1 + i * 1.1);
      final lx = math.cos(a) * rx * facet;
      final lz = math.sin(a) * rz * facet;
      final planeTilt = lx * tiltX + lz * tiltZ;
      final shelfInset = 0.83 + 0.08 * math.cos(a * 2.0 - seed);

      skirtRing.add(rot(lx * 1.12, -0.56, lz * 1.12));
      midOuterRing.add(rot(lx * 0.99, h * 0.46 + planeTilt * 0.65, lz * 0.99));
      midShelfRing.add(
        rot(lx * shelfInset, h * 0.50 + planeTilt * 0.70, lz * shelfInset),
      );
      crownRing.add(rot(lx * 0.76, h + planeTilt, lz * 0.76));
    }

    final base = color ?? Vector4(0.96, 0.95, 0.93, 0.5);
    final topCol = Vector4(base.x * 1.16, base.y * 1.10, base.z * 1.00, 0.5);
    final shelfCol = Vector4(base.x * 1.04, base.y * 1.02, base.z * 0.96, 0.5);
    final upperCol = Vector4(base.x * 0.92, base.y * 0.93, base.z * 0.96, 0.5);
    final lowerCol = Vector4(base.x * 0.76, base.y * 0.80, base.z * 0.86, 0.5);

    final centerWorld = rot(0, h * 0.5, 0);
    for (var i = 0; i < sides; i++) {
      final next = (i + 1) % sides;
      final s0 = skirtRing[i];
      final s1 = skirtRing[next];
      final mo0 = midOuterRing[i];
      final mo1 = midOuterRing[next];
      final ms0 = midShelfRing[i];
      final ms1 = midShelfRing[next];
      final c0 = crownRing[i];
      final c1 = crownRing[next];

      final outDir = ((mo0 + mo1) * 0.5) - centerWorld
        ..y = 0.12;

      addTriangleOutward(
        builder,
        c0,
        c1,
        topCenter,
        Vector3(0, 1, 0),
        uvScale: 0.48,
        color: topCol,
      );
      addQuadOutward(
        builder,
        ms0,
        ms1,
        c1,
        c0,
        outDir,
        uvScale: 0.48,
        color: upperCol,
      );
      addQuadOutward(
        builder,
        mo0,
        mo1,
        ms1,
        ms0,
        Vector3(0, 1, 0),
        uvScale: 0.48,
        color: shelfCol,
      );
      addQuadOutward(
        builder,
        s0,
        s1,
        mo1,
        mo0,
        outDir,
        uvScale: 0.48,
        color: lowerCol,
      );
      addTriangleOutward(
        builder,
        s1,
        s0,
        botCenter,
        Vector3(0, -1, 0),
        uvScale: 0.48,
        color: lowerCol,
      );
    }
    builder.color(_whiteColor);
  }

  static void addCordSegment(
    GeometryBuilder builder,
    Vec3 a,
    Vec3 b, {
    double halfThick = 0.022,
    Vector4? color,
  }) {
    final dx = b.x - a.x;
    final dz = b.z - a.z;
    final hLen = math.sqrt(dx * dx + dz * dz);
    final nx = hLen > 1e-5 ? -dz / hLen * halfThick : halfThick;
    final nz = hLen > 1e-5 ? dx / hLen * halfThick : 0.0;
    builder.color(color ?? _whiteColor);

    int v(Vector3 p, double u, double tv) {
      builder.texCoord(Vector2(u, tv));
      return builder.addVertex(p);
    }

    final a0 = v(Vector3(a.x - nx, a.y - halfThick, a.z - nz), 0, 0);
    final a1 = v(Vector3(a.x + nx, a.y - halfThick, a.z + nz), 1, 0);
    final a2 = v(Vector3(a.x + nx, a.y + halfThick, a.z + nz), 1, 1);
    final a3 = v(Vector3(a.x - nx, a.y + halfThick, a.z - nz), 0, 1);

    final b0 = v(Vector3(b.x - nx, b.y - halfThick, b.z - nz), 0, hLen);
    final b1 = v(Vector3(b.x + nx, b.y - halfThick, b.z + nz), 1, hLen);
    final b2 = v(Vector3(b.x + nx, b.y + halfThick, b.z + nz), 1, hLen);
    final b3 = v(Vector3(b.x - nx, b.y + halfThick, b.z - nz), 0, hLen);

    builder
      ..addTriangle(a3, b3, b2)
      ..addTriangle(a3, b2, a2)
      ..addTriangle(a0, a1, b1)
      ..addTriangle(a0, b1, b0)
      ..addTriangle(a1, a2, b2)
      ..addTriangle(a1, b2, b1)
      ..addTriangle(a0, b0, b3)
      ..addTriangle(a0, b3, a3);
  }

  static void addTaperedLimb(
    GeometryBuilder builder,
    Vec3 a,
    Vec3 b,
    double rA,
    double rB, {
    int sides = 5,
    Vector4? color,
  }) {
    final axis = (b - a).toVector3();
    final len = axis.length;
    if (len <= 1e-5) {
      return;
    }
    final dir = axis / len;
    final upRef = dir.y.abs() < 0.92 ? Vector3(0, 1, 0) : Vector3(1, 0, 0);
    final u = upRef.cross(dir).normalized();
    final w = dir.cross(u).normalized();

    final ringA = <Vector3>[];
    final ringB = <Vector3>[];
    final centerA = a.toVector3();
    final centerB = b.toVector3();
    for (var i = 0; i < sides; i++) {
      final ang = (i / sides) * math.pi * 2;
      final radial = u * math.cos(ang) + w * math.sin(ang);
      ringA.add(centerA + radial * rA);
      ringB.add(centerB + radial * rB);
    }

    for (var i = 0; i < sides; i++) {
      final next = (i + 1) % sides;
      final outHint =
          ((ringA[i] + ringA[next] + ringB[i] + ringB[next]) * 0.25) -
          ((centerA + centerB) * 0.5);
      addQuadOutward(
        builder,
        ringA[i],
        ringA[next],
        ringB[next],
        ringB[i],
        outHint,
        uvScale: 1.2,
        color: color,
      );
      addTriangleOutward(
        builder,
        ringB[i],
        ringB[next],
        centerB,
        dir,
        color: color,
      );
    }
  }

  static void addLanternBody(
    GeometryBuilder lanternBuilder,
    GeometryBuilder timberBuilder,
    Vector3 topHook, {
    double radius = 0.17,
    double height = 0.38,
  }) {
    addBox(
      timberBuilder,
      Vector3(topHook.x - 0.015, topHook.y - 0.12, topHook.z - 0.015),
      Vector3(topHook.x + 0.015, topHook.y + 0.01, topHook.z + 0.015),
    );
    final capTopY = topHook.y - 0.13;
    final bodyTopY = capTopY - 0.025;
    final bodyMidY = bodyTopY - height * 0.48;
    final bodyBotY = bodyTopY - height;
    final capBotY = bodyBotY - 0.025;
    final capR = radius * 0.58;

    addBox(
      timberBuilder,
      Vector3(topHook.x - capR, bodyTopY + 0.008, topHook.z - capR),
      Vector3(topHook.x + capR, capTopY, topHook.z + capR),
    );
    addBox(
      timberBuilder,
      Vector3(topHook.x - capR * 0.88, capBotY, topHook.z - capR * 0.88),
      Vector3(
        topHook.x + capR * 0.88,
        bodyBotY - 0.008,
        topHook.z + capR * 0.88,
      ),
    );

    const sides = 6;
    final topRing = <Vector3>[];
    final midRing = <Vector3>[];
    final botRing = <Vector3>[];
    for (var i = 0; i < sides; i++) {
      final ang = (i / sides) * math.pi * 2;
      final ca = math.cos(ang);
      final sa = math.sin(ang);
      topRing.add(
        Vector3(topHook.x + ca * capR, bodyTopY, topHook.z + sa * capR),
      );
      midRing.add(
        Vector3(topHook.x + ca * radius, bodyMidY, topHook.z + sa * radius),
      );
      botRing.add(
        Vector3(
          topHook.x + ca * capR * 0.92,
          bodyBotY,
          topHook.z + sa * capR * 0.92,
        ),
      );
    }
    final topCenter = Vector3(topHook.x, bodyTopY, topHook.z);
    final botCenter = Vector3(topHook.x, bodyBotY, topHook.z);
    for (var i = 0; i < sides; i++) {
      final next = (i + 1) % sides;
      final out =
          ((midRing[i] + midRing[next]) * 0.5) -
          Vector3(topHook.x, bodyMidY, topHook.z);
      addQuadOutward(
        lanternBuilder,
        midRing[i],
        midRing[next],
        topRing[next],
        topRing[i],
        out + Vector3(0, 0.2, 0),
        uvScale: 1.6,
      );
      addQuadOutward(
        lanternBuilder,
        botRing[i],
        botRing[next],
        midRing[next],
        midRing[i],
        out - Vector3(0, 0.2, 0),
        uvScale: 1.6,
      );
      addTriangleOutward(
        lanternBuilder,
        topRing[i],
        topRing[next],
        topCenter,
        Vector3(0, 1, 0),
      );
      addTriangleOutward(
        lanternBuilder,
        botRing[next],
        botRing[i],
        botCenter,
        Vector3(0, -1, 0),
      );
    }
  }

  static void addLeanToRoof(
    GeometryBuilder roofBuilder, {
    required double xMin,
    required double xMax,
    required double zWall,
    required double zFront,
    required double yWall,
    required double yFront,
    double thick = 0.08,
  }) {
    final tW0 = Vector3(xMin, yWall + thick, zWall);
    final tW1 = Vector3(xMax, yWall + thick, zWall);
    final tF1 = Vector3(xMax, yFront + thick, zFront);
    final tF0 = Vector3(xMin, yFront + thick, zFront);

    final bW0 = Vector3(xMin, yWall, zWall);
    final bW1 = Vector3(xMax, yWall, zWall);
    final bF1 = Vector3(xMax, yFront, zFront);
    final bF0 = Vector3(xMin, yFront, zFront);

    final zSign = zFront >= zWall ? 1.0 : -1.0;
    addQuadOutward(
      roofBuilder,
      tW0,
      tW1,
      tF1,
      tF0,
      Vector3(0, 1, zSign * 0.35),
      uvScale: 0.75,
    );
    addQuadOutward(
      roofBuilder,
      bW0,
      bW1,
      bF1,
      bF0,
      Vector3(0, -1, -zSign * 0.35),
    );
    addQuadOutward(
      roofBuilder,
      bF0,
      bF1,
      tF1,
      tF0,
      Vector3(0, 0, zSign),
      uvScale: 0.75,
    );
    addQuadOutward(roofBuilder, bW0, bF0, tF0, tW0, Vector3(-1, 0, 0));
    addQuadOutward(roofBuilder, bW1, bF1, tF1, tW1, Vector3(1, 0, 0));
  }

  static void addGabledRoof(
    GeometryBuilder roofBuilder,
    GeometryBuilder timberBuilder, {
    required double xHalf,
    required double zMin,
    required double zMax,
    required double eavesY,
    required double ridgeY,
    double thick = 0.14,
  }) {
    final tR0 = Vector3(0, ridgeY + thick, zMin);
    final tR1 = Vector3(0, ridgeY + thick, zMax);
    final tL0 = Vector3(-xHalf, eavesY + thick, zMin);
    final tL1 = Vector3(-xHalf, eavesY + thick, zMax);
    final tRt0 = Vector3(xHalf, eavesY + thick, zMin);
    final tRt1 = Vector3(xHalf, eavesY + thick, zMax);

    final bR0 = Vector3(0, ridgeY, zMin);
    final bR1 = Vector3(0, ridgeY, zMax);
    final bL0 = Vector3(-xHalf, eavesY, zMin);
    final bL1 = Vector3(-xHalf, eavesY, zMax);
    final bRt0 = Vector3(xHalf, eavesY, zMin);
    final bRt1 = Vector3(xHalf, eavesY, zMax);

    addQuadOutward(
      roofBuilder,
      tL0,
      tL1,
      tR1,
      tR0,
      Vector3(-0.5, 1, 0),
      uvScale: 0.75,
    );
    addQuadOutward(
      roofBuilder,
      tR0,
      tR1,
      tRt1,
      tRt0,
      Vector3(0.5, 1, 0),
      uvScale: 0.75,
    );
    addQuadOutward(roofBuilder, bL0, bL1, bR1, bR0, Vector3(0.5, -1, 0));
    addQuadOutward(roofBuilder, bR0, bR1, bRt1, bRt0, Vector3(-0.5, -1, 0));
    addQuadOutward(roofBuilder, bL0, bL1, tL1, tL0, Vector3(-1, 0, 0));
    addQuadOutward(roofBuilder, bRt0, bRt1, tRt1, tRt0, Vector3(1, 0, 0));
    addQuadOutward(roofBuilder, bL1, bR1, tR1, tL1, Vector3(0, 0, 1));
    addQuadOutward(roofBuilder, bR1, bRt1, tRt1, tR1, Vector3(0, 0, 1));
    addQuadOutward(roofBuilder, bL0, bR0, tR0, tL0, Vector3(0, 0, -1));
    addQuadOutward(roofBuilder, bR0, bRt0, tRt0, tR0, Vector3(0, 0, -1));

    final crestBottom = ridgeY + thick + 0.02;
    addBox(
      roofBuilder,
      Vector3(-0.15, crestBottom, zMin - 0.06),
      Vector3(0.15, crestBottom + 0.19, zMax + 0.06),
    );
    addBox(
      roofBuilder,
      Vector3(-0.20, crestBottom + 0.21, zMax - 0.22),
      Vector3(0.20, crestBottom + 0.42, zMax + 0.10),
    );
    addBox(
      roofBuilder,
      Vector3(-0.20, crestBottom + 0.21, zMin - 0.10),
      Vector3(0.20, crestBottom + 0.42, zMin + 0.22),
    );
    addBox(
      timberBuilder,
      Vector3(-0.08, ridgeY - 0.24, zMax + 0.02),
      Vector3(0.08, ridgeY - 0.04, zMax + 0.16),
    );
    addBox(
      timberBuilder,
      Vector3(-0.08, ridgeY - 0.24, zMin - 0.16),
      Vector3(0.08, ridgeY - 0.04, zMin - 0.02),
    );
  }

  static void addNoboriBanner(
    GeometryBuilder timberBuilder,
    GeometryBuilder clothBuilder, {
    required double xPole,
    required double zPole,
    required double dirX,
    required Vector4 mainColor,
    required Vector4 crestColor,
    double topY = 2.52,
    double bottomY = 0.86,
    double bannerWidth = 0.34,
  }) {
    addBox(
      timberBuilder,
      Vector3(xPole - 0.085, 0.04, zPole - 0.085),
      Vector3(xPole + 0.085, 0.22, zPole + 0.085),
    );
    addTaperedLimb(
      timberBuilder,
      Vec3(xPole, 0.24, zPole),
      Vec3(xPole, topY, zPole),
      0.026,
      0.018,
      sides: 6,
    );
    addCordSegment(
      timberBuilder,
      Vec3(xPole + dirX * 0.03, topY - 0.05, zPole),
      Vec3(xPole + dirX * (bannerWidth + 0.08), topY - 0.05, zPole),
      halfThick: 0.014,
    );

    final edgeNear = xPole + dirX * 0.055;
    final edgeFar = xPole + dirX * (0.055 + bannerWidth);
    final xMin = math.min(edgeNear, edgeFar);
    final xMax = math.max(edgeNear, edgeFar);

    addBox(
      clothBuilder,
      Vector3(xMin, bottomY, zPole - 0.016),
      Vector3(xMax, bottomY + 0.36, zPole + 0.016),
      color: crestColor,
    );
    addBox(
      clothBuilder,
      Vector3(xMin, bottomY + 0.39, zPole - 0.016),
      Vector3(xMax, topY - 0.11, zPole + 0.016),
      color: mainColor,
    );
  }

  static Vector3 _localPropPoint(
    Vector3 origin,
    double cy,
    double sy,
    double lx,
    double ly,
    double lz,
  ) => Vector3(
    origin.x + lx * cy + lz * sy,
    origin.y + ly,
    origin.z - lx * sy + lz * cy,
  );

  static void _addRotatedBox(
    GeometryBuilder builder,
    Vector3 origin,
    double cy,
    double sy,
    Vector3 minLocal,
    Vector3 maxLocal, {
    Vector4? color,
  }) {
    final b00 = _localPropPoint(
      origin,
      cy,
      sy,
      minLocal.x,
      minLocal.y,
      minLocal.z,
    );
    final b10 = _localPropPoint(
      origin,
      cy,
      sy,
      maxLocal.x,
      minLocal.y,
      minLocal.z,
    );
    final b11 = _localPropPoint(
      origin,
      cy,
      sy,
      maxLocal.x,
      minLocal.y,
      maxLocal.z,
    );
    final b01 = _localPropPoint(
      origin,
      cy,
      sy,
      minLocal.x,
      minLocal.y,
      maxLocal.z,
    );
    final t00 = _localPropPoint(
      origin,
      cy,
      sy,
      minLocal.x,
      maxLocal.y,
      minLocal.z,
    );
    final t10 = _localPropPoint(
      origin,
      cy,
      sy,
      maxLocal.x,
      maxLocal.y,
      minLocal.z,
    );
    final t11 = _localPropPoint(
      origin,
      cy,
      sy,
      maxLocal.x,
      maxLocal.y,
      maxLocal.z,
    );
    final t01 = _localPropPoint(
      origin,
      cy,
      sy,
      minLocal.x,
      maxLocal.y,
      maxLocal.z,
    );

    final nPosX = Vector3(cy, 0, -sy);
    final nNegX = Vector3(-cy, 0, sy);
    final nPosZ = Vector3(sy, 0, cy);
    final nNegZ = Vector3(-sy, 0, -cy);
    addQuadOutward(builder, b00, b10, t10, t00, nNegZ, color: color);
    addQuadOutward(builder, b11, b01, t01, t11, nPosZ, color: color);
    addQuadOutward(builder, b01, b00, t00, t01, nNegX, color: color);
    addQuadOutward(builder, b10, b11, t11, t10, nPosX, color: color);
    addQuadOutward(builder, t00, t10, t11, t01, Vector3(0, 1, 0), color: color);
    addQuadOutward(
      builder,
      b01,
      b11,
      b10,
      b00,
      Vector3(0, -1, 0),
      color: color,
    );
  }

  static void addSakeBarrelRack(
    GeometryBuilder timberBuilder,
    GeometryBuilder strawBuilder, {
    required Vector3 origin,
    double yaw = 0,
    bool twoTier = true,
  }) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);

    for (final zSkid in const [-0.15, 0.15]) {
      _addRotatedBox(
        timberBuilder,
        origin,
        cy,
        sy,
        Vector3(-0.56, -0.04, zSkid - 0.04),
        Vector3(0.56, 0.075, zSkid + 0.04),
      );
    }

    final caskStrawColor = Vector4(1.06, 0.96, 0.78, 1);
    void emitHorizontalCask(double lx, double ly, double radius) {
      final a = _localPropPoint(origin, cy, sy, lx, ly, -0.24);
      final b = _localPropPoint(origin, cy, sy, lx, ly, 0.24);
      addTaperedLimb(
        strawBuilder,
        Vec3(a.x, a.y, a.z),
        Vec3(b.x, b.y, b.z),
        radius,
        radius,
        sides: 8,
        color: caskStrawColor,
      );
      for (final hz in const [-0.18, 0.18]) {
        final ha = _localPropPoint(origin, cy, sy, lx, ly, hz - 0.025);
        final hb = _localPropPoint(origin, cy, sy, lx, ly, hz + 0.025);
        addTaperedLimb(
          timberBuilder,
          Vec3(ha.x, ha.y, ha.z),
          Vec3(hb.x, hb.y, hb.z),
          radius + 0.015,
          radius + 0.015,
          sides: 8,
        );
      }
      for (final capZ in const [-0.245, 0.245]) {
        _addRotatedBox(
          timberBuilder,
          origin,
          cy,
          sy,
          Vector3(lx - radius * 0.62, ly - radius * 0.62, capZ - 0.012),
          Vector3(lx + radius * 0.62, ly + radius * 0.62, capZ + 0.012),
        );
      }
    }

    emitHorizontalCask(-0.27, 0.31, 0.22);
    emitHorizontalCask(0.27, 0.31, 0.22);
    if (twoTier) {
      emitHorizontalCask(0, 0.70, 0.21);
    }
  }

  static void addHandcart(
    GeometryBuilder timberBuilder,
    GeometryBuilder cargoBuilder, {
    required Vector3 origin,
    double yaw = 0,
  }) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);

    for (final side in const [-0.38, 0.38]) {
      final wIn = _localPropPoint(origin, cy, sy, side - 0.03, 0.34, -0.12);
      final wOut = _localPropPoint(origin, cy, sy, side + 0.03, 0.34, -0.12);
      addTaperedLimb(
        timberBuilder,
        Vec3(wIn.x, wIn.y, wIn.z),
        Vec3(wOut.x, wOut.y, wOut.z),
        0.34,
        0.34,
        sides: 8,
      );
      final hIn = _localPropPoint(origin, cy, sy, side - 0.06, 0.34, -0.12);
      final hOut = _localPropPoint(origin, cy, sy, side + 0.06, 0.34, -0.12);
      addTaperedLimb(
        cargoBuilder,
        Vec3(hIn.x, hIn.y, hIn.z),
        Vec3(hOut.x, hOut.y, hOut.z),
        0.09,
        0.09,
        sides: 6,
        color: Vector4(0.86, 0.76, 0.60, 1),
      );
    }

    final axL = _localPropPoint(origin, cy, sy, -0.45, 0.34, -0.12);
    final axR = _localPropPoint(origin, cy, sy, 0.45, 0.34, -0.12);
    addCordSegment(
      timberBuilder,
      Vec3(axL.x, axL.y, axL.z),
      Vec3(axR.x, axR.y, axR.z),
      halfThick: 0.032,
    );

    for (final rx in const [-0.29, 0.29]) {
      final rear = _localPropPoint(origin, cy, sy, rx, 0.48, -0.78);
      final front = _localPropPoint(origin, cy, sy, rx * 0.88, 0.06, 0.92);
      addCordSegment(
        timberBuilder,
        Vec3(rear.x, rear.y, rear.z),
        Vec3(front.x, front.y, front.z),
        halfThick: 0.030,
      );
    }
    final barL = _localPropPoint(origin, cy, sy, -0.28, 0.07, 0.86);
    final barR = _localPropPoint(origin, cy, sy, 0.28, 0.07, 0.86);
    addCordSegment(
      timberBuilder,
      Vec3(barL.x, barL.y, barL.z),
      Vec3(barR.x, barR.y, barR.z),
      halfThick: 0.024,
    );

    for (var s = 0; s < 4; s++) {
      final lz = -0.66 + s * 0.32;
      final ly = 0.45 - (lz + 0.78) * 0.24;
      final sL = _localPropPoint(origin, cy, sy, -0.32, ly, lz);
      final sR = _localPropPoint(origin, cy, sy, 0.32, ly, lz);
      addCordSegment(
        timberBuilder,
        Vec3(sL.x, sL.y, sL.z),
        Vec3(sR.x, sR.y, sR.z),
      );
    }

    _addRotatedBox(
      cargoBuilder,
      origin,
      cy,
      sy,
      Vector3(-0.24, 0.44, -0.62),
      Vector3(0.24, 0.82, -0.14),
      color: Vector4(0.98, 0.88, 0.70, 1),
    );
    final baleA = _localPropPoint(origin, cy, sy, -0.22, 0.48, 0.14);
    final baleB = _localPropPoint(origin, cy, sy, 0.22, 0.48, 0.14);
    addTaperedLimb(
      cargoBuilder,
      Vec3(baleA.x, baleA.y, baleA.z),
      Vec3(baleB.x, baleB.y, baleB.z),
      0.16,
      0.16,
      sides: 7,
      color: Vector4(1.06, 0.95, 0.74, 1),
    );
  }

  static void addFirewoodStack(
    GeometryBuilder timberBuilder,
    GeometryBuilder roofBuilder, {
    required Vector3 origin,
    double yaw = 0,
  }) {
    final cy = math.cos(yaw);
    final sy = math.sin(yaw);

    for (final sx in const [-0.46, 0.46]) {
      _addRotatedBox(
        timberBuilder,
        origin,
        cy,
        sy,
        Vector3(sx - 0.03, -0.04, -0.18),
        Vector3(sx + 0.03, 0.68, -0.12),
      );
      _addRotatedBox(
        timberBuilder,
        origin,
        cy,
        sy,
        Vector3(sx - 0.03, -0.04, 0.12),
        Vector3(sx + 0.03, 0.58, 0.18),
      );
    }

    for (var row = 0; row < 3; row++) {
      final count = 6 - row;
      final ly = 0.09 + row * 0.115;
      for (var c = 0; c < count; c++) {
        final lx = -((count - 1) * 0.068) + c * 0.136;
        final a = _localPropPoint(origin, cy, sy, lx, ly, -0.20);
        final b = _localPropPoint(origin, cy, sy, lx, ly, 0.20);
        addTaperedLimb(
          timberBuilder,
          Vec3(a.x, a.y, a.z),
          Vec3(b.x, b.y, b.z),
          0.056,
          0.052,
          sides: 6,
        );
      }
    }

    final rBL = _localPropPoint(origin, cy, sy, -0.54, 0.72, -0.24);
    final rBR = _localPropPoint(origin, cy, sy, 0.54, 0.72, -0.24);
    final rFL = _localPropPoint(origin, cy, sy, -0.54, 0.58, 0.26);
    final rFR = _localPropPoint(origin, cy, sy, 0.54, 0.58, 0.26);
    final upOffset = Vector3(0, 0.045, 0);
    addQuadOutward(
      roofBuilder,
      rFL + upOffset,
      rFR + upOffset,
      rBR + upOffset,
      rBL + upOffset,
      Vector3(0, 1, 0),
    );
    addQuadOutward(roofBuilder, rBL, rBR, rFR, rFL, Vector3(0, -1, 0));
  }

  static void addStoneToro(
    GeometryBuilder stoneBuilder,
    GeometryBuilder glowBuilder,
    Vector3 origin,
  ) {
    final toroColor = Vector4(0.96, 0.95, 0.92, 0.50);
    addTaperedLimb(
      stoneBuilder,
      Vec3(origin.x, origin.y - 0.16, origin.z),
      Vec3(origin.x, origin.y + 0.16, origin.z),
      0.27,
      0.23,
      sides: 6,
      color: toroColor,
    );
    addTaperedLimb(
      stoneBuilder,
      Vec3(origin.x, origin.y + 0.175, origin.z),
      Vec3(origin.x, origin.y + 0.76, origin.z),
      0.115,
      0.095,
      sides: 6,
      color: toroColor,
    );
    addTaperedLimb(
      stoneBuilder,
      Vec3(origin.x, origin.y + 0.775, origin.z),
      Vec3(origin.x, origin.y + 0.87, origin.z),
      0.14,
      0.23,
      sides: 6,
      color: toroColor,
    );
    addBox(
      glowBuilder,
      Vector3(origin.x - 0.11, origin.y + 0.885, origin.z - 0.11),
      Vector3(origin.x + 0.11, origin.y + 1.15, origin.z + 0.11),
    );
    addTaperedLimb(
      stoneBuilder,
      Vec3(origin.x, origin.y + 1.165, origin.z),
      Vec3(origin.x, origin.y + 1.36, origin.z),
      0.33,
      0.075,
      sides: 6,
      color: toroColor,
    );
    addTaperedLimb(
      stoneBuilder,
      Vec3(origin.x, origin.y + 1.372, origin.z),
      Vec3(origin.x, origin.y + 1.48, origin.z),
      0.062,
      0.012,
      sides: 6,
      color: toroColor,
    );
  }

  Node buildStructureNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final structureNode = Node(name: 'structure_${structure.id.value}')
      ..position = structure.position.toVector3()
      ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), structure.yawRadians);

    final content = switch (structure.kind) {
      StructureKind.machiya => buildMachiyaNode(structure, resolveMaterial),
      StructureKind.chaya => buildChayaNode(structure, resolveMaterial),
      StructureKind.kura => buildKuraNode(structure, resolveMaterial),
      StructureKind.marketStall => buildMarketStallNode(
        structure,
        resolveMaterial,
      ),
      StructureKind.toriiGate => buildToriiGateNode(structure, resolveMaterial),
      StructureKind.yaguraTower => buildYaguraTowerNode(
        structure,
        resolveMaterial,
      ),
      StructureKind.rockOutcrop => buildRockOutcropNode(
        structure,
        resolveMaterial,
      ),
      StructureKind.mapleCluster => buildMapleNode(structure, resolveMaterial),
      StructureKind.bambooGrove => buildBambooNode(structure, resolveMaterial),
      StructureKind.pineTree => buildPineNode(structure, resolveMaterial),
      StructureKind.weepingWillow => buildWillowNode(
        structure,
        resolveMaterial,
      ),
    };

    structureNode.add(content);
    return structureNode;
  }

  Node buildMachiyaNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final hash = structure.id.value.hashCode.abs();
    final isTwoStory = hash.isEven;
    final variant = hash % 3;

    final stoneBuilder = GeometryBuilder();
    final plasterBuilder = GeometryBuilder();
    final timberBuilder = GeometryBuilder();
    final shojiBuilder = GeometryBuilder();
    final roofBuilder = GeometryBuilder();
    final awningBuilder = GeometryBuilder();
    final lanternBuilder = GeometryBuilder();

    addBox(
      stoneBuilder,
      Vector3(-2.60, -1.40, -3.28),
      Vector3(2.60, 0.22, 3.28),
    );

    final wallHeight = isTwoStory ? 4.45 : 3.18;
    final eavesY = wallHeight + 0.08;
    final ridgeY = eavesY + 1.38;

    addBox(
      plasterBuilder,
      Vector3(-2.44, 0.26, -3.12),
      Vector3(2.44, wallHeight, 3.12),
    );
    addTriangleOutward(
      plasterBuilder,
      Vector3(-2.40, wallHeight + 0.02, 3.10),
      Vector3(2.40, wallHeight + 0.02, 3.10),
      Vector3(0, ridgeY - 0.16, 3.10),
      Vector3(0, 0, 1),
    );
    addTriangleOutward(
      plasterBuilder,
      Vector3(-2.40, wallHeight + 0.02, -3.10),
      Vector3(2.40, wallHeight + 0.02, -3.10),
      Vector3(0, ridgeY - 0.16, -3.10),
      Vector3(0, 0, -1),
    );

    const cornerPosts = [
      (-2.54, -2.38, 3.04, 3.20),
      (2.38, 2.54, 3.04, 3.20),
      (-2.54, -2.38, -3.20, -3.04),
      (2.38, 2.54, -3.20, -3.04),
    ];
    for (final post in cornerPosts) {
      addBox(
        timberBuilder,
        Vector3(post.$1, 0.24, post.$3),
        Vector3(post.$2, wallHeight + 0.04, post.$4),
      );
    }

    addBox(
      timberBuilder,
      Vector3(-2.34, 0.28, 3.16),
      Vector3(-0.88, 0.94, 3.23),
    );
    addBox(timberBuilder, Vector3(0.88, 0.28, 3.16), Vector3(2.34, 0.94, 3.23));
    addBox(timberBuilder, Vector3(-2.52, 0.28, -3), Vector3(-2.47, 1.38, 3));
    addBox(timberBuilder, Vector3(2.47, 0.28, -3), Vector3(2.52, 1.38, 3));
    addBox(
      timberBuilder,
      Vector3(-2.34, 0.28, -3.21),
      Vector3(2.34, 1.38, -3.16),
    );
    for (final sideSign in const [-1.0, 1.0]) {
      final xIn = sideSign < 0 ? -2.53 : 2.47;
      final xOut = sideSign < 0 ? -2.47 : 2.53;
      addBox(timberBuilder, Vector3(xIn, 2.26, -3), Vector3(xOut, 2.36, 3));
      addBox(
        timberBuilder,
        Vector3(xIn, wallHeight - 0.08, -3),
        Vector3(xOut, wallHeight + 0.02, 3),
      );
      addBox(
        timberBuilder,
        Vector3(xIn, 1.40, -0.05),
        Vector3(xOut, 2.24, 0.05),
      );
      addBox(
        timberBuilder,
        Vector3(xIn, 2.38, -0.05),
        Vector3(xOut, wallHeight - 0.10, 0.05),
      );
      if (isTwoStory) {
        final sxIn = sideSign < 0 ? -2.51 : 2.47;
        final sxOut = sideSign < 0 ? -2.47 : 2.51;
        addBox(
          shojiBuilder,
          Vector3(sxIn, 2.96, -0.94),
          Vector3(sxOut, 3.62, -0.22),
        );
        addBox(
          shojiBuilder,
          Vector3(sxIn, 2.96, 0.22),
          Vector3(sxOut, 3.62, 0.94),
        );
      }
    }

    addBox(
      timberBuilder,
      Vector3(-0.84, 0.24, 3.15),
      Vector3(-0.72, 2.22, 3.30),
    );
    addBox(timberBuilder, Vector3(0.72, 0.24, 3.15), Vector3(0.84, 2.22, 3.30));
    addBox(
      timberBuilder,
      Vector3(-2.36, 2.24, 3.15),
      Vector3(2.36, 2.36, 3.28),
    );

    addBox(
      shojiBuilder,
      Vector3(-2.28, 0.98, 3.16),
      Vector3(-0.90, 2.20, 3.21),
    );
    addBox(shojiBuilder, Vector3(-0.68, 0.32, 3.16), Vector3(0.68, 2.20, 3.21));
    addBox(shojiBuilder, Vector3(0.90, 0.98, 3.16), Vector3(2.28, 2.20, 3.21));

    for (final span in const [(-2.22, -0.96), (0.96, 2.22)]) {
      const bars = 5;
      for (var i = 0; i < bars; i++) {
        final bx = span.$1 + (span.$2 - span.$1) * (i / (bars - 1));
        addBox(
          timberBuilder,
          Vector3(bx - 0.025, 0.96, 3.24),
          Vector3(bx + 0.025, 2.20, 3.28),
        );
      }
    }

    const norenPanels = [(-0.62, -0.24), (-0.18, 0.18), (0.24, 0.62)];
    for (final p in norenPanels) {
      addBox(
        awningBuilder,
        Vector3(p.$1, 1.48, 3.32),
        Vector3(p.$2, 2.16, 3.36),
      );
    }

    addLeanToRoof(
      roofBuilder,
      xMin: -2.78,
      xMax: 2.78,
      zWall: 3.16,
      zFront: 4.02,
      yWall: 2.52,
      yFront: 2.18,
    );
    for (final px in const [-2.48, 2.48]) {
      addBox(
        timberBuilder,
        Vector3(px - 0.055, 0.02, 3.84),
        Vector3(px + 0.055, 2.16, 3.95),
      );
    }

    if (isTwoStory) {
      addBox(
        shojiBuilder,
        Vector3(-1.68, 2.92, 3.16),
        Vector3(1.68, 3.96, 3.22),
      );
      for (var i = 0; i < 7; i++) {
        final bx = -1.62 + 3.24 * (i / 6);
        addBox(
          timberBuilder,
          Vector3(bx - 0.025, 2.90, 3.25),
          Vector3(bx + 0.025, 3.42, 3.32),
        );
      }
      addBox(
        timberBuilder,
        Vector3(-1.76, 3.44, 3.24),
        Vector3(1.76, 3.50, 3.34),
      );
    }

    addGabledRoof(
      roofBuilder,
      timberBuilder,
      xHalf: 3.06,
      zMin: -3.72,
      zMax: 3.72,
      eavesY: eavesY,
      ridgeY: ridgeY,
    );

    if (variant == 0) {
      addBox(
        timberBuilder,
        Vector3(1.72, 0.04, 3.40),
        Vector3(2.24, 0.86, 3.92),
      );
      addBox(
        shojiBuilder,
        Vector3(1.80, 0.16, 3.94),
        Vector3(2.16, 0.76, 3.99),
      );
      addTaperedLimb(
        timberBuilder,
        const Vec3(-1.95, 0.04, 3.58),
        const Vec3(-1.95, 0.68, 3.58),
        0.24,
        0.22,
        sides: 6,
      );
    } else if (variant == 1) {
      addBox(
        timberBuilder,
        Vector3(-2.22, 0.04, 3.36),
        Vector3(-1.58, 0.56, 3.88),
      );
      addBox(
        timberBuilder,
        Vector3(-2.12, 0.58, 3.42),
        Vector3(-1.64, 0.98, 3.84),
      );
      addLanternBody(
        lanternBuilder,
        timberBuilder,
        Vector3(1.08, 2.16, 3.86),
        radius: 0.15,
        height: 0.34,
      );
      addNoboriBanner(
        timberBuilder,
        awningBuilder,
        xPole: 2.26,
        zPole: 4.14,
        dirX: -1,
        mainColor: Vector4(0.14, 0.24, 0.48, 0.5),
        crestColor: Vector4(0.94, 0.88, 0.72, 0.5),
      );
    } else {
      addBox(
        timberBuilder,
        Vector3(1.32, 0.04, 3.42),
        Vector3(2.28, 0.42, 3.84),
      );
      addLanternBody(
        lanternBuilder,
        timberBuilder,
        Vector3(-1.08, 2.16, 3.86),
        radius: 0.15,
        height: 0.34,
      );
      addNoboriBanner(
        timberBuilder,
        awningBuilder,
        xPole: -2.26,
        zPole: 4.14,
        dirX: 1,
        mainColor: Vector4(0.58, 0.18, 0.12, 0.5),
        crestColor: Vector4(0.92, 0.82, 0.62, 0.5),
      );
    }

    final clutterStyle = (hash ~/ 3) % 3;
    if (clutterStyle == 0) {
      addSakeBarrelRack(
        timberBuilder,
        plasterBuilder,
        origin: Vector3(-2.92, 0, 1.15),
        yaw: math.pi / 2,
      );
    } else if (clutterStyle == 1) {
      addFirewoodStack(
        timberBuilder,
        roofBuilder,
        origin: Vector3(2.90, 0, -0.55),
        yaw: -math.pi / 2,
      );
    } else {
      addHandcart(
        timberBuilder,
        plasterBuilder,
        origin: Vector3(-2.98, 0, -0.35),
        yaw: 0.05,
      );
    }

    root
      ..add(
        Node(
          mesh: Mesh(
            stoneBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.ishigakiStone),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            plasterBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.plasterWall),
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
            shojiBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.shojiScreen),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            awningBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.fabricAwning),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            roofBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.kawaraTile),
          ),
        ),
      );
    if (variant != 0) {
      root.add(
        Node(
          mesh: Mesh(
            lanternBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.chochinLantern),
          ),
        ),
      );
    }

    return root;
  }

  Node buildChayaNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final stoneBuilder = GeometryBuilder();
    final plasterBuilder = GeometryBuilder();
    final timberBuilder = GeometryBuilder();
    final shojiBuilder = GeometryBuilder();
    final roofBuilder = GeometryBuilder();
    final lacquerBuilder = GeometryBuilder();
    final awningBuilder = GeometryBuilder();
    final lanternBuilder = GeometryBuilder();

    addBox(
      stoneBuilder,
      Vector3(-2.90, -1.40, -2.75),
      Vector3(2.10, 0.20, 1.55),
    );
    addBox(
      stoneBuilder,
      Vector3(-0.45, -0.20, 2.72),
      Vector3(0.45, 0.05, 3.12),
    );

    addBox(
      timberBuilder,
      Vector3(-2.92, 0.22, 1.58),
      Vector3(2.92, 0.35, 2.58),
    );
    addBox(
      timberBuilder,
      Vector3(2.12, 0.22, -2.68),
      Vector3(2.92, 0.35, 1.56),
    );
    for (final st in const [(-2.60, 2.48), (0.0, 2.48), (2.78, 2.48)]) {
      addBox(
        stoneBuilder,
        Vector3(st.$1 - 0.14, -0.80, st.$2 - 0.14),
        Vector3(st.$1 + 0.14, 0.20, st.$2 + 0.14),
      );
    }
    for (final vp in const [
      (-2.80, 2.46),
      (-0.92, 2.46),
      (0.92, 2.46),
      (2.78, 2.46),
      (2.78, 0.0),
      (2.78, -2.46),
    ]) {
      addBox(
        timberBuilder,
        Vector3(vp.$1 - 0.06, 0.37, vp.$2 - 0.06),
        Vector3(vp.$1 + 0.06, 2.46, vp.$2 + 0.06),
      );
    }

    const wallTop = 3.06;
    addBox(
      plasterBuilder,
      Vector3(-2.72, 0.37, -2.58),
      Vector3(2.06, wallTop, 1.52),
    );
    addTriangleOutward(
      plasterBuilder,
      Vector3(-2.68, wallTop + 0.02, 1.50),
      Vector3(2.04, wallTop + 0.02, 1.50),
      Vector3(-0.32, 4.38, 1.50),
      Vector3(0, 0, 1),
    );
    addTriangleOutward(
      plasterBuilder,
      Vector3(-2.68, wallTop + 0.02, -2.56),
      Vector3(2.04, wallTop + 0.02, -2.56),
      Vector3(-0.32, 4.38, -2.56),
      Vector3(0, 0, -1),
    );

    addBox(
      shojiBuilder,
      Vector3(-2.42, 0.42, 1.54),
      Vector3(-0.88, 2.28, 1.59),
    );
    addBox(shojiBuilder, Vector3(-0.68, 0.42, 1.54), Vector3(0.68, 2.28, 1.59));
    addBox(shojiBuilder, Vector3(0.88, 0.42, 1.54), Vector3(1.88, 2.28, 1.59));
    addBox(shojiBuilder, Vector3(2.08, 0.42, -1.90), Vector3(2.13, 2.28, 1.24));

    for (final p in const [(-0.78, -0.30), (-0.22, 0.22), (0.30, 0.78)]) {
      addBox(
        awningBuilder,
        Vector3(p.$1, 1.72, 2.50),
        Vector3(p.$2, 2.34, 2.55),
      );
    }

    const eavesY = 3.12;
    const ridgeY = 4.54;
    addGabledRoof(
      roofBuilder,
      timberBuilder,
      xHalf: 3.18,
      zMin: -3.05,
      zMax: 2.15,
      eavesY: eavesY,
      ridgeY: ridgeY,
    );
    addLeanToRoof(
      roofBuilder,
      xMin: -3.08,
      xMax: 3.04,
      zWall: 1.54,
      zFront: 2.96,
      yWall: 2.74,
      yFront: 2.36,
    );

    addBox(
      timberBuilder,
      Vector3(-2.42, 0.02, 2.74),
      Vector3(-0.92, 0.36, 3.24),
    );
    addBox(
      lacquerBuilder,
      Vector3(-2.46, 0.38, 2.70),
      Vector3(-0.88, 0.46, 3.28),
    );

    addStoneToro(stoneBuilder, shojiBuilder, Vector3(2.48, 0, 2.94));
    if (structure.id.value.hashCode.abs().isEven) {
      addSakeBarrelRack(
        timberBuilder,
        plasterBuilder,
        origin: Vector3(-3.22, 0, -0.70),
        yaw: math.pi / 2,
      );
    } else {
      addFirewoodStack(
        timberBuilder,
        roofBuilder,
        origin: Vector3(-3.18, 0, -0.60),
        yaw: math.pi / 2,
      );
    }

    addLanternBody(
      lanternBuilder,
      timberBuilder,
      Vector3(-1.58, 2.34, 2.84),
      radius: 0.18,
      height: 0.40,
    );
    addLanternBody(
      lanternBuilder,
      timberBuilder,
      Vector3(1.58, 2.34, 2.84),
      radius: 0.18,
      height: 0.40,
    );
    addNoboriBanner(
      timberBuilder,
      awningBuilder,
      xPole: -2.68,
      zPole: 3.12,
      dirX: 1,
      mainColor: Vector4(0.68, 0.14, 0.09, 0.5),
      crestColor: Vector4(0.96, 0.88, 0.70, 0.5),
      topY: 2.58,
      bottomY: 0.88,
    );

    root
      ..add(
        Node(
          mesh: Mesh(
            stoneBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.ishigakiStone),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            plasterBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.plasterWall),
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
            shojiBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.shojiScreen),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            lacquerBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.vermilionLacquer),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            awningBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.fabricAwning),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            lanternBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.chochinLantern),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            roofBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.kawaraTile),
          ),
        ),
      );
    return root;
  }

  Node buildKuraNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final stoneBuilder = GeometryBuilder();
    final kuraBuilder = GeometryBuilder();
    final timberBuilder = GeometryBuilder();
    final roofBuilder = GeometryBuilder();

    const wBase = 2.38;
    const dBase = 2.88;
    const wTop = 2.26;
    const dTop = 2.76;
    const yBase = -1.50;
    const yStone = 0.68;

    final sb0 = Vector3(-wBase, yBase, -dBase);
    final sb1 = Vector3(wBase, yBase, -dBase);
    final sb2 = Vector3(wBase, yBase, dBase);
    final sb3 = Vector3(-wBase, yBase, dBase);
    final st0 = Vector3(-wTop, yStone, -dTop);
    final st1 = Vector3(wTop, yStone, -dTop);
    final st2 = Vector3(wTop, yStone, dTop);
    final st3 = Vector3(-wTop, yStone, dTop);

    addQuadOutward(stoneBuilder, sb0, sb1, st1, st0, Vector3(0, 0.2, -1));
    addQuadOutward(stoneBuilder, sb1, sb2, st2, st1, Vector3(1, 0.2, 0));
    addQuadOutward(stoneBuilder, sb2, sb3, st3, st2, Vector3(0, 0.2, 1));
    addQuadOutward(stoneBuilder, sb3, sb0, st0, st3, Vector3(-1, 0.2, 0));
    addQuadOutward(stoneBuilder, st0, st1, st2, st3, Vector3(0, 1, 0));

    addBox(
      stoneBuilder,
      Vector3(-0.92, -0.40, dTop + 0.03),
      Vector3(0.92, 0.34, dTop + 0.44),
    );
    addBox(
      stoneBuilder,
      Vector3(-0.88, 0.36, dTop + 0.03),
      Vector3(0.88, 0.66, dTop + 0.24),
    );

    addBox(
      timberBuilder,
      Vector3(-2.22, 0.70, -2.72),
      Vector3(2.22, 1.72, 2.72),
    );

    const wallTop = 4.86;
    const eavesY = 4.92;
    const ridgeY = 6.32;
    addBox(
      kuraBuilder,
      Vector3(-2.18, 1.74, -2.68),
      Vector3(2.18, wallTop, 2.68),
    );
    addTriangleOutward(
      kuraBuilder,
      Vector3(-2.16, wallTop + 0.02, 2.66),
      Vector3(2.16, wallTop + 0.02, 2.66),
      Vector3(0, ridgeY - 0.14, 2.66),
      Vector3(0, 0, 1),
    );
    addTriangleOutward(
      kuraBuilder,
      Vector3(-2.16, wallTop + 0.02, -2.66),
      Vector3(2.16, wallTop + 0.02, -2.66),
      Vector3(0, ridgeY - 0.14, -2.66),
      Vector3(0, 0, -1),
    );

    addBox(kuraBuilder, Vector3(-0.92, 0.72, 2.74), Vector3(0.92, 2.66, 2.86));
    addBox(
      timberBuilder,
      Vector3(-0.74, 0.74, 2.88),
      Vector3(-0.04, 2.50, 2.94),
    );
    addBox(timberBuilder, Vector3(0.04, 0.74, 2.88), Vector3(0.74, 2.50, 2.94));
    addLeanToRoof(
      roofBuilder,
      xMin: -1.36,
      xMax: 1.36,
      zWall: 2.70,
      zFront: 3.38,
      yWall: 2.98,
      yFront: 2.70,
    );

    addBox(kuraBuilder, Vector3(-0.56, 3.38, 2.70), Vector3(0.56, 4.20, 2.82));
    addBox(
      timberBuilder,
      Vector3(-0.42, 3.48, 2.84),
      Vector3(0.42, 4.10, 2.89),
    );

    addGabledRoof(
      roofBuilder,
      timberBuilder,
      xHalf: 2.74,
      zMin: -3.22,
      zMax: 3.22,
      eavesY: eavesY,
      ridgeY: ridgeY,
      thick: 0.16,
    );

    final strawBuilder = GeometryBuilder();
    addSakeBarrelRack(
      timberBuilder,
      strawBuilder,
      origin: Vector3(-1.76, 0, 3.24),
      yaw: 0.06,
    );
    addHandcart(
      timberBuilder,
      strawBuilder,
      origin: Vector3(2.86, 0, 0.45),
      yaw: 0.10,
    );

    root
      ..add(
        Node(
          mesh: Mesh(
            stoneBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.ishigakiStone),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            strawBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.plasterWall),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            kuraBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.kuraPlaster),
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
            roofBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.kawaraTile),
          ),
        ),
      );
    return root;
  }

  Node buildMarketStallNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final timberBuilder = GeometryBuilder();
    final awningBuilder = GeometryBuilder();
    final goodsBuilder = GeometryBuilder();
    final lacquerBuilder = GeometryBuilder();
    final lanternBuilder = GeometryBuilder();

    const postCoords = [
      (-1.18, -0.98),
      (1.08, -0.98),
      (-1.18, 0.88),
      (1.08, 0.88),
    ];
    for (final coord in postCoords) {
      addBox(
        timberBuilder,
        Vector3(coord.$1, -0.60, coord.$2),
        Vector3(coord.$1 + 0.10, 2.24, coord.$2 + 0.10),
      );
    }

    addBox(
      timberBuilder,
      Vector3(-0.96, 0.06, -0.38),
      Vector3(0.96, 0.84, 0.48),
    );
    addBox(
      goodsBuilder,
      Vector3(-0.82, 0.86, -0.26),
      Vector3(-0.18, 1.22, 0.34),
    );
    addBox(
      lacquerBuilder,
      Vector3(0.08, 0.86, -0.22),
      Vector3(0.78, 1.02, 0.36),
    );
    addTaperedLimb(
      timberBuilder,
      const Vec3(-1.32, 0.02, 0.32),
      const Vec3(-1.32, 0.62, 0.32),
      0.21,
      0.19,
      sides: 6,
    );
    if (structure.id.value.hashCode.abs().isEven) {
      addSakeBarrelRack(
        timberBuilder,
        goodsBuilder,
        origin: Vector3(1.42, 0, -0.16),
        yaw: -math.pi / 2,
        twoTier: false,
      );
    } else {
      addBox(
        timberBuilder,
        Vector3(1.22, 0.02, -0.44),
        Vector3(1.66, 0.42, 0.06),
      );
      addBox(
        goodsBuilder,
        Vector3(1.26, 0.44, -0.38),
        Vector3(1.62, 0.74, 0.02),
      );
    }

    addLeanToRoof(
      awningBuilder,
      xMin: -1.42,
      xMax: 1.42,
      zWall: -1.20,
      zFront: 1.22,
      yWall: 2.66,
      yFront: 2.26,
      thick: 0.06,
    );
    for (final flap in const [(-1.32, -0.50), (-0.40, 0.40), (0.50, 1.32)]) {
      addBox(
        awningBuilder,
        Vector3(flap.$1, 1.94, 1.18),
        Vector3(flap.$2, 2.24, 1.23),
      );
    }

    addLanternBody(
      lanternBuilder,
      timberBuilder,
      Vector3(1.12, 2.24, 1.08),
      radius: 0.16,
      height: 0.36,
    );
    addNoboriBanner(
      timberBuilder,
      awningBuilder,
      xPole: -1.24,
      zPole: 1.28,
      dirX: 1,
      mainColor: Vector4(0.84, 0.52, 0.14, 0.5),
      crestColor: Vector4(0.18, 0.26, 0.46, 0.5),
      topY: 2.46,
      bottomY: 0.84,
      bannerWidth: 0.32,
    );

    root
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
            goodsBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.plasterWall),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            lacquerBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.vermilionLacquer),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            awningBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.fabricAwning),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            lanternBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.chochinLantern),
          ),
        ),
      );

    return root;
  }

  Node buildToriiGateNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final stoneBuilder = GeometryBuilder();
    final lacquerBuilder = GeometryBuilder();
    final timberBuilder = GeometryBuilder();
    final roofBuilder = GeometryBuilder();
    final lanternBuilder = GeometryBuilder();

    for (final px in const [-2.02, 2.02]) {
      addBox(
        stoneBuilder,
        Vector3(px - 0.26, -0.95, -0.26),
        Vector3(px + 0.26, 0.36, 0.26),
      );
      addTaperedLimb(
        lacquerBuilder,
        Vec3(px, 0.38, 0),
        Vec3(px * 0.96, 4.34, 0),
        0.16,
        0.14,
        sides: 8,
      );
    }

    addBox(
      lacquerBuilder,
      Vector3(-2.46, 3.40, -0.11),
      Vector3(2.46, 3.62, 0.11),
    );
    addBox(
      timberBuilder,
      Vector3(-0.24, 3.64, -0.13),
      Vector3(0.24, 4.32, 0.13),
    );

    addBox(
      lacquerBuilder,
      Vector3(-2.62, 4.36, -0.18),
      Vector3(2.62, 4.54, 0.18),
    );
    addBox(roofBuilder, Vector3(-2.84, 4.56, -0.26), Vector3(2.84, 4.78, 0.26));
    addBox(
      roofBuilder,
      Vector3(-3.04, 4.64, -0.27),
      Vector3(-2.86, 4.88, 0.27),
    );
    addBox(roofBuilder, Vector3(2.86, 4.64, -0.27), Vector3(3.04, 4.88, 0.27));

    addLanternBody(
      lanternBuilder,
      timberBuilder,
      Vector3(-1.38, 3.38, 0),
      radius: 0.18,
      height: 0.42,
    );
    addLanternBody(
      lanternBuilder,
      timberBuilder,
      Vector3(1.38, 3.38, 0),
      radius: 0.18,
      height: 0.42,
    );

    root
      ..add(
        Node(
          mesh: Mesh(
            stoneBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.ishigakiStone),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            lacquerBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.vermilionLacquer),
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
            roofBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.kawaraTile),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            lanternBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.chochinLantern),
          ),
        ),
      );
    return root;
  }

  Node buildYaguraTowerNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final stoneBuilder = GeometryBuilder();
    final timberBuilder = GeometryBuilder();
    final shojiBuilder = GeometryBuilder();
    final roofBuilder = GeometryBuilder();

    const yBase = -1.80;
    const yStoneTop = 2.20;
    const wBase = 1.92;
    const wTop = 1.62;

    final sb0 = Vector3(-wBase, yBase, -wBase);
    final sb1 = Vector3(wBase, yBase, -wBase);
    final sb2 = Vector3(wBase, yBase, wBase);
    final sb3 = Vector3(-wBase, yBase, wBase);
    final st0 = Vector3(-wTop, yStoneTop, -wTop);
    final st1 = Vector3(wTop, yStoneTop, -wTop);
    final st2 = Vector3(wTop, yStoneTop, wTop);
    final st3 = Vector3(-wTop, yStoneTop, wTop);

    addQuadOutward(stoneBuilder, sb0, sb1, st1, st0, Vector3(0, 0.2, -1));
    addQuadOutward(stoneBuilder, sb1, sb2, st2, st1, Vector3(1, 0.2, 0));
    addQuadOutward(stoneBuilder, sb2, sb3, st3, st2, Vector3(0, 0.2, 1));
    addQuadOutward(stoneBuilder, sb3, sb0, st0, st3, Vector3(-1, 0.2, 0));
    addQuadOutward(stoneBuilder, st0, st1, st2, st3, Vector3(0, 1, 0));

    const cols = [(-1.38, -1.38), (1.22, -1.38), (-1.38, 1.22), (1.22, 1.22)];
    for (final c in cols) {
      addBox(
        timberBuilder,
        Vector3(c.$1, yStoneTop + 0.02, c.$2),
        Vector3(c.$1 + 0.16, 4.50, c.$2 + 0.16),
      );
    }

    addBox(
      timberBuilder,
      Vector3(-1.80, 4.52, -1.80),
      Vector3(1.80, 4.66, 1.80),
    );
    addBox(
      timberBuilder,
      Vector3(-1.02, 4.68, -1.02),
      Vector3(1.02, 6.40, 1.02),
    );
    addBox(shojiBuilder, Vector3(-0.76, 4.96, 1.05), Vector3(0.76, 6.08, 1.10));
    addBox(
      shojiBuilder,
      Vector3(-0.76, 4.96, -1.10),
      Vector3(0.76, 6.08, -1.05),
    );

    const rw = 2.40;
    const reBotY = 6.44;
    const reTopY = 6.56;
    const raY = 8.68;
    final rt0 = Vector3(-rw, reTopY, -rw);
    final rt1 = Vector3(rw, reTopY, -rw);
    final rt2 = Vector3(rw, reTopY, rw);
    final rt3 = Vector3(-rw, reTopY, rw);
    final rb0 = Vector3(-rw, reBotY, -rw);
    final rb1 = Vector3(rw, reBotY, -rw);
    final rb2 = Vector3(rw, reBotY, rw);
    final rb3 = Vector3(-rw, reBotY, rw);
    final rApex = Vector3(0, raY, 0);

    addTriangleOutward(roofBuilder, rt0, rt1, rApex, Vector3(0, 1, -1));
    addTriangleOutward(roofBuilder, rt1, rt2, rApex, Vector3(1, 1, 0));
    addTriangleOutward(roofBuilder, rt2, rt3, rApex, Vector3(0, 1, 1));
    addTriangleOutward(roofBuilder, rt3, rt0, rApex, Vector3(-1, 1, 0));
    addQuadOutward(roofBuilder, rb0, rb1, rb2, rb3, Vector3(0, -1, 0));

    root
      ..add(
        Node(
          mesh: Mesh(
            stoneBuilder.build(),
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
            shojiBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.shojiScreen),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            roofBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.kawaraTile),
          ),
        ),
      );
    return root;
  }

  static List<Vec3> sampleCubicSpine(
    Vec3 p0,
    Vec3 p1,
    Vec3 p2,
    Vec3 p3, {
    int segments = 4,
  }) {
    final pts = <Vec3>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      final inv = 1 - t;
      final w0 = inv * inv * inv;
      final w1 = 3 * inv * inv * t;
      final w2 = 3 * inv * t * t;
      final w3 = t * t * t;
      pts.add(
        Vec3(
          p0.x * w0 + p1.x * w1 + p2.x * w2 + p3.x * w3,
          p0.y * w0 + p1.y * w1 + p2.y * w2 + p3.y * w3,
          p0.z * w0 + p1.z * w1 + p2.z * w2 + p3.z * w3,
        ),
      );
    }
    return pts;
  }

  static void addCurvedTube(
    GeometryBuilder builder,
    List<Vec3> spine,
    double rStart,
    double rEnd, {
    int sides = 6,
    Vector4? color,
    bool nodalRings = false,
  }) {
    if (spine.length < 2) {
      return;
    }
    final centers = [for (final p in spine) p.toVector3()];
    final tangents = <Vector3>[];
    for (var i = 0; i < centers.length; i++) {
      final raw = i == 0
          ? centers[1] - centers[0]
          : (i == centers.length - 1
                ? centers[i] - centers[i - 1]
                : centers[i + 1] - centers[i - 1]);
      tangents.add(raw.length > 1e-5 ? raw.normalized() : Vector3(0, 1, 0));
    }

    var u = (tangents[0].y.abs() < 0.92 ? Vector3(0, 1, 0) : Vector3(1, 0, 0))
        .cross(tangents[0])
        .normalized();
    var w = tangents[0].cross(u).normalized();

    final rings = <List<Vector3>>[];
    for (var s = 0; s < centers.length; s++) {
      if (s > 0) {
        final tDir = tangents[s];
        final proj = u - tDir * u.dot(tDir);
        if (proj.length > 1e-4) {
          u = proj.normalized();
          w = tDir.cross(u).normalized();
        }
      }
      final frac = s / (centers.length - 1);
      final r = rStart + (rEnd - rStart) * math.pow(frac, 0.82);
      final ring = <Vector3>[];
      for (var i = 0; i < sides; i++) {
        final ang = (i / sides) * math.pi * 2;
        final radial = u * math.cos(ang) + w * math.sin(ang);
        ring.add(centers[s] + radial * r);
      }
      rings.add(ring);
    }

    final baseCol = color ?? _whiteColor;
    for (var s = 0; s < rings.length - 1; s++) {
      final ringA = rings[s];
      final ringB = rings[s + 1];
      final segMid = (centers[s] + centers[s + 1]) * 0.5;
      for (var i = 0; i < sides; i++) {
        final next = (i + 1) % sides;
        final outHint =
            ((ringA[i] + ringA[next] + ringB[next] + ringB[i]) * 0.25) - segMid;
        addQuadOutward(
          builder,
          ringA[i],
          ringA[next],
          ringB[next],
          ringB[i],
          outHint,
          uvScale: 1.25,
          color: baseCol,
        );
      }
      if (nodalRings && s > 0) {
        final nodeCol = Vector4(
          baseCol.x * 0.62,
          baseCol.y * 0.66,
          baseCol.z * 0.56,
          baseCol.w,
        );
        final cNode = centers[s];
        final tNode = tangents[s];
        final collarR =
            (rStart +
                (rEnd - rStart) * math.pow(s / (rings.length - 1), 0.82)) *
            1.16;
        addTaperedLimb(
          builder,
          Vec3(
            cNode.x - tNode.x * 0.022,
            cNode.y - tNode.y * 0.022,
            cNode.z - tNode.z * 0.022,
          ),
          Vec3(
            cNode.x + tNode.x * 0.022,
            cNode.y + tNode.y * 0.022,
            cNode.z + tNode.z * 0.022,
          ),
          collarR,
          collarR * 0.98,
          sides: sides,
          color: nodeCol,
        );
      }
    }

    final lastRing = rings.last;
    final tipCenter = centers.last;
    final tipDir = tangents.last;
    for (var i = 0; i < sides; i++) {
      final next = (i + 1) % sides;
      addTriangleOutward(
        builder,
        lastRing[i],
        lastRing[next],
        tipCenter,
        tipDir,
        color: baseCol,
      );
    }
  }

  static void addPineCloudPad(
    GeometryBuilder builder,
    Vector3 center,
    Vector3 radii, {
    required Vector4 color,
    double phase = 0,
  }) {
    Vector4 tint(double mult, int salt) {
      final jR = 1.0 + 0.05 * math.sin(phase * 1.7 + salt * 2.1);
      final jG = 1.0 + 0.06 * math.cos(phase * 1.4 + salt * 2.9);
      return Vector4(
        (color.x * mult * jR).clamp(0.05, 1.45),
        (color.y * mult * jG).clamp(0.05, 1.45),
        (color.z * mult).clamp(0.05, 1.45),
        color.w,
      );
    }

    const lowerCount = 6;
    for (var i = 0; i < lowerCount; i++) {
      final yaw = phase + (i / lowerCount) * math.pi * 2;
      final stem = Vector3(
        center.x + math.cos(yaw) * radii.x * 0.16,
        center.y - radii.y * 0.26,
        center.z + math.sin(yaw) * radii.z * 0.16,
      );
      addArchedFoliageCard(
        builder,
        stem,
        yaw: yaw,
        pitchUp: 0.18 + 0.04 * math.sin(i * 1.9 + phase),
        length: radii.x * 1.08,
        width: radii.z * 1.04,
        droop: radii.y * 0.44,
        color: tint(0.76, i),
      );
    }

    const midCount = 5;
    for (var i = 0; i < midCount; i++) {
      final yaw = phase + 0.52 + (i / midCount) * math.pi * 2;
      final stem = Vector3(
        center.x + math.cos(yaw) * radii.x * 0.10,
        center.y + radii.y * 0.06,
        center.z + math.sin(yaw) * radii.z * 0.10,
      );
      addArchedFoliageCard(
        builder,
        stem,
        yaw: yaw,
        pitchUp: 0.38 + 0.05 * math.cos(i * 2.3 + phase),
        length: radii.x * 0.96,
        width: radii.z * 0.96,
        droop: radii.y * 0.36,
        color: tint(1.02, i + 8),
      );
    }

    for (var i = 0; i < 3; i++) {
      final yaw = phase + 1.04 + (i / 3) * math.pi * 2;
      final stem = Vector3(
        center.x - math.cos(yaw) * radii.x * 0.22,
        center.y + radii.y * 0.36,
        center.z - math.sin(yaw) * radii.z * 0.22,
      );
      addArchedFoliageCard(
        builder,
        stem,
        yaw: yaw,
        pitchUp: 0.48,
        length: radii.x * 0.84,
        width: radii.z * 0.86,
        droop: radii.y * 0.30,
        color: tint(1.22, i + 17),
      );
    }
  }

  static void addWillowCurtainCluster(
    GeometryBuilder builder, {
    required double hangLen,
    required double width,
    required Vector4 color,
    required double baseYaw,
    required double phase,
  }) {
    int emit(Vector3 pos, double u, double v, Vector4 c) {
      builder
        ..color(c)
        ..texCoord(Vector2(u, v));
      return builder.addVertex(pos);
    }

    for (var k = 0; k < 3; k++) {
      final yaw = baseYaw + (k / 3) * math.pi * 2 + 0.27;
      final ca = math.cos(yaw);
      final sa = math.sin(yaw);
      final right = Vector3(-sa, 0, ca);
      final capCol = Vector4(
        (color.x * 1.10).clamp(0.05, 1.45),
        (color.y * 1.12).clamp(0.05, 1.45),
        (color.z * 1.04).clamp(0.05, 1.45),
        color.w,
      );
      final hw = width * 0.48;
      final p0 = Vector3(ca * 0.04, 0.06, sa * 0.04);
      final p1 = Vector3(ca * width * 0.44, 0.14, sa * width * 0.44);
      final p2 = Vector3(ca * width * 0.86, -0.22, sa * width * 0.86);
      final v0 = emit(p0 - right * hw * 0.75, 0, 1, capCol);
      final v1 = emit(p0 + right * hw * 0.75, 1, 1, capCol);
      final v2 = emit(p1 - right * hw, 0, 0.55, capCol);
      final v3 = emit(p1 + right * hw, 1, 0.55, capCol);
      final v4 = emit(p2 - right * hw * 0.90, 0, 0, capCol);
      final v5 = emit(p2 + right * hw * 0.90, 1, 0, capCol);
      builder
        ..addTriangle(v0, v1, v3)
        ..addTriangle(v0, v3, v2)
        ..addTriangle(v2, v3, v5)
        ..addTriangle(v2, v5, v4);
    }

    const drapes = 5;
    for (var i = 0; i < drapes; i++) {
      final yaw =
          baseYaw + (i / drapes) * math.pi * 2 + 0.13 * math.sin(phase + i);
      final ca = math.cos(yaw);
      final sa = math.sin(yaw);
      final right = Vector3(-sa, 0, ca);
      final curLen = hangLen * (0.82 + 0.24 * ((i * 37 % 11) / 10.0));
      final flare = 0.14 + 0.06 * (i % 3);
      final shade = 0.86 + 0.24 * (i / drapes);
      final cCol = Vector4(
        (color.x * shade).clamp(0.05, 1.45),
        (color.y * (0.92 + 0.14 * (i % 2))).clamp(0.05, 1.45),
        (color.z * shade).clamp(0.05, 1.45),
        color.w,
      );

      final topC = Vector3(ca * 0.10, 0, sa * 0.10);
      final midC = Vector3(
        ca * (0.10 + flare * 0.68),
        -curLen * 0.46,
        sa * (0.10 + flare * 0.68),
      );
      final botC = Vector3(ca * (0.10 + flare), -curLen, sa * (0.10 + flare));

      final hwTop = width * 0.44;
      final hwMid = width * 0.54;
      final hwBot = width * 0.46;

      final v0 = emit(topC - right * hwTop, 0, 1, cCol);
      final v1 = emit(topC + right * hwTop, 1, 1, cCol);
      final v2 = emit(midC - right * hwMid, 0, 0.54, cCol);
      final v3 = emit(midC + right * hwMid, 1, 0.54, cCol);
      final v4 = emit(botC - right * hwBot, 0, 0, cCol);
      final v5 = emit(botC + right * hwBot, 1, 0, cCol);

      builder
        ..addTriangle(v0, v1, v3)
        ..addTriangle(v0, v3, v2)
        ..addTriangle(v2, v3, v5)
        ..addTriangle(v2, v5, v4);
    }
  }

  Node buildMapleNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final dna = _TreeDna.fromStructure(structure);
    final timberBuilder = GeometryBuilder();
    final mapleBuilder = GeometryBuilder();
    final rockBuilder = GeometryBuilder();
    final fernBuilder = GeometryBuilder();

    final phenotype = switch (structure.id.value) {
      'maple_bridge_nw' => 0,
      'maple_gorge_se' => 1,
      'maple_alley_ne' => 2,
      'maple_upper_ne' => 3,
      _ => dna.bucket(4, 1),
    };

    final hScale = 0.88 + 0.30 * dna.unit(2);
    final spread = 0.90 + 0.28 * dna.unit(3);
    final leanX = 0.24 * dna.signed(4);
    final leanZ = 0.24 * dna.signed(5);
    final twist = dna.unit(6) * math.pi * 2;

    final forkPt = Vec3(leanX * 0.72, 1.78 * hScale, leanZ * 0.72);
    addCurvedTube(
      timberBuilder,
      sampleCubicSpine(
        const Vec3(0, -0.04, 0),
        Vec3(leanX * 0.28, 0.62 * hScale, leanZ * 0.28),
        Vec3(leanX * 0.92, 1.24 * hScale, leanZ * 0.92),
        forkPt,
        segments: 5,
      ),
      0.27 * (0.92 + 0.14 * dna.unit(7)),
      0.16,
      sides: 7,
    );

    for (var r = 0; r < 4; r++) {
      final rAng = twist + r * (math.pi * 0.5) + 0.24 * dna.signed(10 + r);
      final reach = 0.56 + 0.22 * dna.unit(14 + r);
      addCurvedTube(
        timberBuilder,
        sampleCubicSpine(
          Vec3(math.cos(rAng) * 0.10, 0.38, math.sin(rAng) * 0.10),
          Vec3(
            math.cos(rAng) * reach * 0.55,
            0.18,
            math.sin(rAng) * reach * 0.55,
          ),
          Vec3(
            math.cos(rAng) * reach * 0.85,
            0.04,
            math.sin(rAng) * reach * 0.85,
          ),
          Vec3(math.cos(rAng) * reach, -0.08, math.sin(rAng) * reach),
          segments: 3,
        ),
        0.105,
        0.036,
        sides: 5,
      );
    }

    Vector4 padTint(double tierFrac, int salt) {
      final j = 0.06 * dna.signed(30 + salt);
      return switch (phenotype) {
        0 => Vector4(
          (0.86 + 0.32 * tierFrac + j).clamp(0.10, 1.38),
          (0.11 + 0.15 * tierFrac).clamp(0.05, 1.38),
          0.10,
          1,
        ),
        1 => Vector4(
          (0.78 + 0.42 * tierFrac + j).clamp(0.10, 1.38),
          (0.32 + 0.44 * tierFrac + j * 0.5).clamp(0.08, 1.38),
          0.15 + 0.08 * tierFrac,
          1,
        ),
        2 => Vector4(
          (0.92 + 0.30 * tierFrac + j).clamp(0.10, 1.38),
          (0.64 + 0.34 * tierFrac + j).clamp(0.10, 1.38),
          0.22 + 0.08 * tierFrac,
          1,
        ),
        _ =>
          tierFrac < 0.42
              ? Vector4(0.50 + j, 0.78 + j, 0.28, 1)
              : Vector4(
                  0.88 + 0.24 * tierFrac + j,
                  0.42 + 0.22 * tierFrac,
                  0.18,
                  1,
                ),
      };
    }

    const scaffoldCount = 5;
    for (var b = 0; b < scaffoldCount; b++) {
      final ang =
          twist + (b / scaffoldCount) * math.pi * 2 + 0.22 * dna.signed(50 + b);
      final tier = b / (scaffoldCount - 1);
      final bReach = (1.18 + 0.56 * dna.unit(60 + b)) * spread;
      final bHeight = (3.10 + tier * 1.45 + 0.28 * dna.signed(70 + b)) * hScale;
      final tip = Vec3(
        forkPt.x + math.cos(ang) * bReach,
        bHeight,
        forkPt.z + math.sin(ang) * bReach,
      );
      final mid1 = Vec3(
        forkPt.x + math.cos(ang + 0.18) * bReach * 0.42,
        forkPt.y + (bHeight - forkPt.y) * 0.56,
        forkPt.z + math.sin(ang + 0.18) * bReach * 0.42,
      );
      final mid2 = Vec3(
        forkPt.x + math.cos(ang - 0.12) * bReach * 0.82,
        bHeight - 0.18,
        forkPt.z + math.sin(ang - 0.12) * bReach * 0.82,
      );
      addCurvedTube(
        timberBuilder,
        sampleCubicSpine(forkPt, mid1, mid2, tip),
        0.115,
        0.042,
      );

      addLeafSprayCloud(
        mapleBuilder,
        Vector3(tip.x, tip.y + 0.06, tip.z),
        Vector3(
          (1.24 + 0.24 * dna.unit(80 + b)) * spread,
          0.38 + 0.08 * dna.unit(85 + b),
          (1.12 + 0.22 * dna.unit(90 + b)) * spread,
        ),
        color: padTint(tier * 0.72, b),
        phase: twist + b * 1.37,
      );

      if (b.isEven) {
        final subAng = ang + 0.48 * (b == 0 ? 1 : -1);
        final subTip = Vec3(
          mid1.x + math.cos(subAng) * 0.82 * spread,
          mid1.y + 0.92 * hScale,
          mid1.z + math.sin(subAng) * 0.82 * spread,
        );
        addCurvedTube(
          timberBuilder,
          sampleCubicSpine(
            mid1,
            Vec3(
              (mid1.x + subTip.x) * 0.5,
              mid1.y + 0.58 * hScale,
              (mid1.z + subTip.z) * 0.5,
            ),
            Vec3(subTip.x * 0.92, subTip.y - 0.08, subTip.z * 0.92),
            subTip,
            segments: 3,
          ),
          0.068,
          0.028,
          sides: 5,
        );
        addLeafSprayCloud(
          mapleBuilder,
          Vector3(subTip.x, subTip.y + 0.05, subTip.z),
          Vector3(1.06 * spread, 0.36, 0.98 * spread),
          color: padTint(0.55 + tier * 0.35, b + 10),
          phase: twist + b * 2.1 + 0.7,
        );
      }
    }

    final apex = Vec3(
      forkPt.x + leanX * 0.65,
      (5.15 + 0.45 * dna.unit(95)) * hScale,
      forkPt.z + leanZ * 0.65,
    );
    addCurvedTube(
      timberBuilder,
      sampleCubicSpine(
        forkPt,
        Vec3(forkPt.x - leanX * 0.35, 3.10 * hScale, forkPt.z - leanZ * 0.35),
        Vec3(apex.x + 0.16, apex.y - 0.85, apex.z - 0.14),
        apex,
        segments: 5,
      ),
      0.125,
      0.036,
    );
    addLeafSprayCloud(
      mapleBuilder,
      Vector3(apex.x * 0.7, apex.y - 0.62, apex.z * 0.7),
      Vector3(1.38 * spread, 0.44, 1.26 * spread),
      color: padTint(0.82, 21),
      phase: twist + 3.8,
    );
    addLeafSprayCloud(
      mapleBuilder,
      Vector3(apex.x, apex.y + 0.04, apex.z),
      Vector3(1.08 * spread, 0.38, 1.00 * spread),
      color: padTint(1, 22),
      phase: twist + 4.9,
    );

    final rockAng = twist + 0.85;
    addRockBoulder(
      rockBuilder,
      Vector3(math.cos(rockAng) * 0.76, 0.24, math.sin(rockAng) * 0.76),
      Vector3(0.58, 0.24, 0.46),
      yaw: rockAng,
      seed: dna.unit(97) * 6.0,
    );
    addRockBoulder(
      rockBuilder,
      Vector3(
        math.cos(rockAng + 2.3) * 0.62,
        0.16,
        math.sin(rockAng + 2.3) * 0.62,
      ),
      Vector3(0.38, 0.16, 0.32),
      yaw: rockAng + 1.1,
      seed: dna.unit(98) * 6.0,
    );
    addShrubRosette(
      fernBuilder,
      Vector3(
        math.cos(rockAng + 3.6) * 0.68,
        0.09,
        math.sin(rockAng + 3.6) * 0.68,
      ),
      Vector3(0.80, 0.34, 0.74),
      color: Vector4(0.84, 0.98, 0.72, 1),
      phase: twist + 0.8,
    );

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
            fernBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.bambooCanopy),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            mapleBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.mapleCanopy),
          ),
        ),
      );

    return root;
  }

  Node buildBambooNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final dna = _TreeDna.fromStructure(structure);
    final culmBuilder = GeometryBuilder();
    final foliageBuilder = GeometryBuilder();
    final rockBuilder = GeometryBuilder();

    final culmCount = 12 + dna.bucket(4, 1);
    final baseTwist = dna.unit(2) * math.pi * 2;
    final hScale = 0.88 + 0.28 * dna.unit(3);

    for (var i = 0; i < culmCount; i++) {
      final ringFrac = i / culmCount;
      final ang =
          baseTwist + ringFrac * math.pi * 2 + 0.24 * dna.signed(10 + i);
      final rBase = 0.16 + 0.78 * math.sqrt((i % 7 + 0.4) / 7.4);
      final archOut = rBase + 0.42 + 0.56 * dna.unit(30 + i);
      final height = (5.45 + 2.15 * dna.unit(50 + i)) * hScale;

      final bx = math.cos(ang) * rBase;
      final bz = math.sin(ang) * rBase;
      final tx = math.cos(ang) * archOut;
      final tz = math.sin(ang) * archOut;

      final age = dna.unit(70 + i);
      final culmColor = age < 0.35
          ? Vector4(0.42, 0.68, 0.34, 1)
          : (age < 0.76
                ? Vector4(0.56, 0.72, 0.28, 1)
                : Vector4(0.76, 0.68, 0.25, 1));

      final spine = sampleCubicSpine(
        Vec3(bx, 0.02, bz),
        Vec3(bx * 1.08, height * 0.36, bz * 1.08),
        Vec3(bx + (tx - bx) * 0.54, height * 0.72, bz + (tz - bz) * 0.54),
        Vec3(tx, height, tz),
        segments: 5,
      );
      addCurvedTube(
        culmBuilder,
        spine,
        0.046 - 0.008 * dna.unit(90 + i),
        0.020,
        color: culmColor,
        nodalRings: true,
      );

      if (i.isEven || i == culmCount - 1) {
        final upperPt = spine[4];
        final tipPt = spine[5];
        final shade = 0.90 + 0.26 * dna.unit(110 + i);
        addLeafSprayCloud(
          foliageBuilder,
          Vector3(upperPt.x, upperPt.y - 0.12, upperPt.z),
          Vector3(1.16, 0.38, 1.08),
          color: Vector4(shade * 0.90, shade * 1.04, shade * 0.80, 1),
          phase: baseTwist + i * 0.93,
        );
        addLeafSprayCloud(
          foliageBuilder,
          Vector3(tipPt.x, tipPt.y + 0.04, tipPt.z),
          Vector3(1.02, 0.34, 0.96),
          color: Vector4(shade * 1.02, shade * 1.12, shade * 0.86, 1),
          phase: baseTwist + i * 1.47 + 0.6,
        );
      } else if (i % 3 == 1) {
        final midPt = spine[3];
        final shade = 0.84 + 0.20 * dna.unit(130 + i);
        addLeafSprayCloud(
          foliageBuilder,
          Vector3(midPt.x * 1.12, midPt.y, midPt.z * 1.12),
          Vector3(1.06, 0.36, 0.98),
          color: Vector4(shade * 0.88, shade * 1.02, shade * 0.78, 1),
          phase: baseTwist + i * 1.19,
        );
      }
    }

    for (var s = 0; s < 3; s++) {
      final sAng = baseTwist + s * 2.1 + 0.4;
      final sr = 0.58 + 0.22 * s;
      addShrubRosette(
        foliageBuilder,
        Vector3(math.cos(sAng) * sr, 0.08, math.sin(sAng) * sr),
        Vector3(0.84, 0.36, 0.78),
        color: Vector4(0.82 + 0.06 * s, 0.98, 0.72, 1),
        phase: baseTwist + s * 1.5,
      );
    }

    final rAng = baseTwist + 1.15;
    addRockBoulder(
      rockBuilder,
      Vector3(math.cos(rAng) * 0.68, 0.22, math.sin(rAng) * 0.68),
      Vector3(0.52, 0.20, 0.42),
      yaw: rAng,
      seed: dna.unit(150) * 6.0,
    );

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
            culmBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.plasterWall),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            foliageBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.bambooCanopy),
          ),
        ),
      );

    return root;
  }

  Node buildPineNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final dna = _TreeDna.fromStructure(structure);
    final timberBuilder = GeometryBuilder();
    final pineBuilder = GeometryBuilder();
    final rockBuilder = GeometryBuilder();
    final fernBuilder = GeometryBuilder();

    final hScale = 0.92 + 0.24 * dna.unit(1);
    final sweepAng = dna.unit(2) * math.pi * 2;
    final sweepCos = math.cos(sweepAng);
    final sweepSin = math.sin(sweepAng);
    final barkColor = Vector4(0.86, 0.82, 0.80, 1);

    final elbow1 = Vec3(sweepCos * 0.88, 1.95 * hScale, sweepSin * 0.88);
    final elbow2 = Vec3(-sweepCos * 0.42, 3.85 * hScale, -sweepSin * 0.42);
    final crownApex = Vec3(sweepCos * 0.28, 5.65 * hScale, sweepSin * 0.28);

    addCurvedTube(
      timberBuilder,
      sampleCubicSpine(
        const Vec3(0, -0.06, 0),
        elbow1,
        elbow2,
        crownApex,
        segments: 7,
      ),
      0.30,
      0.068,
      sides: 7,
      color: barkColor,
    );

    for (var r = 0; r < 4; r++) {
      final rAng = sweepAng + r * 1.57 + 0.28 * dna.signed(10 + r);
      final rr = 0.72 + 0.24 * dna.unit(15 + r);
      addCurvedTube(
        timberBuilder,
        sampleCubicSpine(
          Vec3(math.cos(rAng) * 0.14, 0.44, math.sin(rAng) * 0.14),
          Vec3(math.cos(rAng) * rr * 0.52, 0.26, math.sin(rAng) * rr * 0.52),
          Vec3(math.cos(rAng) * rr * 0.86, 0.06, math.sin(rAng) * rr * 0.86),
          Vec3(math.cos(rAng) * rr, -0.10, math.sin(rAng) * rr),
          segments: 3,
        ),
        0.12,
        0.042,
        sides: 5,
        color: barkColor,
      );
    }

    final shelfSpecs = [
      (0.32, sweepAng + 0.12, 1.72, 1.44, 0.26),
      (0.46, sweepAng + 2.38, 1.58, 1.32, 0.25),
      (0.60, sweepAng - 1.85, 1.48, 1.24, 0.24),
      (0.73, sweepAng + 1.05, 1.34, 1.16, 0.23),
      (0.85, sweepAng + 3.25, 1.18, 1.04, 0.22),
    ];

    final trunkPts = sampleCubicSpine(
      const Vec3(0, -0.06, 0),
      elbow1,
      elbow2,
      crownApex,
      segments: 20,
    );

    for (var s = 0; s < shelfSpecs.length; s++) {
      final spec = shelfSpecs[s];
      final idx = (spec.$1 * 20).round().clamp(2, 19);
      final origin = trunkPts[idx];
      final bAng = spec.$2 + 0.18 * dna.signed(30 + s);
      final reach = spec.$3 * (0.90 + 0.22 * dna.unit(40 + s));
      final padR = spec.$4 * (0.92 + 0.18 * dna.unit(50 + s));

      final tip = Vec3(
        origin.x + math.cos(bAng) * reach,
        origin.y + (0.12 - 0.06 * s) * hScale,
        origin.z + math.sin(bAng) * reach,
      );
      final dip = Vec3(
        origin.x + math.cos(bAng + 0.16) * reach * 0.52,
        origin.y - 0.18,
        origin.z + math.sin(bAng + 0.16) * reach * 0.52,
      );
      addCurvedTube(
        timberBuilder,
        sampleCubicSpine(
          origin,
          dip,
          Vec3(
            origin.x + math.cos(bAng) * reach * 0.84,
            tip.y - 0.06,
            origin.z + math.sin(bAng) * reach * 0.84,
          ),
          tip,
        ),
        0.115 - 0.012 * s,
        0.038,
        color: barkColor,
      );

      final shade = 0.88 + 0.22 * (s / shelfSpecs.length);
      addPineCloudPad(
        pineBuilder,
        Vector3(tip.x, tip.y + 0.08, tip.z),
        Vector3(padR, spec.$5, padR * 0.92),
        color: Vector4(shade * 0.94, shade * 1.04, shade * 0.96, 1),
        phase: sweepAng + s * 1.63,
      );

      if (s < 3) {
        final subAng = bAng + (s.isEven ? 0.62 : -0.62);
        final subTip = Vec3(
          dip.x + math.cos(subAng) * reach * 0.56,
          dip.y + 0.28,
          dip.z + math.sin(subAng) * reach * 0.56,
        );
        addTaperedLimb(
          timberBuilder,
          dip,
          subTip,
          0.058,
          0.026,
          color: barkColor,
        );
        addPineCloudPad(
          pineBuilder,
          Vector3(subTip.x, subTip.y + 0.06, subTip.z),
          Vector3(padR * 0.72, spec.$5 * 0.86, padR * 0.68),
          color: Vector4(shade * 0.88, shade * 0.98, shade * 0.92, 1),
          phase: sweepAng + s * 2.41 + 0.9,
        );
      }
    }

    addPineCloudPad(
      pineBuilder,
      Vector3(crownApex.x, crownApex.y + 0.10, crownApex.z),
      Vector3(1.36, 0.26, 1.24),
      color: Vector4(1.08, 1.16, 1.02, 1),
      phase: sweepAng + 5.1,
    );

    addRockBoulder(
      rockBuilder,
      Vector3(sweepCos * 0.74, 0.28, sweepSin * 0.74),
      Vector3(0.68, 0.28, 0.54),
      yaw: sweepAng + 0.4,
      seed: dna.unit(70) * 6.0,
    );
    addRockBoulder(
      rockBuilder,
      Vector3(-sweepSin * 0.64, 0.18, sweepCos * 0.64),
      Vector3(0.46, 0.19, 0.38),
      yaw: sweepAng + 1.9,
      seed: dna.unit(71) * 6.0,
    );
    addShrubRosette(
      fernBuilder,
      Vector3(-sweepCos * 0.62, 0.09, -sweepSin * 0.62),
      Vector3(0.76, 0.30, 0.72),
      color: Vector4(0.78, 0.94, 0.70, 1),
      phase: sweepAng + 1.2,
    );

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
            fernBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.bambooCanopy),
          ),
        ),
      )
      ..add(
        Node(
          mesh: Mesh(
            pineBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.pineCanopy),
          ),
        ),
      );

    return root;
  }

  Node buildWillowNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final dna = _TreeDna.fromStructure(structure);
    final timberBuilder = GeometryBuilder();
    final rockBuilder = GeometryBuilder();
    final fernBuilder = GeometryBuilder();

    final hScale = 0.92 + 0.22 * dna.unit(1);
    final leanAng = dna.unit(2) * math.pi * 2;
    final leanCos = math.cos(leanAng);
    final leanSin = math.sin(leanAng);

    final fork = Vec3(leanCos * 0.58, 2.55 * hScale, leanSin * 0.58);
    addCurvedTube(
      timberBuilder,
      sampleCubicSpine(
        const Vec3(0, -0.06, 0),
        Vec3(leanCos * 0.18, 0.85 * hScale, leanSin * 0.18),
        Vec3(leanCos * 0.48, 1.75 * hScale, leanSin * 0.48),
        fork,
        segments: 5,
      ),
      0.29,
      0.17,
      sides: 7,
    );

    for (var r = 0; r < 4; r++) {
      final rAng = leanAng + r * 1.57 + 0.25 * dna.signed(8 + r);
      addCurvedTube(
        timberBuilder,
        sampleCubicSpine(
          Vec3(math.cos(rAng) * 0.14, 0.36, math.sin(rAng) * 0.14),
          Vec3(math.cos(rAng) * 0.48, 0.16, math.sin(rAng) * 0.48),
          Vec3(math.cos(rAng) * 0.68, 0.02, math.sin(rAng) * 0.68),
          Vec3(math.cos(rAng) * 0.78, -0.08, math.sin(rAng) * 0.78),
          segments: 3,
        ),
        0.11,
        0.038,
        sides: 5,
      );
    }

    final willowMat = resolveMaterial(ShukubaSurfaceRole.willowCanopy);
    const boughCount = 8;
    for (var b = 0; b < boughCount; b++) {
      final bAng =
          leanAng + (b / boughCount) * math.pi * 2 + 0.16 * dna.signed(20 + b);
      final isOuter = b.isEven;
      final reach = (isOuter ? 2.05 : 1.38) * (0.90 + 0.22 * dna.unit(30 + b));
      final peakY = (isOuter ? 4.25 : 4.88) * hScale;
      final tipY = (isOuter ? 3.55 : 4.35) * hScale;

      final tip = Vec3(
        fork.x + math.cos(bAng) * reach,
        tipY,
        fork.z + math.sin(bAng) * reach,
      );
      addCurvedTube(
        timberBuilder,
        sampleCubicSpine(
          fork,
          Vec3(
            fork.x + math.cos(bAng) * reach * 0.34,
            peakY,
            fork.z + math.sin(bAng) * reach * 0.34,
          ),
          Vec3(
            fork.x + math.cos(bAng) * reach * 0.78,
            peakY + 0.08,
            fork.z + math.sin(bAng) * reach * 0.78,
          ),
          tip,
          segments: 5,
        ),
        0.105,
        0.028,
      );

      final curtainBuilder = GeometryBuilder();
      final shade = 0.90 + 0.22 * dna.unit(45 + b);
      addWillowCurtainCluster(
        curtainBuilder,
        hangLen: (isOuter ? 2.38 : 2.15) * hScale,
        width: isOuter ? 1.06 : 0.96,
        color: Vector4(shade * 0.96, shade * 1.06, shade * 0.88, 1),
        baseYaw: bAng + b * 0.193,
        phase: leanAng + b * 1.31,
      );
      root.add(
        Node(mesh: Mesh(curtainBuilder.build(), willowMat))
          ..position = tip.toVector3(),
      );

      final archMid = Vec3(
        fork.x + math.cos(bAng) * reach * 0.56,
        peakY + 0.10,
        fork.z + math.sin(bAng) * reach * 0.56,
      );
      final archCrownBuilder = GeometryBuilder();
      addWillowCurtainCluster(
        archCrownBuilder,
        hangLen: 1.45 * hScale,
        width: 0.88,
        color: Vector4(shade * 1.04, shade * 1.12, shade * 0.92, 1),
        baseYaw: bAng + 0.62,
        phase: leanAng + b * 2.13,
      );
      root.add(
        Node(mesh: Mesh(archCrownBuilder.build(), willowMat))
          ..position = archMid.toVector3(),
      );
    }

    final crownTip = Vec3(
      fork.x + leanCos * 0.22,
      5.05 * hScale,
      fork.z + leanSin * 0.22,
    );
    addCurvedTube(
      timberBuilder,
      sampleCubicSpine(
        fork,
        Vec3(fork.x, 3.65 * hScale, fork.z),
        Vec3(crownTip.x, 4.55 * hScale, crownTip.z),
        crownTip,
      ),
      0.11,
      0.032,
    );
    final topBuilder = GeometryBuilder();
    addWillowCurtainCluster(
      topBuilder,
      hangLen: 1.95 * hScale,
      width: 1.14,
      color: Vector4(1.08, 1.14, 0.94, 1),
      baseYaw: leanAng + 1.717,
      phase: leanAng + 5.4,
    );
    root.add(
      Node(mesh: Mesh(topBuilder.build(), willowMat))
        ..position = crownTip.toVector3(),
    );

    addRockBoulder(
      rockBuilder,
      Vector3(-leanCos * 0.68, 0.22, -leanSin * 0.68),
      Vector3(0.56, 0.22, 0.44),
      yaw: leanAng + 0.8,
      seed: dna.unit(80) * 6.0,
    );
    addShrubRosette(
      fernBuilder,
      Vector3(leanSin * 0.66, 0.08, -leanCos * 0.66),
      Vector3(0.82, 0.34, 0.76),
      color: Vector4(0.84, 1, 0.74, 1),
      phase: leanAng + 1.6,
    );

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
            fernBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.bambooCanopy),
          ),
        ),
      );

    return root;
  }

  Node buildRockOutcropNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final dna = _TreeDna.fromStructure(structure);
    final phenotype = dna.bucket(4, 1);
    final twist = dna.unit(2) * math.pi * 2;
    final hScale = 0.88 + 0.28 * dna.unit(3);
    final spread = 0.90 + 0.22 * dna.unit(4);

    final rockBuilder = GeometryBuilder();
    final fernBuilder = GeometryBuilder();

    final warmSlate = Vector4(
      0.94 + 0.10 * dna.signed(4),
      0.92 + 0.08 * dna.signed(5),
      0.88 + 0.08 * dna.signed(6),
      0.5,
    );
    final coolSlate = Vector4(
      0.84 + 0.08 * dna.signed(7),
      0.88 + 0.07 * dna.signed(8),
      0.95 + 0.06 * dna.signed(9),
      0.5,
    );

    switch (phenotype) {
      case 0:
        addStratifiedCliffBlock(
          rockBuilder,
          Vector3(-0.18 * spread, 0, -0.14 * spread),
          Vector3(1.06 * spread, 1.12 * hScale, 0.88 * spread),
          yaw: twist,
          tiltX: 0.09,
          tiltZ: -0.06,
          seed: dna.unit(11) * 7.0,
          color: warmSlate,
        );
        addStratifiedCliffBlock(
          rockBuilder,
          Vector3(0.66 * spread, 0, 0.34 * spread),
          Vector3(0.78 * spread, 0.66 * hScale, 0.68 * spread),
          yaw: twist + 0.72,
          tiltX: -0.06,
          tiltZ: 0.08,
          seed: dna.unit(12) * 7.0,
          color: coolSlate,
        );
        addRockBoulder(
          rockBuilder,
          Vector3(-0.82 * spread, 0.16, 0.56 * spread),
          Vector3(0.52 * spread, 0.28 * hScale, 0.44 * spread),
          yaw: twist + 1.9,
          seed: dna.unit(13) * 6.0,
          color: warmSlate,
        );
        addShrubRosette(
          fernBuilder,
          Vector3(0.18 * spread, 0.08, 0.86 * spread),
          Vector3(0.84, 0.36, 0.78),
          color: Vector4(0.82, 0.98, 0.70, 1),
          phase: twist + 0.5,
        );
      case 1:
        addStratifiedCliffBlock(
          rockBuilder,
          Vector3(0, 0, -0.10 * spread),
          Vector3(0.72 * spread, 1.18 * hScale, 0.62 * spread),
          yaw: twist,
          tiltX: 0.05,
          tiltZ: 0.04,
          seed: dna.unit(21) * 7.0,
          color: warmSlate,
        );
        addStratifiedCliffBlock(
          rockBuilder,
          Vector3(-0.86 * spread, 0, 0.24 * spread),
          Vector3(0.62 * spread, 0.74 * hScale, 0.54 * spread),
          yaw: twist - 0.64,
          tiltX: -0.09,
          tiltZ: 0.05,
          seed: dna.unit(22) * 7.0,
          color: coolSlate,
        );
        addStratifiedCliffBlock(
          rockBuilder,
          Vector3(0.82 * spread, 0, 0.30 * spread),
          Vector3(0.56 * spread, 0.54 * hScale, 0.48 * spread),
          yaw: twist + 0.88,
          tiltX: 0.08,
          tiltZ: -0.07,
          seed: dna.unit(23) * 7.0,
          color: warmSlate,
        );
        addRockBoulder(
          rockBuilder,
          Vector3(0.06 * spread, 0.10, 0.88 * spread),
          Vector3(0.54 * spread, 0.16, 0.38 * spread),
          yaw: twist + 0.3,
          seed: dna.unit(24) * 6.0,
          color: coolSlate,
        );
        addShrubRosette(
          fernBuilder,
          Vector3(-0.46 * spread, 0.08, 0.78 * spread),
          Vector3(0.76, 0.32, 0.72),
          color: Vector4(0.80, 0.96, 0.68, 1),
          phase: twist + 1.4,
        );
      case 2:
        addStratifiedCliffBlock(
          rockBuilder,
          Vector3(-0.62 * spread, 0, -0.08 * spread),
          Vector3(0.76 * spread, 1.04 * hScale, 0.96 * spread),
          yaw: twist - 0.22,
          tiltX: 0.11,
          tiltZ: -0.04,
          seed: dna.unit(31) * 7.0,
          color: coolSlate,
        );
        addStratifiedCliffBlock(
          rockBuilder,
          Vector3(0.64 * spread, 0, 0.12 * spread),
          Vector3(0.72 * spread, 0.84 * hScale, 0.90 * spread),
          yaw: twist + 0.28,
          tiltX: -0.10,
          tiltZ: 0.06,
          seed: dna.unit(32) * 7.0,
          color: warmSlate,
        );
        addRockBoulder(
          rockBuilder,
          Vector3(0.02, 0.14, 0.82 * spread),
          Vector3(0.46 * spread, 0.24 * hScale, 0.40 * spread),
          yaw: twist + 1.1,
          seed: dna.unit(33) * 6.0,
          color: warmSlate,
        );
        addShrubRosette(
          fernBuilder,
          Vector3(-0.08, 0.08, -0.82 * spread),
          Vector3(0.88, 0.38, 0.82),
          color: Vector4(0.84, 1, 0.72, 1),
          phase: twist + 2.2,
        );
      default:
        addStratifiedCliffBlock(
          rockBuilder,
          Vector3(0, 0, 0),
          Vector3(1.28 * spread, 0.72 * hScale, 1.02 * spread),
          yaw: twist,
          tiltX: 0.06,
          tiltZ: 0.08,
          seed: dna.unit(41) * 7.0,
          color: warmSlate,
        );
        addStratifiedCliffBlock(
          rockBuilder,
          Vector3(-0.32 * spread, 0.18, -0.22 * spread),
          Vector3(0.74 * spread, 0.88 * hScale, 0.64 * spread),
          yaw: twist + 0.58,
          tiltX: -0.07,
          tiltZ: 0.05,
          seed: dna.unit(42) * 7.0,
          color: coolSlate,
        );
        for (var s = 0; s < 3; s++) {
          final sa = twist + 0.9 + s * 2.05;
          addRockBoulder(
            rockBuilder,
            Vector3(
              math.cos(sa) * 1.12 * spread,
              0.12,
              math.sin(sa) * 0.96 * spread,
            ),
            Vector3(0.38, 0.20, 0.32),
            yaw: sa + 0.6,
            seed: dna.unit(45 + s) * 6.0,
            color: s.isEven ? coolSlate : warmSlate,
          );
        }
        addShrubRosette(
          fernBuilder,
          Vector3(0.78 * spread, 0.08, 0.66 * spread),
          Vector3(0.80, 0.34, 0.74),
          color: Vector4(0.82, 0.98, 0.70, 1),
          phase: twist + 3.1,
        );
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
            fernBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.bambooCanopy),
          ),
        ),
      );
    return root;
  }

  Node buildLanternSpanNode(
    LanternSpan span,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final timberBuilder = GeometryBuilder();
    final lanternBuilder = GeometryBuilder();

    const segs = 12;
    var prev = span.sampleCatenary(0);
    for (var i = 1; i <= segs; i++) {
      final curr = span.sampleCatenary(i / segs);
      if ((curr - prev).length > 1e-6) {
        addCordSegment(timberBuilder, prev, curr, halfThick: 0.020);
      }
      prev = curr;
    }

    final hangPoints = span.lanternHangPoints();
    for (final hp in hangPoints) {
      addLanternBody(lanternBuilder, timberBuilder, hp.toVector3());
    }

    root
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
            lanternBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.chochinLantern),
          ),
        ),
      );

    return root;
  }

  Node buildStreetAgentNode(
    StreetAgentRole role,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final clothBuilder = GeometryBuilder();
    final timberBuilder = GeometryBuilder();
    var hasTimber = false;

    final (kimonoTint, haoriTint, obiTint) = switch (role) {
      StreetAgentRole.townsfolk => (
        Vector4(0.68, 0.46, 0.26, 1),
        Vector4(0.24, 0.34, 0.48, 1),
        Vector4(0.84, 0.68, 0.34, 1),
      ),
      StreetAgentRole.lanternWatchman => (
        Vector4(0.18, 0.26, 0.44, 1),
        Vector4(0.62, 0.20, 0.14, 1),
        Vector4(0.90, 0.84, 0.68, 1),
      ),
      StreetAgentRole.nightSmuggler => (
        Vector4(0.24, 0.34, 0.26, 1),
        Vector4(0.48, 0.38, 0.24, 1),
        Vector4(0.66, 0.24, 0.16, 1),
      ),
    };
    final skinTint = Vector4(0.88, 0.72, 0.58, 1);
    final creamCloth = Vector4(0.94, 0.90, 0.80, 1);
    final hairTint = Vector4(0.09, 0.08, 0.09, 1);
    final kyahanTint = Vector4(0.16, 0.20, 0.28, 1);
    final sandalTint = Vector4(0.58, 0.46, 0.28, 1);

    addTaperedLimb(
      clothBuilder,
      const Vec3(-0.085, 0.08, 0.05),
      const Vec3(-0.075, 0.23, 0.03),
      0.046,
      0.054,
      sides: 6,
      color: kyahanTint,
    );
    addTaperedLimb(
      clothBuilder,
      const Vec3(0.085, 0.08, -0.05),
      const Vec3(0.075, 0.23, -0.03),
      0.046,
      0.054,
      sides: 6,
      color: kyahanTint,
    );
    addBox(
      clothBuilder,
      Vector3(-0.125, 0.025, -0.01),
      Vector3(-0.045, 0.075, 0.16),
      color: sandalTint,
    );
    addBox(
      clothBuilder,
      Vector3(0.045, 0.025, -0.14),
      Vector3(0.125, 0.075, 0.03),
      color: sandalTint,
    );

    addTaperedLimb(
      clothBuilder,
      const Vec3(0, 0.19, 0),
      const Vec3(0, 0.74, 0),
      0.205,
      0.165,
      sides: 7,
      color: kimonoTint,
    );
    addTaperedLimb(
      clothBuilder,
      const Vec3(0, 0.74, 0),
      const Vec3(0, 0.88, 0),
      0.188,
      0.184,
      sides: 7,
      color: obiTint,
    );
    addBox(
      clothBuilder,
      Vector3(-0.11, 0.75, -0.25),
      Vector3(0.11, 0.89, -0.17),
      color: obiTint,
    );

    addTaperedLimb(
      clothBuilder,
      const Vec3(0, 0.88, 0),
      const Vec3(0, 1.30, 0),
      0.225,
      0.145,
      sides: 7,
      color: haoriTint,
    );
    addBox(
      clothBuilder,
      Vector3(-0.065, 1.18, 0.11),
      Vector3(0.065, 1.32, 0.165),
      color: creamCloth,
    );

    addTaperedLimb(
      clothBuilder,
      const Vec3(-0.16, 1.24, 0),
      const Vec3(-0.31, 1.05, 0.08),
      0.075,
      0.068,
      color: haoriTint,
    );
    addBox(
      clothBuilder,
      Vector3(-0.33, 0.83, -0.02),
      Vector3(-0.22, 1.07, 0.15),
      color: haoriTint,
    );
    addTaperedLimb(
      clothBuilder,
      const Vec3(-0.29, 1.03, 0.09),
      const Vec3(-0.21, 0.97, 0.24),
      0.052,
      0.042,
      color: kimonoTint,
    );
    addSculptedEllipsoid(
      clothBuilder,
      Vector3(-0.20, 0.96, 0.26),
      Vector3(0.042, 0.040, 0.048),
      color: skinTint,
    );

    if (role == StreetAgentRole.lanternWatchman) {
      addTaperedLimb(
        clothBuilder,
        const Vec3(0.16, 1.24, 0.02),
        const Vec3(0.28, 1.12, 0.20),
        0.075,
        0.068,
        color: haoriTint,
      );
      addBox(
        clothBuilder,
        Vector3(0.21, 0.89, 0.08),
        Vector3(0.32, 1.13, 0.24),
        color: haoriTint,
      );
      addTaperedLimb(
        clothBuilder,
        const Vec3(0.27, 1.12, 0.21),
        const Vec3(0.25, 1.15, 0.38),
        0.050,
        0.040,
        color: kimonoTint,
      );
      addSculptedEllipsoid(
        clothBuilder,
        Vector3(0.25, 1.15, 0.40),
        Vector3(0.042, 0.040, 0.048),
        color: skinTint,
      );
    } else {
      addTaperedLimb(
        clothBuilder,
        const Vec3(0.16, 1.24, 0),
        const Vec3(0.31, 1.04, 0.10),
        0.075,
        0.068,
        color: haoriTint,
      );
      addBox(
        clothBuilder,
        Vector3(0.22, 0.83, 0),
        Vector3(0.33, 1.07, 0.17),
        color: haoriTint,
      );
      addTaperedLimb(
        clothBuilder,
        const Vec3(0.29, 1.02, 0.11),
        const Vec3(0.24, 0.98, 0.26),
        0.052,
        0.042,
        color: kimonoTint,
      );
      addSculptedEllipsoid(
        clothBuilder,
        Vector3(0.23, 0.97, 0.28),
        Vector3(0.042, 0.040, 0.048),
        color: skinTint,
      );
    }

    addSculptedEllipsoid(
      clothBuilder,
      Vector3(0, 1.40, 0.01),
      Vector3(0.105, 0.115, 0.108),
      color: skinTint,
    );
    addSculptedEllipsoid(
      clothBuilder,
      Vector3(0, 1.43, -0.025),
      Vector3(0.108, 0.095, 0.105),
      color: hairTint,
    );

    switch (role) {
      case StreetAgentRole.townsfolk:
        final strawHat = Vector4(0.88, 0.74, 0.44, 1);
        addTaperedLimb(
          clothBuilder,
          const Vec3(0, 1.48, 0),
          const Vec3(0, 1.58, 0),
          0.40,
          0.20,
          sides: 8,
          color: strawHat,
        );
        addTaperedLimb(
          clothBuilder,
          const Vec3(0, 1.58, 0),
          const Vec3(0, 1.66, 0),
          0.20,
          0.03,
          sides: 8,
          color: strawHat,
        );
        addSculptedEllipsoid(
          clothBuilder,
          Vector3(-0.08, 1.08, -0.21),
          Vector3(0.16, 0.13, 0.12),
          color: creamCloth,
        );
      case StreetAgentRole.lanternWatchman:
        hasTimber = true;
        addSculptedEllipsoid(
          clothBuilder,
          Vector3(0, 1.53, 0),
          Vector3(0.038, 0.038, 0.085),
          color: hairTint,
        );
        addTaperedLimb(
          clothBuilder,
          const Vec3(0, 1.44, 0),
          const Vec3(0, 1.48, 0),
          0.114,
          0.114,
          sides: 7,
          color: creamCloth,
        );
        addCordSegment(
          timberBuilder,
          const Vec3(0.24, 1.04, 0.22),
          const Vec3(0.26, 1.38, 0.78),
          halfThick: 0.016,
        );
        final lanternBuilder = GeometryBuilder();
        addLanternBody(
          lanternBuilder,
          timberBuilder,
          Vector3(0.26, 1.34, 0.76),
          radius: 0.125,
          height: 0.28,
        );
        root
          ..add(
            Node(
              mesh: Mesh(
                lanternBuilder.build(),
                resolveMaterial(ShukubaSurfaceRole.chochinLantern),
              ),
            ),
          )
          ..add(
            Node(
                mesh: Mesh(
                  buildUnitBillboardQuad(
                    color: Vector4(1.06, 0.86, 0.64, 0.85),
                  ),
                  resolveMaterial(ShukubaSurfaceRole.lanternHaze),
                ),
              )
              ..position = heldLanternLocalOffset.toVector3()
              ..scale = Vector3(1.28, 1.28, 1)
              ..shadowCastingMode = ShadowCastingMode.off,
          );
      case StreetAgentRole.nightSmuggler:
        hasTimber = true;
        final travelHat = Vector4(0.68, 0.54, 0.32, 1);
        addTaperedLimb(
          clothBuilder,
          const Vec3(0, 1.47, 0),
          const Vec3(0, 1.55, 0),
          0.42,
          0.22,
          sides: 8,
          color: travelHat,
        );
        addTaperedLimb(
          clothBuilder,
          const Vec3(0, 1.55, 0),
          const Vec3(0, 1.61, 0),
          0.22,
          0.04,
          sides: 8,
          color: travelHat,
        );
        for (final rx in const [-0.13, 0.13]) {
          addBox(
            timberBuilder,
            Vector3(rx - 0.018, 0.68, -0.21),
            Vector3(rx + 0.018, 1.48, -0.17),
          );
        }
        addBox(
          clothBuilder,
          Vector3(-0.15, 0.74, -0.36),
          Vector3(0.15, 1.05, -0.22),
          color: Vector4(0.76, 0.62, 0.38, 1),
        );
        addBox(
          clothBuilder,
          Vector3(-0.14, 1.08, -0.35),
          Vector3(0.14, 1.38, -0.22),
          color: Vector4(0.62, 0.48, 0.28, 1),
        );
        addTaperedLimb(
          clothBuilder,
          const Vec3(-0.19, 1.45, -0.26),
          const Vec3(0.19, 1.45, -0.26),
          0.072,
          0.072,
          sides: 6,
          color: creamCloth,
        );
        addTaperedLimb(
          timberBuilder,
          const Vec3(0.25, 0.04, 0.30),
          const Vec3(0.22, 1.36, 0.22),
          0.018,
          0.022,
          sides: 6,
        );
    }

    root.add(
      Node(
        mesh: Mesh(
          clothBuilder.build(),
          resolveMaterial(ShukubaSurfaceRole.plasterWall),
        ),
      ),
    );
    if (hasTimber) {
      root.add(
        Node(
          mesh: Mesh(
            timberBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.charredTimber),
          ),
        ),
      );
    }
    return root;
  }

  Node buildPreviewNode(
    BuildPreview preview,
    ShukubaMaterialResolver resolveMaterial,
    GroundHeightSampler sampleGroundY,
  ) {
    final root = Node();
    switch (preview) {
      case NoBuildPreview():
        return root;
      case StampGhostPreview(
        :final kind,
        :final position,
        :final yawRadians,
        :final lanternSpans,
      ):
        final ghostMat = resolveMaterial(ShukubaSurfaceRole.ghostPreview);
        final spec = kind.spec;
        final hw = spec.footprintWidth * 0.5;
        final hd = spec.footprintDepth * 0.5;
        final stampBuilder = GeometryBuilder();
        final padTint = Vector4(1, 0.94, 0.78, 0.92);
        final postTint = Vector4(0.98, 0.88, 0.64, 0.74);
        final cordFrameTint = Vector4(0.98, 0.88, 0.64, 0.54);

        const rim = 0.14;
        addBox(
          stampBuilder,
          Vector3(-hw, 0.03, hd - rim),
          Vector3(hw, 0.15, hd),
          color: padTint,
        );
        addBox(
          stampBuilder,
          Vector3(-hw, 0.03, -hd),
          Vector3(hw, 0.15, -hd + rim),
          color: padTint,
        );
        addBox(
          stampBuilder,
          Vector3(-hw, 0.03, -hd + rim),
          Vector3(-hw + rim, 0.15, hd - rim),
          color: padTint,
        );
        addBox(
          stampBuilder,
          Vector3(hw - rim, 0.03, -hd + rim),
          Vector3(hw, 0.15, hd - rim),
          color: padTint,
        );

        if (spec.snapsToRoadTangent || spec.straddlesRoad) {
          addTriangleOutward(
            stampBuilder,
            Vector3(-0.62, 0.09, hd + 0.18),
            Vector3(0.62, 0.09, hd + 0.18),
            Vector3(0, 0.09, hd + 0.88),
            Vector3(0, 1, 0),
            color: Vector4(1, 0.96, 0.82, 0.98),
          );
        }

        if (kind.isNaturalFeature) {
          const ringSegs = 8;
          final rIn = math.max(0.45, hw * 0.62);
          final rOut = rIn + 0.12;
          final natureTint = kind == StructureKind.rockOutcrop
              ? Vector4(0.86, 0.88, 0.90, 0.86)
              : Vector4(0.68, 0.95, 0.58, 0.86);
          for (var i = 0; i < ringSegs; i++) {
            final a0 = (i / ringSegs) * math.pi * 2;
            final a1 = ((i + 1) / ringSegs) * math.pi * 2;
            addQuadOutward(
              stampBuilder,
              Vector3(math.cos(a0) * rIn, 0.08, math.sin(a0) * rIn),
              Vector3(math.cos(a1) * rIn, 0.08, math.sin(a1) * rIn),
              Vector3(math.cos(a1) * rOut, 0.08, math.sin(a1) * rOut),
              Vector3(math.cos(a0) * rOut, 0.08, math.sin(a0) * rOut),
              Vector3(0, 1, 0),
              color: natureTint,
            );
          }
        } else {
          final stakeTop = math.min(1.35, spec.height * 0.32);
          final x0 = -hw + 0.06;
          final x1 = hw - 0.06;
          final z0 = -hd + 0.06;
          final z1 = hd - 0.06;
          for (final cx in [x0, x1]) {
            for (final cz in [z0, z1]) {
              addBox(
                stampBuilder,
                Vector3(cx - 0.04, 0.15, cz - 0.04),
                Vector3(cx + 0.04, stakeTop, cz + 0.04),
                color: postTint,
              );
            }
          }
          final railY = stakeTop - 0.08;
          final corners = [
            Vec3(x0, railY, z0),
            Vec3(x1, railY, z0),
            Vec3(x1, railY, z1),
            Vec3(x0, railY, z1),
          ];
          for (var i = 0; i < corners.length; i++) {
            addCordSegment(
              stampBuilder,
              corners[i],
              corners[(i + 1) % corners.length],
              color: cordFrameTint,
            );
          }
        }

        final stampNode = Node(mesh: Mesh(stampBuilder.build(), ghostMat))
          ..position = position.toVector3()
          ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), yawRadians);
        root.add(stampNode);

        if (lanternSpans.isNotEmpty) {
          final cordBuilder = GeometryBuilder();
          final chordTint = Vector4(1, 0.76, 0.32, 0.85);
          for (final span in lanternSpans) {
            var prev = span.sampleCatenary(0);
            for (var i = 1; i <= 10; i++) {
              final curr = span.sampleCatenary(i / 10);
              addCordSegment(
                cordBuilder,
                prev,
                curr,
                halfThick: 0.026,
                color: chordTint,
              );
              prev = curr;
            }
          }
          root.add(Node(mesh: Mesh(cordBuilder.build(), ghostMat)));
        }

      case StrokeRibbonPreview(:final style, :final points, :final widthMeters):
        final ghostMat = resolveMaterial(ShukubaSurfaceRole.ghostPreview);
        final builder = GeometryBuilder();
        if (points.length < 2) {
          if (points.length == 1) {
            final p = points.first;
            final gy = sampleGroundY(p.x, p.z);
            addBox(
              builder,
              Vector3(p.x - 0.35, gy + 0.06, p.z - 0.35),
              Vector3(p.x + 0.35, gy + 0.22, p.z + 0.35),
              color: Vector4(1, 0.84, 0.42, 0.90),
            );
            root.add(Node(mesh: Mesh(builder.build(), ghostMat)));
          }
          return root;
        }
        final halfW = widthMeters * 0.5;
        final (yTopOff, tint) = switch (style) {
          StrokePreviewStyle.lane => (0.10, Vector4(1, 0.80, 0.38, 0.82)),
          StrokePreviewStyle.gardenPath => (
            0.09,
            Vector4(0.76, 0.92, 0.72, 0.84),
          ),
          StrokePreviewStyle.terrace => (1.55, Vector4(0.72, 0.86, 1, 0.65)),
          StrokePreviewStyle.wall => (1.92, Vector4(0.98, 0.94, 0.86, 0.72)),
        };

        final ribbonPoints =
            (style == StrokePreviewStyle.lane ||
                style == StrokePreviewStyle.gardenPath)
            ? RoadSpline(
                id: const EntityId('__preview__'),
                controlPoints: points,
                widthMeters: widthMeters,
              ).smoothCenterline(stepMeters: 0.70)
            : points;

        for (var i = 0; i < ribbonPoints.length - 1; i++) {
          final a = ribbonPoints[i];
          final b = ribbonPoints[i + 1];
          final delta = b - a;
          final segLen = delta.horizontalLength;
          if (segLen <= 1e-4) {
            continue;
          }
          final steps = math.max(1, (segLen / 1.4).ceil());
          for (var k = 0; k < steps; k++) {
            final cA = Vec3.lerp(a, b, k / steps);
            final cB = Vec3.lerp(a, b, (k + 1) / steps);
            final along = (cB - cA).normalizedHorizontal();
            final rightN = Vec3(-along.z, 0, along.x);
            final gyA = sampleGroundY(cA.x, cA.z) + 0.05;
            final gyB = sampleGroundY(cB.x, cB.z) + 0.05;

            final ltA = (Vec3(cA.x, gyA + yTopOff, cA.z) - rightN * halfW)
                .toVector3();
            final ltB = (Vec3(cB.x, gyB + yTopOff, cB.z) - rightN * halfW)
                .toVector3();
            final rtA = (Vec3(cA.x, gyA + yTopOff, cA.z) + rightN * halfW)
                .toVector3();
            final rtB = (Vec3(cB.x, gyB + yTopOff, cB.z) + rightN * halfW)
                .toVector3();
            addQuadOutward(
              builder,
              ltA,
              ltB,
              rtB,
              rtA,
              Vector3(0, 1, 0),
              color: tint,
            );

            if (yTopOff > 0.25) {
              final lbA = (Vec3(cA.x, gyA, cA.z) - rightN * halfW).toVector3();
              final lbB = (Vec3(cB.x, gyB, cB.z) - rightN * halfW).toVector3();
              final rbA = (Vec3(cA.x, gyA, cA.z) + rightN * halfW).toVector3();
              final rbB = (Vec3(cB.x, gyB, cB.z) + rightN * halfW).toVector3();
              addQuadOutward(
                builder,
                lbA,
                lbB,
                ltB,
                ltA,
                Vector3(-rightN.x, 0, -rightN.z),
                color: tint,
              );
              addQuadOutward(
                builder,
                rbA,
                rbB,
                rtB,
                rtA,
                Vector3(rightN.x, 0, rightN.z),
                color: tint,
              );
            }
          }
        }
        root.add(Node(mesh: Mesh(builder.build(), ghostMat)));

      case DemolishHoverPreview(:final candidate):
        final ghostMat = resolveMaterial(ShukubaSurfaceRole.ghostPreview);
        final builder = GeometryBuilder();
        const segs = 12;
        final c = candidate.center;
        final rIn = math.max(0.5, candidate.radiusMeters);
        final rOut = rIn + 0.26;
        final redTint = Vector4(1, 0.24, 0.16, 1);
        for (var i = 0; i < segs; i++) {
          final a0 = (i / segs) * math.pi * 2;
          final a1 = ((i + 1) / segs) * math.pi * 2;
          final xIn0 = c.x + math.cos(a0) * rIn;
          final zIn0 = c.z + math.sin(a0) * rIn;
          final xIn1 = c.x + math.cos(a1) * rIn;
          final zIn1 = c.z + math.sin(a1) * rIn;
          final xOut0 = c.x + math.cos(a0) * rOut;
          final zOut0 = c.z + math.sin(a0) * rOut;
          final xOut1 = c.x + math.cos(a1) * rOut;
          final zOut1 = c.z + math.sin(a1) * rOut;
          final y = sampleGroundY(c.x, c.z) + 0.10;
          addQuadOutward(
            builder,
            Vector3(xIn0, y, zIn0),
            Vector3(xIn1, y, zIn1),
            Vector3(xOut1, y, zOut1),
            Vector3(xOut0, y, zOut0),
            Vector3(0, 1, 0),
            color: redTint,
          );
        }
        root.add(Node(mesh: Mesh(builder.build(), ghostMat)));
    }

    return root;
  }
}

class _TreeDna {
  factory fromStructure(PlacedStructure structure) {
    var h = 0x45d9f3b;
    for (final code in structure.id.value.codeUnits) {
      h = ((h ^ code) * 0x119de1f3) & 0x7fffffff;
    }
    final px = (structure.position.x * 137).round();
    final pz = (structure.position.z * 193).round();
    h = (h ^ (px * 73856093) ^ (pz * 19349663)) & 0x7fffffff;
    return _TreeDna._(h);
  }

  const new _(this._seed);

  final int _seed;

  int _mix(int salt) {
    var x = (_seed ^ (salt * 0x9e3779b9)) & 0x7fffffff;
    x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0x7fffffff;
    x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0x7fffffff;
    return (x ^ (x >> 16)) & 0x7fffffff;
  }

  double unit(int salt) => (_mix(salt) % 100003) / 100003.0;

  double signed(int salt) => unit(salt) * 2 - 1;

  int bucket(int count, int salt) => _mix(salt) % count;
}
