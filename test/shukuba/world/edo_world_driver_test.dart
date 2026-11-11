import 'dart:io';

import 'package:flutter_scene/scene.dart' show Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        AmbientLoopKind,
        CameraPreset,
        CourtyardWall,
        EntityId,
        PlacedStructure,
        RoadSpline,
        RoadStyle,
        StreetAgentRole,
        StructureKind,
        TerraceCourse,
        TimeOfDayRig,
        Vec3,
        defaultShukubaMaterial;
import 'package:kage_no_machi/shukuba/world/world.dart';

bool _checkImpellerAvailable() {
  try {
    Scene();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final impellerAvailable = _checkImpellerAvailable();
  const impellerSkipReason =
      'Flutter GPU Impeller backend not enabled in headless sandbox';

  group('Starter ward and terrain domain logic (CPU)', () {
    test(
      'buildStarterShukubaGraph builds city-builder ward without watchtowers',
      () {
        const terrain = TerrainBuilder();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

        expect(graph.roads.length, greaterThanOrEqualTo(4));
        expect(graph.terraces.length, 2);
        expect(graph.walls.length, greaterThanOrEqualTo(2));
        expect(graph.structures.length, greaterThanOrEqualTo(18));
        expect(graph.lanternSpans.length, greaterThanOrEqualTo(5));

        final towers = graph.structures.values
            .where((s) => s.kind == StructureKind.yaguraTower)
            .toList();
        expect(towers, isEmpty);
        expect(graph.structuralSightcones, isEmpty);

        expect(
          graph.structures.values.any((s) => s.kind == StructureKind.chaya),
          isTrue,
        );
        expect(
          graph.structures.values.any((s) => s.kind == StructureKind.kura),
          isTrue,
        );
        expect(
          graph.structures.values.any((s) => s.kind == StructureKind.toriiGate),
          isTrue,
        );
        expect(
          graph.structures.values.any((s) => s.kind == StructureKind.pineTree),
          isTrue,
        );
        expect(
          graph.structures.values.any(
            (s) => s.kind == StructureKind.weepingWillow,
          ),
          isTrue,
        );
        expect(
          graph.structures.values.any(
            (s) => s.kind == StructureKind.rockOutcrop,
          ),
          isTrue,
        );
        expect(graph.roads.any((r) => r.style == RoadStyle.gardenPath), isTrue);
        expect(graph.terraces.every((t) => t.crestPoints.length >= 4), isTrue);
      },
    );

    test(
      'sampleGroundHeight resolves bridge arch, terraces, and kaidan stairs',
      () {
        expect(TerrainConfig.gridStep, 0.5);
        const terrain = TerrainBuilder();
        final lowerTerrace = TerraceCourse(
          id: const EntityId('terrace_lower_east'),
          crestPoints: const [Vec3(4.8, 1.8, -24), Vec3(4.8, 1.8, 24)],
          topElevation: 1.8,
          depthMeters: 8.5,
        );

        final bridgeCenterY = terrain.sampleGroundHeight(0, 0);
        expect(bridgeCenterY, closeTo(1.58, 0.05));

        final westApproachY = terrain.sampleGroundHeight(-5.2, 0);
        expect(westApproachY, closeTo(0.40, 0.05));

        final eastApproachY = terrain.sampleGroundHeight(5.2, 0);
        expect(eastApproachY, closeTo(1.80, 0.05));

        final terraceY = terrain.sampleGroundHeight(
          8,
          0,
          terraces: [lowerTerrace],
        );
        expect(terraceY, closeTo(1.80, 0.05));

        final starter = buildStarterShukubaGraph(terrain.sampleGroundHeight);
        final midStairY = terrain.sampleGroundHeight(
          14.8,
          -0.15,
          terraces: starter.terraces,
          roads: starter.roads,
        );
        expect(midStairY, greaterThan(1.90));
        expect(midStairY, lessThan(3.30));

        final riverbedY = terrain.sampleRawTerrain(0, 10);
        expect(riverbedY, closeTo(-1.85, 0.15));
      },
    );

    test('60 step calls update townsfolk agents with finite positions', () {
      final driver = EdoWorldDriver()..initSimulation();

      final initialAgents = driver.agents;
      expect(initialAgents.length, 3);
      expect(driver.activeSightcones, isEmpty);

      const dt = 1 / 60;
      for (var frame = 0; frame < 60; frame++) {
        driver.step(dt, rig: TimeOfDayRig.goldenDusk);

        for (final agent in driver.agents) {
          expect(agent.position.x.isFinite, isTrue);
          expect(agent.position.y.isFinite, isTrue);
          expect(agent.position.z.isFinite, isTrue);
          expect(agent.yawRadians.isFinite, isTrue);
        }
      }

      final lanternBearer = driver.agents.firstWhere(
        (a) => a.role == StreetAgentRole.lanternWatchman,
      );
      expect(lanternBearer.carriesLantern, isTrue);
      expect(driver.activeLanternOrigins, isNotEmpty);
    });

    test('scene-graph updates never call Node.children.clear()', () {
      final dartFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      final offenders = <String>[];
      for (final file in dartFiles) {
        if (file.readAsStringSync().contains('.children.clear()')) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'Use Node.removeAll() instead of Node.children.clear() so '
            'flutter_scene unmounts children from RenderScene.',
      );
    });

    test(
      'FloraScatterBuilder excludes river, bridge, roads, and footprints',
      () {
        const terrain = TerrainBuilder();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

        expect(
          FloraScatterBuilder.isClearForGroundFlora(0, 12, graph),
          isFalse,
        );
        expect(FloraScatterBuilder.isClearForGroundFlora(0, 0, graph), isFalse);
        expect(
          FloraScatterBuilder.isClearForGroundFlora(-14, 0, graph),
          isFalse,
        );

        final firstShop = graph.structures.values.firstWhere(
          (s) => s.kind == StructureKind.machiya,
        );
        expect(
          FloraScatterBuilder.isClearForGroundFlora(
            firstShop.position.x,
            firstShop.position.z,
            graph,
          ),
          isFalse,
        );

        expect(
          FloraScatterBuilder.isClearForGroundFlora(-28, 22, graph),
          isTrue,
        );
      },
    );

    test(
      'activeLanternOrigins tracks held bamboo-pole lantern in world space',
      () {
        final driver = EdoWorldDriver()..initSimulation();
        for (var i = 0; i < 30; i++) {
          driver.step(1 / 60, rig: TimeOfDayRig.blueHourNight);
        }
        final bearer = driver.agents.firstWhere(
          (a) => a.role == StreetAgentRole.lanternWatchman,
        );
        final expectedHeld =
            bearer.position +
            EdoKitBuilder.heldLanternLocalOffset.rotateY(bearer.yawRadians);
        final matched = driver.activeLanternOrigins.any(
          (o) => (o - expectedHeld).length < 1e-6,
        );
        expect(matched, isTrue);

        final gate = driver.graph.structures.values.firstWhere(
          (s) => s.kind == StructureKind.toriiGate,
        );
        expect(EdoKitBuilder.structureLanternLocalOffsets(gate).length, 2);
      },
    );

    test(
      'AtmosphereBuilder and stylized townsfolk build expected child meshes',
      () {
        const terrain = TerrainBuilder();
        const kit = EdoKitBuilder();
        const atmosphere = AtmosphereBuilder();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

        final atmosNode = atmosphere.buildAtmosphereNode(
          graph: graph,
          resolveMaterial: defaultShukubaMaterial,
          sampleGroundY: terrain.sampleGroundHeight,
        );
        expect(atmosNode.children.length, 3);

        final townsfolkNode = kit.buildStreetAgentNode(
          StreetAgentRole.townsfolk,
          defaultShukubaMaterial,
        );
        final watchmanNode = kit.buildStreetAgentNode(
          StreetAgentRole.lanternWatchman,
          defaultShukubaMaterial,
        );
        final merchantNode = kit.buildStreetAgentNode(
          StreetAgentRole.nightSmuggler,
          defaultShukubaMaterial,
        );

        expect(townsfolkNode.children.length, 1);
        expect(watchmanNode.children.length, 4);
        expect(merchantNode.children.length, 2);
      },
      skip: !impellerAvailable ? impellerSkipReason : false,
    );
  });

  group('EdoWorldDriver and Scene verification', () {
    test(
      'initializes starter ward with required structures and spans',
      () async {
        final scene = Scene();
        final driver = EdoWorldDriver();
        await driver.attach(scene);

        final graph = driver.graph;
        expect(graph.lanternSpans.length, greaterThanOrEqualTo(5));
        expect(driver.activeSightcones, isEmpty);
        expect(driver.activeLanternOrigins, isNotEmpty);
        expect(driver.agents.length, greaterThanOrEqualTo(3));

        expect(
          driver.ambientLoopAnchors.containsKey(AmbientLoopKind.riverMurmur),
          isTrue,
        );
        expect(
          driver.ambientLoopAnchors.containsKey(AmbientLoopKind.bambooWind),
          isTrue,
        );
        expect(
          driver.ambientLoopAnchors.containsKey(AmbientLoopKind.nightCrickets),
          isTrue,
        );

        driver.dispose();
      },
      skip: !impellerAvailable ? impellerSkipReason : false,
    );

    test(
      'findCoplanarOverlaps is strictly empty across all camera presets',
      () async {
        final scene = Scene();
        final driver = EdoWorldDriver();
        await driver.attach(scene);

        for (final preset in CameraPreset.verificationPresets) {
          final camera = preset.toPerspectiveCamera();
          final overlaps = scene.findCoplanarOverlaps(camera: camera);
          final overlapMessages = overlaps.map((o) => o.describe()).toList();
          expect(
            overlaps,
            isEmpty,
            reason:
                'Preset ${preset.id} reported coplanar overlaps:\n'
                '${overlapMessages.join('\n')}',
          );
        }

        driver.dispose();
      },
      skip: !impellerAvailable ? impellerSkipReason : false,
    );

    test('applyGraph is idempotent and converges to identical state', () async {
      final scene = Scene();
      final driver = EdoWorldDriver();
      await driver.attach(scene);

      final initialGraph = driver.graph;
      driver
        ..applyGraph(initialGraph)
        ..applyGraph(initialGraph);

      expect(driver.graph, equals(initialGraph));

      final camera = CameraPreset.duskOverview.toPerspectiveCamera();
      final overlaps = scene.findCoplanarOverlaps(camera: camera);
      expect(overlaps, isEmpty);

      driver.dispose();
    }, skip: !impellerAvailable ? impellerSkipReason : false);

    test(
      'stamping extra chaya, kura, torii, wall, road, terrace has no overlaps',
      () async {
        final scene = Scene();
        final driver = EdoWorldDriver();
        await driver.attach(scene);

        var nextGraph = driver.graph;

        nextGraph = nextGraph
            .putStructure(
              PlacedStructure(
                id: EntityId.validated('chaya_extra_w'),
                kind: StructureKind.chaya,
                position: Vec3(-24, driver.sampleGroundHeight(-24, -12), -12),
              ),
            )
            .putStructure(
              PlacedStructure(
                id: EntityId.validated('kura_extra_w'),
                kind: StructureKind.kura,
                position: Vec3(-24, driver.sampleGroundHeight(-24, 13), 13),
              ),
            )
            .putStructure(
              PlacedStructure(
                id: EntityId.validated('torii_extra_e'),
                kind: StructureKind.toriiGate,
                position: Vec3(24.5, driver.sampleGroundHeight(24.5, 0), 0),
                yawRadians: 1.5707963,
              ),
            )
            .putWall(
              CourtyardWall.validated(
                id: EntityId.validated('wall_extra_w'),
                controlPoints: [
                  Vec3(-28, driver.sampleGroundHeight(-28, -16), -16),
                  Vec3(-20, driver.sampleGroundHeight(-20, -16), -16),
                ],
              ),
            )
            .putRoad(
              RoadSpline.validated(
                id: EntityId.validated('road_upper_path'),
                style: RoadStyle.gardenPath,
                controlPoints: [
                  Vec3(16, driver.sampleGroundHeight(16, 15), 15),
                  Vec3(21, driver.sampleGroundHeight(21, 16.5), 16.5),
                  Vec3(26, driver.sampleGroundHeight(26, 15), 15),
                ],
                widthMeters: 1.75,
              ),
            )
            .putStructure(
              PlacedStructure(
                id: EntityId.validated('rock_extra_nw'),
                kind: StructureKind.rockOutcrop,
                position: Vec3(-28, driver.sampleGroundHeight(-28, 16), 16),
                yawRadians: 0.9,
              ),
            )
            .putTerrace(
              TerraceCourse.validated(
                id: EntityId.validated('terrace_plateau_north'),
                crestPoints: [
                  Vec3(27, driver.sampleGroundHeight(27, 4), 4),
                  Vec3(27, driver.sampleGroundHeight(27, 18), 18),
                ],
                topElevation: 4.6,
                depthMeters: 6,
              ),
            );

        driver.applyGraph(nextGraph);

        final camera = CameraPreset.nightMarket.toPerspectiveCamera();
        final overlaps = scene.findCoplanarOverlaps(camera: camera);
        final overlapMessages = overlaps.map((o) => o.describe()).toList();
        expect(
          overlaps,
          isEmpty,
          reason:
              'Stamped graph had coplanar overlaps:\n'
              '${overlapMessages.join('\n')}',
        );

        driver.dispose();
      },
      skip: !impellerAvailable ? impellerSkipReason : false,
    );
  });
}
