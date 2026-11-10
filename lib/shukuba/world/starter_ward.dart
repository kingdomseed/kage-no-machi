import 'dart:math' as math;

import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        EntityId,
        GroundHeightSampler,
        PlacedStructure,
        RoadSpline,
        ShukubaGraph,
        StructureKind,
        TerraceCourse,
        Vec3;

ShukubaGraph buildStarterShukubaGraph(GroundHeightSampler sampleGroundY) {
  final roads = <RoadSpline>[
    RoadSpline.validated(
      id: EntityId.validated('road_kaido_west'),
      controlPoints: [
        Vec3(-28, sampleGroundY(-28, 0), 0),
        Vec3(-16, sampleGroundY(-16, 0), 0),
        Vec3(-5.2, sampleGroundY(-5.2, 0), 0),
      ],
      isBridgeApproach: true,
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_kaido_east'),
      controlPoints: [
        Vec3(5.2, sampleGroundY(5.2, 0), 0),
        Vec3(16, sampleGroundY(16, 0), 0),
        Vec3(28, sampleGroundY(28, 0), 0),
      ],
      isBridgeApproach: true,
    ),
  ];

  final terraces = <TerraceCourse>[
    TerraceCourse.validated(
      id: EntityId.validated('terrace_lower_east'),
      crestPoints: [
        Vec3(4.8, sampleGroundY(4.8, -24), -24),
        Vec3(4.8, sampleGroundY(4.8, 24), 24),
      ],
      topElevation: 1.80,
      depthMeters: 8.50,
    ),
    TerraceCourse.validated(
      id: EntityId.validated('terrace_upper_east'),
      crestPoints: [
        Vec3(13.5, sampleGroundY(13.5, -20), -20),
        Vec3(13.5, sampleGroundY(13.5, 20), 20),
      ],
      topElevation: 3.40,
      depthMeters: 10,
    ),
  ];

  final structures = <PlacedStructure>[
    PlacedStructure(
      id: EntityId.validated('machiya_west_s1'),
      kind: StructureKind.machiya,
      position: Vec3(-11, sampleGroundY(-11, -4.8), -4.8),
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_west_n1'),
      kind: StructureKind.machiya,
      position: Vec3(-11, sampleGroundY(-11, 4.8), 4.8),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_west_s2'),
      kind: StructureKind.machiya,
      position: Vec3(-17, sampleGroundY(-17, -4.8), -4.8),
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_west_n2'),
      kind: StructureKind.machiya,
      position: Vec3(-17, sampleGroundY(-17, 4.8), 4.8),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_east_s1'),
      kind: StructureKind.machiya,
      position: Vec3(10.5, sampleGroundY(10.5, -4.8), -4.8),
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_east_n1'),
      kind: StructureKind.machiya,
      position: Vec3(10.5, sampleGroundY(10.5, 4.8), 4.8),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_east_s2'),
      kind: StructureKind.machiya,
      position: Vec3(16.5, sampleGroundY(16.5, -4.8), -4.8),
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_east_n2'),
      kind: StructureKind.machiya,
      position: Vec3(16.5, sampleGroundY(16.5, 4.8), 4.8),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('market_s1'),
      kind: StructureKind.marketStall,
      position: Vec3(6.2, sampleGroundY(6.2, -2.6), -2.6),
    ),
    PlacedStructure(
      id: EntityId.validated('market_n1'),
      kind: StructureKind.marketStall,
      position: Vec3(6.2, sampleGroundY(6.2, 2.6), 2.6),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('tower_west'),
      kind: StructureKind.yaguraTower,
      position: Vec3(-7.5, sampleGroundY(-7.5, 5), 5),
      yawRadians: -2.35,
    ),
    PlacedStructure(
      id: EntityId.validated('tower_east'),
      kind: StructureKind.yaguraTower,
      position: Vec3(14.5, sampleGroundY(14.5, -5.5), -5.5),
      yawRadians: 0.85,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_1'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-4.5, sampleGroundY(-4.5, 4), 4),
      yawRadians: 0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_2'),
      kind: StructureKind.mapleCluster,
      position: Vec3(4.5, sampleGroundY(4.5, -4), -4),
      yawRadians: -0.65,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_3'),
      kind: StructureKind.mapleCluster,
      position: Vec3(12, sampleGroundY(12, 7.5), 7.5),
      yawRadians: 1.10,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_1'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-12, sampleGroundY(-12, 10), 10),
      yawRadians: 0.20,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_2'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-6.5, sampleGroundY(-6.5, -8), -8),
      yawRadians: -0.45,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_3'),
      kind: StructureKind.bambooGrove,
      position: Vec3(16, sampleGroundY(16, -9), -9),
      yawRadians: 0.75,
    ),
  ];

  return ShukubaGraph(roads: roads, terraces: terraces, structures: structures);
}
