import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show GeometryBuilder, Mesh, Node;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        LanternSpan,
        PlacedStructure,
        ShukubaMaterialResolver,
        ShukubaSurfaceRole,
        StreetAgentRole,
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
    const sides = 6;
    final top = Vector3(center.x, center.y + radii.y, center.z);
    final bottom = Vector3(center.x, center.y - radii.y * 0.72, center.z);
    final upperRing = <Vector3>[];
    final lowerRing = <Vector3>[];

    for (var i = 0; i < sides; i++) {
      final angle = phase + (i / sides) * math.pi * 2;
      final wobble = 0.88 + 0.16 * math.sin(angle * 2.0 + phase * 1.7);
      final ca = math.cos(angle) * wobble;
      final sa = math.sin(angle) * wobble;
      upperRing.add(
        Vector3(
          center.x + ca * radii.x * 0.82,
          center.y + radii.y * 0.34,
          center.z + sa * radii.z * 0.82,
        ),
      );
      lowerRing.add(
        Vector3(
          center.x + ca * radii.x,
          center.y - radii.y * 0.20,
          center.z + sa * radii.z,
        ),
      );
    }

    final crownTint = Vector4(
      (color.x * 1.08).clamp(0.0, 1.5),
      (color.y * 1.06).clamp(0.0, 1.5),
      (color.z * 1.04).clamp(0.0, 1.5),
      color.w,
    );
    final underTint = Vector4(
      color.x * 0.78,
      color.y * 0.78,
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

  static void addCordSegment(
    GeometryBuilder builder,
    Vec3 a,
    Vec3 b, {
    double halfThick = 0.022,
  }) {
    final dx = b.x - a.x;
    final dz = b.z - a.z;
    final hLen = math.sqrt(dx * dx + dz * dz);
    final nx = hLen > 1e-5 ? -dz / hLen * halfThick : halfThick;
    final nz = hLen > 1e-5 ? dx / hLen * halfThick : 0.0;

    final a0 = builder.addVertex(Vector3(a.x - nx, a.y - halfThick, a.z - nz));
    final a1 = builder.addVertex(Vector3(a.x + nx, a.y - halfThick, a.z + nz));
    final a2 = builder.addVertex(Vector3(a.x + nx, a.y + halfThick, a.z + nz));
    final a3 = builder.addVertex(Vector3(a.x - nx, a.y + halfThick, a.z - nz));

    final b0 = builder.addVertex(Vector3(b.x - nx, b.y - halfThick, b.z - nz));
    final b1 = builder.addVertex(Vector3(b.x + nx, b.y - halfThick, b.z + nz));
    final b2 = builder.addVertex(Vector3(b.x + nx, b.y + halfThick, b.z + nz));
    final b3 = builder.addVertex(Vector3(b.x - nx, b.y + halfThick, b.z - nz));

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

  Node buildStructureNode(
    PlacedStructure structure,
    ShukubaMaterialResolver resolveMaterial,
  ) {
    final structureNode = Node()
      ..position = structure.position.toVector3()
      ..rotation = Quaternion.axisAngle(Vector3(0, 1, 0), structure.yawRadians);

    final content = switch (structure.kind) {
      StructureKind.machiya => buildMachiyaNode(structure, resolveMaterial),
      StructureKind.marketStall => buildMarketStallNode(
        structure,
        resolveMaterial,
      ),
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
    final isTwoStory = structure.id.value.hashCode.isEven;

    final stoneBuilder = GeometryBuilder();
    final plasterBuilder = GeometryBuilder();
    final timberBuilder = GeometryBuilder();
    final shojiBuilder = GeometryBuilder();
    final roofBuilder = GeometryBuilder();

    addBox(
      stoneBuilder,
      Vector3(-2.60, -1.40, -3.30),
      Vector3(2.60, 0.22, 3.30),
    );

    final wallHeight = isTwoStory ? 4.35 : 2.95;
    final eavesY = wallHeight + 0.10;
    final ridgeY = eavesY + 1.32;

    addBox(
      plasterBuilder,
      Vector3(-2.46, 0.29, -3.16),
      Vector3(2.46, wallHeight, 3.16),
    );
    addTriangleOutward(
      plasterBuilder,
      Vector3(-2.42, wallHeight + 0.02, 3.14),
      Vector3(2.42, wallHeight + 0.02, 3.14),
      Vector3(0, ridgeY - 0.18, 3.14),
      Vector3(0, 0, 1),
    );
    addTriangleOutward(
      plasterBuilder,
      Vector3(-2.42, wallHeight + 0.02, -3.14),
      Vector3(2.42, wallHeight + 0.02, -3.14),
      Vector3(0, ridgeY - 0.18, -3.14),
      Vector3(0, 0, -1),
    );

    const cornerPosts = [
      (-2.54, -2.38, 3.08, 3.24),
      (2.38, 2.54, 3.08, 3.24),
      (-2.54, -2.38, -3.24, -3.08),
      (2.38, 2.54, -3.24, -3.08),
    ];

    for (final post in cornerPosts) {
      addBox(
        timberBuilder,
        Vector3(post.$1, 0.23, post.$3),
        Vector3(post.$2, wallHeight + 0.05, post.$4),
      );
    }

    addBox(
      timberBuilder,
      Vector3(-0.88, 0.23, 3.19),
      Vector3(-0.74, 2.20, 3.35),
    );
    addBox(timberBuilder, Vector3(0.74, 0.23, 3.19), Vector3(0.88, 2.20, 3.35));

    addBox(
      timberBuilder,
      Vector3(-2.36, 0.34, 3.19),
      Vector3(2.36, 0.43, 3.29),
    );
    addBox(
      timberBuilder,
      Vector3(-2.36, 2.22, 3.19),
      Vector3(2.36, 2.36, 3.29),
    );

    addBox(
      shojiBuilder,
      Vector3(-2.30, 0.46, 3.20),
      Vector3(-0.92, 2.18, 3.24),
    );
    addBox(shojiBuilder, Vector3(-0.68, 0.46, 3.20), Vector3(0.68, 2.18, 3.24));
    addBox(shojiBuilder, Vector3(0.92, 0.46, 3.20), Vector3(2.30, 2.18, 3.24));

    if (isTwoStory) {
      addBox(
        shojiBuilder,
        Vector3(-1.60, 2.85, 3.20),
        Vector3(1.60, 3.88, 3.25),
      );
      addBox(
        timberBuilder,
        Vector3(-2.72, 2.44, 3.18),
        Vector3(2.72, 2.64, 3.72),
      );
    }

    void addGabledRoof() {
      const z0 = -3.72;
      const z1 = 3.72;
      const xLeft = -3.02;
      const xRight = 3.02;
      const thick = 0.14;

      final tR0 = Vector3(0, ridgeY + thick, z0);
      final tR1 = Vector3(0, ridgeY + thick, z1);
      final tL0 = Vector3(xLeft, eavesY + thick, z0);
      final tL1 = Vector3(xLeft, eavesY + thick, z1);
      final tRt0 = Vector3(xRight, eavesY + thick, z0);
      final tRt1 = Vector3(xRight, eavesY + thick, z1);

      final bR0 = Vector3(0, ridgeY, z0);
      final bR1 = Vector3(0, ridgeY, z1);
      final bL0 = Vector3(xLeft, eavesY, z0);
      final bL1 = Vector3(xLeft, eavesY, z1);
      final bRt0 = Vector3(xRight, eavesY, z0);
      final bRt1 = Vector3(xRight, eavesY, z1);

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
      addQuadOutward(
        roofBuilder,
        bL0,
        bL1,
        tL1,
        tL0,
        Vector3(-1, 0, 0),
        uvScale: 0.75,
      );
      addQuadOutward(
        roofBuilder,
        bRt0,
        bRt1,
        tRt1,
        tRt0,
        Vector3(1, 0, 0),
        uvScale: 0.75,
      );
      addQuadOutward(
        roofBuilder,
        bL1,
        bR1,
        tR1,
        tL1,
        Vector3(0, 0, 1),
        uvScale: 0.75,
      );
      addQuadOutward(
        roofBuilder,
        bR1,
        bRt1,
        tRt1,
        tR1,
        Vector3(0, 0, 1),
        uvScale: 0.75,
      );
      addQuadOutward(
        roofBuilder,
        bL0,
        bR0,
        tR0,
        tL0,
        Vector3(0, 0, -1),
        uvScale: 0.75,
      );
      addQuadOutward(
        roofBuilder,
        bR0,
        bRt0,
        tRt0,
        tR0,
        Vector3(0, 0, -1),
        uvScale: 0.75,
      );

      addBox(
        timberBuilder,
        Vector3(-0.14, ridgeY + thick + 0.02, z0 - 0.06),
        Vector3(0.14, ridgeY + thick + 0.20, z1 + 0.06),
      );
    }

    addGabledRoof();

    if (structure.id.value.hashCode % 3 == 0) {
      addBox(
        timberBuilder,
        Vector3(1.65, 0.24, 3.38),
        Vector3(2.25, 0.88, 3.98),
      );
      addBox(
        shojiBuilder,
        Vector3(1.72, 0.30, 4.02),
        Vector3(2.18, 0.80, 4.08),
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
        Vector3(coord.$1 + 0.10, 2.22, coord.$2 + 0.10),
      );
    }

    addBox(
      timberBuilder,
      Vector3(-0.85, 0.06, -0.35),
      Vector3(0.85, 0.85, 0.45),
    );

    addBox(
      timberBuilder,
      Vector3(-0.70, 0.89, -0.25),
      Vector3(-0.10, 1.25, 0.35),
    );
    addBox(
      timberBuilder,
      Vector3(0.10, 0.89, -0.25),
      Vector3(0.70, 1.25, 0.35),
    );

    const ax0 = -1.38;
    const ax1 = 1.38;
    const az0 = -1.18;
    const az1 = 1.18;
    const ayBack = 2.62;
    const ayFront = 2.26;
    const aThick = 0.06;

    final at0 = Vector3(ax0, ayBack + aThick, az0);
    final at1 = Vector3(ax1, ayBack + aThick, az0);
    final at2 = Vector3(ax1, ayFront + aThick, az1);
    final at3 = Vector3(ax0, ayFront + aThick, az1);
    final ab0 = Vector3(ax0, ayBack, az0);
    final ab1 = Vector3(ax1, ayBack, az0);
    final ab2 = Vector3(ax1, ayFront, az1);
    final ab3 = Vector3(ax0, ayFront, az1);

    addQuadOutward(awningBuilder, at0, at1, at2, at3, Vector3(0, 1, 0.2));
    addQuadOutward(awningBuilder, ab0, ab1, ab2, ab3, Vector3(0, -1, -0.2));
    addQuadOutward(awningBuilder, ab3, ab2, at2, at3, Vector3(0, 0, 1));
    addQuadOutward(awningBuilder, ab0, ab1, at1, at0, Vector3(0, 0, -1));
    addQuadOutward(awningBuilder, ab0, ab3, at3, at0, Vector3(-1, 0, 0));
    addQuadOutward(awningBuilder, ab1, ab2, at2, at1, Vector3(1, 0, 0));

    addBox(
      lanternBuilder,
      Vector3(0.98, 1.76, 0.94),
      Vector3(1.24, 2.10, 1.20),
    );
    addBox(timberBuilder, Vector3(1.09, 2.12, 1.05), Vector3(1.13, 2.24, 1.09));

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

    const skIn = 1.66;
    const skOut = 2.26;
    const skTopY = 4.48;
    const skEaveY = 4.18;
    const skThick = 0.09;
    final skiT0 = Vector3(-skIn, skTopY, -skIn);
    final skiT1 = Vector3(skIn, skTopY, -skIn);
    final skiT2 = Vector3(skIn, skTopY, skIn);
    final skiT3 = Vector3(-skIn, skTopY, skIn);
    final skoT0 = Vector3(-skOut, skEaveY, -skOut);
    final skoT1 = Vector3(skOut, skEaveY, -skOut);
    final skoT2 = Vector3(skOut, skEaveY, skOut);
    final skoT3 = Vector3(-skOut, skEaveY, skOut);
    final skiB0 = Vector3(-skIn, skTopY - skThick, -skIn);
    final skiB1 = Vector3(skIn, skTopY - skThick, -skIn);
    final skiB2 = Vector3(skIn, skTopY - skThick, skIn);
    final skiB3 = Vector3(-skIn, skTopY - skThick, skIn);
    final skoB0 = Vector3(-skOut, skEaveY - skThick, -skOut);
    final skoB1 = Vector3(skOut, skEaveY - skThick, -skOut);
    final skoB2 = Vector3(skOut, skEaveY - skThick, skOut);
    final skoB3 = Vector3(-skOut, skEaveY - skThick, skOut);

    addQuadOutward(
      roofBuilder,
      skoT0,
      skoT1,
      skiT1,
      skiT0,
      Vector3(0, 1, -0.5),
      uvScale: 0.75,
    );
    addQuadOutward(
      roofBuilder,
      skoT1,
      skoT2,
      skiT2,
      skiT1,
      Vector3(0.5, 1, 0),
      uvScale: 0.75,
    );
    addQuadOutward(
      roofBuilder,
      skoT2,
      skoT3,
      skiT3,
      skiT2,
      Vector3(0, 1, 0.5),
      uvScale: 0.75,
    );
    addQuadOutward(
      roofBuilder,
      skoT3,
      skoT0,
      skiT0,
      skiT3,
      Vector3(-0.5, 1, 0),
      uvScale: 0.75,
    );
    addQuadOutward(roofBuilder, skoB0, skoB1, skiB1, skiB0, Vector3(0, -1, 0));
    addQuadOutward(roofBuilder, skoB1, skoB2, skiB2, skiB1, Vector3(0, -1, 0));
    addQuadOutward(roofBuilder, skoB2, skoB3, skiB3, skiB2, Vector3(0, -1, 0));
    addQuadOutward(roofBuilder, skoB3, skoB0, skiB0, skiB3, Vector3(0, -1, 0));
    addQuadOutward(roofBuilder, skoB0, skoB1, skoT1, skoT0, Vector3(0, 0, -1));
    addQuadOutward(roofBuilder, skoB1, skoB2, skoT2, skoT1, Vector3(1, 0, 0));
    addQuadOutward(roofBuilder, skoB2, skoB3, skoT3, skoT2, Vector3(0, 0, 1));
    addQuadOutward(roofBuilder, skoB3, skoB0, skoT0, skoT3, Vector3(-1, 0, 0));

    addBox(
      timberBuilder,
      Vector3(-1.80, 4.52, -1.80),
      Vector3(1.80, 4.66, 1.80),
    );

    const rPosts = [(-1.84, -1.84), (1.72, -1.84), (-1.84, 1.72), (1.72, 1.72)];
    for (final rp in rPosts) {
      addBox(
        timberBuilder,
        Vector3(rp.$1, 4.68, rp.$2),
        Vector3(rp.$1 + 0.12, 5.44, rp.$2 + 0.12),
      );
    }
    addBox(
      timberBuilder,
      Vector3(-1.82, 5.46, -1.82),
      Vector3(-1.74, 5.54, 1.82),
    );
    addBox(
      timberBuilder,
      Vector3(1.74, 5.46, -1.82),
      Vector3(1.82, 5.54, 1.82),
    );
    addBox(
      timberBuilder,
      Vector3(-1.72, 5.46, -1.82),
      Vector3(1.72, 5.54, -1.74),
    );
    addBox(
      timberBuilder,
      Vector3(-1.72, 5.46, 1.74),
      Vector3(1.72, 5.54, 1.82),
    );

    addBox(
      timberBuilder,
      Vector3(-1.02, 4.68, -1.02),
      Vector3(1.02, 6.40, 1.02),
    );
    const upperPosts = [
      (-1.18, -1.18),
      (1.04, -1.18),
      (-1.18, 1.04),
      (1.04, 1.04),
    ];
    for (final up in upperPosts) {
      addBox(
        timberBuilder,
        Vector3(up.$1, 4.68, up.$2),
        Vector3(up.$1 + 0.14, 6.42, up.$2 + 0.14),
      );
    }

    addBox(shojiBuilder, Vector3(-0.76, 4.96, 1.05), Vector3(0.76, 6.08, 1.10));
    addBox(
      shojiBuilder,
      Vector3(-0.76, 4.96, -1.10),
      Vector3(0.76, 6.08, -1.05),
    );
    addBox(shojiBuilder, Vector3(1.05, 4.96, -0.76), Vector3(1.10, 6.08, 0.76));
    addBox(
      shojiBuilder,
      Vector3(-1.10, 4.96, -0.76),
      Vector3(-1.05, 6.08, 0.76),
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

    addTriangleOutward(
      roofBuilder,
      rt0,
      rt1,
      rApex,
      Vector3(0, 1, -1),
      uvScale: 0.75,
    );
    addTriangleOutward(
      roofBuilder,
      rt1,
      rt2,
      rApex,
      Vector3(1, 1, 0),
      uvScale: 0.75,
    );
    addTriangleOutward(
      roofBuilder,
      rt2,
      rt3,
      rApex,
      Vector3(0, 1, 1),
      uvScale: 0.75,
    );
    addTriangleOutward(
      roofBuilder,
      rt3,
      rt0,
      rApex,
      Vector3(-1, 1, 0),
      uvScale: 0.75,
    );
    addQuadOutward(roofBuilder, rb0, rb1, rt1, rt0, Vector3(0, 0, -1));
    addQuadOutward(roofBuilder, rb1, rb2, rt2, rt1, Vector3(1, 0, 0));
    addQuadOutward(roofBuilder, rb2, rb3, rt3, rt2, Vector3(0, 0, 1));
    addQuadOutward(roofBuilder, rb3, rb0, rt0, rt3, Vector3(-1, 0, 0));
    addQuadOutward(roofBuilder, rb0, rb1, rb2, rb3, Vector3(0, -1, 0));

    addBox(
      timberBuilder,
      Vector3(-0.12, raY + 0.02, -0.12),
      Vector3(0.12, raY + 0.42, 0.12),
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
    final foliageBuilder = GeometryBuilder();

    addBox(
      timberBuilder,
      Vector3(-0.20, -0.50, -0.20),
      Vector3(0.20, 2.35, 0.20),
    );
    addBox(
      timberBuilder,
      Vector3(-0.10, 2.05, -0.10),
      Vector3(0.52, 3.45, 0.30),
    );
    addBox(
      timberBuilder,
      Vector3(-0.54, 2.15, -0.32),
      Vector3(0.06, 3.30, 0.12),
    );

    final clusters = [
      (Vector3(-0.92, 3.45, -0.55), Vector3(1.18, 0.62, 1.05), 0.90, 0.2),
      (Vector3(0.86, 3.65, -0.52), Vector3(1.14, 0.60, 1.02), 1.06, 1.1),
      (Vector3(-0.55, 3.85, 0.78), Vector3(1.22, 0.64, 1.08), 0.98, 2.0),
      (Vector3(0.88, 4.05, 0.62), Vector3(1.06, 0.58, 0.98), 1.12, 2.9),
      (Vector3(-0.12, 4.58, -0.08), Vector3(1.28, 0.66, 1.16), 1.05, 3.7),
      (Vector3(0.14, 5.28, 0.06), Vector3(0.92, 0.56, 0.88), 1.18, 4.6),
    ];

    for (final c in clusters) {
      final shade = c.$3;
      addFoliageCluster(
        foliageBuilder,
        c.$1,
        c.$2,
        color: Vector4(shade, shade * 0.92, shade * 0.84, 1),
        phase: c.$4,
      );
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
            foliageBuilder.build(),
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
    final timberBuilder = GeometryBuilder();
    final foliageBuilder = GeometryBuilder();

    const culmOffsets = [
      (-0.75, -0.55, 6.10),
      (0.65, -0.65, 6.45),
      (-0.42, 0.68, 5.85),
      (0.68, 0.52, 6.30),
      (0.04, 0.02, 6.75),
      (-0.18, -0.32, 5.95),
    ];

    for (final co in culmOffsets) {
      addBox(
        timberBuilder,
        Vector3(co.$1 - 0.055, -0.50, co.$2 - 0.055),
        Vector3(co.$1 + 0.055, co.$3, co.$2 + 0.055),
      );
    }

    final clusters = [
      (Vector3(-0.62, 4.85, -0.45), Vector3(1.15, 0.58, 1.05), 0.90, 0.4),
      (Vector3(0.58, 5.25, 0.42), Vector3(1.12, 0.56, 1.02), 1.04, 1.5),
      (Vector3(-0.18, 5.98, 0.08), Vector3(1.20, 0.60, 1.12), 1.09, 2.6),
      (Vector3(0.08, 6.78, -0.06), Vector3(0.92, 0.54, 0.88), 1.16, 3.8),
    ];

    for (final c in clusters) {
      final shade = c.$3;
      addFoliageCluster(
        foliageBuilder,
        c.$1,
        c.$2,
        color: Vector4(shade * 0.92, shade, shade * 0.88, 1),
        phase: c.$4,
      );
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
        addCordSegment(timberBuilder, prev, curr);
      }
      prev = curr;
    }

    final hangPoints = span.lanternHangPoints();
    for (final hp in hangPoints) {
      addBox(
        timberBuilder,
        Vector3(hp.x - 0.018, hp.y - 0.20, hp.z - 0.018),
        Vector3(hp.x + 0.018, hp.y + 0.01, hp.z + 0.018),
      );
      addBox(
        lanternBuilder,
        Vector3(hp.x - 0.14, hp.y - 0.52, hp.z - 0.14),
        Vector3(hp.x + 0.14, hp.y - 0.16, hp.z + 0.14),
      );
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

    final robeTint = switch (role) {
      StreetAgentRole.townsfolk => Vector4(0.68, 0.54, 0.36, 1),
      StreetAgentRole.lanternWatchman => Vector4(0.16, 0.28, 0.48, 1),
      StreetAgentRole.nightSmuggler => Vector4(0.10, 0.09, 0.16, 1),
    };

    addBox(
      clothBuilder,
      Vector3(-0.22, 0.06, -0.16),
      Vector3(0.22, 1.24, 0.16),
      color: robeTint,
    );
    addBox(
      timberBuilder,
      Vector3(-0.36, 1.44, -0.36),
      Vector3(0.36, 1.51, 0.36),
    );
    addBox(
      clothBuilder,
      Vector3(-0.18, 1.53, -0.18),
      Vector3(0.18, 1.66, 0.18),
      color: Vector4(0.76, 0.62, 0.42, 1),
    );

    if (role == StreetAgentRole.lanternWatchman) {
      addBox(
        timberBuilder,
        Vector3(0.18, 1.05, 0.05),
        Vector3(0.23, 1.10, 0.52),
      );
      final lanternBuilder = GeometryBuilder();
      addBox(
        lanternBuilder,
        Vector3(0.11, 0.74, 0.38),
        Vector3(0.30, 1.04, 0.57),
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

    root
      ..add(
        Node(
          mesh: Mesh(
            clothBuilder.build(),
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
      );
    return root;
  }
}
