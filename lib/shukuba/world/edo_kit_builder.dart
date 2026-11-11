import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show GeometryBuilder, Mesh, Node;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        BuildPreview,
        DemolishHoverPreview,
        GroundHeightSampler,
        LanternSpan,
        NoBuildPreview,
        PlacedStructure,
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
    if (color != null) {
      builder.color(color);
    }

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
    if (color != null) {
      builder.color(color);
    }

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
    if (color != null) {
      builder.color(color);
    }

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

  static void addFoliageCluster(
    GeometryBuilder builder,
    Vector3 center,
    Vector3 radii, {
    required Vector4 color,
    double phase = 0,
  }) {
    const sides = 7;
    final top = Vector3(center.x, center.y + radii.y, center.z);
    final bottom = Vector3(center.x, center.y - radii.y * 0.65, center.z);
    final upperRing = <Vector3>[];
    final lowerRing = <Vector3>[];

    for (var i = 0; i < sides; i++) {
      final angle = phase + (i / sides) * math.pi * 2;
      final wobble = 0.86 + 0.18 * math.sin(angle * 2.0 + phase * 1.7);
      final ca = math.cos(angle) * wobble;
      final sa = math.sin(angle) * wobble;
      upperRing.add(
        Vector3(
          center.x + ca * radii.x * 0.80,
          center.y + radii.y * 0.36,
          center.z + sa * radii.z * 0.80,
        ),
      );
      lowerRing.add(
        Vector3(
          center.x + ca * radii.x,
          center.y - radii.y * 0.16,
          center.z + sa * radii.z,
        ),
      );
    }

    final crownTint = Vector4(
      (color.x * 1.12).clamp(0.0, 1.5),
      (color.y * 1.10).clamp(0.0, 1.5),
      (color.z * 1.04).clamp(0.0, 1.5),
      color.w,
    );
    final underTint = Vector4(
      color.x * 0.72,
      color.y * 0.74,
      color.z * 0.84,
      color.w,
    );

    for (var i = 0; i < sides; i++) {
      final next = (i + 1) % sides;
      final u0 = upperRing[i];
      final u1 = upperRing[next];
      final l0 = lowerRing[i];
      final l1 = lowerRing[next];
      final midOut = ((u0 + u1 + l0 + l1) * 0.25) - center;

      addTriangleOutward(
        builder,
        u0,
        u1,
        top,
        midOut + Vector3(0, radii.y, 0),
        uvScale: 0.8,
        color: crownTint,
      );
      addQuadOutward(
        builder,
        l0,
        l1,
        u1,
        u0,
        midOut,
        uvScale: 0.8,
        color: color,
      );
      addTriangleOutward(
        builder,
        l1,
        l0,
        bottom,
        midOut - Vector3(0, radii.y, 0),
        uvScale: 0.8,
        color: underTint,
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
    if (color != null) {
      builder.color(color);
    }

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

  Node buildStructureNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final structureNode = Node()
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
      StructureKind.mapleCluster => buildMapleNode(structure, resolveMaterial),
      StructureKind.bambooGrove => buildBambooNode(structure, resolveMaterial),
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

    // Lower cedar wainscoting (shitami-ita) + side/rear gable timber framing
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

    // Door jambs & lintel beam
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

    // Shoji screens behind lattice and doorway
    addBox(
      shojiBuilder,
      Vector3(-2.28, 0.98, 3.16),
      Vector3(-0.90, 2.20, 3.21),
    );
    addBox(shojiBuilder, Vector3(-0.68, 0.32, 3.16), Vector3(0.68, 2.20, 3.21));
    addBox(shojiBuilder, Vector3(0.90, 0.98, 3.16), Vector3(2.28, 2.20, 3.21));

    // Vertical street lattice bars (koshi)
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

    // Split dyed noren shop curtains over entrance
    const norenPanels = [(-0.62, -0.24), (-0.18, 0.18), (0.24, 0.62)];
    for (final p in norenPanels) {
      addBox(
        awningBuilder,
        Vector3(p.$1, 1.48, 3.32),
        Vector3(p.$2, 2.16, 3.36),
      );
    }

    // Street-level hisashi porch roof + slender porch posts
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

    // Threshold street props under the porch
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

    // Stone plinth + garden stepping stones
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

    // Engawa wrap-around wooden veranda deck + posts
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

    // Main warm plaster pavilion
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

    // Wide glowing shoji veranda bays
    addBox(
      shojiBuilder,
      Vector3(-2.42, 0.42, 1.54),
      Vector3(-0.88, 2.28, 1.59),
    );
    addBox(shojiBuilder, Vector3(-0.68, 0.42, 1.54), Vector3(0.68, 2.28, 1.59));
    addBox(shojiBuilder, Vector3(0.88, 0.42, 1.54), Vector3(1.88, 2.28, 1.59));
    addBox(shojiBuilder, Vector3(2.08, 0.42, -1.90), Vector3(2.13, 2.28, 1.24));

    // Noren curtains over veranda entrance
    for (final p in const [(-0.78, -0.30), (-0.22, 0.22), (0.30, 0.78)]) {
      addBox(
        awningBuilder,
        Vector3(p.$1, 1.72, 2.50),
        Vector3(p.$2, 2.34, 2.55),
      );
    }

    // Sweeping main kawara roof + front & side veranda hisashi eaves
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

    // Signature vermilion-cloth roadside tea bench (shogi)
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

    // Stone toro garden lantern on right corner
    addBox(stoneBuilder, Vector3(2.26, 0.02, 2.74), Vector3(2.68, 0.24, 3.16));
    addBox(stoneBuilder, Vector3(2.36, 0.26, 2.84), Vector3(2.58, 0.92, 3.06));
    addBox(shojiBuilder, Vector3(2.34, 0.94, 2.82), Vector3(2.60, 1.22, 3.08));
    addBox(stoneBuilder, Vector3(2.20, 1.24, 2.68), Vector3(2.74, 1.38, 3.22));

    // Plump hanging veranda chochin lanterns
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

    // Tall battered ishigaki stone foundation
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

    // Stone entrance steps
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

    // Dark timber lower dado skirt
    addBox(
      timberBuilder,
      Vector3(-2.22, 0.70, -2.72),
      Vector3(2.22, 1.72, 2.72),
    );

    // Chalk-white shikkui plaster vault core + thick gables
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

    // Heavy fireproof doorway + plaster hood + upper shuttered vault window
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

    // Merchant counter + goods + side barrel
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

    // Nuki lower tie beam + wedges + central gakuzuka plaque
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

    // Shimaki & pitched dark kasagi top lintel with upturned tips
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

  Node buildMapleNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final root = Node();
    final timberBuilder = GeometryBuilder();
    final mapleBuilder = GeometryBuilder();
    final rockBuilder = GeometryBuilder();
    final fernBuilder = GeometryBuilder();

    // Sinuous leaning trunk + reaching scaffold branches
    addTaperedLimb(
      timberBuilder,
      const Vec3(0, 0.04, 0),
      const Vec3(0.14, 1.85, 0.08),
      0.24,
      0.16,
      sides: 6,
    );
    addTaperedLimb(
      timberBuilder,
      const Vec3(0.12, 1.72, 0.06),
      const Vec3(-0.88, 3.35, -0.48),
      0.13,
      0.06,
    );
    addTaperedLimb(
      timberBuilder,
      const Vec3(0.14, 1.80, 0.08),
      const Vec3(0.96, 3.55, -0.36),
      0.13,
      0.06,
    );
    addTaperedLimb(
      timberBuilder,
      const Vec3(0.10, 1.90, 0.10),
      const Vec3(-0.46, 3.92, 0.84),
      0.12,
      0.055,
    );
    addTaperedLimb(
      timberBuilder,
      const Vec3(0.16, 1.95, 0.06),
      const Vec3(0.22, 4.88, 0.12),
      0.13,
      0.05,
    );

    // Wide cloud-layered (tamamono) autumn canopy pads
    final pads = [
      (
        Vector3(-1.05, 3.38, -0.58),
        Vector3(1.24, 0.38, 1.08),
        Vector4(0.95, 0.65, 0.55, 1),
        0.2,
      ),
      (
        Vector3(1.08, 3.58, -0.44),
        Vector3(1.20, 0.36, 1.04),
        Vector4(1.18, 0.88, 0.52, 1),
        1.1,
      ),
      (
        Vector3(-0.56, 3.92, 0.88),
        Vector3(1.28, 0.40, 1.12),
        Vector4(1.06, 0.72, 0.50, 1),
        2.0,
      ),
      (
        Vector3(0.84, 4.16, 0.72),
        Vector3(1.12, 0.36, 0.98),
        Vector4(1.24, 0.96, 0.56, 1),
        2.9,
      ),
      (
        Vector3(-0.92, 4.38, 0.14),
        Vector3(1.06, 0.34, 0.96),
        Vector4(1.02, 0.68, 0.48, 1),
        3.5,
      ),
      (
        Vector3(0.12, 4.68, -0.18),
        Vector3(1.38, 0.42, 1.24),
        Vector4(1.14, 0.82, 0.52, 1),
        4.1,
      ),
      (
        Vector3(0.24, 5.42, 0.14),
        Vector3(1.02, 0.36, 0.94),
        Vector4(1.28, 1.02, 0.58, 1),
        4.9,
      ),
    ];

    for (final p in pads) {
      addFoliageCluster(mapleBuilder, p.$1, p.$2, color: p.$3, phase: p.$4);
    }

    // Mossy base boulder + green fern cushion
    addRockBoulder(
      rockBuilder,
      Vector3(0.68, 0.26, 0.46),
      Vector3(0.56, 0.22, 0.46),
      yaw: 0.7,
      seed: 1.9,
    );
    addFoliageCluster(
      fernBuilder,
      Vector3(-0.54, 0.26, 0.52),
      Vector3(0.60, 0.24, 0.54),
      color: Vector4(0.86, 0.98, 0.74, 1),
      phase: 0.8,
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
    final culmBuilder = GeometryBuilder();
    final foliageBuilder = GeometryBuilder();
    final rockBuilder = GeometryBuilder();

    const culmSpecs = [
      (-0.82, -0.58, -1.04, -0.76, 6.25, 0.92),
      (0.72, -0.68, 0.94, -0.88, 6.65, 1.04),
      (-0.48, 0.72, -0.66, 0.96, 5.95, 0.88),
      (0.74, 0.54, 0.96, 0.74, 6.45, 0.98),
      (0.06, 0.04, 0.12, 0.08, 7.15, 1.08),
      (-0.22, -0.34, -0.30, -0.44, 6.10, 0.95),
      (0.32, -0.18, 0.44, -0.26, 6.80, 1.02),
      (-0.68, 0.12, -0.90, 0.18, 5.65, 0.86),
      (0.24, 0.76, 0.34, 0.98, 5.85, 0.90),
      (-0.12, 0.42, -0.18, 0.56, 6.50, 1.00),
    ];

    for (final c in culmSpecs) {
      final shade = c.$6;
      addTaperedLimb(
        culmBuilder,
        Vec3(c.$1, 0.04, c.$2),
        Vec3(c.$3, c.$5, c.$4),
        0.044,
        0.024,
        sides: 6,
        color: Vector4(0.56 * shade, 0.72 * shade, 0.30 * shade, 1),
      );
    }

    final sprays = [
      (Vector3(-0.78, 4.75, -0.52), Vector3(1.26, 0.38, 1.12), 0.92, 0.4),
      (Vector3(0.74, 5.15, 0.48), Vector3(1.22, 0.36, 1.08), 1.04, 1.5),
      (Vector3(-0.42, 5.68, 0.66), Vector3(1.16, 0.35, 1.04), 0.98, 2.2),
      (Vector3(0.58, 6.02, -0.56), Vector3(1.18, 0.36, 1.06), 1.08, 2.9),
      (Vector3(-0.14, 6.42, 0.08), Vector3(1.32, 0.40, 1.18), 1.12, 3.6),
      (Vector3(0.10, 7.05, -0.06), Vector3(0.98, 0.34, 0.92), 1.18, 4.4),
      (Vector3(-0.56, 0.34, -0.42), Vector3(0.66, 0.24, 0.60), 0.84, 0.9),
    ];

    for (final s in sprays) {
      final shade = s.$3;
      addFoliageCluster(
        foliageBuilder,
        s.$1,
        s.$2,
        color: Vector4(shade * 0.94, shade * 1.04, shade * 0.84, 1),
        phase: s.$4,
      );
    }

    addRockBoulder(
      rockBuilder,
      Vector3(0.56, 0.24, -0.48),
      Vector3(0.50, 0.20, 0.42),
      yaw: 1.2,
      seed: 3.1,
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

    final (kimonoTint, haoriTint) = switch (role) {
      StreetAgentRole.townsfolk => (
        Vector4(0.66, 0.46, 0.28, 1),
        Vector4(0.32, 0.38, 0.48, 1),
      ),
      StreetAgentRole.lanternWatchman => (
        Vector4(0.18, 0.28, 0.46, 1),
        Vector4(0.58, 0.22, 0.16, 1),
      ),
      StreetAgentRole.nightSmuggler => (
        Vector4(0.24, 0.32, 0.28, 1),
        Vector4(0.46, 0.38, 0.26, 1),
      ),
    };

    // Tapered kimono skirt + draped haori upper robe + obi sash
    addTaperedLimb(
      clothBuilder,
      const Vec3(0, 0.04, 0),
      const Vec3(0, 0.82, 0),
      0.20,
      0.15,
      sides: 6,
      color: kimonoTint,
    );
    addTaperedLimb(
      clothBuilder,
      const Vec3(0, 0.84, 0),
      const Vec3(0, 1.30, 0),
      0.23,
      0.13,
      sides: 6,
      color: haoriTint,
    );
    // Draped kimono sleeves on left and right
    addTaperedLimb(
      clothBuilder,
      const Vec3(-0.14, 1.22, 0),
      const Vec3(-0.26, 0.86, 0.05),
      0.08,
      0.10,
      color: haoriTint,
    );
    addTaperedLimb(
      clothBuilder,
      const Vec3(0.14, 1.22, 0),
      const Vec3(0.26, 0.86, 0.08),
      0.08,
      0.10,
      color: haoriTint,
    );

    // Head + wide conical woven sugegasa straw hat
    addFoliageCluster(
      clothBuilder,
      Vector3(0, 1.40, 0),
      Vector3(0.11, 0.11, 0.11),
      color: Vector4(0.86, 0.72, 0.58, 1),
    );
    addTaperedLimb(
      clothBuilder,
      const Vec3(0, 1.48, 0),
      const Vec3(0, 1.68, 0),
      0.39,
      0.03,
      sides: 7,
      color: Vector4(0.88, 0.74, 0.46, 1),
    );

    if (role == StreetAgentRole.lanternWatchman) {
      addCordSegment(
        timberBuilder,
        const Vec3(0.22, 0.98, 0.06),
        const Vec3(0.24, 1.14, 0.52),
        halfThick: 0.018,
      );
      final lanternBuilder = GeometryBuilder();
      addLanternBody(
        lanternBuilder,
        timberBuilder,
        Vector3(0.24, 1.12, 0.50),
        radius: 0.12,
        height: 0.28,
      );
      root.add(
        Node(
          mesh: Mesh(
            lanternBuilder.build(),
            resolveMaterial(ShukubaSurfaceRole.chochinLantern),
          ),
        ),
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
    if (role == StreetAgentRole.lanternWatchman) {
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
    if (preview is NoBuildPreview) {
      return root;
    }

    final ghostMat = resolveMaterial(ShukubaSurfaceRole.ghostPreview);
    final builder = GeometryBuilder();

    switch (preview) {
      case NoBuildPreview():
        return root;
      case StampGhostPreview(
        :final kind,
        :final position,
        :final yawRadians,
        :final lanternSpans,
      ):
        final spec = kind.spec;
        final hw = spec.footprintWidth * 0.5;
        final hd = spec.footprintDepth * 0.5;
        final stampBuilder = GeometryBuilder();
        final padTint = Vector4(1, 0.94, 0.78, 0.92);
        final postTint = Vector4(0.98, 0.88, 0.64, 0.74);
        final cordFrameTint = Vector4(0.98, 0.88, 0.64, 0.54);

        // Ground footprint sill bars
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

        // Front-facing directional chevron (+Z local forward)
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

        if (kind == StructureKind.mapleCluster ||
            kind == StructureKind.bambooGrove) {
          const ringSegs = 8;
          final rIn = math.max(0.45, hw * 0.62);
          final rOut = rIn + 0.12;
          final natureTint = Vector4(0.68, 0.95, 0.58, 0.86);
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

        // Preview catenary lantern chords that will auto-string on placement
        if (lanternSpans.isNotEmpty) {
          final chordTint = Vector4(1, 0.76, 0.32, 0.85);
          for (final span in lanternSpans) {
            var prev = span.sampleCatenary(0);
            for (var i = 1; i <= 10; i++) {
              final curr = span.sampleCatenary(i / 10);
              addCordSegment(
                builder,
                prev,
                curr,
                halfThick: 0.026,
                color: chordTint,
              );
              prev = curr;
            }
          }
          root.add(Node(mesh: Mesh(builder.build(), ghostMat)));
        }

      case StrokeRibbonPreview(:final style, :final points, :final widthMeters):
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
          StrokePreviewStyle.terrace => (1.55, Vector4(0.72, 0.86, 1, 0.65)),
          StrokePreviewStyle.wall => (1.92, Vector4(0.98, 0.94, 0.86, 0.72)),
        };

        for (var i = 0; i < points.length - 1; i++) {
          final a = points[i];
          final b = points[i + 1];
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
