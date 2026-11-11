import 'dart:math' as math;

import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        CourtyardWall,
        EntityId,
        GroundHeightSampler,
        PlacedStructure,
        RoadSpline,
        ShukubaGraph,
        StructureKind,
        TerraceCourse,
        Vec3;

ShukubaGraph buildStarterShukubaGraph(GroundHeightSampler sampleGroundY) {
  final terraces = <TerraceCourse>[
    TerraceCourse.alignedToTerrain(
      id: EntityId.validated('terrace_lower_east'),
      crestPoints: [
        Vec3(6, sampleGroundY(6, -24), -24),
        Vec3(6, sampleGroundY(6, 24), 24),
      ],
      topElevation: 1.80,
      depthMeters: 9.2,
      sampleGroundY: sampleGroundY,
    ),
    TerraceCourse.alignedToTerrain(
      id: EntityId.validated('terrace_upper_east'),
      crestPoints: [
        Vec3(15.2, sampleGroundY(15.2, -20), -20),
        Vec3(15.2, sampleGroundY(15.2, 20), 20),
      ],
      topElevation: 3.40,
      depthMeters: 11,
      sampleGroundY: sampleGroundY,
    ),
  ];

  double wardY(double x, double z) {
    var y = sampleGroundY(x, z);
    final probe = Vec3(x, y, z);
    for (final terrace in terraces) {
      final platY = terrace.samplePlatformElevation(probe);
      if (platY != null && platY > y) {
        y = platY;
      }
    }
    return y;
  }

  final roads = <RoadSpline>[
    RoadSpline.validated(
      id: EntityId.validated('road_kaido_west'),
      controlPoints: [
        Vec3(-28, wardY(-28, 0), 0),
        Vec3(-16, wardY(-16, 0), 0),
        Vec3(-5.2, wardY(-5.2, 0), 0),
      ],
      isBridgeApproach: true,
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_kaido_east'),
      controlPoints: [
        Vec3(5.2, wardY(5.2, 0), 0),
        Vec3(16, wardY(16, 0), 0),
        Vec3(28, wardY(28, 0), 0),
      ],
      isBridgeApproach: true,
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_market_alley'),
      widthMeters: 2.6,
      controlPoints: [
        Vec3(9, wardY(9, 1.8), 1.8),
        Vec3(9, wardY(9, 9), 9),
        Vec3(9, wardY(9, 15.2), 15.2),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_west_riverside'),
      widthMeters: 2.4,
      controlPoints: [
        Vec3(-7.8, wardY(-7.8, -1.8), -1.8),
        Vec3(-8.4, wardY(-8.4, -7.8), -7.8),
        Vec3(-9, wardY(-9, -13.6), -13.6),
      ],
    ),
  ];

  final walls = <CourtyardWall>[
    CourtyardWall.validated(
      id: EntityId.validated('wall_kura_compound'),
      controlPoints: [
        Vec3(16.6, wardY(16.6, -4.6), -4.6),
        Vec3(16.6, wardY(16.6, -13.8), -13.8),
        Vec3(24.2, wardY(24.2, -13.8), -13.8),
      ],
    ),
    CourtyardWall.validated(
      id: EntityId.validated('wall_teahouse_garden'),
      controlPoints: [
        Vec3(-15, wardY(-15, 9.2), 9.2),
        Vec3(-7.4, wardY(-7.4, 9.2), 9.2),
        Vec3(-7.4, wardY(-7.4, 5.4), 5.4),
      ],
    ),
  ];

  final structures = <PlacedStructure>[
    PlacedStructure(
      id: EntityId.validated('torii_west_gate'),
      kind: StructureKind.toriiGate,
      position: Vec3(-23.4, wardY(-23.4, 0), 0),
      yawRadians: math.pi / 2,
    ),
    PlacedStructure(
      id: EntityId.validated('chaya_west_bridgehead'),
      kind: StructureKind.chaya,
      position: Vec3(-11.4, wardY(-11.4, 5.45), 5.45),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_west_s1'),
      kind: StructureKind.machiya,
      position: Vec3(-11.6, wardY(-11.6, -5.65), -5.65),
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_west_n2'),
      kind: StructureKind.machiya,
      position: Vec3(-18.4, wardY(-18.4, 5.65), 5.65),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_west_s2'),
      kind: StructureKind.machiya,
      position: Vec3(-18.4, wardY(-18.4, -5.65), -5.65),
    ),
    PlacedStructure(
      id: EntityId.validated('stall_west_riverside'),
      kind: StructureKind.marketStall,
      position: Vec3(-6.2, wardY(-6.2, -3.5), -3.5),
      yawRadians: -0.45,
    ),
    PlacedStructure(
      id: EntityId.validated('market_east_s1'),
      kind: StructureKind.marketStall,
      position: Vec3(7.4, wardY(7.4, -2.55), -2.55),
    ),
    PlacedStructure(
      id: EntityId.validated('market_east_n1'),
      kind: StructureKind.marketStall,
      position: Vec3(7.4, wardY(7.4, 2.55), 2.55),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_east_s1'),
      kind: StructureKind.machiya,
      position: Vec3(11.6, wardY(11.6, -5.65), -5.65),
    ),
    PlacedStructure(
      id: EntityId.validated('chaya_east_alley'),
      kind: StructureKind.chaya,
      position: Vec3(12.6, wardY(12.6, 8.2), 8.2),
      yawRadians: -math.pi / 2,
    ),
    PlacedStructure(
      id: EntityId.validated('market_east_alley'),
      kind: StructureKind.marketStall,
      position: Vec3(6.9, wardY(6.9, 8.2), 8.2),
      yawRadians: math.pi / 2,
    ),
    PlacedStructure(
      id: EntityId.validated('kura_upper_east'),
      kind: StructureKind.kura,
      position: Vec3(20.4, wardY(20.4, -9.2), -9.2),
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_upper_n1'),
      kind: StructureKind.machiya,
      position: Vec3(19.6, wardY(19.6, 5.65), 5.65),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_bridge_nw'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-5.2, wardY(-5.2, 4.4), 4.4),
      yawRadians: 0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_gorge_se'),
      kind: StructureKind.mapleCluster,
      position: Vec3(4.8, wardY(4.8, -5.2), -5.2),
      yawRadians: -0.65,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_alley_ne'),
      kind: StructureKind.mapleCluster,
      position: Vec3(12.8, wardY(12.8, 14), 14),
      yawRadians: 1.15,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_upper_ne'),
      kind: StructureKind.mapleCluster,
      position: Vec3(17.2, wardY(17.2, 11.4), 11.4),
      yawRadians: -1.10,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_west_courtyard'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-14.6, wardY(-14.6, -11.6), -11.6),
      yawRadians: 1.45,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_teahouse_garden'),
      kind: StructureKind.pineTree,
      position: Vec3(-8.8, wardY(-8.8, 14.2), 14.2),
      yawRadians: -0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_west_torii'),
      kind: StructureKind.pineTree,
      position: Vec3(-24.8, wardY(-24.8, -5.2), -5.2),
      yawRadians: 0.85,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_kura_ridge'),
      kind: StructureKind.pineTree,
      position: Vec3(24.4, wardY(24.4, -15.8), -15.8),
      yawRadians: -1.25,
    ),
    PlacedStructure(
      id: EntityId.validated('willow_west_bank'),
      kind: StructureKind.weepingWillow,
      position: Vec3(-5.3, wardY(-5.3, 8.6), 8.6),
      yawRadians: 0.40,
    ),
    PlacedStructure(
      id: EntityId.validated('willow_east_foreshore'),
      kind: StructureKind.weepingWillow,
      position: Vec3(4.6, wardY(4.6, -11.2), -11.2),
      yawRadians: -2.45,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_west_garden'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-18.2, wardY(-18.2, 22.8), 22.8),
      yawRadians: 0.25,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_west_gorge'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-5.6, wardY(-5.6, -9.4), -9.4),
      yawRadians: -0.45,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_lower_se'),
      kind: StructureKind.bambooGrove,
      position: Vec3(11.4, wardY(11.4, -12.4), -12.4),
      yawRadians: 0.80,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_upper_se'),
      kind: StructureKind.bambooGrove,
      position: Vec3(24.6, wardY(24.6, -8.8), -8.8),
      yawRadians: -0.55,
    ),
  ];

  return ShukubaGraph(
    roads: roads,
    terraces: terraces,
    walls: walls,
    structures: structures,
  );
}
