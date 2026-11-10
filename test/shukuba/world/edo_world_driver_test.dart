import 'package:flutter_scene/scene.dart' show Scene;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show
        AmbientLoopKind,
        CameraPreset,
        EntityId,
        PlacedStructure,
        RoadSpline,
        StreetAgentRole,
        StructureKind,
        TerraceCourse,
        TimeOfDayRig,
        Vec3;
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
      'buildStarterShukubaGraph produces >= 6 spans and >= 2 sightcones',
      () {
        const terrain = TerrainBuilder();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

        expect(graph.roads.length, 2);
        expect(graph.terraces.length, 2);
        expect(graph.structures.length, greaterThanOrEqualTo(16));
        expect(graph.lanternSpans.length, greaterThanOrEqualTo(6));

        final towers = graph.structures.values
            .where((s) => s.kind == StructureKind.yaguraTower)
            .toList();
        expect(towers.length, 2);
        expect(graph.structuralSightcones.length, greaterThanOrEqualTo(2));
      },
    );

    test('sampleGroundHeight resolves bridge arch and terrace platforms', () {
      const terrain = TerrainBuilder();
      final lowerTerrace = TerraceCourse(
        id: const EntityId('terrace_lower_east'),
        crestPoints: const [Vec3(4.8, 1.8, -24), Vec3(4.8, 1.8, 24)],
        topElevation: 1.8,
        depthMeters: 8.5,
      );

      final bridgeCenterY = terrain.sampleGroundHeight(0, 0);
      expect(bridgeCenterY, closeTo(1.55, 0.05));

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

      final riverbedY = terrain.sampleRawTerrain(0, 10);
      expect(riverbedY, closeTo(-1.85, 0.15));
    });

    test(
      '60 step calls update agents with finite positions and smooth alerts',
      () {
        final driver = EdoWorldDriver()..initSimulation();

        final initialAgents = driver.agents;
        expect(initialAgents.length, 3);
        expect(driver.activeSightcones.length, greaterThanOrEqualTo(2));

        const dt = 1 / 60;
        for (var frame = 0; frame < 60; frame++) {
          driver.step(dt, rig: TimeOfDayRig.goldenDusk);

          for (final agent in driver.agents) {
            expect(agent.position.x.isFinite, isTrue);
            expect(agent.position.y.isFinite, isTrue);
            expect(agent.position.z.isFinite, isTrue);
            expect(agent.yawRadians.isFinite, isTrue);
          }

          final sightcones = driver.activeSightcones;
          expect(sightcones.length, greaterThanOrEqualTo(2));
          for (final cone in sightcones) {
            expect(cone.alertLevel, greaterThanOrEqualTo(0));
            expect(cone.alertLevel, lessThanOrEqualTo(1));
          }
        }

        final watchman = driver.agents.firstWhere(
          (a) => a.role == StreetAgentRole.lanternWatchman,
        );
        expect(watchman.carriesLantern, isTrue);
        expect(driver.activeLanternOrigins, isNotEmpty);
      },
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
        expect(graph.lanternSpans.length, greaterThanOrEqualTo(6));
        expect(driver.activeSightcones.length, greaterThanOrEqualTo(2));
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
      'stamping extra machiya, stall, tower, road, terrace keeps zero overlaps',
      () async {
        final scene = Scene();
        final driver = EdoWorldDriver();
        await driver.attach(scene);

        var nextGraph = driver.graph;

        final extraMachiya = PlacedStructure(
          id: EntityId.validated('machiya_extra_w3'),
          kind: StructureKind.machiya,
          position: Vec3(-23, driver.sampleGroundHeight(-23, -4.8), -4.8),
        );
        nextGraph = nextGraph.putStructure(extraMachiya);

        final extraStall = PlacedStructure(
          id: EntityId.validated('market_extra_e2'),
          kind: StructureKind.marketStall,
          position: Vec3(8.5, driver.sampleGroundHeight(8.5, -2.6), -2.6),
        );
        nextGraph = nextGraph.putStructure(extraStall);

        final extraTower = PlacedStructure(
          id: EntityId.validated('tower_extra_upper'),
          kind: StructureKind.yaguraTower,
          position: Vec3(-22, driver.sampleGroundHeight(-22, 6.5), 6.5),
          yawRadians: -1.2,
        );
        nextGraph = nextGraph.putStructure(extraTower);

        final extraRoad = RoadSpline.validated(
          id: EntityId.validated('road_upper_path'),
          controlPoints: [
            Vec3(14, driver.sampleGroundHeight(14, 6), 6),
            Vec3(22, driver.sampleGroundHeight(22, 6), 6),
          ],
          widthMeters: 2.8,
        );
        nextGraph = nextGraph.putRoad(extraRoad);

        final extraTerrace = TerraceCourse.validated(
          id: EntityId.validated('terrace_plateau_north'),
          crestPoints: [
            Vec3(24, driver.sampleGroundHeight(24, 4), 4),
            Vec3(24, driver.sampleGroundHeight(24, 18), 18),
          ],
          topElevation: 4.5,
          depthMeters: 6,
        );
        nextGraph = nextGraph.putTerrace(extraTerrace);

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

    test(
      '60 step calls update agents with finite positions and smooth alerts',
      () async {
        final scene = Scene();
        final driver = EdoWorldDriver();
        await driver.attach(scene);

        final initialAgents = driver.agents;
        expect(initialAgents.length, 3);

        const dt = 1 / 60;
        for (var frame = 0; frame < 60; frame++) {
          driver.step(dt, rig: TimeOfDayRig.goldenDusk);

          for (final agent in driver.agents) {
            expect(agent.position.x.isFinite, isTrue);
            expect(agent.position.y.isFinite, isTrue);
            expect(agent.position.z.isFinite, isTrue);
            expect(agent.yawRadians.isFinite, isTrue);
          }

          final sightcones = driver.activeSightcones;
          expect(sightcones.length, greaterThanOrEqualTo(2));
          for (final cone in sightcones) {
            expect(cone.alertLevel, greaterThanOrEqualTo(0));
            expect(cone.alertLevel, lessThanOrEqualTo(1));
          }
        }

        final watchman = driver.agents.firstWhere(
          (a) => a.role == StreetAgentRole.lanternWatchman,
        );
        expect(watchman.carriesLantern, isTrue);
        expect(driver.activeLanternOrigins, isNotEmpty);

        driver.dispose();
      },
      skip: !impellerAvailable ? impellerSkipReason : false,
    );
  });
}
