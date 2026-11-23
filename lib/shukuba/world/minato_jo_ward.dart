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
        StreetAgentRole,
        StructureKind,
        TerraceCourse,
        Vec3;

typedef MinatoHeroPlacement = ({
  String name,
  String assetPath,
  double x,
  double z,
  double yaw,
  double y,
});

ShukubaGraph buildMinatoJoGraph(GroundHeightSampler sampleGroundY) {
  final terraces = <TerraceCourse>[
    TerraceCourse.alignedToTerrain(
      id: EntityId.validated('minato_terrace_south_town'),
      crestPoints: [
        Vec3(-21, sampleGroundY(-21, 13.8), 13.8),
        Vec3(-20.4, sampleGroundY(-20.4, 21.5), 21.5),
        Vec3(-19.8, sampleGroundY(-19.8, 29), 29),
      ],
      topElevation: 2.35,
      depthMeters: 9,
      sampleGroundY: sampleGroundY,
    ),
    TerraceCourse.alignedToTerrain(
      id: EntityId.validated('minato_terrace_shrine_bluff'),
      crestPoints: [
        Vec3(-23, sampleGroundY(-23, -18), -18),
        Vec3(-22.2, sampleGroundY(-22.2, -9), -9),
        Vec3(-21.5, sampleGroundY(-21.5, 1.5), 1.5),
      ],
      topElevation: 3.15,
      depthMeters: 9.5,
      sampleGroundY: sampleGroundY,
    ),
  ];

  double minatoY(double x, double z) {
    var y = sampleGroundY(x, z);
    for (final terrace in terraces) {
      y = terrace.sampleGradedElevation(x, z, y);
    }
    return y;
  }

  final roads = <RoadSpline>[
    RoadSpline.validated(
      id: EntityId.validated('road_minato_boulevard'),
      widthMeters: 3.4,
      controlPoints: [
        Vec3(-44, minatoY(-44, 14), 14),
        Vec3(-28, minatoY(-28, 10), 10),
        Vec3(-16, minatoY(-16, 7.2), 7.2),
        Vec3(-6, minatoY(-6, 5.8), 5.8),
        Vec3(3, minatoY(3, 5.5), 5.5),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_minato_quay'),
      widthMeters: 2.8,
      controlPoints: [
        Vec3(1.9, minatoY(1.9, -8.5), -8.5),
        Vec3(1.9, minatoY(1.9, 5.5), 5.5),
        Vec3(1.9, minatoY(1.9, 18), 18),
        Vec3(1.9, minatoY(1.9, 29.5), 29.5),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_castle_approach'),
      widthMeters: 2.8,
      controlPoints: [
        Vec3(-10, minatoY(-10, 6.2), 6.2),
        Vec3(-11.5, minatoY(-11.5, -3), -3),
        Vec3(-10.5, minatoY(-10.5, -12.5), -12.5),
        Vec3(-8.5, minatoY(-8.5, -19.5), -19.5),
        Vec3(-5.8, minatoY(-5.8, -21), -21),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_south_port_alley'),
      widthMeters: 2.6,
      controlPoints: [
        Vec3(-24, minatoY(-24, 20), 20),
        Vec3(-12, minatoY(-12, 19.5), 19.5),
        Vec3(1.9, minatoY(1.9, 18), 18),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_shrine_bluff_roji'),
      style: RoadStyle.gardenPath,
      widthMeters: 1.75,
      controlPoints: [
        Vec3(-11.5, minatoY(-11.5, -3), -3),
        Vec3(-19, minatoY(-19, -4.5), -4.5),
        Vec3(-26.5, minatoY(-26.5, -6.5), -6.5),
        Vec3(-27.2, minatoY(-27.2, -13.5), -13.5),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_warehouse_yard_roji'),
      style: RoadStyle.gardenPath,
      widthMeters: 1.7,
      controlPoints: [
        Vec3(-5, minatoY(-5, 18.8), 18.8),
        Vec3(-5.5, minatoY(-5.5, 25.5), 25.5),
        Vec3(1.9, minatoY(1.9, 26.5), 26.5),
      ],
    ),
  ];

  final walls = <CourtyardWall>[
    CourtyardWall.validated(
      id: EntityId.validated('minato_wall_kura_yard'),
      controlPoints: [
        Vec3(-14.2, minatoY(-14.2, 28.5), 28.5),
        Vec3(-2.5, minatoY(-2.5, 28.5), 28.5),
        Vec3(-2.5, minatoY(-2.5, 31.8), 31.8),
      ],
    ),
    CourtyardWall.validated(
      id: EntityId.validated('minato_wall_shrine_garden'),
      controlPoints: [
        Vec3(-30.7, minatoY(-30.7, -2.5), -2.5),
        Vec3(-30.7, minatoY(-30.7, -16.8), -16.8),
        Vec3(-24, minatoY(-24, -16.8), -16.8),
      ],
    ),
  ];

  final structures = <PlacedStructure>[
    // Harbor Torii gateway framing the Sunset Boulevard descent to Main Pier 2
    PlacedStructure(
      id: EntityId.validated('torii_harbor_quay'),
      kind: StructureKind.toriiGate,
      position: Vec3(0.6, minatoY(0.6, 5.5), 5.5),
      yawRadians: math.pi / 2,
    ),

    // Descending Sunset Boulevard — North Machiya Row facing south
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_w3'),
      kind: StructureKind.machiya,
      position: Vec3(-41.5, minatoY(-41.5, 9.2), 9.2),
      yawRadians: 0.18,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_w2'),
      kind: StructureKind.machiya,
      position: Vec3(-34.8, minatoY(-34.8, 7.2), 7.2),
      yawRadians: 0.16,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_n1'),
      kind: StructureKind.machiya,
      position: Vec3(-28, minatoY(-28, 5), 5),
      yawRadians: 0.18,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_n2'),
      kind: StructureKind.machiya,
      position: Vec3(-22, minatoY(-22, 3.6), 3.6),
      yawRadians: 0.20,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_n3'),
      kind: StructureKind.machiya,
      position: Vec3(-16, minatoY(-16, 2.2), 2.2),
      yawRadians: 0.16,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_n4'),
      kind: StructureKind.machiya,
      position: Vec3(-4.8, minatoY(-4.8, 1.1), 1.1),
      yawRadians: 0.10,
      variant: 2,
    ),

    // Descending Sunset Boulevard — South Machiya Row facing north
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_w4'),
      kind: StructureKind.machiya,
      position: Vec3(-35.6, minatoY(-35.6, 16.8), 16.8),
      yawRadians: math.pi + 0.16,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_s1'),
      kind: StructureKind.machiya,
      position: Vec3(-29, minatoY(-29, 14.8), 14.8),
      yawRadians: math.pi + 0.18,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_s2'),
      kind: StructureKind.machiya,
      position: Vec3(-23.2, minatoY(-23.2, 13.4), 13.4),
      yawRadians: math.pi + 0.20,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_s3'),
      kind: StructureKind.machiya,
      position: Vec3(-17.4, minatoY(-17.4, 12.1), 12.1),
      yawRadians: math.pi + 0.16,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_s4'),
      kind: StructureKind.machiya,
      position: Vec3(-11.4, minatoY(-11.4, 10.9), 10.9),
      yawRadians: math.pi + 0.14,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_bvd_s5'),
      kind: StructureKind.machiya,
      position: Vec3(-5.4, minatoY(-5.4, 10.3), 10.3),
      yawRadians: math.pi + 0.08,
    ),

    // South Port Alley & Castle Approach Townhouses
    PlacedStructure(
      id: EntityId.validated('minato_machiya_south_1'),
      kind: StructureKind.machiya,
      position: Vec3(-24.5, minatoY(-24.5, 25), 25),
      yawRadians: math.pi,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_south_2'),
      kind: StructureKind.machiya,
      position: Vec3(-17.5, minatoY(-17.5, 24.8), 24.8),
      yawRadians: math.pi,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_castle_w'),
      kind: StructureKind.machiya,
      position: Vec3(-16.4, minatoY(-16.4, -11.8), -11.8),
      yawRadians: math.pi / 2,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_castle_e'),
      kind: StructureKind.machiya,
      position: Vec3(-7.1, minatoY(-7.1, -9.6), -9.6),
      yawRadians: -math.pi / 2,
    ),

    // 4 Hero Chaya Teahouses (quay, boulevard, and castle approach)
    PlacedStructure(
      id: EntityId.validated('minato_chaya_north_quay'),
      kind: StructureKind.chaya,
      position: Vec3(-2.4, minatoY(-2.4, -4.6), -4.6),
      yawRadians: math.pi / 2,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_chaya_south_quay'),
      kind: StructureKind.chaya,
      position: Vec3(-2.6, minatoY(-2.6, 15.8), 15.8),
      yawRadians: math.pi / 2,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_chaya_castle_road'),
      kind: StructureKind.chaya,
      position: Vec3(-15.8, minatoY(-15.8, -5), -5),
      yawRadians: math.pi / 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_chaya_south_alley'),
      kind: StructureKind.chaya,
      position: Vec3(-9.2, minatoY(-9.2, 16.1), 16.1),
      yawRadians: 0,
      variant: 2,
    ),

    // 4 Hero Kura Warehouses (diamond namako-kabe vaults along port yard)
    PlacedStructure(
      id: EntityId.validated('minato_kura_quay_1'),
      kind: StructureKind.kura,
      position: Vec3(-2.6, minatoY(-2.6, 21.8), 21.8),
      yawRadians: math.pi / 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_kura_quay_2'),
      kind: StructureKind.kura,
      position: Vec3(-2.6, minatoY(-2.6, 27.6), 27.6),
      yawRadians: math.pi / 2,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_kura_south_alley'),
      kind: StructureKind.kura,
      position: Vec3(-11, minatoY(-11, 24.4), 24.4),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_kura_upper_west'),
      kind: StructureKind.kura,
      position: Vec3(-42.5, minatoY(-42.5, 19), 19),
      yawRadians: math.pi + 0.18,
      variant: 2,
    ),

    // 4 Yatai Market Stalls along the Harbor Stone Quay Plaza
    PlacedStructure(
      id: EntityId.validated('minato_stall_quay_1'),
      kind: StructureKind.marketStall,
      position: Vec3(4.65, minatoY(4.65, -1.2), -1.2),
      yawRadians: -math.pi / 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_stall_quay_2'),
      kind: StructureKind.marketStall,
      position: Vec3(5.05, minatoY(5.05, 9.6), 9.6),
      yawRadians: -math.pi / 2,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_stall_quay_3'),
      kind: StructureKind.marketStall,
      position: Vec3(5.35, minatoY(5.35, 21.2), 21.2),
      yawRadians: -math.pi / 2,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_stall_quay_4'),
      kind: StructureKind.marketStall,
      position: Vec3(5.25, minatoY(5.25, 26.8), 26.8),
      yawRadians: -math.pi / 2,
      variant: 3,
    ),

    // Western Bluff Bell Pavilion, Zen Court, & Courtyard Well
    PlacedStructure(
      id: EntityId.validated('minato_shoro_bell'),
      kind: StructureKind.shoroBell,
      position: Vec3(-26.5, minatoY(-26.5, -14.2), -14.2),
      yawRadians: 0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_karesansui_court'),
      kind: StructureKind.karesansuiGarden,
      position: Vec3(-27.8, minatoY(-27.8, -6.5), -6.5),
      yawRadians: 0.12,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_stone_well'),
      kind: StructureKind.stoneWell,
      position: Vec3(-7.2, minatoY(-7.2, 23.2), 23.2),
      yawRadians: 0.4,
    ),

    // 45+ Botanical Trees & Coastal Rock Outcrops framing town and castle
    // Foreground boulevard trees clear of the central street canyon ray
    PlacedStructure(
      id: EntityId.validated('minato_pine_bvd_fg_left'),
      kind: StructureKind.pineTree,
      position: Vec3(-25.5, minatoY(-25.5, 21), 21),
      yawRadians: 0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_bvd_fg_right'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-29.5, minatoY(-29.5, 1.5), 1.5),
      yawRadians: -0.52,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_bvd_frame_south'),
      kind: StructureKind.pineTree,
      position: Vec3(-21, minatoY(-21, 17.5), 17.5),
      yawRadians: 0.45,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_bvd_frame_south'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-31.8, minatoY(-31.8, 22), 22),
      yawRadians: -0.65,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_bvd_frame_north'),
      kind: StructureKind.pineTree,
      position: Vec3(-22.5, minatoY(-22.5, -0.4), -0.4),
      yawRadians: -0.42,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_quay_north'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-4.2, minatoY(-4.2, -13.2), -13.2),
      yawRadians: 0.72,
    ),
    // Castle Honmaru / Ninomaru framing Maples & Pines (clear of Tenshukaku & yaguras)
    PlacedStructure(
      id: EntityId.validated('minato_maple_castle_south_crest'),
      kind: StructureKind.mapleCluster,
      position: Vec3(9.5, minatoY(9.5, -18.5), -18.5),
      yawRadians: 0.28,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_castle_sw'),
      kind: StructureKind.mapleCluster,
      position: Vec3(2.8, minatoY(2.8, -19), -19),
      yawRadians: 0.55,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_castle_nw'),
      kind: StructureKind.pineTree,
      position: Vec3(1.5, minatoY(1.5, -36.5), -36.5),
      yawRadians: 1.10,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_castle_north'),
      kind: StructureKind.mapleCluster,
      position: Vec3(14.5, minatoY(14.5, -40.5), -40.5),
      yawRadians: -0.95,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_castle_ne'),
      kind: StructureKind.pineTree,
      position: Vec3(20.5, minatoY(20.5, -36.8), -36.8),
      yawRadians: 0.25,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_castle_se'),
      kind: StructureKind.mapleCluster,
      position: Vec3(21.2, minatoY(21.2, -19.5), -19.5),
      yawRadians: 1.35,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_otemon_s'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-12.5, minatoY(-12.5, -26.5), -26.5),
      yawRadians: -0.48,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_otemon_nw'),
      kind: StructureKind.pineTree,
      position: Vec3(-14.2, minatoY(-14.2, -34.5), -34.5),
      yawRadians: 0.88,
    ),
    // Waterfront & Cove Trees + Rocks
    PlacedStructure(
      id: EntityId.validated('minato_willow_cove_south'),
      kind: StructureKind.weepingWillow,
      position: Vec3(3.5, minatoY(3.5, 33), 33),
      yawRadians: 0.52,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_spit_west'),
      kind: StructureKind.pineTree,
      position: Vec3(11.5, minatoY(11.5, 33.8), 33.8),
      yawRadians: -0.30,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_rock_spit_point'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(18.5, minatoY(18.5, 34.5), 34.5),
      yawRadians: 0.65,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_rock_north_headland'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(12, minatoY(12, -49.5), -49.5),
      yawRadians: -0.75,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_rock_shrine_bluff'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(-21, minatoY(-21, -17.5), -17.5),
      yawRadians: 1.20,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_rock_south_shore'),
      kind: StructureKind.rockOutcrop,
      position: Vec3(2.5, minatoY(2.5, 42.5), 42.5),
      yawRadians: 0.38,
    ),
    // Western & North-Western Countryside Groves across x in [-72, -26]
    PlacedStructure(
      id: EntityId.validated('minato_pine_nw_1'),
      kind: StructureKind.pineTree,
      position: Vec3(-33.5, minatoY(-33.5, -24), -24),
      yawRadians: 0.25,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_nw_1'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-39, minatoY(-39, -14.5), -14.5),
      yawRadians: -0.70,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_bamboo_nw_1'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-44, minatoY(-44, -27), -27),
      yawRadians: 0.42,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_nw_2'),
      kind: StructureKind.pineTree,
      position: Vec3(-52, minatoY(-52, -18.5), -18.5),
      yawRadians: 1.15,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_nw_2'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-48.5, minatoY(-48.5, -38), -38),
      yawRadians: -0.45,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_nw_3'),
      kind: StructureKind.pineTree,
      position: Vec3(-26, minatoY(-26, -42), -42),
      yawRadians: 0.62,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_bamboo_nw_2'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-36.5, minatoY(-36.5, -52), -52),
      yawRadians: -0.88,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_nw_4'),
      kind: StructureKind.pineTree,
      position: Vec3(-12, minatoY(-12, -54), -54),
      yawRadians: 0.94,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_n_headland'),
      kind: StructureKind.mapleCluster,
      position: Vec3(2.5, minatoY(2.5, -52.5), -52.5),
      yawRadians: -0.55,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_w_ridge_1'),
      kind: StructureKind.pineTree,
      position: Vec3(-54, minatoY(-54, 2.5), 2.5),
      yawRadians: 0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_bamboo_w_ridge_1'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-58, minatoY(-58, 18), 18),
      yawRadians: -0.60,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_w_ridge_2'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-48.5, minatoY(-48.5, 29), 29),
      yawRadians: 0.85,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_w_ridge_2'),
      kind: StructureKind.pineTree,
      position: Vec3(-62, minatoY(-62, -8.5), -8.5),
      yawRadians: -1.10,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_w_ridge_3'),
      kind: StructureKind.pineTree,
      position: Vec3(-66, minatoY(-66, -32), -32),
      yawRadians: 0.48,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_sw_1'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-34, minatoY(-34, 32.5), 32.5),
      yawRadians: 1.02,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_bamboo_sw_1'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-22, minatoY(-22, 36), 36),
      yawRadians: -0.35,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_sw_1'),
      kind: StructureKind.pineTree,
      position: Vec3(-12.5, minatoY(-12.5, 37.5), 37.5),
      yawRadians: 0.72,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_sw_2'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-4.5, minatoY(-4.5, 42), 42),
      yawRadians: -0.82,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_sw_2'),
      kind: StructureKind.pineTree,
      position: Vec3(-44, minatoY(-44, 44), 44),
      yawRadians: 0.56,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_bamboo_sw_2'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-58, minatoY(-58, 38), 38),
      yawRadians: 1.24,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_willow_sw_1'),
      kind: StructureKind.weepingWillow,
      position: Vec3(-38, minatoY(-38, -2), -2),
      yawRadians: -0.45,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_far_nw_1'),
      kind: StructureKind.pineTree,
      position: Vec3(-56, minatoY(-56, -54), -54),
      yawRadians: 0.90,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_far_nw_2'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-28, minatoY(-28, -64), -64),
      yawRadians: -0.72,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_far_sw_1'),
      kind: StructureKind.pineTree,
      position: Vec3(-32, minatoY(-32, 56), 56),
      yawRadians: 0.34,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_far_sw_2'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-14, minatoY(-14, 58), 58),
      yawRadians: -1.05,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_bamboo_far_sw_3'),
      kind: StructureKind.bambooGrove,
      position: Vec3(-62, minatoY(-62, 58), 58),
      yawRadians: 0.68,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_far_w_edge'),
      kind: StructureKind.pineTree,
      position: Vec3(-72, minatoY(-72, 12), 12),
      yawRadians: -0.25,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_maple_far_n_headland'),
      kind: StructureKind.mapleCluster,
      position: Vec3(-6, minatoY(-6, -66), -66),
      yawRadians: 0.80,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_pine_far_s_cove'),
      kind: StructureKind.pineTree,
      position: Vec3(-18, minatoY(-18, -70), -70),
      yawRadians: -0.62,
    ),
  ];

  return ShukubaGraph(
    roads: roads,
    terraces: terraces,
    walls: walls,
    structures: structures,
  );
}

List<MinatoHeroPlacement> buildMinatoCastleAndHarborPlacements(
  GroundHeightSampler sampleGroundY,
) {
  double groundPlus(double x, double z, [double dy = 0.02]) =>
      sampleGroundY(x, z) + dy;

  return <MinatoHeroPlacement>[
    // Monumental 5-Tier Honmaru Keep
    (
      name: 'minato_castle_tenshukaku',
      assetPath: 'assets/models/castle_tenshukaku.glb',
      x: 11.5,
      z: -27.5,
      yaw: 0.22,
      y: 7.80,
    ),
    // 4 Corner Watch Turrets (Yagura) atop corner bastions
    (
      name: 'minato_castle_yagura_sw',
      assetPath: 'assets/models/castle_yagura.glb',
      x: -2.0,
      z: -14.0,
      yaw: 0.0,
      y: 7.72,
    ),
    (
      name: 'minato_castle_yagura_se',
      assetPath: 'assets/models/castle_yagura.glb',
      x: 25.0,
      z: -14.0,
      yaw: -0.35,
      y: 7.73,
    ),
    (
      name: 'minato_castle_yagura_ne',
      assetPath: 'assets/models/castle_yagura.glb',
      x: 25.0,
      z: -42.5,
      yaw: math.pi,
      y: 7.75,
    ),
    (
      name: 'minato_castle_yagura_nw',
      assetPath: 'assets/models/castle_yagura.glb',
      x: -2.0,
      z: -42.5,
      yaw: math.pi / 2,
      y: 7.74,
    ),
    // Grand Twin-Bastion Otemon Gatehouse spanning road_castle_approach
    (
      name: 'minato_castle_otemon_gate',
      assetPath: 'assets/models/castle_otemon_gate.glb',
      x: -8.5,
      z: -19.5,
      yaw: math.pi / 2,
      y: 4.65,
    ),
    // 4 Battered Ishigaki Corner Bastions staggered vs neighboring walls
    (
      name: 'minato_ishigaki_corner_sw',
      assetPath: 'assets/models/castle_ishigaki_corner.glb',
      x: -2.0,
      z: -14.0,
      yaw: 0.0,
      y: 1.15,
    ),
    (
      name: 'minato_ishigaki_corner_se',
      assetPath: 'assets/models/castle_ishigaki_corner.glb',
      x: 25.0,
      z: -14.0,
      yaw: 0.0,
      y: 1.16,
    ),
    (
      name: 'minato_ishigaki_corner_ne',
      assetPath: 'assets/models/castle_ishigaki_corner.glb',
      x: 25.0,
      z: -42.5,
      yaw: 0.0,
      y: 1.18,
    ),
    (
      name: 'minato_ishigaki_corner_nw',
      assetPath: 'assets/models/castle_ishigaki_corner.glb',
      x: -2.0,
      z: -42.5,
      yaw: 0.0,
      y: 1.17,
    ),
    // Battered Ishigaki Curtain Walls on all 4 Honmaru sides
    // (2 abutting 12.04m segments per side -> 0 wall-to-wall overlap)
    (
      name: 'minato_ishigaki_wall_south_1',
      assetPath: 'assets/models/castle_ishigaki_wall.glb',
      x: 5.45,
      z: -14.05,
      yaw: 0.0,
      y: 1.08,
    ),
    (
      name: 'minato_ishigaki_wall_south_2',
      assetPath: 'assets/models/castle_ishigaki_wall.glb',
      x: 17.51,
      z: -14.05,
      yaw: 0.0,
      y: 1.08,
    ),
    (
      name: 'minato_ishigaki_wall_north_1',
      assetPath: 'assets/models/castle_ishigaki_wall.glb',
      x: 5.45,
      z: -42.55,
      yaw: math.pi,
      y: 1.07,
    ),
    (
      name: 'minato_ishigaki_wall_north_2',
      assetPath: 'assets/models/castle_ishigaki_wall.glb',
      x: 17.51,
      z: -42.55,
      yaw: math.pi,
      y: 1.07,
    ),
    (
      name: 'minato_ishigaki_wall_east_1',
      assetPath: 'assets/models/castle_ishigaki_wall.glb',
      x: 25.08,
      z: -22.25,
      yaw: math.pi / 2,
      y: 1.10,
    ),
    (
      name: 'minato_ishigaki_wall_east_2',
      assetPath: 'assets/models/castle_ishigaki_wall.glb',
      x: 25.08,
      z: -34.30,
      yaw: math.pi / 2,
      y: 1.10,
    ),
    (
      name: 'minato_ishigaki_wall_west_1',
      assetPath: 'assets/models/castle_ishigaki_wall.glb',
      x: -2.08,
      z: -22.25,
      yaw: math.pi / 2,
      y: 1.09,
    ),
    (
      name: 'minato_ishigaki_wall_west_2',
      assetPath: 'assets/models/castle_ishigaki_wall.glb',
      x: -2.08,
      z: -34.30,
      yaw: math.pi / 2,
      y: 1.09,
    ),
    // Loopholed Hei Plaster Castle Parapet Walls
    // (3 abutting segments per side spaced 8.25m -> 1 cm joint, 0 overlap)
    (
      name: 'minato_hei_wall_south_1',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: 4.65,
      z: -13.66,
      yaw: 0.0,
      y: 7.66,
    ),
    (
      name: 'minato_hei_wall_south_2',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: 12.90,
      z: -13.66,
      yaw: 0.0,
      y: 7.66,
    ),
    (
      name: 'minato_hei_wall_south_3',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: 21.15,
      z: -13.66,
      yaw: 0.0,
      y: 7.66,
    ),
    (
      name: 'minato_hei_wall_north_1',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: 4.65,
      z: -42.84,
      yaw: math.pi,
      y: 7.65,
    ),
    (
      name: 'minato_hei_wall_north_2',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: 12.90,
      z: -42.84,
      yaw: math.pi,
      y: 7.65,
    ),
    (
      name: 'minato_hei_wall_north_3',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: 21.15,
      z: -42.84,
      yaw: math.pi,
      y: 7.65,
    ),
    (
      name: 'minato_hei_wall_east_1',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: 24.92,
      z: -20.00,
      yaw: math.pi / 2,
      y: 7.67,
    ),
    (
      name: 'minato_hei_wall_east_2',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: 24.92,
      z: -28.25,
      yaw: math.pi / 2,
      y: 7.67,
    ),
    (
      name: 'minato_hei_wall_east_3',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: 24.92,
      z: -36.50,
      yaw: math.pi / 2,
      y: 7.67,
    ),
    (
      name: 'minato_hei_wall_west_1',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: -2.02,
      z: -20.00,
      yaw: math.pi / 2,
      y: 7.66,
    ),
    (
      name: 'minato_hei_wall_west_2',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: -2.02,
      z: -28.25,
      yaw: math.pi / 2,
      y: 7.66,
    ),
    (
      name: 'minato_hei_wall_west_3',
      assetPath: 'assets/models/castle_hei_wall.glb',
      x: -2.02,
      z: -36.50,
      yaw: math.pi / 2,
      y: 7.66,
    ),

    // 5 Harbor Piers (Main Trade Pier Outer staggered to avoid any endcap/side overlap)
    (
      name: 'minato_pier_north_castle',
      assetPath: 'assets/models/harbor_pier.glb',
      x: 12.1,
      z: -5.5,
      yaw: math.pi / 2,
      y: -0.55,
    ),
    (
      name: 'minato_pier_main_inner',
      assetPath: 'assets/models/harbor_pier.glb',
      x: 12.3,
      z: 5.5,
      yaw: math.pi / 2,
      y: -0.55,
    ),
    (
      name: 'minato_pier_main_outer',
      assetPath: 'assets/models/harbor_pier.glb',
      x: 23.36,
      z: 5.53,
      yaw: math.pi / 2,
      y: -0.52,
    ),
    (
      name: 'minato_pier_south_market',
      assetPath: 'assets/models/harbor_pier.glb',
      x: 12.1,
      z: 17.5,
      yaw: math.pi / 2,
      y: -0.55,
    ),
    (
      name: 'minato_pier_south_ferry',
      assetPath: 'assets/models/harbor_pier.glb',
      x: 11.5,
      z: 26.5,
      yaw: math.pi / 2,
      y: -0.55,
    ),

    // Edo Wooden Todai Harbor Lighthouse on SE Breakwater Spit
    (
      name: 'minato_harbor_todai',
      assetPath: 'assets/models/harbor_todai.glb',
      x: 23.5,
      z: 32.5,
      yaw: -0.45,
      y: 0.86,
    ),

    // 4 Twin-Masted Sengokubune vessels floating at water surface (-0.55m)
    (
      name: 'minato_ship_main_pier',
      assetPath: 'assets/models/ship_sengokubune.glb',
      x: 18.7,
      z: 0.1,
      yaw: 1.48,
      y: -0.55,
    ),
    (
      name: 'minato_ship_south_pier',
      assetPath: 'assets/models/ship_sengokubune.glb',
      x: 19.1,
      z: 12.1,
      yaw: 1.66,
      y: -0.55,
    ),
    (
      name: 'minato_ship_sunset_bay',
      assetPath: 'assets/models/ship_sengokubune.glb',
      x: 37.5,
      z: -3.5,
      yaw: 0.62,
      y: -0.55,
    ),
    (
      name: 'minato_ship_outer_channel',
      assetPath: 'assets/models/ship_sengokubune.glb',
      x: 58.0,
      z: 16.5,
      yaw: 1.15,
      y: -0.55,
    ),

    // 5 Traditional Edo Wasen Skiffs moored in the cove
    (
      name: 'minato_boat_wasen_1',
      assetPath: 'assets/models/boat_wasen.glb',
      x: 9.2,
      z: 10.8,
      yaw: 1.25,
      y: -0.55,
    ),
    (
      name: 'minato_boat_wasen_2',
      assetPath: 'assets/models/boat_wasen.glb',
      x: 8.6,
      z: 22.5,
      yaw: 1.85,
      y: -0.55,
    ),
    (
      name: 'minato_boat_wasen_3',
      assetPath: 'assets/models/boat_wasen.glb',
      x: 24.5,
      z: 10.2,
      yaw: 0.95,
      y: -0.55,
    ),
    (
      name: 'minato_boat_wasen_4',
      assetPath: 'assets/models/boat_wasen.glb',
      x: 15.2,
      z: -8.6,
      yaw: 2.15,
      y: -0.55,
    ),
    (
      name: 'minato_boat_wasen_5',
      assetPath: 'assets/models/boat_wasen.glb',
      x: 31.5,
      z: 22.8,
      yaw: 0.72,
      y: -0.55,
    ),

    // 5 Harbor Cargo Stacks + Quay Sake Casks, Handcarts & Stone Lanterns
    (
      name: 'minato_cargo_quay_1',
      assetPath: 'assets/models/harbor_cargo.glb',
      x: 0.2,
      z: 8.2,
      yaw: 0.35,
      y: groundPlus(0.2, 8.2),
    ),
    (
      name: 'minato_cargo_quay_2',
      assetPath: 'assets/models/harbor_cargo.glb',
      x: 0.3,
      z: 19.2,
      yaw: -0.28,
      y: groundPlus(0.3, 19.2),
    ),
    (
      name: 'minato_cargo_quay_3',
      assetPath: 'assets/models/harbor_cargo.glb',
      x: 5.2,
      z: 24.5,
      yaw: 1.15,
      y: groundPlus(5.2, 24.5),
    ),
    (
      name: 'minato_cargo_pier_main',
      assetPath: 'assets/models/harbor_cargo.glb',
      x: 14.4,
      z: 5.5,
      yaw: 0.15,
      y: 0.77,
    ),
    (
      name: 'minato_cargo_north_pier',
      assetPath: 'assets/models/harbor_cargo.glb',
      x: 12.4,
      z: -5.4,
      yaw: -0.45,
      y: 0.77,
    ),
    (
      name: 'minato_sake_barrels_1',
      assetPath: 'assets/models/edo_sake_barrels.glb',
      x: -0.4,
      z: -3.0,
      yaw: 0.2,
      y: groundPlus(-0.4, -3),
    ),
    (
      name: 'minato_sake_barrels_2',
      assetPath: 'assets/models/edo_sake_barrels.glb',
      x: -0.5,
      z: 14.5,
      yaw: -0.4,
      y: groundPlus(-0.5, 14.5),
    ),
    (
      name: 'minato_handcart_quay',
      assetPath: 'assets/models/edo_handcart.glb',
      x: 4.5,
      z: 13.0,
      yaw: 0.15,
      y: groundPlus(4.5, 13),
    ),
    (
      name: 'minato_handcart_bvd',
      assetPath: 'assets/models/edo_handcart.glb',
      x: -13.2,
      z: 8.6,
      yaw: -0.25,
      y: groundPlus(-13.2, 8.6),
    ),
    (
      name: 'minato_lantern_torii_n',
      assetPath: 'assets/models/edo_stone_lantern.glb',
      x: -1.4,
      z: 2.6,
      yaw: -0.2,
      y: sampleGroundY(-1.4, 2.6) - 0.04,
    ),
    (
      name: 'minato_lantern_torii_s',
      assetPath: 'assets/models/edo_stone_lantern.glb',
      x: -1.4,
      z: 8.4,
      yaw: 0.2,
      y: sampleGroundY(-1.4, 8.4) - 0.04,
    ),
    (
      name: 'minato_lantern_otemon_w',
      assetPath: 'assets/models/edo_stone_lantern.glb',
      x: -11.5,
      z: -16.8,
      yaw: 0.1,
      y: sampleGroundY(-11.5, -16.8) - 0.04,
    ),
    (
      name: 'minato_lantern_otemon_e',
      assetPath: 'assets/models/edo_stone_lantern.glb',
      x: -11.5,
      z: -22.2,
      yaw: -0.1,
      y: sampleGroundY(-11.5, -22.2) - 0.04,
    ),

    // Harbor A-frame Timber Dock Cranes at pier heads
    (
      name: 'minato_crane_north_pier',
      assetPath: 'assets/models/harbor_crane.glb',
      x: 15.8,
      z: -5.5,
      yaw: math.pi / 2 - 0.18,
      y: 0.77,
    ),
    (
      name: 'minato_crane_main_pier',
      assetPath: 'assets/models/harbor_crane.glb',
      x: 26.2,
      z: 5.5,
      yaw: math.pi / 2 + 0.14,
      y: 0.77,
    ),
    (
      name: 'minato_crane_south_pier',
      assetPath: 'assets/models/harbor_crane.glb',
      x: 15.6,
      z: 17.5,
      yaw: math.pi / 2 + 0.08,
      y: 0.77,
    ),

    // Coastal Headlands & Cliffs wrapping Castle Promontory & Coves
    (
      name: 'minato_headland_castle_ne',
      assetPath: 'assets/models/rock_coastal_headland.glb',
      x: 28.6,
      z: -39.5,
      yaw: 0.42,
      y: -1.15,
    ),
    (
      name: 'minato_headland_castle_e',
      assetPath: 'assets/models/rock_coastal_headland.glb',
      x: 29.0,
      z: -28.0,
      yaw: -0.35,
      y: -1.10,
    ),
    (
      name: 'minato_headland_castle_se',
      assetPath: 'assets/models/rock_coastal_headland.glb',
      x: 28.4,
      z: -16.5,
      yaw: 1.15,
      y: -1.15,
    ),
    (
      name: 'minato_headland_castle_n1',
      assetPath: 'assets/models/rock_coastal_headland.glb',
      x: 19.5,
      z: -46.2,
      yaw: 2.05,
      y: -1.10,
    ),
    (
      name: 'minato_headland_castle_n2',
      assetPath: 'assets/models/rock_coastal_headland.glb',
      x: 6.5,
      z: -45.8,
      yaw: -1.45,
      y: -1.05,
    ),
    (
      name: 'minato_cliff_north_cove_1',
      assetPath: 'assets/models/rock_cliff_a.glb',
      x: -6.5,
      z: -48.5,
      yaw: 0.65,
      y: groundPlus(-6.5, -48.5, -0.75),
    ),
    (
      name: 'minato_cliff_north_cove_2',
      assetPath: 'assets/models/rock_cliff_b.glb',
      x: -13.5,
      z: -50.2,
      yaw: -0.85,
      y: groundPlus(-13.5, -50.2, -0.65),
    ),
    (
      name: 'minato_headland_spit_tip',
      assetPath: 'assets/models/rock_coastal_headland.glb',
      x: 27.5,
      z: 33.8,
      yaw: 0.85,
      y: -0.72,
    ),
    (
      name: 'minato_cliff_spit_s1',
      assetPath: 'assets/models/rock_cliff_b.glb',
      x: 21.8,
      z: 36.8,
      yaw: -0.45,
      y: -0.62,
    ),
    (
      name: 'minato_riprap_spit_s2',
      assetPath: 'assets/models/rock_shore_riprap.glb',
      x: 15.2,
      z: 36.2,
      yaw: 1.25,
      y: -0.48,
    ),
    (
      name: 'minato_riprap_south_cove',
      assetPath: 'assets/models/rock_shore_riprap.glb',
      x: 9.2,
      z: 34.5,
      yaw: -1.10,
      y: -0.45,
    ),

    // Minato Boulevard & Quay Props (Wagons, Wagasa, Fence, Banners, Andon)
    (
      name: 'minato_wagon_west_bvd',
      assetPath: 'assets/models/edo_wagon.glb',
      x: -20.2,
      z: 9.6,
      yaw: 1.32,
      y: groundPlus(-20.2, 9.6, 0),
    ),
    (
      name: 'minato_wagon_quay_plaza',
      assetPath: 'assets/models/edo_wagon.glb',
      x: -4.8,
      z: 2,
      yaw: -0.15,
      y: groundPlus(-4.8, 2, 0),
    ),
    (
      name: 'minato_wagasa_quay',
      assetPath: 'assets/models/edo_wagasa_bench.glb',
      x: -2.5,
      z: 11.2,
      yaw: 0.25,
      y: groundPlus(-2.5, 11.2, 0),
    ),
    (
      name: 'minato_wagasa_midtown',
      assetPath: 'assets/models/edo_wagasa_bench.glb',
      x: -18.2,
      z: 16.5,
      yaw: -1.35,
      y: groundPlus(-18.2, 16.5, 0),
    ),
    (
      name: 'minato_bamboo_fence_castle_edge',
      assetPath: 'assets/models/edo_bamboo_fence.glb',
      x: -6.8,
      z: -11.2,
      yaw: 0.12,
      y: groundPlus(-6.8, -11.2, 0),
    ),
    (
      name: 'minato_nobori_torii_side',
      assetPath: 'assets/models/edo_nobori_banner.glb',
      x: -2.8,
      z: 1.8,
      yaw: 0.15,
      y: groundPlus(-2.8, 1.8, 0),
    ),
    (
      name: 'minato_nobori_quay_south',
      assetPath: 'assets/models/edo_nobori_banner.glb',
      x: 1.8,
      z: 11.8,
      yaw: -0.25,
      y: groundPlus(1.8, 11.8, 0),
    ),
    (
      name: 'minato_andon_boulevard',
      assetPath: 'assets/models/edo_andon_lantern.glb',
      x: -9.5,
      z: 10.2,
      yaw: 0,
      y: groundPlus(-9.5, 10.2, 0),
    ),
  ];
}

List<
  ({
    EntityId id,
    StreetAgentRole role,
    Vec3 position,
    List<Vec3> waypoints,
    bool carriesLantern,
    double speed,
    double bobPhase,
  })
>
buildMinatoStreetAgents(GroundHeightSampler sampleGroundY) => [
  (
    id: EntityId.validated('minato_dockworker_1'),
    role: StreetAgentRole.townsfolk,
    position: Vec3(1.9, sampleGroundY(1.9, 0), 0),
    waypoints: [
      Vec3(1.9, sampleGroundY(1.9, -6.5), -6.5),
      Vec3(1.9, sampleGroundY(1.9, 5.5), 5.5),
      Vec3(1.9, sampleGroundY(1.9, 22), 22),
      Vec3(1.9, sampleGroundY(1.9, 5.5), 5.5),
    ],
    carriesLantern: false,
    speed: 1.55,
    bobPhase: 0.0,
  ),
  (
    id: EntityId.validated('minato_watchman_quay'),
    role: StreetAgentRole.lanternWatchman,
    position: Vec3(-14, sampleGroundY(-14, 6.9), 6.9),
    waypoints: [
      Vec3(-28, sampleGroundY(-28, 10), 10),
      Vec3(-16, sampleGroundY(-16, 7.2), 7.2),
      Vec3(-6, sampleGroundY(-6, 5.8), 5.8),
      Vec3(1.9, sampleGroundY(1.9, 5.5), 5.5),
      Vec3(-6, sampleGroundY(-6, 5.8), 5.8),
      Vec3(-16, sampleGroundY(-16, 7.2), 7.2),
    ],
    carriesLantern: true,
    speed: 1.4,
    bobPhase: 1.2,
  ),
  (
    id: EntityId.validated('minato_castle_courier'),
    role: StreetAgentRole.nightSmuggler,
    position: Vec3(-11, sampleGroundY(-11, -5), -5),
    waypoints: [
      Vec3(-10, sampleGroundY(-10, 5), 5),
      Vec3(-11.5, sampleGroundY(-11.5, -3), -3),
      Vec3(-10.5, sampleGroundY(-10.5, -12.5), -12.5),
      Vec3(-8.5, sampleGroundY(-8.5, -19.5), -19.5),
      Vec3(-10.5, sampleGroundY(-10.5, -12.5), -12.5),
    ],
    carriesLantern: true,
    speed: 1.5,
    bobPhase: 2.3,
  ),
  (
    id: EntityId.validated('minato_merchant_alley'),
    role: StreetAgentRole.townsfolk,
    position: Vec3(-12, sampleGroundY(-12, 19.5), 19.5),
    waypoints: [
      Vec3(-22, sampleGroundY(-22, 20), 20),
      Vec3(-12, sampleGroundY(-12, 19.5), 19.5),
      Vec3(1.9, sampleGroundY(1.9, 18), 18),
      Vec3(-12, sampleGroundY(-12, 19.5), 19.5),
    ],
    carriesLantern: false,
    speed: 1.35,
    bobPhase: 0.7,
  ),
];

List<Vec3> buildMinatoExtraLanternOrigins() => const <Vec3>[
  // Tenshukaku & Otemon Castle Keep warm lanterns
  Vec3(11.5, 16.5, -24.5),
  Vec3(-8.5, 8.8, -19.5),
  // Todai harbor lighthouse warm beacon
  Vec3(23.5, 6.8, 32.5),
  // Harbor pier lamp posts
  Vec3(12.3, 2.9, 1.9),
  Vec3(23.3, 2.9, 9.1),
  Vec3(12.1, 2.9, 13.9),
  Vec3(12.1, 2.9, -1.9),
];
