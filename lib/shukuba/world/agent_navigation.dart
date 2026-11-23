import 'dart:math' as math;

import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show GroundHeightSampler, ShowcaseRealm, ShukubaGraph, StructureKind, Vec3;
import 'package:kage_no_machi/shukuba/world/minato_jo_ward.dart'
    show buildMinatoCastleAndHarborPlacements;
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart'
    show TerrainConfig;

const double kAgentCollisionRadius = 0.36;
const double kAgentAvoidanceMargin = 0.55;

typedef ShukubaHeroPropPlacement = ({
  String name,
  String assetPath,
  double x,
  double z,
  double yaw,
  double yOffset,
  double scale,
});

/// Returns static GLB prop placements for Shukuba Valley.
List<ShukubaHeroPropPlacement> buildShukubaHeroPropPlacements(
  GroundHeightSampler sampleGroundHeight,
) {
  double rx(double z, double dx) => TerrainConfig.riverCenterX(z) + dx;
  double waterYOffset(double x, double z, double delta) =>
      TerrainConfig.waterSurfaceElevation - sampleGroundHeight(x, z) + delta;

  final placements = <ShukubaHeroPropPlacement>[
    (
      name: 'hero_distant_pagoda',
      assetPath: 'assets/models/edo_distant_pagoda.glb',
      x: 68,
      z: -21,
      yaw: 0.42,
      yOffset: -0.35,
      scale: 1,
    ),
    (
      name: 'hero_stone_lantern_bridge_w',
      assetPath: 'assets/models/edo_stone_lantern.glb',
      x: -6.35,
      z: 2.35,
      yaw: 0,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_stone_lantern_bridge_e',
      assetPath: 'assets/models/edo_stone_lantern.glb',
      x: 6.15,
      z: 2.30,
      yaw: 3.14,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_stone_lantern_torii_n',
      assetPath: 'assets/models/edo_stone_lantern.glb',
      x: -22.8,
      z: 2.85,
      yaw: 0.10,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_stone_lantern_torii_s',
      assetPath: 'assets/models/edo_stone_lantern.glb',
      x: -22.8,
      z: -2.85,
      yaw: -0.10,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_handcart_west',
      assetPath: 'assets/models/edo_handcart.glb',
      x: -14.8,
      z: -2.35,
      yaw: 0.25,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_handcart_east',
      assetPath: 'assets/models/edo_handcart.glb',
      x: 22.6,
      z: 2.15,
      yaw: -0.35,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_sake_barrels_chaya',
      assetPath: 'assets/models/edo_sake_barrels.glb',
      x: -8.5,
      z: 3.35,
      yaw: 0.40,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_sake_barrels_market',
      assetPath: 'assets/models/edo_sake_barrels.glb',
      x: 10.4,
      z: -2.55,
      yaw: -0.30,
      yOffset: 0,
      scale: 1,
    ),
    // Stone water-stairs seated flush on west bank into shallow water
    (
      name: 'hero_river_stairs_nw',
      assetPath: 'assets/models/edo_river_stairs.glb',
      x: rx(-14.6, -3.15),
      z: -14.6,
      yaw: -0.18,
      yOffset:
          sampleGroundHeight(rx(-14.6, -4.38), -14.6) -
          sampleGroundHeight(rx(-14.6, -3.15), -14.6) -
          0.04,
      scale: 1,
    ),
    (
      name: 'hero_river_stairs_sw',
      assetPath: 'assets/models/edo_river_stairs.glb',
      x: rx(11.4, -3.15),
      z: 11.4,
      yaw: -0.22,
      yOffset:
          sampleGroundHeight(rx(11.4, -4.38), 11.4) -
          sampleGroundHeight(rx(11.4, -3.15), 11.4) -
          0.04,
      scale: 1,
    ),
    // Street life props (wagons, wagasa benches, andon, nobori).
    (
      name: 'hero_wagon_west',
      assetPath: 'assets/models/edo_wagon.glb',
      x: -20.4,
      z: -2.45,
      yaw: 1.42,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_wagon_east',
      assetPath: 'assets/models/edo_wagon.glb',
      x: 16.4,
      z: 2.45,
      yaw: -1.52,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_wagasa_west_chaya',
      assetPath: 'assets/models/edo_wagasa_bench.glb',
      x: -8.6,
      z: 4.15,
      yaw: 0.35,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_wagasa_east_alley',
      assetPath: 'assets/models/edo_wagasa_bench.glb',
      x: 13.4,
      z: 4.4,
      yaw: -1.25,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_andon_west_1',
      assetPath: 'assets/models/edo_andon_lantern.glb',
      x: -14.2,
      z: 2.95,
      yaw: 0,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_andon_east_1',
      assetPath: 'assets/models/edo_andon_lantern.glb',
      x: 10.2,
      z: -2.95,
      yaw: 3.14,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_nobori_west',
      assetPath: 'assets/models/edo_nobori_banner.glb',
      x: -14,
      z: 4.25,
      yaw: 0.12,
      yOffset: 0,
      scale: 1,
    ),
    (
      name: 'hero_nobori_east',
      assetPath: 'assets/models/edo_nobori_banner.glb',
      x: 9.8,
      z: 2.85,
      yaw: 3.05,
      yOffset: 0,
      scale: 1,
    ),
  ];

  // 14 shallow waterline cobble bars + bridge abutment cobble bars along z.
  const cobbleBarSpecs =
      <(String name, double z, double dx, double yaw, double wDelta, double s)>[
        ('hero_river_cobble_bar_01', -54.0, -3.55, 0.24, -0.07, 1.16),
        ('hero_river_cobble_bar_02', -46.5, 3.30, -0.48, -0.08, 1.04),
        ('hero_river_cobble_bar_03', -40.5, -3.40, 0.92, -0.06, 1.22),
        ('hero_river_cobble_bar_04', -31.0, 3.05, -1.18, -0.09, 0.96),
        ('hero_river_cobble_bar_05', -28.0, -2.95, 0.44, -0.10, 1.08),
        ('hero_river_cobble_bar_06', -21.8, 2.75, 2.15, -0.08, 0.90),
        ('hero_river_cobble_bar_07', -13.0, 2.60, -0.22, -0.09, 0.84),
        ('hero_river_cobble_bridge_se', -3.9, 2.55, 0.54, -0.09, 0.86),
        ('hero_river_cobble_bridge_nw', 3.9, -2.55, -0.42, -0.09, 0.86),
        ('hero_river_cobble_bar_10', 15.6, 2.60, 1.75, -0.08, 0.94),
        ('hero_river_cobble_bar_11', 17.8, -2.75, 0.14, -0.11, 1.02),
        ('hero_river_cobble_bar_12', 27.6, 2.90, -0.84, -0.07, 1.18),
        ('hero_river_cobble_bar_13', 40.2, -3.15, 1.32, -0.06, 1.24),
        ('hero_river_cobble_bar_14', 55.5, 3.30, -2.04, -0.08, 1.12),
      ];
  for (final spec in cobbleBarSpecs) {
    final x = rx(spec.$2, spec.$3);
    placements.add((
      name: spec.$1,
      assetPath: 'assets/models/rock_river_cobble_bar.glb',
      x: x,
      z: spec.$2,
      yaw: spec.$4,
      yOffset: waterYOffset(x, spec.$2, spec.$5),
      scale: spec.$6,
    ));
  }

  // 13 mossy granite bank ledges anchoring bends, town banks & shoulders.
  const bankLedgeSpecs =
      <(String name, double z, double dx, double yaw, double s)>[
        ('hero_bank_ledge_01', -48.5, -4.45, 0.18, 1.12),
        ('hero_bank_ledge_02', -40.8, 4.15, 2.88, 1.04),
        ('hero_bank_ledge_03', -32.6, -4.15, -0.26, 0.96),
        ('hero_bank_ledge_04', -26.8, 3.85, -2.74, 1.08),
        ('hero_bank_ledge_05', -22.2, -3.65, 0.34, 0.88),
        ('hero_bank_ledge_town_nw', -7.6, -3.30, 0.22, 0.84),
        ('hero_bank_ledge_town_sw', 7.7, -3.40, -0.18, 0.84),
        ('hero_bank_ledge_town_se', 5.2, 3.15, 2.84, 0.82),
        ('hero_bank_ledge_06', 11.6, 3.20, 3.04, 0.82),
        ('hero_bank_ledge_07', 21.4, 3.35, -2.86, 0.94),
        ('hero_bank_ledge_08', 25.4, -3.65, -0.16, 1.06),
        ('hero_bank_ledge_09', 38.6, 4.05, 2.68, 1.16),
        ('hero_bank_ledge_10', 49.0, -4.15, 0.42, 1.14),
      ];
  for (final spec in bankLedgeSpecs) {
    final x = rx(spec.$2, spec.$3);
    placements.add((
      name: spec.$1,
      assetPath: 'assets/models/rock_bank_ledge.glb',
      x: x,
      z: spec.$2,
      yaw: spec.$4,
      yOffset: -0.22,
      scale: spec.$5,
    ));
  }

  // 8 sculpted bank boulders & riprap clusters + 7 emergent mid-stream shoals.
  const bankClusterSpecs =
      <(String name, String asset, double z, double dx, double yaw, double s)>[
        (
          'hero_shore_riprap_s1',
          'assets/models/rock_shore_riprap.glb',
          -51.2,
          3.40,
          0.72,
          1.06,
        ),
        (
          'hero_shore_boulder_s2',
          'assets/models/rock_river_boulder.glb',
          -44.6,
          -3.85,
          0.64,
          0.98,
        ),
        (
          'hero_shore_boulder_s1',
          'assets/models/rock_river_boulder.glb',
          -35.5,
          3.25,
          -1.14,
          0.94,
        ),
        (
          'hero_shore_riprap_e1',
          'assets/models/rock_shore_riprap.glb',
          -16.8,
          2.75,
          -0.68,
          0.86,
        ),
        (
          'hero_shore_boulder_town_e',
          'assets/models/rock_river_boulder.glb',
          -8.4,
          2.65,
          1.45,
          0.82,
        ),
        (
          'hero_shore_boulder_n1',
          'assets/models/rock_river_boulder.glb',
          31.8,
          -3.35,
          0.56,
          1.04,
        ),
        (
          'hero_shore_boulder_n2',
          'assets/models/rock_river_boulder.glb',
          45.2,
          3.60,
          -0.92,
          1.10,
        ),
        (
          'hero_shore_riprap_n2',
          'assets/models/rock_shore_riprap.glb',
          32.4,
          3.15,
          1.62,
          0.96,
        ),
      ];
  for (final spec in bankClusterSpecs) {
    final x = rx(spec.$3, spec.$4);
    placements.add((
      name: spec.$1,
      assetPath: spec.$2,
      x: x,
      z: spec.$3,
      yaw: spec.$5,
      yOffset: -0.18,
      scale: spec.$6,
    ));
  }

  const streamShoalSpecs =
      <(String name, double z, double dx, double yaw, double s)>[
        ('hero_stream_shoal_s3', -36.5, -0.75, 0.48, 0.92),
        ('hero_stream_shoal_s2', -24.5, -0.60, -1.12, 1.05),
        ('hero_stream_shoal_n2', -18.5, -0.75, 1.25, 0.86),
        ('hero_stream_shoal_n', -11.4, -0.85, 0.58, 0.82),
        ('hero_stream_shoal_s', 8.6, 0.35, -0.78, 0.78),
        ('hero_stream_shoal_n3', 21.5, -0.55, 1.94, 0.98),
        ('hero_stream_shoal_n4', 35.0, -0.50, -0.42, 1.14),
      ];
  for (final spec in streamShoalSpecs) {
    final x = rx(spec.$2, spec.$3);
    placements.add((
      name: spec.$1,
      assetPath: 'assets/models/rock_river_boulder.glb',
      x: x,
      z: spec.$2,
      yaw: spec.$4,
      yOffset: waterYOffset(x, spec.$2, -0.14),
      scale: spec.$5,
    ));
  }

  // 12 lush bankside shrub clusters framing upper ledges & river bends.
  const bankShrubSpecs =
      <(String name, double z, double dx, double yaw, double s)>[
        ('hero_bank_shrub_01', -45.5, -6.2, 0.42, 1.04),
        ('hero_bank_shrub_02', -47.0, 5.8, -1.15, 0.92),
        ('hero_bank_shrub_03', -36.5, -5.8, 2.08, 0.88),
        ('hero_bank_shrub_04', -38.0, 5.8, -0.54, 1.08),
        ('hero_bank_shrub_05', -29.0, 6.2, 1.44, 0.84),
        ('hero_bank_shrub_06', -20.2, -5.8, -2.18, 0.96),
        ('hero_bank_shrub_07', 14.8, -5.2, 0.78, 0.76),
        ('hero_bank_shrub_08', 24.5, 5.4, -1.62, 1.02),
        ('hero_bank_shrub_09', 28.2, -5.6, 2.46, 0.94),
        ('hero_bank_shrub_10', 39.2, 6.2, -0.32, 1.10),
        ('hero_bank_shrub_11', 52.5, -6.0, 1.18, 0.90),
        ('hero_bank_shrub_12', 48.0, 6.2, -2.42, 1.06),
      ];
  for (final spec in bankShrubSpecs) {
    final x = rx(spec.$2, spec.$3);
    placements.add((
      name: spec.$1,
      assetPath: 'assets/models/tree_shrub_cluster.glb',
      x: x,
      z: spec.$2,
      yaw: spec.$4,
      yOffset: -0.10,
      scale: spec.$5,
    ));
  }

  return placements;
}

class AgentObbObstacle {
  const new({
    required this.cx,
    required this.cz,
    required this.yawRadians,
    required this.halfX,
    required this.halfZ,
    required this.label,
  });

  final double cx;
  final double cz;
  final double yawRadians;
  final double halfX;
  final double halfZ;
  final String label;
}

class AgentWallCapsule {
  const new({
    required this.ax,
    required this.az,
    required this.bx,
    required this.bz,
    required this.radius,
    required this.label,
  });

  final double ax;
  final double az;
  final double bx;
  final double bz;
  final double radius;
  final String label;
}

class AgentCircleObstacle {
  const new({
    required this.cx,
    required this.cz,
    required this.radius,
    required this.label,
  });

  final double cx;
  final double cz;
  final double radius;
  final String label;
}

typedef _SurfaceSample = ({
  double clearance,
  double nx,
  double nz,
  String label,
});

/// 2D horizontal obstacle & water collision map for street agent navigation.
class AgentObstacleMap {
  const new _({
    required this.obbs,
    required this.walls,
    required this.circles,
    required this._realm,
    required this._sampleGroundHeight,
  });

  factory build({
    required ShukubaGraph graph,
    required ShowcaseRealm realm,
    required double Function(double x, double z) sampleGroundHeight,
  }) {
    final obbs = <AgentObbObstacle>[];
    final walls = <AgentWallCapsule>[];
    final circles = <AgentCircleObstacle>[];

    for (final structure in graph.structures.values) {
      switch (structure.kind) {
        case StructureKind.toriiGate:
          for (final side in const <double>[-1.68, 1.68]) {
            final pillar =
                structure.position +
                Vec3(side, 0, 0).rotateY(structure.yawRadians);
            circles.add(
              AgentCircleObstacle(
                cx: pillar.x,
                cz: pillar.z,
                radius: 0.28,
                label: structure.id.value,
              ),
            );
          }
        case StructureKind.pineTree:
        case StructureKind.mapleCluster:
        case StructureKind.weepingWillow:
          circles.add(
            AgentCircleObstacle(
              cx: structure.position.x,
              cz: structure.position.z,
              radius: 0.45,
              label: structure.id.value,
            ),
          );
        case StructureKind.bambooGrove:
          circles.add(
            AgentCircleObstacle(
              cx: structure.position.x,
              cz: structure.position.z,
              radius: 0.90,
              label: structure.id.value,
            ),
          );
        case StructureKind.machiya:
        case StructureKind.minka:
        case StructureKind.chaya:
        case StructureKind.kura:
        case StructureKind.marketStall:
        case StructureKind.shoroBell:
        case StructureKind.stoneWell:
        case StructureKind.karesansuiGarden:
        case StructureKind.yaguraTower:
        case StructureKind.rockOutcrop:
          final (halfX, halfZ) = _structureHalfExtents(
            structure.kind,
            structure.spec.footprintWidth * 0.5,
            structure.spec.footprintDepth * 0.5,
          );
          obbs.add(
            AgentObbObstacle(
              cx: structure.position.x,
              cz: structure.position.z,
              yawRadians: structure.yawRadians,
              halfX: halfX,
              halfZ: halfZ,
              label: structure.id.value,
            ),
          );
      }
    }

    for (final wall in graph.walls) {
      final radius = wall.thicknessMeters * 0.5 + 0.12;
      for (var i = 0; i < wall.controlPoints.length - 1; i++) {
        final p0 = wall.controlPoints[i];
        final p1 = wall.controlPoints[i + 1];
        walls.add(
          AgentWallCapsule(
            ax: p0.x,
            az: p0.z,
            bx: p1.x,
            bz: p1.z,
            radius: radius,
            label: wall.id.value,
          ),
        );
      }
    }

    if (realm == ShowcaseRealm.minatoJo) {
      obbs
        ..add(
          const AgentObbObstacle(
            cx: 11.5,
            cz: -28.25,
            yawRadians: 0,
            halfX: 16.5,
            halfZ: 17.2,
            label: 'minato_castle_honmaru',
          ),
        )
        ..add(
          const AgentObbObstacle(
            cx: -8.5,
            cz: -19.5,
            yawRadians: math.pi / 2,
            halfX: 6.5,
            halfZ: 2.75,
            label: 'minato_castle_otemon_gate',
          ),
        );
      for (final item in buildMinatoCastleAndHarborPlacements(
        sampleGroundHeight,
      )) {
        _addHeroPropObstacle(
          name: item.name,
          assetPath: item.assetPath,
          x: item.x,
          z: item.z,
          yaw: item.yaw,
          circleRadius: 0.52,
          obbs: obbs,
          circles: circles,
        );
      }
    } else {
      for (final item in buildShukubaHeroPropPlacements(sampleGroundHeight)) {
        _addHeroPropObstacle(
          name: item.name,
          assetPath: item.assetPath,
          x: item.x,
          z: item.z,
          yaw: item.yaw,
          circleRadius: 0.50,
          obbs: obbs,
          circles: circles,
        );
      }
    }

    return AgentObstacleMap._(
      obbs: List.unmodifiable(obbs),
      walls: List.unmodifiable(walls),
      circles: List.unmodifiable(circles),
      realm: realm,
      sampleGroundHeight: sampleGroundHeight,
    );
  }

  final List<AgentObbObstacle> obbs;
  final List<AgentWallCapsule> walls;
  final List<AgentCircleObstacle> circles;
  final ShowcaseRealm _realm;
  final GroundHeightSampler _sampleGroundHeight;

  static (double, double) _structureHalfExtents(
    StructureKind kind,
    double specHalfX,
    double specHalfZ,
  ) => switch (kind) {
    StructureKind.machiya => (
      math.max(specHalfX, 2.05),
      math.max(specHalfZ, 2.45),
    ),
    StructureKind.chaya => (
      math.max(specHalfX, 2.30),
      math.max(specHalfZ, 2.35),
    ),
    StructureKind.kura => (
      math.max(specHalfX, 2.20),
      math.max(specHalfZ, 2.45),
    ),
    StructureKind.minka => (
      math.max(specHalfX, 2.15),
      math.max(specHalfZ, 2.30),
    ),
    StructureKind.marketStall => (
      math.max(specHalfX, 1.28),
      math.max(specHalfZ, 0.90),
    ),
    StructureKind.karesansuiGarden => (
      math.max(specHalfX, 2.50),
      math.max(specHalfZ, 2.10),
    ),
    StructureKind.stoneWell => (
      math.max(specHalfX, 0.85),
      math.max(specHalfZ, 0.85),
    ),
    StructureKind.shoroBell => (
      math.max(specHalfX, 1.55),
      math.max(specHalfZ, 1.55),
    ),
    StructureKind.rockOutcrop => (
      math.max(specHalfX, 1.45),
      math.max(specHalfZ, 1.45),
    ),
    _ => (math.max(specHalfX, 0.75), math.max(specHalfZ, 0.75)),
  };

  static void _addHeroPropObstacle({
    required String name,
    required String assetPath,
    required double x,
    required double z,
    required double yaw,
    required double circleRadius,
    required List<AgentObbObstacle> obbs,
    required List<AgentCircleObstacle> circles,
  }) {
    if (assetPath.contains('edo_wooden_fence_gate')) {
      obbs.add(
        AgentObbObstacle(
          cx: x,
          cz: z,
          yawRadians: yaw,
          halfX: 2.50,
          halfZ: 0.42,
          label: name,
        ),
      );
    } else if (assetPath.contains('edo_bamboo_fence')) {
      obbs.add(
        AgentObbObstacle(
          cx: x,
          cz: z,
          yawRadians: yaw,
          halfX: 1.56,
          halfZ: 0.22,
          label: name,
        ),
      );
    } else if (assetPath.contains('edo_wagon')) {
      obbs.add(
        AgentObbObstacle(
          cx: x,
          cz: z,
          yawRadians: yaw,
          halfX: 0.76,
          halfZ: 1.75,
          label: name,
        ),
      );
    } else if (assetPath.contains('edo_wagasa_bench')) {
      obbs.add(
        AgentObbObstacle(
          cx: x,
          cz: z,
          yawRadians: yaw,
          halfX: 1.15,
          halfZ: 1.05,
          label: name,
        ),
      );
    } else if (assetPath.contains('edo_street_clutter') ||
        assetPath.contains('harbor_cargo') ||
        assetPath.contains('edo_sake_barrels') ||
        assetPath.contains('edo_handcart') ||
        assetPath.contains('edo_stone_lantern') ||
        assetPath.contains('edo_andon_lantern')) {
      circles.add(
        AgentCircleObstacle(cx: x, cz: z, radius: circleRadius, label: name),
      );
    }
  }

  static double _hypot(double a, double b) => math.sqrt(a * a + b * b);

  static _SurfaceSample _sampleWall(
    AgentWallCapsule w,
    double x,
    double z,
    double agentRadius,
  ) {
    final abx = w.bx - w.ax;
    final abz = w.bz - w.az;
    final len2 = abx * abx + abz * abz;
    final t = len2 < 1e-9
        ? 0.0
        : (((x - w.ax) * abx + (z - w.az) * abz) / len2).clamp(0.0, 1.0);
    final qx = w.ax + t * abx;
    final qz = w.az + t * abz;
    final dx = x - qx;
    final dz = z - qz;
    final d = _hypot(dx, dz);
    final effR = w.radius + agentRadius;
    if (d > 1e-6) {
      return (clearance: d - effR, nx: dx / d, nz: dz / d, label: w.label);
    }
    final len = math.sqrt(len2);
    return (
      clearance: -effR,
      nx: len > 1e-6 ? -abz / len : 1,
      nz: len > 1e-6 ? abx / len : 0,
      label: w.label,
    );
  }

  static _SurfaceSample _sampleCircle(
    AgentCircleObstacle c,
    double x,
    double z,
    double agentRadius,
  ) {
    final dx = x - c.cx;
    final dz = z - c.cz;
    final d = _hypot(dx, dz);
    final effR = c.radius + agentRadius;
    return (
      clearance: d - effR,
      nx: d > 1e-6 ? dx / d : 1,
      nz: d > 1e-6 ? dz / d : 0,
      label: c.label,
    );
  }

  Iterable<_SurfaceSample> _allSamples(
    double x,
    double z,
    double agentRadius,
  ) sync* {
    for (final o in obbs) {
      yield _sampleObbResolved(o, x, z, agentRadius);
    }
    for (final w in walls) {
      yield _sampleWall(w, x, z, agentRadius);
    }
    for (final c in circles) {
      yield _sampleCircle(c, x, z, agentRadius);
    }
  }

  static _SurfaceSample _sampleObbResolved(
    AgentObbObstacle o,
    double x,
    double z,
    double agentRadius,
  ) {
    final dx = x - o.cx;
    final dz = z - o.cz;
    final c = math.cos(o.yawRadians);
    final s = math.sin(o.yawRadians);
    final lx = dx * c - dz * s;
    final lz = dx * s + dz * c;
    final clx = lx.clamp(-o.halfX, o.halfX);
    final clz = lz.clamp(-o.halfZ, o.halfZ);
    final ex = lx - clx;
    final ez = lz - clz;
    final edgeDist = _hypot(ex, ez);
    final double clearance;
    final double nlx;
    final double nlz;
    if (edgeDist > 1e-6) {
      clearance = edgeDist - agentRadius;
      nlx = ex / edgeDist;
      nlz = ez / edgeDist;
    } else {
      final penX = o.halfX - lx.abs();
      final penZ = o.halfZ - lz.abs();
      if (penX <= penZ) {
        clearance = -(penX + agentRadius);
        nlx = lx >= 0 ? 1 : -1;
        nlz = 0;
      } else {
        clearance = -(penZ + agentRadius);
        nlx = 0;
        nlz = lz >= 0 ? 1 : -1;
      }
    }
    return (
      clearance: clearance,
      nx: nlx * c + nlz * s,
      nz: -nlx * s + nlz * c,
      label: o.label,
    );
  }

  ({double fx, double fz}) computeAvoidanceForce(
    double x,
    double z,
    double targetX,
    double targetZ, {
    double agentRadius = kAgentCollisionRadius,
  }) {
    final toTx = targetX - x;
    final toTz = targetZ - z;
    final toTLen = _hypot(toTx, toTz);
    final tx = toTLen > 1e-4 ? toTx / toTLen : 0.0;
    final tz = toTLen > 1e-4 ? toTz / toTLen : 0.0;

    var fx = 0.0;
    var fz = 0.0;

    void accumulate(double clearance, double nx, double nz) {
      if (clearance >= kAgentAvoidanceMargin) {
        return;
      }
      final strength =
          ((kAgentAvoidanceMargin - clearance) / kAgentAvoidanceMargin).clamp(
            0.0,
            1.5,
          );
      fx += nx * strength * 4.5;
      fz += nz * strength * 4.5;
      if (toTLen > 1e-4) {
        final dot = -nz * tx + nx * tz;
        final slx = dot >= 0 ? -nz : nz;
        final slz = dot >= 0 ? nx : -nx;
        fx += slx * strength * 3.2;
        fz += slz * strength * 3.2;
      }
    }

    for (final sample in _allSamples(x, z, agentRadius)) {
      accumulate(sample.clearance, sample.nx, sample.nz);
    }

    if (_realm == ShowcaseRealm.shukubaValley && z.abs() > 1.55) {
      final rcx = TerrainConfig.riverCenterX(z);
      final bankClearance = (x - rcx).abs() - 3.45;
      accumulate(bankClearance, x >= rcx ? 1 : -1, 0);
    } else if (_realm == ShowcaseRealm.minatoJo &&
        _sampleGroundHeight(x, z) < 0.60) {
      final yEast = _sampleGroundHeight(x + 0.6, z);
      final yWest = _sampleGroundHeight(x - 0.6, z);
      accumulate(-0.1, yWest >= yEast ? -1 : 1, 0);
    }

    return (fx: fx, fz: fz);
  }

  ({double x, double z, bool hit}) resolvePosition(
    double prevX,
    double prevZ,
    double nextX,
    double nextZ, {
    double agentRadius = kAgentCollisionRadius,
  }) {
    var x = nextX;
    var z = nextZ;
    var hit = false;

    for (var pass = 0; pass < 3; pass++) {
      for (final sample in _allSamples(x, z, agentRadius)) {
        if (sample.clearance < 0) {
          final push = -sample.clearance;
          x += sample.nx * push;
          z += sample.nz * push;
          hit = true;
        }
      }
    }

    if (_realm == ShowcaseRealm.shukubaValley && z.abs() > 1.55) {
      final rcx = TerrainConfig.riverCenterX(z);
      if ((x - rcx).abs() < 3.45) {
        x = rcx + (x >= rcx ? 3.45 : -3.45);
        hit = true;
      }
    } else if (_realm == ShowcaseRealm.minatoJo &&
        _sampleGroundHeight(x, z) < 0.42) {
      hit = true;
      if (_sampleGroundHeight(prevX, prevZ) >= 0.42) {
        x = prevX;
        z = prevZ;
      } else {
        for (var i = 0; i < 5 && _sampleGroundHeight(x, z) < 0.42; i++) {
          x -= 0.4;
        }
      }
    }

    return (x: x, z: z, hit: hit);
  }

  String? firstCollisionLabel(
    double x,
    double z, {
    double agentRadius = kAgentCollisionRadius - 0.04,
  }) {
    for (final sample in _allSamples(x, z, agentRadius)) {
      if (sample.clearance < 0) {
        return sample.label;
      }
    }
    if (_realm == ShowcaseRealm.shukubaValley && z.abs() > 1.55) {
      final rcx = TerrainConfig.riverCenterX(z);
      if ((x - rcx).abs() < 3.40) {
        return 'shukuba_river';
      }
    } else if (_realm == ShowcaseRealm.minatoJo &&
        _sampleGroundHeight(x, z) < 0.42) {
      return 'minato_sea';
    }
    return null;
  }
}
