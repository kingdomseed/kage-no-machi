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
        Vec3(-44, minatoY(-44, 15.2), 15.2),
        Vec3(-32, minatoY(-32, 11.4), 11.4),
        Vec3(-22, minatoY(-22, 10.6), 10.6),
        Vec3(-14.5, minatoY(-14.5, 8.2), 8.2),
        Vec3(-7.2, minatoY(-7.2, 6.2), 6.2),
        Vec3(3, minatoY(3, 5.5), 5.5),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_minato_quay'),
      widthMeters: 2.8,
      controlPoints: [
        Vec3(1.9, minatoY(1.9, -8.5), -8.5),
        Vec3(2, minatoY(2, 5.5), 5.5),
        Vec3(2.1, minatoY(2.1, 17.4), 17.4),
        Vec3(2.1, minatoY(2.1, 29.5), 29.5),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_castle_approach'),
      widthMeters: 2.8,
      controlPoints: [
        Vec3(-9.5, minatoY(-9.5, 6.8), 6.8),
        Vec3(-11.2, minatoY(-11.2, -2.5), -2.5),
        Vec3(-11.6, minatoY(-11.6, -11.5), -11.5),
        Vec3(-12.8, minatoY(-12.8, -18.8), -18.8),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_south_port_alley'),
      widthMeters: 2.6,
      controlPoints: [
        Vec3(-25, minatoY(-25, 21), 21),
        Vec3(-14.8, minatoY(-14.8, 19.8), 19.8),
        Vec3(-6.2, minatoY(-6.2, 19.9), 19.9),
        Vec3(-5.8, minatoY(-5.8, 17.6), 17.6),
        Vec3(2, minatoY(2, 17.4), 17.4),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_shrine_bluff_roji'),
      style: RoadStyle.gardenPath,
      widthMeters: 1.75,
      controlPoints: [
        Vec3(-11.2, minatoY(-11.2, -2.5), -2.5),
        Vec3(-11.8, minatoY(-11.8, -7.8), -7.8),
        Vec3(-19.8, minatoY(-19.8, -7.8), -7.8),
        Vec3(-22.6, minatoY(-22.6, -7.8), -7.8),
        Vec3(-22.4, minatoY(-22.4, -13), -13),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_warehouse_yard_roji'),
      style: RoadStyle.gardenPath,
      widthMeters: 1.7,
      controlPoints: [
        Vec3(-6.2, minatoY(-6.2, 19.9), 19.9),
        Vec3(-6, minatoY(-6, 22.8), 22.8),
        Vec3(-6, minatoY(-6, 26.6), 26.6),
        Vec3(-8.2, minatoY(-8.2, 27), 27),
      ],
    ),
    RoadSpline.validated(
      id: EntityId.validated('road_jokamachi_upper_lane'),
      style: RoadStyle.gardenPath,
      widthMeters: 1.75,
      controlPoints: [
        Vec3(-19.2, minatoY(-19.2, 19.8), 19.8),
        Vec3(-19.4, minatoY(-19.4, 12.6), 12.6),
        Vec3(-19.4, minatoY(-19.4, 8), 8),
        Vec3(-19.4, minatoY(-19.4, 2.6), 2.6),
        Vec3(-19.6, minatoY(-19.6, -3.5), -3.5),
        Vec3(-19.8, minatoY(-19.8, -7.8), -7.8),
      ],
    ),
  ];

  final walls = <CourtyardWall>[
    CourtyardWall.validated(
      id: EntityId.validated('minato_wall_kura_yard'),
      controlPoints: [
        Vec3(-14.5, minatoY(-14.5, 29.8), 29.8),
        Vec3(-2.6, minatoY(-2.6, 29.8), 29.8),
        Vec3(-2.6, minatoY(-2.6, 32.8), 32.8),
      ],
    ),
    CourtyardWall.validated(
      id: EntityId.validated('minato_wall_shrine_garden'),
      controlPoints: [
        Vec3(-31.2, minatoY(-31.2, -2.8), -2.8),
        Vec3(-31.2, minatoY(-31.2, -17), -17),
        Vec3(-23.8, minatoY(-23.8, -17), -17),
      ],
    ),
    CourtyardWall.validated(
      id: EntityId.validated('minato_wall_samurai_compound'),
      controlPoints: [
        Vec3(-17, minatoY(-17, -0.5), -0.5),
        Vec3(-12.8, minatoY(-12.8, -0.5), -0.5),
        Vec3(-12.8, minatoY(-12.8, -1.6), -1.6),
      ],
    ),
    CourtyardWall.validated(
      id: EntityId.validated('minato_wall_midtown_courtyard'),
      controlPoints: [
        Vec3(-19.8, minatoY(-19.8, 28.2), 28.2),
        Vec3(-14.6, minatoY(-14.6, 28.2), 28.2),
        Vec3(-14.6, minatoY(-14.6, 24), 24),
      ],
    ),
    CourtyardWall.validated(
      id: EntityId.validated('minato_wall_upper_terrace'),
      controlPoints: [
        Vec3(-36.5, minatoY(-36.5, 4.8), 4.8),
        Vec3(-36.5, minatoY(-36.5, -1.8), -1.8),
        Vec3(-31.2, minatoY(-31.2, -1.8), -1.8),
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

    // Asymmetric Eastern Throat & Waterfront Corner Machiya
    PlacedStructure(
      id: EntityId.validated('minato_machiya_quay_n'),
      kind: StructureKind.machiya,
      position: Vec3(-3.2, minatoY(-3.2, 0.2), 0.2),
      yawRadians: math.pi / 2 + 0.14,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_throat_n'),
      kind: StructureKind.machiya,
      position: Vec3(-5.6, minatoY(-5.6, 1.4), 1.4),
      yawRadians: 0.15,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_throat_s'),
      kind: StructureKind.machiya,
      position: Vec3(-7.4, minatoY(-7.4, 11.4), 11.4),
      yawRadians: math.pi - 0.18,
      variant: 2,
    ),

    // Mid-Town Market Square (Hiroba) Staggered Frontier — wide open center
    PlacedStructure(
      id: EntityId.validated('minato_chaya_market_n'),
      kind: StructureKind.chaya,
      position: Vec3(-15.8, minatoY(-15.8, 3.2), 3.2),
      yawRadians: 0.22,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_market_nw'),
      kind: StructureKind.machiya,
      position: Vec3(-23.4, minatoY(-23.4, 4.6), 4.6),
      yawRadians: 0.34,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_hiroba_sw'),
      kind: StructureKind.machiya,
      position: Vec3(-22.6, minatoY(-22.6, 16.8), 16.8),
      yawRadians: math.pi + 0.10,
    ),

    // Western Ascending Ridge & Staggered Machiya / Minka Cottages
    PlacedStructure(
      id: EntityId.validated('minato_machiya_west_n1'),
      kind: StructureKind.machiya,
      position: Vec3(-28.8, minatoY(-28.8, 6.2), 6.2),
      yawRadians: 0.14,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_west_n2'),
      kind: StructureKind.machiya,
      position: Vec3(-35.2, minatoY(-35.2, 7.6), 7.6),
      yawRadians: 0.24,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_west_n3'),
      kind: StructureKind.machiya,
      position: Vec3(-41.8, minatoY(-41.8, 9.8), 9.8),
      yawRadians: 0.32,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_west_s1'),
      kind: StructureKind.machiya,
      position: Vec3(-30.6, minatoY(-30.6, 16.4), 16.4),
      yawRadians: math.pi + 0.18,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_minka_west_ridge'),
      kind: StructureKind.minka,
      position: Vec3(-37.8, minatoY(-37.8, 18.2), 18.2),
      yawRadians: math.pi + 0.30,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_minka_shrine_slope'),
      kind: StructureKind.minka,
      position: Vec3(-34.8, minatoY(-34.8, -9.4), -9.4),
      yawRadians: 0.45,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_minka_south_hill'),
      kind: StructureKind.minka,
      position: Vec3(-31.8, minatoY(-31.8, 26.8), 26.8),
      yawRadians: math.pi + 0.42,
    ),

    // South Port Alley & Castle Approach Townhouses
    PlacedStructure(
      id: EntityId.validated('minato_machiya_south_1'),
      kind: StructureKind.machiya,
      position: Vec3(-24.8, minatoY(-24.8, 25.4), 25.4),
      yawRadians: math.pi - 0.12,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_south_2'),
      kind: StructureKind.machiya,
      position: Vec3(-17.8, minatoY(-17.8, 24.4), 24.4),
      yawRadians: math.pi + 0.15,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_castle_w'),
      kind: StructureKind.machiya,
      position: Vec3(-16.2, minatoY(-16.2, -12), -12),
      yawRadians: math.pi / 2 + 0.08,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_machiya_castle_e'),
      kind: StructureKind.machiya,
      position: Vec3(-7.2, minatoY(-7.2, -9.8), -9.8),
      yawRadians: -math.pi / 2 - 0.10,
      variant: 1,
    ),

    // 4 Hero Chaya Teahouses (quay, market, castle approach)
    PlacedStructure(
      id: EntityId.validated('minato_chaya_north_quay'),
      kind: StructureKind.chaya,
      position: Vec3(-2.5, minatoY(-2.5, -5.2), -5.2),
      yawRadians: math.pi / 2,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_chaya_south_quay'),
      kind: StructureKind.chaya,
      position: Vec3(-2.4, minatoY(-2.4, 13.2), 13.2),
      yawRadians: math.pi / 2 - 0.16,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_chaya_castle_road'),
      kind: StructureKind.chaya,
      position: Vec3(-15.6, minatoY(-15.6, -4.4), -4.4),
      yawRadians: math.pi / 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_chaya_south_alley'),
      kind: StructureKind.chaya,
      position: Vec3(-8.4, minatoY(-8.4, 15.8), 15.8),
      yawRadians: -0.25,
      variant: 2,
    ),

    // 5 Hero Kura Storehouses (port yard, castle guardhouse, & west edge)
    PlacedStructure(
      id: EntityId.validated('minato_kura_quay_1'),
      kind: StructureKind.kura,
      position: Vec3(-2.6, minatoY(-2.6, 21.8), 21.8),
      yawRadians: math.pi / 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_kura_quay_2'),
      kind: StructureKind.kura,
      position: Vec3(-2.4, minatoY(-2.4, 27.2), 27.2),
      yawRadians: math.pi / 2 + 0.12,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_kura_south_alley'),
      kind: StructureKind.kura,
      position: Vec3(-11.2, minatoY(-11.2, 24.6), 24.6),
      yawRadians: math.pi,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_kura_castle_guard'),
      kind: StructureKind.kura,
      position: Vec3(-7.4, minatoY(-7.4, -3.2), -3.2),
      yawRadians: -math.pi / 2 + 0.14,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_kura_upper_west'),
      kind: StructureKind.kura,
      position: Vec3(-43.8, minatoY(-43.8, 19.6), 19.6),
      yawRadians: math.pi + 0.12,
      variant: 2,
    ),

    // Clustered Yatai Market Stalls split across Harbor Quay & Mid-Town Square
    PlacedStructure(
      id: EntityId.validated('minato_stall_quay_1'),
      kind: StructureKind.marketStall,
      position: Vec3(4.65, minatoY(4.65, -1.2), -1.2),
      yawRadians: -math.pi / 2 + 0.15,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_stall_quay_2'),
      kind: StructureKind.marketStall,
      position: Vec3(5.15, minatoY(5.15, 22.8), 22.8),
      yawRadians: -math.pi / 2 - 0.12,
      variant: 2,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_stall_quay_3'),
      kind: StructureKind.marketStall,
      position: Vec3(4.95, minatoY(4.95, 26.2), 26.2),
      yawRadians: -math.pi / 2 + 0.08,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_stall_hiroba_1'),
      kind: StructureKind.marketStall,
      position: Vec3(-13.8, minatoY(-13.8, 12.2), 12.2),
      yawRadians: -0.35,
      variant: 1,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_stall_hiroba_2'),
      kind: StructureKind.marketStall,
      position: Vec3(-10.8, minatoY(-10.8, 13.4), 13.4),
      yawRadians: -2.55,
      variant: 3,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_stall_hiroba_3'),
      kind: StructureKind.marketStall,
      position: Vec3(-16.2, minatoY(-16.2, 13.8), 13.8),
      yawRadians: 0.68,
    ),

    // Western Bluff Bell Pavilion, Zen Court, & Courtyard Wells
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
      position: Vec3(-8.2, minatoY(-8.2, 23), 23),
      yawRadians: 0.4,
    ),
    PlacedStructure(
      id: EntityId.validated('minato_stone_well_market'),
      kind: StructureKind.stoneWell,
      position: Vec3(-13.2, minatoY(-13.2, 14.8), 14.8),
      yawRadians: -0.5,
    ),

    // Coastal Rock Outcrops & Prominent Landmark Accents
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
  ];

  void addTreeGroup(
    String prefix,
    List<({StructureKind kind, double x, double z, double yaw})> entries, {
    double minGroundY = 0.88,
  }) {
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final y = minatoY(e.x, e.z);
      if (y < minGroundY) {
        continue;
      }
      structures.add(
        PlacedStructure(
          id: EntityId.validated('${prefix}_$i'),
          kind: e.kind,
          position: Vec3(e.x, y, e.z),
          yawRadians: e.yaw,
        ),
      );
    }
  }

  // 1. Courtyard & Pocket Town Trees (~15 trees, clear of camera rays)
  addTreeGroup('minato_town_tree', const [
    (kind: StructureKind.pineTree, x: -26.8, z: 22.8, yaw: 0.35),
    (kind: StructureKind.mapleCluster, x: -29.5, z: 1.5, yaw: -0.52),
    (
      kind: StructureKind.mapleCluster,
      x: -17.2,
      z: -2.4,
      yaw: 0.78,
    ), // samurai compound courtyard
    (
      kind: StructureKind.mapleCluster,
      x: -17.8,
      z: 17.6,
      yaw: -0.45,
    ), // midtown courtyard garden
    (
      kind: StructureKind.pineTree,
      x: -13.2,
      z: 1.4,
      yaw: 1.15,
    ), // corner pocket behind throat machiya
    (
      kind: StructureKind.weepingWillow,
      x: -4.4,
      z: 21.2,
      yaw: 0.62,
    ), // quay yard corner tree
    (
      kind: StructureKind.mapleCluster,
      x: -4.2,
      z: -13.2,
      yaw: 0.72,
    ), // north quay cove edge
    (
      kind: StructureKind.pineTree,
      x: -29.2,
      z: -12.0,
      yaw: -0.25,
    ), // shrine garden backdrop
    (
      kind: StructureKind.pineTree,
      x: -24.5,
      z: -15.5,
      yaw: 0.90,
    ), // bell pavilion pine
    (
      kind: StructureKind.mapleCluster,
      x: -33.2,
      z: 1.5,
      yaw: -0.82,
    ), // upper terrace courtyard maple
    (
      kind: StructureKind.bambooGrove,
      x: -21.6,
      z: 29.4,
      yaw: 0.42,
    ), // south backyard bamboo
    (
      kind: StructureKind.pineTree,
      x: -13.2,
      z: 32.0,
      yaw: -0.34,
    ), // behind kura yard wall
    (
      kind: StructureKind.weepingWillow,
      x: 3.5,
      z: 33.0,
      yaw: 0.52,
    ), // south cove harbor edge
    (
      kind: StructureKind.pineTree,
      x: 11.5,
      z: 33.8,
      yaw: -0.30,
    ), // lighthouse spit pine
    (
      kind: StructureKind.mapleCluster,
      x: -21.2,
      z: -0.4,
      yaw: 0.38,
    ), // cross-lane junction shade
  ], minGroundY: 0.72);

  // 2. Castle Honmaru, Ninomaru & Cliff Flanks (clear of Keep & Yaguras)
  addTreeGroup('minato_castle_tree', const [
    (kind: StructureKind.mapleCluster, x: 9.5, z: -18.5, yaw: 0.28),
    (kind: StructureKind.mapleCluster, x: 2.8, z: -19.0, yaw: 0.55),
    (kind: StructureKind.pineTree, x: 1.5, z: -36.5, yaw: 1.10),
    (kind: StructureKind.mapleCluster, x: 14.5, z: -40.5, yaw: -0.95),
    (kind: StructureKind.pineTree, x: 20.5, z: -36.8, yaw: 0.25),
    (kind: StructureKind.mapleCluster, x: 21.2, z: -19.5, yaw: 1.35),
    (kind: StructureKind.mapleCluster, x: -12.5, z: -26.5, yaw: -0.48),
    (kind: StructureKind.pineTree, x: -14.2, z: -34.5, yaw: 0.88),
    (kind: StructureKind.pineTree, x: -16.8, z: -22.2, yaw: 0.15),
    (kind: StructureKind.mapleCluster, x: -19.5, z: -28.0, yaw: 1.05),
    (kind: StructureKind.pineTree, x: -17.5, z: -39.5, yaw: -0.62),
    (kind: StructureKind.pineTree, x: -23.0, z: -23.5, yaw: 0.44),
    (kind: StructureKind.mapleCluster, x: -23.5, z: -34.0, yaw: -1.12),
    (kind: StructureKind.pineTree, x: -8.5, z: -42.5, yaw: 0.75),
    (kind: StructureKind.pineTree, x: 4.5, z: -45.5, yaw: -0.35),
    (kind: StructureKind.mapleCluster, x: 11.5, z: -45.2, yaw: 0.92),
    (kind: StructureKind.pineTree, x: 17.8, z: -44.8, yaw: 1.40),
    (kind: StructureKind.mapleCluster, x: -6.5, z: -14.8, yaw: -0.20),
    (kind: StructureKind.pineTree, x: 4.5, z: -12.6, yaw: 0.68),
    (kind: StructureKind.pineTree, x: 18.5, z: -13.2, yaw: -0.78),
  ]);

  // 3. Northern Headland & Pebble Cove Hillsides (~22 coastal trees)
  addTreeGroup('minato_north_forest', const [
    (kind: StructureKind.pineTree, x: -12.0, z: -54.0, yaw: 0.94),
    (kind: StructureKind.mapleCluster, x: 2.5, z: -52.5, yaw: -0.55),
    (kind: StructureKind.pineTree, x: -2.0, z: -58.0, yaw: 0.22),
    (kind: StructureKind.mapleCluster, x: -6.0, z: -66.0, yaw: 0.80),
    (kind: StructureKind.pineTree, x: -18.0, z: -70.0, yaw: -0.62),
    (kind: StructureKind.pineTree, x: -24.5, z: -56.0, yaw: 0.48),
    (kind: StructureKind.mapleCluster, x: -28.0, z: -64.0, yaw: -0.72),
    (kind: StructureKind.pineTree, x: -34.0, z: -60.0, yaw: 1.18),
    (kind: StructureKind.mapleCluster, x: -36.5, z: -52.0, yaw: -0.88),
    (kind: StructureKind.pineTree, x: -21.0, z: -48.5, yaw: 0.35),
    (kind: StructureKind.mapleCluster, x: -15.5, z: -47.0, yaw: -1.02),
    (kind: StructureKind.pineTree, x: -8.5, z: -49.5, yaw: 0.56),
    (kind: StructureKind.pineTree, x: -19.5, z: -62.0, yaw: -0.28),
    (kind: StructureKind.mapleCluster, x: -12.5, z: -63.5, yaw: 1.10),
    (kind: StructureKind.pineTree, x: -30.5, z: -54.5, yaw: -0.45),
    (kind: StructureKind.mapleCluster, x: -28.5, z: -45.5, yaw: 0.72),
    (kind: StructureKind.mapleCluster, x: -42.5, z: -58.5, yaw: -0.90),
    (kind: StructureKind.pineTree, x: -46.0, z: -49.5, yaw: 0.30),
    (kind: StructureKind.pineTree, x: -39.5, z: -44.0, yaw: 1.28),
    (kind: StructureKind.mapleCluster, x: -25.0, z: -38.5, yaw: -0.52),
    (kind: StructureKind.pineTree, x: -32.0, z: -36.0, yaw: 0.82),
    (kind: StructureKind.pineTree, x: -43.0, z: -34.5, yaw: -0.18),
  ]);

  // 4. Western Ridge & Surround Hillside Forest (~58 trees, x in [-78, -26])
  addTreeGroup('minato_west_forest', const [
    (kind: StructureKind.pineTree, x: -33.5, z: -24.0, yaw: 0.25),
    (kind: StructureKind.mapleCluster, x: -39.0, z: -14.5, yaw: -0.70),
    (kind: StructureKind.pineTree, x: -44.0, z: -27.0, yaw: 0.42),
    (kind: StructureKind.pineTree, x: -52.0, z: -18.5, yaw: 1.15),
    (kind: StructureKind.mapleCluster, x: -48.5, z: -38.0, yaw: -0.45),
    (kind: StructureKind.pineTree, x: -26.0, z: -42.0, yaw: 0.62),
    (kind: StructureKind.pineTree, x: -56.0, z: -54.0, yaw: 0.90),
    (kind: StructureKind.pineTree, x: -54.0, z: 2.5, yaw: 0.35),
    (kind: StructureKind.mapleCluster, x: -58.0, z: 18.0, yaw: -0.60),
    (kind: StructureKind.mapleCluster, x: -48.5, z: 29.0, yaw: 0.85),
    (kind: StructureKind.pineTree, x: -62.0, z: -8.5, yaw: -1.10),
    (kind: StructureKind.pineTree, x: -66.0, z: -32.0, yaw: 0.48),
    (kind: StructureKind.weepingWillow, x: -38.0, z: -2.0, yaw: -0.45),
    (kind: StructureKind.pineTree, x: -72.0, z: 12.0, yaw: -0.25),
    (kind: StructureKind.mapleCluster, x: -44.5, z: -8.5, yaw: 0.65),
    (kind: StructureKind.pineTree, x: -49.5, z: -11.5, yaw: -0.82),
    (kind: StructureKind.mapleCluster, x: -46.0, z: 4.5, yaw: 1.25),
    (kind: StructureKind.mapleCluster, x: -50.5, z: 12.5, yaw: -0.35),
    (kind: StructureKind.pineTree, x: -55.0, z: 26.5, yaw: 0.92),
    (kind: StructureKind.mapleCluster, x: -51.5, z: 19.5, yaw: -1.05),
    (kind: StructureKind.pineTree, x: -42.5, z: 27.5, yaw: 0.55),
    (kind: StructureKind.pineTree, x: -49.0, z: -22.5, yaw: -0.68),
    (kind: StructureKind.mapleCluster, x: -57.5, z: -28.0, yaw: 1.02),
    (kind: StructureKind.pineTree, x: -62.0, z: -42.0, yaw: -0.22),
    (kind: StructureKind.pineTree, x: -58.5, z: -6.0, yaw: 0.74),
    (kind: StructureKind.mapleCluster, x: -64.5, z: 4.0, yaw: -0.94),
    (kind: StructureKind.pineTree, x: -66.0, z: 22.0, yaw: 0.40),
    (kind: StructureKind.mapleCluster, x: -69.5, z: -18.5, yaw: -0.58),
    (kind: StructureKind.mapleCluster, x: -70.5, z: 32.0, yaw: 1.15),
    (kind: StructureKind.pineTree, x: -35.0, z: 21.5, yaw: -0.75),
    (kind: StructureKind.mapleCluster, x: -39.5, z: 25.0, yaw: 0.30),
    (kind: StructureKind.pineTree, x: -47.0, z: 1.5, yaw: -1.18),
    (kind: StructureKind.pineTree, x: -41.0, z: -19.5, yaw: 0.88),
    (kind: StructureKind.mapleCluster, x: -53.5, z: -46.5, yaw: -0.42),
    (kind: StructureKind.pineTree, x: -64.5, z: -21.0, yaw: 0.60),
    (kind: StructureKind.mapleCluster, x: -37.5, z: -29.5, yaw: -0.85),
    (kind: StructureKind.mapleCluster, x: -45.5, z: -44.0, yaw: 0.45),
    (kind: StructureKind.pineTree, x: -51.0, z: -31.5, yaw: 1.32),
    (kind: StructureKind.mapleCluster, x: -60.0, z: 9.5, yaw: -0.28),
    (kind: StructureKind.pineTree, x: -67.5, z: -2.0, yaw: 0.72),
    (kind: StructureKind.pineTree, x: -56.0, z: -14.0, yaw: -0.96),
    (kind: StructureKind.mapleCluster, x: -32.0, z: 32.5, yaw: 0.50),
    (kind: StructureKind.pineTree, x: -27.5, z: 31.5, yaw: -0.62),
    (kind: StructureKind.pineTree, x: -68.0, z: 42.0, yaw: 0.95),
    (kind: StructureKind.pineTree, x: -75.0, z: -35.0, yaw: 0.32),
    (kind: StructureKind.mapleCluster, x: -76.0, z: -22.0, yaw: -0.78),
    (kind: StructureKind.pineTree, x: -74.0, z: -10.0, yaw: 1.12),
    (kind: StructureKind.mapleCluster, x: -73.0, z: 4.0, yaw: -0.40),
    (kind: StructureKind.pineTree, x: -68.0, z: -40.0, yaw: 0.68),
    (kind: StructureKind.mapleCluster, x: -64.0, z: -12.0, yaw: -1.04),
    (kind: StructureKind.pineTree, x: -61.0, z: -36.0, yaw: 0.24),
    (kind: StructureKind.mapleCluster, x: -59.0, z: -20.0, yaw: 0.86),
    (kind: StructureKind.pineTree, x: -55.0, z: -41.0, yaw: -0.52),
    (kind: StructureKind.mapleCluster, x: -53.0, z: -5.0, yaw: 1.30),
    (kind: StructureKind.pineTree, x: -48.0, z: -16.0, yaw: -0.66),
    (kind: StructureKind.mapleCluster, x: -45.0, z: -38.0, yaw: 0.48),
    (kind: StructureKind.pineTree, x: -43.0, z: -22.0, yaw: -0.90),
    (kind: StructureKind.pineTree, x: -78.0, z: -28.0, yaw: 0.72),
  ]);

  // 5. Southern Bay & Pebble Cove Foothills (~24 trees framing south peninsula)
  addTreeGroup('minato_south_forest', const [
    (kind: StructureKind.mapleCluster, x: -34.0, z: 32.5, yaw: 1.02),
    (kind: StructureKind.pineTree, x: -22.0, z: 36.0, yaw: -0.35),
    (kind: StructureKind.pineTree, x: -12.5, z: 37.5, yaw: 0.72),
    (kind: StructureKind.mapleCluster, x: -4.5, z: 42.0, yaw: -0.82),
    (kind: StructureKind.pineTree, x: -44.0, z: 44.0, yaw: 0.56),
    (kind: StructureKind.mapleCluster, x: -58.0, z: 38.0, yaw: 1.24),
    (kind: StructureKind.pineTree, x: -32.0, z: 56.0, yaw: 0.34),
    (kind: StructureKind.mapleCluster, x: -14.0, z: 58.0, yaw: -1.05),
    (kind: StructureKind.pineTree, x: -62.0, z: 58.0, yaw: 0.68),
    (kind: StructureKind.pineTree, x: -26.5, z: 44.5, yaw: -0.48),
    (kind: StructureKind.mapleCluster, x: -18.5, z: 45.0, yaw: 0.92),
    (kind: StructureKind.pineTree, x: -9.5, z: 47.0, yaw: -0.70),
    (kind: StructureKind.mapleCluster, x: -36.5, z: 40.5, yaw: 0.38),
    (kind: StructureKind.mapleCluster, x: -38.5, z: 50.0, yaw: 1.18),
    (kind: StructureKind.pineTree, x: -49.5, z: 52.0, yaw: -0.25),
    (kind: StructureKind.mapleCluster, x: -52.5, z: 34.0, yaw: 0.64),
    (kind: StructureKind.pineTree, x: -22.5, z: 53.5, yaw: -0.92),
    (kind: StructureKind.weepingWillow, x: 1.8, z: 37.5, yaw: 0.45),
    (kind: StructureKind.pineTree, x: 6.5, z: 38.5, yaw: -0.55),
    (kind: StructureKind.mapleCluster, x: -3.5, z: 50.5, yaw: 0.82),
    (kind: StructureKind.pineTree, x: -15.5, z: 39.5, yaw: -1.10),
    (kind: StructureKind.pineTree, x: -45.5, z: 60.0, yaw: 0.28),
    (kind: StructureKind.mapleCluster, x: -28.0, z: 62.5, yaw: -0.60),
    (kind: StructureKind.pineTree, x: -8.0, z: 59.5, yaw: 1.05),
  ], minGroundY: 0.85);

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

  final items = <MinatoHeroPlacement>[
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
      y: -0.59,
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
      z: 20.6,
      yaw: -0.28,
      y: groundPlus(0.3, 20.6),
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
      x: 0.35,
      z: 15.2,
      yaw: -0.4,
      y: groundPlus(0.35, 15.2),
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
      x: -15.5,
      z: 10.6,
      yaw: -0.35,
      y: groundPlus(-15.5, 10.6),
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
      y: 0.73,
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

    // Minato Boulevard, Market Square & Quay Props
    (
      name: 'minato_wagon_west_bvd',
      assetPath: 'assets/models/edo_wagon.glb',
      x: -23,
      z: 13,
      yaw: 1.38,
      y: groundPlus(-23, 13, 0),
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
      x: -17.2,
      z: 11.4,
      yaw: -1.10,
      y: groundPlus(-17.2, 11.4, 0),
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
      x: -9.4,
      z: 9.6,
      yaw: 0,
      y: groundPlus(-9.4, 9.6, 0),
    ),
    (
      name: 'minato_fence_gate_castle',
      assetPath: 'assets/models/edo_wooden_fence_gate.glb',
      x: -16.2,
      z: -16.8,
      yaw: 0.20,
      y: groundPlus(-16.2, -16.8, 0),
    ),
    (
      name: 'minato_fence_gate_kura',
      assetPath: 'assets/models/edo_wooden_fence_gate.glb',
      x: -9.6,
      z: 28.2,
      yaw: 0.05,
      y: groundPlus(-9.6, 28.2, 0),
    ),
    (
      name: 'minato_fence_gate_shrine',
      assetPath: 'assets/models/edo_wooden_fence_gate.glb',
      x: -24.8,
      z: -11.4,
      yaw: math.pi / 2 - 0.15,
      y: groundPlus(-24.8, -11.4, 0),
    ),
    (
      name: 'minato_clutter_hiroba_w',
      assetPath: 'assets/models/edo_street_clutter.glb',
      x: -17.2,
      z: 14.2,
      yaw: 0.55,
      y: groundPlus(-17.2, 14.2, 0),
    ),
    (
      name: 'minato_clutter_quay_south',
      assetPath: 'assets/models/edo_street_clutter.glb',
      x: -0.8,
      z: 23.8,
      yaw: -0.82,
      y: groundPlus(-0.8, 23.8, 0),
    ),
    (
      name: 'minato_clutter_south_alley',
      assetPath: 'assets/models/edo_street_clutter.glb',
      x: -14.8,
      z: 21.8,
      yaw: 1.45,
      y: groundPlus(-14.8, 21.8, 0),
    ),
    (
      name: 'minato_clutter_north_quay',
      assetPath: 'assets/models/edo_street_clutter.glb',
      x: -0.6,
      z: -7.2,
      yaw: 0.25,
      y: groundPlus(-0.6, -7.2, 0),
    ),
  ];

  // Anchor seawall shoulders and natural cove shorelines along tidal contours.
  double? findShoreX(
    double z, {
    double xMin = -35.0,
    double xMax = 26.0,
    double targetY = 0.22,
  }) {
    for (var x = xMax; x >= xMin; x -= 0.5) {
      if (sampleGroundY(x, z) >= targetY) {
        return x;
      }
    }
    return null;
  }

  const shoreShelves =
      <
        ({
          String name,
          String asset,
          double z,
          double targetY,
          double dy,
          double yaw,
        })
      >[
        (
          name: 'minato_seawall_shoulder_n1',
          asset: 'assets/models/rock_coastal_shelf.glb',
          z: -11.4,
          targetY: 0.30,
          dy: -0.22,
          yaw: 0.32,
        ),
        (
          name: 'minato_seawall_shoulder_n2',
          asset: 'assets/models/rock_shore_riprap.glb',
          z: -13.2,
          targetY: 0.12,
          dy: -0.32,
          yaw: -0.55,
        ),
        (
          name: 'minato_seawall_shoulder_s1',
          asset: 'assets/models/rock_coastal_shelf.glb',
          z: 32.0,
          targetY: 0.30,
          dy: -0.22,
          yaw: -0.28,
        ),
        (
          name: 'minato_seawall_shoulder_s2',
          asset: 'assets/models/rock_river_boulder.glb',
          z: 33.4,
          targetY: 0.14,
          dy: -0.18,
          yaw: 0.88,
        ),
        (
          name: 'minato_shore_shelf_n3',
          asset: 'assets/models/rock_coastal_shelf.glb',
          z: -47.5,
          targetY: 0.24,
          dy: -0.20,
          yaw: 0.65,
        ),
        (
          name: 'minato_shore_boulder_n4',
          asset: 'assets/models/rock_river_boulder.glb',
          z: -50.2,
          targetY: 0.08,
          dy: -0.14,
          yaw: -1.10,
        ),
        (
          name: 'minato_shore_shelf_n5',
          asset: 'assets/models/rock_coastal_shelf.glb',
          z: -53.8,
          targetY: 0.22,
          dy: -0.20,
          yaw: -0.42,
        ),
        (
          name: 'minato_shore_riprap_n6',
          asset: 'assets/models/rock_shore_riprap.glb',
          z: -58.2,
          targetY: 0.12,
          dy: -0.28,
          yaw: 1.05,
        ),
        (
          name: 'minato_shore_shelf_n7',
          asset: 'assets/models/rock_coastal_shelf.glb',
          z: -63.0,
          targetY: 0.24,
          dy: -0.20,
          yaw: 0.18,
        ),
        (
          name: 'minato_shore_shelf_s3',
          asset: 'assets/models/rock_coastal_shelf.glb',
          z: 35.8,
          targetY: 0.22,
          dy: -0.18,
          yaw: 0.74,
        ),
        (
          name: 'minato_shore_boulder_s4',
          asset: 'assets/models/rock_river_boulder.glb',
          z: 39.2,
          targetY: 0.08,
          dy: -0.14,
          yaw: -0.92,
        ),
        (
          name: 'minato_shore_shelf_s5',
          asset: 'assets/models/rock_coastal_shelf.glb',
          z: 43.4,
          targetY: 0.22,
          dy: -0.20,
          yaw: 1.38,
        ),
        (
          name: 'minato_shore_riprap_s6',
          asset: 'assets/models/rock_shore_riprap.glb',
          z: 47.8,
          targetY: 0.12,
          dy: -0.26,
          yaw: -0.30,
        ),
        (
          name: 'minato_shore_shelf_s7',
          asset: 'assets/models/rock_coastal_shelf.glb',
          z: 52.6,
          targetY: 0.24,
          dy: -0.20,
          yaw: 0.52,
        ),
        (
          name: 'minato_shore_boulder_s8',
          asset: 'assets/models/rock_river_boulder.glb',
          z: 57.5,
          targetY: 0.10,
          dy: -0.15,
          yaw: -1.25,
        ),
        (
          name: 'minato_shore_stairs_n',
          asset: 'assets/models/edo_river_stairs.glb',
          z: -48.6,
          targetY: 0.45,
          dy: -0.08,
          yaw: 1.45,
        ),
        (
          name: 'minato_shore_stairs_s',
          asset: 'assets/models/edo_river_stairs.glb',
          z: 34.4,
          targetY: 0.45,
          dy: -0.08,
          yaw: 1.72,
        ),
      ];

  for (final s in shoreShelves) {
    final sx = findShoreX(s.z, targetY: s.targetY);
    if (sx == null) {
      continue;
    }
    items.add((
      name: s.name,
      assetPath: s.asset,
      x: sx,
      z: s.z,
      yaw: s.yaw,
      y: groundPlus(sx, s.z, s.dy),
    ));
  }

  // Dense lush coastal & hillside shrub clusters anchored on firm upper slopes.
  const shrubCoords = <({double x, double z, double yaw})>[
    (x: -24.2, z: 18.8, yaw: 0.4),
    (x: -17.6, z: -1.5, yaw: 1.2),
    (x: -16.8, z: 18.8, yaw: -0.6),
    (x: -10.8, z: 1.4, yaw: 2.1),
    (x: -25.2, z: -12.6, yaw: 0.8),
    (x: -31.8, z: -4.5, yaw: -1.4),
    (x: -32.4, z: 3.2, yaw: 1.9),
    (x: -13.6, z: 30.8, yaw: 0.3),
    (x: -5.2, z: -14.2, yaw: -0.9),
    (x: -14.8, z: -24.8, yaw: 1.5),
    (x: -16.4, z: -33.2, yaw: -0.4),
    (x: -18.2, z: -41.5, yaw: 2.4),
    (x: 3.2, z: -44.2, yaw: 0.7),
    (x: 13.8, z: -44.0, yaw: -1.2),
    (x: 5.5, z: -13.6, yaw: 1.1),
    (x: 16.5, z: -14.2, yaw: -0.5),
    (x: -9.8, z: -46.8, yaw: 2.0),
    (x: -18.5, z: -51.5, yaw: 0.2),
    (x: -26.5, z: -53.0, yaw: -1.8),
    (x: -34.0, z: -48.0, yaw: 0.9),
    (x: -35.8, z: -22.5, yaw: -0.7),
    (x: -41.5, z: -15.5, yaw: 1.6),
    (x: -46.5, z: -29.0, yaw: -2.2),
    (x: -50.0, z: -16.0, yaw: 0.5),
    (x: -45.0, z: 6.5, yaw: 1.3),
    (x: -48.0, z: 22.5, yaw: -0.8),
    (x: -53.5, z: 4.5, yaw: 2.6),
    (x: -55.0, z: 16.5, yaw: -1.1),
    (x: -37.5, z: 24.5, yaw: 0.6),
    (x: -30.5, z: 31.2, yaw: 1.8),
    (x: -21.5, z: 34.5, yaw: -0.3),
    (x: -11.5, z: 36.2, yaw: 2.2),
    (x: -3.2, z: 35.5, yaw: -1.5),
    (x: 9.8, z: 33.0, yaw: 0.4),
    (x: 1.5, z: 40.5, yaw: 1.4),
    (x: -16.5, z: 43.2, yaw: -0.9),
    (x: -34.5, z: 42.5, yaw: 2.0),
    (x: -41.8, z: 34.5, yaw: -0.2),
  ];

  for (var i = 0; i < shrubCoords.length; i++) {
    final s = shrubCoords[i];
    final gy = sampleGroundY(s.x, s.z);
    if (gy < 0.70) {
      continue;
    }
    items.add((
      name: 'minato_shrub_cluster_$i',
      assetPath: 'assets/models/tree_shrub_cluster.glb',
      x: s.x,
      z: s.z,
      yaw: s.yaw,
      y: gy - 0.03,
    ));
  }

  return items;
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
    position: Vec3(1.9, sampleGroundY(1.9, -6.5), -6.5),
    waypoints: [
      Vec3(1.9, sampleGroundY(1.9, -6.5), -6.5),
      Vec3(1.9, sampleGroundY(1.9, 5.5), 5.5),
      Vec3(2, sampleGroundY(2, 17.4), 17.4),
      Vec3(2, sampleGroundY(2, 25.5), 25.5),
      Vec3(2, sampleGroundY(2, 17.4), 17.4),
      Vec3(1.9, sampleGroundY(1.9, 5.5), 5.5),
    ],
    carriesLantern: false,
    speed: 1.50,
    bobPhase: 0,
  ),
  (
    id: EntityId.validated('minato_watchman_quay'),
    role: StreetAgentRole.lanternWatchman,
    position: Vec3(-14.5, sampleGroundY(-14.5, 8.2), 8.2),
    waypoints: [
      Vec3(-32, sampleGroundY(-32, 11.4), 11.4),
      Vec3(-22, sampleGroundY(-22, 10.6), 10.6),
      Vec3(-14.5, sampleGroundY(-14.5, 8.2), 8.2),
      Vec3(-7.2, sampleGroundY(-7.2, 6.2), 6.2),
      Vec3(1.8, sampleGroundY(1.8, 5.5), 5.5),
      Vec3(-7.2, sampleGroundY(-7.2, 6.2), 6.2),
      Vec3(-14.5, sampleGroundY(-14.5, 8.2), 8.2),
      Vec3(-22, sampleGroundY(-22, 10.6), 10.6),
    ],
    carriesLantern: true,
    speed: 1.35,
    bobPhase: 1.2,
  ),
  (
    id: EntityId.validated('minato_castle_courier'),
    role: StreetAgentRole.nightSmuggler,
    position: Vec3(-11.2, sampleGroundY(-11.2, -2.5), -2.5),
    waypoints: [
      Vec3(-9.5, sampleGroundY(-9.5, 6.8), 6.8),
      Vec3(-11.2, sampleGroundY(-11.2, -2.5), -2.5),
      Vec3(-11.6, sampleGroundY(-11.6, -11.5), -11.5),
      Vec3(-12.8, sampleGroundY(-12.8, -16.8), -16.8),
      Vec3(-11.6, sampleGroundY(-11.6, -11.5), -11.5),
      Vec3(-11.2, sampleGroundY(-11.2, -2.5), -2.5),
    ],
    carriesLantern: false,
    speed: 1.48,
    bobPhase: 2.3,
  ),
  (
    id: EntityId.validated('minato_merchant_alley'),
    role: StreetAgentRole.townsfolk,
    position: Vec3(-14.8, sampleGroundY(-14.8, 19.8), 19.8),
    waypoints: [
      Vec3(-24.2, sampleGroundY(-24.2, 20.8), 20.8),
      Vec3(-14.8, sampleGroundY(-14.8, 19.8), 19.8),
      Vec3(-6.2, sampleGroundY(-6.2, 19.9), 19.9),
      Vec3(-5.8, sampleGroundY(-5.8, 17.6), 17.6),
      Vec3(1.9, sampleGroundY(1.9, 17.4), 17.4),
      Vec3(-5.8, sampleGroundY(-5.8, 17.6), 17.6),
      Vec3(-6.2, sampleGroundY(-6.2, 19.9), 19.9),
      Vec3(-14.8, sampleGroundY(-14.8, 19.8), 19.8),
    ],
    carriesLantern: false,
    speed: 1.32,
    bobPhase: 0.7,
  ),
  (
    id: EntityId.validated('minato_hiroba_shopper'),
    role: StreetAgentRole.townsfolk,
    position: Vec3(-15.5, sampleGroundY(-15.5, 8.6), 8.6),
    waypoints: [
      Vec3(-15.5, sampleGroundY(-15.5, 8.6), 8.6),
      Vec3(-12.8, sampleGroundY(-12.8, 9.6), 9.6),
      Vec3(-11.2, sampleGroundY(-11.2, 8.2), 8.2),
      Vec3(-13.6, sampleGroundY(-13.6, 7.6), 7.6),
    ],
    carriesLantern: false,
    speed: 1.15,
    bobPhase: 3.1,
  ),
  (
    id: EntityId.validated('minato_porter_warehouse'),
    role: StreetAgentRole.nightSmuggler,
    position: Vec3(-6, sampleGroundY(-6, 26.5), 26.5),
    waypoints: [
      Vec3(-6, sampleGroundY(-6, 26.5), 26.5),
      Vec3(-6, sampleGroundY(-6, 22.8), 22.8),
      Vec3(-6.2, sampleGroundY(-6.2, 19.9), 19.9),
      Vec3(-5.8, sampleGroundY(-5.8, 17.6), 17.6),
      Vec3(2, sampleGroundY(2, 17.4), 17.4),
      Vec3(2, sampleGroundY(2, 26.5), 26.5),
      Vec3(2, sampleGroundY(2, 17.4), 17.4),
      Vec3(-5.8, sampleGroundY(-5.8, 17.6), 17.6),
      Vec3(-6.2, sampleGroundY(-6.2, 19.9), 19.9),
      Vec3(-6, sampleGroundY(-6, 22.8), 22.8),
    ],
    carriesLantern: false,
    speed: 1.25,
    bobPhase: 4,
  ),
  (
    id: EntityId.validated('minato_shrine_monk'),
    role: StreetAgentRole.townsfolk,
    position: Vec3(-19.8, sampleGroundY(-19.8, -7.8), -7.8),
    waypoints: [
      Vec3(-19.8, sampleGroundY(-19.8, -7.8), -7.8),
      Vec3(-22.6, sampleGroundY(-22.6, -7.8), -7.8),
      Vec3(-22.4, sampleGroundY(-22.4, -13), -13),
      Vec3(-22.6, sampleGroundY(-22.6, -7.8), -7.8),
    ],
    carriesLantern: false,
    speed: 1.12,
    bobPhase: 1.8,
  ),
  (
    id: EntityId.validated('minato_watchman_upper'),
    role: StreetAgentRole.lanternWatchman,
    position: Vec3(-22, sampleGroundY(-22, 10.6), 10.6),
    waypoints: [
      Vec3(-41.5, sampleGroundY(-41.5, 14.5), 14.5),
      Vec3(-32, sampleGroundY(-32, 11.4), 11.4),
      Vec3(-22, sampleGroundY(-22, 10.6), 10.6),
      Vec3(-19.4, sampleGroundY(-19.4, 12.6), 12.6),
      Vec3(-19.2, sampleGroundY(-19.2, 19.6), 19.6),
      Vec3(-19.4, sampleGroundY(-19.4, 12.6), 12.6),
      Vec3(-22, sampleGroundY(-22, 10.6), 10.6),
      Vec3(-32, sampleGroundY(-32, 11.4), 11.4),
    ],
    carriesLantern: true,
    speed: 1.30,
    bobPhase: 2.9,
  ),
  (
    id: EntityId.validated('minato_samurai_otemon'),
    role: StreetAgentRole.nightSmuggler,
    position: Vec3(-13, sampleGroundY(-13, -18.8), -18.8),
    waypoints: [
      Vec3(-12.6, sampleGroundY(-12.6, -13.8), -13.8),
      Vec3(-13, sampleGroundY(-13, -18.8), -18.8),
      Vec3(-13, sampleGroundY(-13, -22.2), -22.2),
      Vec3(-13, sampleGroundY(-13, -18.8), -18.8),
    ],
    carriesLantern: false,
    speed: 1.22,
    bobPhase: 0.4,
  ),
  (
    id: EntityId.validated('minato_townswoman_cross'),
    role: StreetAgentRole.townsfolk,
    position: Vec3(-19.4, sampleGroundY(-19.4, 2.6), 2.6),
    waypoints: [
      Vec3(-19.6, sampleGroundY(-19.6, -3.5), -3.5),
      Vec3(-19.4, sampleGroundY(-19.4, 2.6), 2.6),
      Vec3(-19.4, sampleGroundY(-19.4, 8.4), 8.4),
      Vec3(-14.5, sampleGroundY(-14.5, 8.2), 8.2),
      Vec3(-19.4, sampleGroundY(-19.4, 8.4), 8.4),
      Vec3(-19.4, sampleGroundY(-19.4, 2.6), 2.6),
    ],
    carriesLantern: false,
    speed: 1.28,
    bobPhase: 5.1,
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
