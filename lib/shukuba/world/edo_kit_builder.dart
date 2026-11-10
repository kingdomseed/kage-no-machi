import 'package:flutter_scene/scene.dart' show GeometryBuilder, Mesh, Node;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        LanternSpan,
        PlacedStructure,
        ShukubaMaterialResolver,
        ShukubaSurfaceRole,
        StructureKind;
import 'package:vector_math/vector_math.dart' show Quaternion, Vector3, Vector4;

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
    if (color != null) builder.color(color);

    final v0 = builder.addVertex(Vector3(x0, y0, z0));
    final v1 = builder.addVertex(Vector3(x0, y1, z0));
    final v2 = builder.addVertex(Vector3(x1, y1, z0));
    final v3 = builder.addVertex(Vector3(x1, y0, z0));
    builder
      ..addTriangle(v0, v1, v2)
      ..addTriangle(v0, v2, v3);

    final v4 = builder.addVertex(Vector3(x1, y0, z1));
    final v5 = builder.addVertex(Vector3(x1, y1, z1));
    final v6 = builder.addVertex(Vector3(x0, y1, z1));
    final v7 = builder.addVertex(Vector3(x0, y0, z1));
    builder
      ..addTriangle(v4, v5, v6)
      ..addTriangle(v4, v6, v7);

    final v8 = builder.addVertex(Vector3(x0, y0, z1));
    final v9 = builder.addVertex(Vector3(x0, y1, z1));
    final v10 = builder.addVertex(Vector3(x0, y1, z0));
    final v11 = builder.addVertex(Vector3(x0, y0, z0));
    builder
      ..addTriangle(v8, v9, v10)
      ..addTriangle(v8, v10, v11);

    final v12 = builder.addVertex(Vector3(x1, y0, z0));
    final v13 = builder.addVertex(Vector3(x1, y1, z0));
    final v14 = builder.addVertex(Vector3(x1, y1, z1));
    final v15 = builder.addVertex(Vector3(x1, y0, z1));
    builder
      ..addTriangle(v12, v13, v14)
      ..addTriangle(v12, v14, v15);

    final v16 = builder.addVertex(Vector3(x0, y0, z1));
    final v17 = builder.addVertex(Vector3(x0, y0, z0));
    final v18 = builder.addVertex(Vector3(x1, y0, z0));
    final v19 = builder.addVertex(Vector3(x1, y0, z1));
    builder
      ..addTriangle(v16, v17, v18)
      ..addTriangle(v16, v18, v19);

    final v20 = builder.addVertex(Vector3(x0, y1, z0));
    final v21 = builder.addVertex(Vector3(x0, y1, z1));
    final v22 = builder.addVertex(Vector3(x1, y1, z1));
    final v23 = builder.addVertex(Vector3(x1, y1, z0));
    builder
      ..addTriangle(v20, v21, v22)
      ..addTriangle(v20, v22, v23);
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

    final plinthMin = Vector3(-2.42, -1.40, -3.12);
    final plinthMax = Vector3(2.42, 0.20, 3.12);
    addBox(stoneBuilder, plinthMin, plinthMax);

    final wallHeight = isTwoStory ? 4.35 : 2.95;
    final wallMin = Vector3(-2.50, 0.20, -3.20);
    final wallMax = Vector3(2.50, wallHeight, 3.20);
    addBox(plasterBuilder, wallMin, wallMax);

    final cornerPosts = [
      (Vector3(-2.62, 0.15, 3.12), Vector3(-2.42, 0.15, 3.32)),
      (Vector3(2.42, 0.15, 3.12), Vector3(2.62, 0.15, 3.32)),
      (Vector3(-2.62, 0.15, -3.32), Vector3(-2.42, 0.15, -3.12)),
      (Vector3(2.42, 0.15, -3.32), Vector3(2.62, 0.15, -3.12)),
    ];

    for (final post in cornerPosts) {
      addBox(
        timberBuilder,
        Vector3(post.$1.x, 0.15, post.$1.z),
        Vector3(post.$2.x, wallHeight + 0.10, post.$2.z),
      );
    }

    addBox(
      timberBuilder,
      Vector3(-0.86, 0.18, 3.12),
      Vector3(-0.72, wallHeight + 0.05, 3.28),
    );
    addBox(
      timberBuilder,
      Vector3(0.72, 0.18, 3.12),
      Vector3(0.86, wallHeight + 0.05, 3.28),
    );

    addBox(
      timberBuilder,
      Vector3(-2.55, 0.22, 3.23),
      Vector3(2.55, 0.40, 3.27),
    );
    addBox(
      timberBuilder,
      Vector3(-2.55, 2.22, 3.23),
      Vector3(2.55, 2.38, 3.27),
    );

    addBox(shojiBuilder, Vector3(-0.68, 0.42, 3.21), Vector3(0.68, 2.20, 3.25));

    if (isTwoStory) {
      addBox(
        shojiBuilder,
        Vector3(-1.40, 2.85, 3.21),
        Vector3(1.40, 3.85, 3.25),
      );
      addBox(
        timberBuilder,
        Vector3(-2.70, 2.45, 3.15),
        Vector3(2.70, 2.70, 3.58),
      );
    }

    final ridgeY = isTwoStory ? 5.60 : 4.20;
    final eavesY = isTwoStory ? 4.30 : 2.90;

    void addGabledRoof() {
      const z0 = -3.65;
      const z1 = 3.65;
      const xLeft = -2.90;
      const xRight = 2.90;

      final vR0 = roofBuilder.addVertex(Vector3(0, ridgeY, z0));
      final vR1 = roofBuilder.addVertex(Vector3(0, ridgeY, z1));
      final vL0 = roofBuilder.addVertex(Vector3(xLeft, eavesY, z0));
      final vL1 = roofBuilder.addVertex(Vector3(xLeft, eavesY, z1));
      final vRt0 = roofBuilder.addVertex(Vector3(xRight, eavesY, z0));
      final vRt1 = roofBuilder.addVertex(Vector3(xRight, eavesY, z1));

      roofBuilder
        ..addTriangle(vL0, vL1, vR1)
        ..addTriangle(vL0, vR1, vR0)
        ..addTriangle(vR0, vR1, vRt1)
        ..addTriangle(vR0, vRt1, vRt0)
        ..addTriangle(vL0, vR0, vRt0)
        ..addTriangle(vL1, vRt1, vR1);

      addBox(
        timberBuilder,
        Vector3(-0.12, ridgeY - 0.02, z0 - 0.05),
        Vector3(0.12, ridgeY + 0.16, z1 + 0.05),
      );
    }

    addGabledRoof();

    if (structure.id.value.hashCode % 3 == 0) {
      addBox(
        timberBuilder,
        Vector3(1.65, 0.20, 3.35),
        Vector3(2.25, 0.85, 3.95),
      );
      addBox(
        shojiBuilder,
        Vector3(1.72, 0.28, 3.96),
        Vector3(2.18, 0.78, 3.99),
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
        Vector3(coord.$1 + 0.10, 2.45, coord.$2 + 0.10),
      );
    }

    addBox(
      timberBuilder,
      Vector3(-0.85, 0.05, -0.35),
      Vector3(0.85, 0.85, 0.45),
    );

    addBox(
      timberBuilder,
      Vector3(-0.70, 0.87, -0.25),
      Vector3(-0.10, 1.25, 0.35),
    );
    addBox(
      timberBuilder,
      Vector3(0.10, 0.87, -0.25),
      Vector3(0.70, 1.25, 0.35),
    );

    const ax0 = -1.35;
    const ax1 = 1.35;
    const az0 = -1.15;
    const az1 = 1.15;
    const ayBack = 2.65;
    const ayFront = 2.25;

    final v0 = awningBuilder.addVertex(Vector3(ax0, ayBack, az0));
    final v1 = awningBuilder.addVertex(Vector3(ax1, ayBack, az0));
    final v2 = awningBuilder.addVertex(Vector3(ax1, ayFront, az1));
    final v3 = awningBuilder.addVertex(Vector3(ax0, ayFront, az1));

    awningBuilder
      ..addTriangle(v0, v1, v2)
      ..addTriangle(v0, v2, v3);

    addBox(lanternBuilder, Vector3(1, 1.88, 0.95), Vector3(1.22, 2.18, 1.17));
    addBox(timberBuilder, Vector3(1.09, 2.18, 1.04), Vector3(1.13, 2.38, 1.08));

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
    const wBase = 1.90;
    const wTop = 1.60;

    final sb0 = stoneBuilder.addVertex(Vector3(-wBase, yBase, -wBase));
    final sb1 = stoneBuilder.addVertex(Vector3(wBase, yBase, -wBase));
    final sb2 = stoneBuilder.addVertex(Vector3(wBase, yBase, wBase));
    final sb3 = stoneBuilder.addVertex(Vector3(-wBase, yBase, wBase));

    final st0 = stoneBuilder.addVertex(Vector3(-wTop, yStoneTop, -wTop));
    final st1 = stoneBuilder.addVertex(Vector3(wTop, yStoneTop, -wTop));
    final st2 = stoneBuilder.addVertex(Vector3(wTop, yStoneTop, wTop));
    final st3 = stoneBuilder.addVertex(Vector3(-wTop, yStoneTop, wTop));

    stoneBuilder
      ..addTriangle(sb0, sb1, st1)
      ..addTriangle(sb0, st1, st0)
      ..addTriangle(sb1, sb2, st2)
      ..addTriangle(sb1, st2, st1)
      ..addTriangle(sb2, sb3, st3)
      ..addTriangle(sb2, st3, st2)
      ..addTriangle(sb3, sb0, st0)
      ..addTriangle(sb3, st0, st3)
      ..addTriangle(st0, st1, st2)
      ..addTriangle(st0, st2, st3);

    const cols = [(-1.38, -1.38), (1.22, -1.38), (-1.38, 1.22), (1.22, 1.22)];
    for (final c in cols) {
      addBox(
        timberBuilder,
        Vector3(c.$1, yStoneTop, c.$2),
        Vector3(c.$1 + 0.16, 4.60, c.$2 + 0.16),
      );
    }

    addBox(
      timberBuilder,
      Vector3(-1.80, 4.50, -1.80),
      Vector3(1.80, 4.62, 1.80),
    );

    const rPosts = [(-1.86, -1.86), (1.74, -1.86), (-1.86, 1.74), (1.74, 1.74)];
    for (final rp in rPosts) {
      addBox(
        timberBuilder,
        Vector3(rp.$1, 4.60, rp.$2),
        Vector3(rp.$1 + 0.12, 5.48, rp.$2 + 0.12),
      );
    }
    addBox(
      timberBuilder,
      Vector3(-1.84, 5.40, -1.84),
      Vector3(1.84, 5.48, 1.84),
    );

    addBox(
      timberBuilder,
      Vector3(-1.05, 4.62, -1.05),
      Vector3(1.05, 6.40, 1.05),
    );
    addBox(shojiBuilder, Vector3(-0.75, 4.90, 1.06), Vector3(0.75, 6.10, 1.09));
    addBox(
      shojiBuilder,
      Vector3(-0.75, 4.90, -1.09),
      Vector3(0.75, 6.10, -1.06),
    );

    addBox(
      timberBuilder,
      Vector3(-0.25, 5.10, -0.25),
      Vector3(0.25, 5.75, 0.25),
    );

    const rw = 2.25;
    const reY = 6.45;
    const raY = 8.80;

    final rv0 = roofBuilder.addVertex(Vector3(-rw, reY, -rw));
    final rv1 = roofBuilder.addVertex(Vector3(rw, reY, -rw));
    final rv2 = roofBuilder.addVertex(Vector3(rw, reY, rw));
    final rv3 = roofBuilder.addVertex(Vector3(-rw, reY, rw));
    final rApex = roofBuilder.addVertex(Vector3(0, raY, 0));

    roofBuilder
      ..addTriangle(rv0, rv1, rApex)
      ..addTriangle(rv1, rv2, rApex)
      ..addTriangle(rv2, rv3, rApex)
      ..addTriangle(rv3, rv0, rApex);

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
      Vector3(-0.16, -0.50, -0.16),
      Vector3(0.16, 2.20, 0.16),
    );
    addBox(
      timberBuilder,
      Vector3(-0.12, 2.10, -0.12),
      Vector3(0.35, 3.60, 0.25),
    );

    final foliageBoxes = [
      (Vector3(-1.10, 3.10, -1), Vector3(0.80, 4, 0.90)),
      (Vector3(-0.70, 3.80, -0.80), Vector3(1.10, 4.80, 0.95)),
      (Vector3(-0.90, 4.60, -0.70), Vector3(0.70, 5.75, 0.70)),
    ];

    final colorVariants = [
      Vector4(0.78, 0.22, 0.14, 1),
      Vector4(0.88, 0.38, 0.16, 1),
      Vector4(0.82, 0.52, 0.18, 1),
    ];

    for (var i = 0; i < foliageBoxes.length; i++) {
      addBox(
        foliageBuilder,
        foliageBoxes[i].$1,
        foliageBoxes[i].$2,
        color: colorVariants[i % colorVariants.length],
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
      (-0.65, -0.50),
      (0.55, -0.60),
      (-0.35, 0.60),
      (0.60, 0.45),
      (0.00, 0.00),
    ];

    for (final co in culmOffsets) {
      addBox(
        timberBuilder,
        Vector3(co.$1 - 0.05, -0.50, co.$2 - 0.05),
        Vector3(co.$1 + 0.05, 6.20, co.$2 + 0.05),
      );
    }

    final foliageBoxes = [
      (Vector3(-1.20, 4.40, -1.20), Vector3(1.20, 5.50, 1.20)),
      (Vector3(-1, 5.40, -1), Vector3(1, 6.40, 1)),
      (Vector3(-0.75, 6.30, -0.75), Vector3(0.75, 7.20, 0.75)),
    ];

    for (final fb in foliageBoxes) {
      addBox(foliageBuilder, fb.$1, fb.$2, color: Vector4(0.31, 0.58, 0.28, 1));
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

    const segs = 10;
    var prev = span.sampleCatenary(0);
    for (var i = 1; i <= segs; i++) {
      final curr = span.sampleCatenary(i / segs);
      final mid = (prev + curr) * 0.5;
      final delta = curr - prev;
      final len = delta.length;
      if (len > 1e-6) {
        addBox(
          timberBuilder,
          Vector3(mid.x - 0.02, mid.y - 0.02, mid.z - 0.02),
          Vector3(mid.x + 0.02, mid.y + 0.02, mid.z + 0.02),
        );
      }
      prev = curr;
    }

    final hangPoints = span.lanternHangPoints();
    for (final hp in hangPoints) {
      addBox(
        timberBuilder,
        Vector3(hp.x - 0.015, hp.y - 0.16, hp.z - 0.015),
        Vector3(hp.x + 0.015, hp.y, hp.z + 0.015),
      );
      addBox(
        lanternBuilder,
        Vector3(hp.x - 0.12, hp.y - 0.48, hp.z - 0.12),
        Vector3(hp.x + 0.12, hp.y - 0.16, hp.z + 0.12),
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
}
