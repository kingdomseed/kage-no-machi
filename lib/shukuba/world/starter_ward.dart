import 'dart:math' as math;

import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        CourtyardWall,
        EntityId,
        GroundHeightSampler,
        PlacedStructure,
        RoadSpline,
        RoadStyle,
        ShukubaGraph,
        StructureKind,
        TerraceCourse,
        Vec3;

ShukubaGraph buildStarterShukubaGraph(GroundHeightSampler sampleGroundY) {
  final terraces = <TerraceCourse>[
    TerraceCourse.alignedToTerrain(
      id: EntityId.validated('terrace_lower_east'),
      crestPoints: [
        Vec3(8, sampleGroundY(8, -23), -23),
        Vec3(5.9, sampleGroundY(5.9, -14), -14),
        Vec3(6.4, sampleGroundY(6.4, 14), 14),
        Vec3(8.8, sampleGroundY(8.8, 23), 23),
      ],
      topElevation: 1.80,
      depthMeters: 9.8,
      sampleGroundY: sampleGroundY,
    ),
    TerraceCourse.alignedToTerrain(
      id: EntityId.validated('terrace_upper_east'),
      crestPoints: [
        Vec3(17.6, sampleGroundY(17.6, -19), -19),
        Vec3(15.2, sampleGroundY(15.2, -12), -12),
        Vec3(15.4, sampleGroundY(15.4, 12.5), 12.5),
        Vec3(17.8, sampleGroundY(17.8, 19), 19),
      ],
      topElevation: 3.40,
      depthMeters: 11.6,
      sampleGroundY: sampleGroundY,
    ),
  ];

  double wardY(double x, double z) {
    var y = sampleGroundY(x, z);
    for (final terrace in terraces) {
      y = terrace.sampleGradedElevation(x, z, y);
    }
    return y;
  }

  final roads = <RoadSpline>[
    RoadSpline.validated(
      id: EntityId.validated('road_kaido_west'),
      controlPoints: [
        Vec3(-87.5, wardY(-87.5, 0.16), 0.16),
        Vec3(-76, wardY(-76, 0.12), 0.12),
        Vec3(-66, wardY(-66, 0), 0),
        Vec3(-51, wardY(-51, -0.45), -0.45),
        Vec3(-38, wardY(-38, 0.35), 0.35),
        Vec3(-28, wardY(-28, -0.55), -0.55),
        Vec3(-19.5, wardY(-19.5, 0.30), 0.30),
        Vec3(-11.5, wardY(-11.5, -0.22), -0.22),
        Vec3(-5.2, wardY(-5.2, 0), 0),
      ],
      isBridgeApproach: true,
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_kaido_east'),
      controlPoints: [
        Vec3(5.2, wardY(5.2, 0), 0),
        Vec3(9, wardY(9, 0.20), 0.20),
        Vec3(12.6, wardY(12.6, -0.12), -0.12),
        Vec3(15.3, wardY(15.3, -0.15), -0.15),
        Vec3(20.6, wardY(20.6, 0.35), 0.35),
        Vec3(27.5, wardY(27.5, -0.30), -0.30),
        Vec3(39.5, wardY(39.5, 0.28), 0.28),
        Vec3(53, wardY(53, -0.22), -0.22),
        Vec3(66, wardY(66, 0), 0),
        Vec3(76, wardY(76, 0.14), 0.14),
        Vec3(87.5, wardY(87.5, 0.18), 0.18),
      ],
      isBridgeApproach: true,
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_market_alley'),
      widthMeters: 2.6,
      controlPoints: [
        Vec3(9, wardY(9, 1.8), 1.8),
        Vec3(9.35, wardY(9.35, 8.6), 8.6),
        Vec3(8.8, wardY(8.8, 15.2), 15.2),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_west_riverside'),
      widthMeters: 2.4,
      controlPoints: [
        Vec3(-7.8, wardY(-7.8, -1.8), -1.8),
        Vec3(-8.2, wardY(-8.2, -7.8), -7.8),
        Vec3(-9.4, wardY(-9.4, -13.6), -13.6),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_teahouse_roji'),
      style: RoadStyle.gardenPath,
      widthMeters: 1.75,
      controlPoints: [
        Vec3(-15.6, wardY(-15.6, 2.4), 2.4),
        Vec3(-16.2, wardY(-16.2, 8.2), 8.2),
        Vec3(-14.6, wardY(-14.6, 14.4), 14.4),
        Vec3(-13.2, wardY(-13.2, 19.6), 19.6),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_kura_roji'),
      style: RoadStyle.gardenPath,
      widthMeters: 1.70,
      controlPoints: [
        Vec3(18.2, wardY(18.2, -1.8), -1.8),
        Vec3(18.5, wardY(18.5, -3.9), -3.9),
        Vec3(19.8, wardY(19.8, -5.8), -5.8),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_south_terrace_roji'),
      style: RoadStyle.gardenPath,
      widthMeters: 1.85,
      controlPoints: [
        Vec3(2.9, wardY(2.9, -20.8), -20.8),
        Vec3(3.2, wardY(3.2, -16.8), -16.8),
        Vec3(5.4, wardY(5.4, -15.3), -15.3),
        Vec3(11.4, wardY(11.4, -15.2), -15.2),
        Vec3(18.6, wardY(18.6, -15.3), -15.3),
        Vec3(20.4, wardY(20.4, -13.2), -13.2),
      ],
    ),
  ];

  final walls = <CourtyardWall>[
    CourtyardWall.validated(
      id: EntityId.validated('wall_kura_compound'),
      controlPoints: [
        Vec3(16.8, wardY(16.8, -4.8), -4.8),
        Vec3(16.8, wardY(16.8, -13.5), -13.5),
        Vec3(24.8, wardY(24.8, -13.5), -13.5),
      ],
    ),
    CourtyardWall.validated(
      id: EntityId.validated('wall_teahouse_garden'),
      controlPoints: [
        Vec3(-15, wardY(-15, 9.4), 9.4),
        Vec3(-7.4, wardY(-7.4, 9.4), 9.4),
        Vec3(-7.4, wardY(-7.4, 5.4), 5.4),
      ],
    ),
  ];

  final structures = <PlacedStructure>[
    PlacedStructure(
      id: EntityId.validated('torii_west_gate'),
      kind: StructureKind.toriiGate,
      position: Vec3(-23.6, wardY(-23.6, -0.10), -0.10),
      yawRadians: math.pi / 2 + 0.08,
    ),
    PlacedStructure(
      id: EntityId.validated('chaya_west_bridgehead'),
      kind: StructureKind.chaya,
      position: Vec3(-11.4, wardY(-11.4, 5.55), 5.55),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_west_s1'),
      kind: StructureKind.machiya,
      position: Vec3(-11.6, wardY(-11.6, -5.75), -5.75),
      yawRadians: -0.04,
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_west_n2'),
      kind: StructureKind.machiya,
      position: Vec3(-18.6, wardY(-18.6, 5.85), 5.85),
      yawRadians: math.pi + 0.05,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_west_s2'),
      kind: StructureKind.machiya,
      position: Vec3(-18.6, wardY(-18.6, -5.65), -5.65),
      yawRadians: 0.05,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('stall_west_riverside'),
      kind: StructureKind.marketStall,
      position: Vec3(-5.75, wardY(-5.75, -3.85), -3.85),
      yawRadians: -0.28,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('market_east_s1'),
      kind: StructureKind.marketStall,
      position: Vec3(7.6, wardY(7.6, -2.55), -2.55),
    ),
    PlacedStructure(
      id: EntityId.validated('market_east_n1'),
      kind: StructureKind.marketStall,
      position: Vec3(7.8, wardY(7.8, 3.35), 3.35),
      yawRadians: math.pi,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_east_s1'),
      kind: StructureKind.machiya,
      position: Vec3(12.25, wardY(12.25, -6.25), -6.25),
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('chaya_east_alley'),
      kind: StructureKind.chaya,
      position: Vec3(12.8, wardY(12.8, 8.2), 8.2),
      yawRadians: -math.pi / 2,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('market_east_alley'),
      kind: StructureKind.marketStall,
      position: Vec3(7.1, wardY(7.1, 8.2), 8.2),
      yawRadians: math.pi / 2,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('kura_upper_east'),
      kind: StructureKind.kura,
      position: Vec3(20.6, wardY(20.6, -9.8), -9.8),
    ),
    PlacedStructure(
      id: EntityId.validated('machiya_upper_n1'),
      kind: StructureKind.machiya,
      position: Vec3(19.8, wardY(19.8, 5.85), 5.85),
      yawRadians: math.pi,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('rock_west_bluff'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(-4.8, wardY(-4.8, 13.4), 13.4),
      yawRadians: 0.55,
    ),
    PlacedStructure(
      id: EntityId.validated('rock_west_riverside_crag'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(-12.6, wardY(-12.6, -15.4), -15.4),
      yawRadians: -0.85,
    ),
    PlacedStructure(
      id: EntityId.validated('rock_east_bastion_toe'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(11.6, wardY(11.6, -19.2), -19.2),
      yawRadians: 1.35,
    ),
    PlacedStructure(
      id: EntityId.validated('rock_upper_garden_crag'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(23, wardY(23, 9.8), 9.8),
      yawRadians: -1.65,
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
      position: Vec3(4.7, wardY(4.7, -5.4), -5.4),
      yawRadians: -0.65,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_alley_ne'),
      kind: StructureKind.mapleCluster,
      position: Vec3(12.6, wardY(12.6, 14.2), 14.2),
      yawRadians: 1.15,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_upper_ne'),
      kind: StructureKind.mapleCluster,
      position: Vec3(17.6, wardY(17.6, 11.8), 11.8),
      yawRadians: -1.10,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_west_courtyard'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-15.4, wardY(-15.4, -11.8), -11.8),
      yawRadians: 1.45,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_teahouse_garden'),
      kind: StructureKind.pineTree,
      position: Vec3(-11.4, wardY(-11.4, 14.2), 14.2),
      yawRadians: -0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_west_torii'),
      kind: StructureKind.pineTree,
      position: Vec3(-24.8, wardY(-24.8, -5.4), -5.4),
      yawRadians: 0.85,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_kura_ridge'),
      kind: StructureKind.pineTree,
      position: Vec3(24.8, wardY(24.8, -16.4), -16.4),
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
      position: Vec3(4.5, wardY(4.5, -11.4), -11.4),
      yawRadians: -2.45,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_west_garden'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-17.6, wardY(-17.6, 22.4), 22.4),
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
      position: Vec3(11.6, wardY(11.6, -12.4), -12.4),
      yawRadians: 0.80,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_upper_se'),
      kind: StructureKind.bambooGrove,
      position: Vec3(26.2, wardY(26.2, -8.6), -8.6),
      yawRadians: -0.55,
    ),
    PlacedStructure(
      id: EntityId.validated('shoro_temple_bell'),
      kind: StructureKind.shoroBell,
      position: Vec3(23.5, wardY(23.5, 14.5), 14.5),
      yawRadians: -math.pi / 2,
    ),
    PlacedStructure(
      id: EntityId.validated('karesansui_market_court'),
      kind: StructureKind.karesansuiGarden,
      position: Vec3(13.5, wardY(13.5, 19.5), 19.5),
    ),
    PlacedStructure(
      id: EntityId.validated('well_east_riverside'),
      kind: StructureKind.stoneWell,
      position: Vec3(6, wardY(6, 20), 20),
      yawRadians: -0.2,
    ),
    PlacedStructure(
      id: EntityId.validated('minka_west_riverside'),
      kind: StructureKind.minka,
      position: Vec3(-19.4, wardY(-19.4, -13.2), -13.2),
      yawRadians: 0.42,
    ),
    PlacedStructure(
      id: EntityId.validated('minka_east_terrace_s'),
      kind: StructureKind.minka,
      position: Vec3(22.4, wardY(22.4, -18.8), -18.8),
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minka_west_kaido_farm'),
      kind: StructureKind.minka,
      position: Vec3(-42.5, wardY(-42.5, -5.8), -5.8),
      yawRadians: 0.08,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minka_east_kaido_farm'),
      kind: StructureKind.minka,
      position: Vec3(34.5, wardY(34.5, -6.2), -6.2),
      yawRadians: -0.06,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('minka_west_north_homestead'),
      kind: StructureKind.minka,
      position: Vec3(-33.5, wardY(-33.5, 19.5), 19.5),
      yawRadians: -0.45,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('kura_west_granary'),
      kind: StructureKind.kura,
      position: Vec3(-38.8, wardY(-38.8, 22.8), 22.8),
      yawRadians: 0.25,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('chaya_east_pass_rest'),
      kind: StructureKind.chaya,
      position: Vec3(48.5, wardY(48.5, 6.2), 6.2),
      yawRadians: math.pi,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_west_kaido'),
      kind: StructureKind.pineTree,
      position: Vec3(-47.8, wardY(-47.8, -7.4), -7.4),
      yawRadians: 0.65,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_west_mitsuke'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-59.5, wardY(-59.5, 6.4), 6.4),
      yawRadians: -0.75,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_west_kaido'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-35.2, wardY(-35.2, 7.6), 7.6),
      yawRadians: 0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_east_tanada'),
      kind: StructureKind.bambooGrove,
      position: Vec3(37.2, wardY(37.2, 11.4), 11.4),
      yawRadians: -0.40,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_east_mitsuke'),
      kind: StructureKind.pineTree,
      position: Vec3(59.2, wardY(59.2, -6.4), -6.4),
      yawRadians: 1.10,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_nw_bluff'),
      kind: StructureKind.pineTree,
      position: Vec3(-44, wardY(-44, 32), 32),
      yawRadians: 0.50,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_nw_copse'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-54, wardY(-54, -26), -26),
      yawRadians: -0.80,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_sw_meadow'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-31, wardY(-31, -28.5), -28.5),
      yawRadians: 0.95,
    ),
    PlacedStructure(
      id: EntityId.validated('willow_north_bend'),
      kind: StructureKind.weepingWillow,
      position: Vec3(-5.8, wardY(-5.8, 36.5), 36.5),
      yawRadians: 0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('willow_south_bend'),
      kind: StructureKind.weepingWillow,
      position: Vec3(5.6, wardY(5.6, -34.5), -34.5),
      yawRadians: -2.20,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_tanada_north_rim'),
      kind: StructureKind.pineTree,
      position: Vec3(35.8, wardY(35.8, 34), 34),
      yawRadians: -0.60,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_tanada_south_rim'),
      kind: StructureKind.mapleCluster,
      position: Vec3(35.2, wardY(35.2, -31), -31),
      yawRadians: 1.25,
    ),
    PlacedStructure(
      id: EntityId.validated('rock_west_plain_outcrop'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(-49.5, wardY(-49.5, 16.5), 16.5),
      yawRadians: 0.75,
    ),
    PlacedStructure(
      id: EntityId.validated('rock_east_tanada_shoulder'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(36.2, wardY(36.2, -13.5), -13.5),
      yawRadians: -1.15,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_nw_pasture'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-28.4, wardY(-28.4, 26.8), 26.8),
      yawRadians: 0.62,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_nw_ridge'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-46.2, wardY(-46.2, 41.5), 41.5),
      yawRadians: -0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_nw_meadow_edge'),
      kind: StructureKind.pineTree,
      position: Vec3(-31.8, wardY(-31.8, 36.2), 36.2),
      yawRadians: 1.05,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_sw_flank'),
      kind: StructureKind.pineTree,
      position: Vec3(-27.6, wardY(-27.6, -16.4), -16.4),
      yawRadians: 0.42,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_west_meadow'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-34.6, wardY(-34.6, -9.8), -9.8),
      yawRadians: -0.68,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_nw_glade'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-25.8, wardY(-25.8, 17.8), 17.8),
      yawRadians: 1.18,
    ),
    PlacedStructure(
      id: EntityId.validated('rock_west_glade'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(-35.4, wardY(-35.4, 11.6), 11.6),
      yawRadians: -0.52,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_se_flank'),
      kind: StructureKind.mapleCluster,
      position: Vec3(30.8, wardY(30.8, -19.6), -19.6),
      yawRadians: -0.84,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_east_pasture'),
      kind: StructureKind.bambooGrove,
      position: Vec3(39.2, wardY(39.2, -10.8), -10.8),
      yawRadians: 0.56,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_east_pasture'),
      kind: StructureKind.pineTree,
      position: Vec3(45.6, wardY(45.6, 10.6), 10.6),
      yawRadians: -1.12,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_sw_valley_rim'),
      kind: StructureKind.pineTree,
      position: Vec3(-14.5, wardY(-14.5, -22.5), -22.5),
      yawRadians: 0.45,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_sw_hollow'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-25.6, wardY(-25.6, -23.8), -23.8),
      yawRadians: -0.60,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_se_terrace_skirt'),
      kind: StructureKind.pineTree,
      position: Vec3(15.8, wardY(15.8, -25.2), -25.2),
      yawRadians: -0.92,
    ),
    PlacedStructure(
      id: EntityId.validated('bamboo_se_meadow'),
      kind: StructureKind.bambooGrove,
      position: Vec3(28.6, wardY(28.6, -26.4), -26.4),
      yawRadians: 0.72,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_ne_pasture'),
      kind: StructureKind.pineTree,
      position: Vec3(31.2, wardY(31.2, 22.8), 22.8),
      yawRadians: 1.15,
    ),
    PlacedStructure(
      id: EntityId.validated('maple_ne_temple_slope'),
      kind: StructureKind.mapleCluster,
      position: Vec3(20.4, wardY(20.4, 24.8), 24.8),
      yawRadians: -0.55,
    ),
    PlacedStructure(
      id: EntityId.validated('pine_nw_river_meadow'),
      kind: StructureKind.pineTree,
      position: Vec3(-11.8, wardY(-11.8, 27.6), 27.6),
      yawRadians: -0.38,
    ),
    PlacedStructure(
      id: EntityId.validated('rock_sw_pasture_ledge'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(-21.2, wardY(-21.2, -19.8), -19.8),
      yawRadians: 0.88,
    ),
  ];

  return ShukubaGraph(
    roads: roads,
    terraces: terraces,
    walls: walls,
    structures: structures,
  );
}
