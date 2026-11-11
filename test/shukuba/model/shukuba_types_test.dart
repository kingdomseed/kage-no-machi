import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';

void main() {
  group('TimeOfDayRig and PentatonicScale', () {
    test('clamps out-of-bounds and NaN inputs into [0, 1]', () {
      expect(const TimeOfDayRig(-0.4).value, 0);
      expect(const TimeOfDayRig(1.8).value, 1);
      expect(const TimeOfDayRig(double.nan).value, 0);
      expect(const TimeOfDayRig(0.42).value, closeTo(0.42, 1e-9));
    });

    test('switches from Yo (< 0.55) to In-sen (>= 0.55) on concert D4', () {
      expect(TimeOfDayRig.goldenDusk.scale, PentatonicScale.yo);
      expect(const TimeOfDayRig(0.549).scale, PentatonicScale.yo);
      expect(const TimeOfDayRig(0.55).scale, PentatonicScale.inSen);
      expect(TimeOfDayRig.blueHourNight.scale, PentatonicScale.inSen);

      expect(PentatonicScale.yo.frequencyHzAt(0), closeTo(293.6648, 1e-3));
      expect(PentatonicScale.yo.frequencyHzAt(3), closeTo(440, 1e-6));
      expect(PentatonicScale.inSen.frequencyHzAt(1), closeTo(311.127, 1e-3));
      expect(PentatonicScale.inSen.frequencyHzAt(4), closeTo(523.251, 1e-3));
      expect(PentatonicScale.yo.frequencyHzAt(5), closeTo(293.6648 * 2, 1e-3));
    });

    test('computes bounded dew, mist, mote, firefly, and halo curves', () {
      const dusk = TimeOfDayRig.goldenDusk;
      const night = TimeOfDayRig.blueHourNight;

      expect(dusk.dewFactor, inInclusiveRange(0.20, 0.40));
      expect(night.dewFactor, greaterThan(0.85));
      expect(dusk.riverMistOpacity, inInclusiveRange(0.50, 0.80));
      expect(night.riverMistOpacity, inInclusiveRange(0.50, 0.80));
      expect(dusk.duskMoteGain, greaterThan(0.90));
      expect(night.duskMoteGain, lessThan(0.05));
      expect(night.nightFireflyGain, greaterThan(0.95));
      expect(night.lanternHaloOpacity, greaterThan(dusk.lanternHaloOpacity));
    });
  });

  group('LanternSpan.deriveAll and ShukubaGraph', () {
    test('strings facing eaves within 6.5m without duplicates or tangles', () {
      const northHouse = PlacedStructure(
        id: EntityId('machiya_north'),
        kind: StructureKind.machiya,
        position: Vec3(0, 0, -5.8),
      );
      const southHouse = PlacedStructure(
        id: EntityId('machiya_south'),
        kind: StructureKind.machiya,
        position: Vec3(0, 0, 5.8),
        yawRadians: math.pi,
      );
      const farStall = PlacedStructure(
        id: EntityId('stall_far'),
        kind: StructureKind.marketStall,
        position: Vec3(20, 0, 0),
      );

      final graph = ShukubaGraph(
        structures: const [southHouse, northHouse, farStall],
      );

      expect(graph.lanternSpans, hasLength(2));
      for (final span in graph.lanternSpans) {
        expect(span.lengthMeters, lessThanOrEqualTo(LanternSpan.maxSpanMeters));
        expect(span.midpoint.y, lessThan(span.startWorld.y));
      }

      final reversedGraph = ShukubaGraph(
        structures: const [farStall, northHouse, southHouse],
      );
      expect(reversedGraph, equals(graph));
      expect(reversedGraph.lanternSpans, equals(graph.lanternSpans));
    });

    test(
      'previewLanternSpansFor returns spans that a ghost candidate adds',
      () {
        const northHouse = PlacedStructure(
          id: EntityId('machiya_north'),
          kind: StructureKind.machiya,
          position: Vec3(0, 0, -5.6),
        );
        final graph = ShukubaGraph(structures: const [northHouse]);
        const ghostChaya = PlacedStructure(
          id: EntityId('__ghost_preview__'),
          kind: StructureKind.chaya,
          position: Vec3(0, 0, 5.4),
          yawRadians: math.pi,
        );

        final previewSpans = graph.previewLanternSpansFor(ghostChaya);
        expect(previewSpans, hasLength(2));
      },
    );

    test('caps each eave hook at degree 1 when 3 stalls crowd one lane', () {
      const stallA = PlacedStructure(
        id: EntityId('stall_a'),
        kind: StructureKind.marketStall,
        position: Vec3(0, 0, -2.4),
      );
      const stallB = PlacedStructure(
        id: EntityId('stall_b'),
        kind: StructureKind.marketStall,
        position: Vec3(-0.3, 0, 2.4),
        yawRadians: math.pi,
      );
      const stallC = PlacedStructure(
        id: EntityId('stall_c'),
        kind: StructureKind.marketStall,
        position: Vec3(0.4, 0, 2.5),
        yawRadians: math.pi,
      );

      final spans = LanternSpan.deriveAll(const [stallA, stallB, stallC]);
      final seenHooks = <(EntityId, int)>{};
      for (final span in spans) {
        final hookA = (span.endpointA.structureId, span.endpointA.anchorIndex);
        final hookB = (span.endpointB.structureId, span.endpointB.anchorIndex);
        expect(seenHooks.add(hookA), isTrue);
        expect(seenHooks.add(hookB), isTrue);
      }
    });

    test(
      'putRoad, putTerrace, putWall, putStructure, and remove are idempotent',
      () {
        final road = RoadSpline.validated(
          id: EntityId.validated('side_lane'),
          controlPoints: const [Vec3(-12, 0, 0), Vec3(12, 0, 0)],
        );
        final terrace = TerraceCourse.validated(
          id: EntityId.validated('north_terrace'),
          crestPoints: const [Vec3(-10, 1.8, -4), Vec3(10, 1.8, -4)],
          topElevation: 1.8,
        );
        final wall = CourtyardWall.validated(
          id: EntityId.validated('compound_wall'),
          controlPoints: const [Vec3(4, 1.8, -8), Vec3(12, 1.8, -8)],
        );
        const kura = PlacedStructure(
          id: EntityId('kura_1'),
          kind: StructureKind.kura,
          position: Vec3(8, 1.8, -11),
        );

        final once = ShukubaGraph.empty
            .putRoad(road)
            .putTerrace(terrace)
            .putWall(wall)
            .putStructure(kura);
        final twice = once
            .putRoad(road)
            .putTerrace(terrace)
            .putWall(wall)
            .putStructure(kura);

        expect(twice, equals(once));
        expect(
          twice.findDemolishCandidate(const Vec3(8, 1.8, -10.8))?.id,
          kura.id,
        );
        expect(
          twice.findDemolishCandidate(const Vec3(5, 1.8, -8.1))?.id,
          wall.id,
        );
        expect(
          twice.removeEntity(wall.id).removeEntity(wall.id).walls,
          isEmpty,
        );
        expect(
          twice.removeEntity(kura.id).removeEntity(kura.id).structures,
          isEmpty,
        );
      },
    );

    test(
      'snapStructure aligns facade to road kerb and straddles toriiGate',
      () {
        final graph = ShukubaGraph.empty
            .putRoad(
              RoadSpline.validated(
                id: const EntityId('lane_1'),
                controlPoints: const [Vec3(-10, 0, 0), Vec3(10, 0, 0)],
              ),
            )
            .putTerrace(
              TerraceCourse.validated(
                id: const EntityId('terrace_1'),
                crestPoints: const [Vec3(-10, 2.2, -3.5), Vec3(10, 2.2, -3.5)],
                topElevation: 2.2,
                depthMeters: 8,
              ),
            );

        final snapped = graph.snapStructure(
          kind: StructureKind.machiya,
          rawPoint: const Vec3(2, 0, -1.2),
          sampleGroundY: (_, _) => 0.4,
        );

        expect(snapped.snappedRoadId, const EntityId('lane_1'));
        expect(snapped.position.z, closeTo(-(1.6 + 3.4 + 0.35), 1e-6));
        expect(snapped.position.y, closeTo(2.2, 1e-6));
        expect(snapped.yawRadians, closeTo(0, 1e-6));

        final gateSnap = graph.snapStructure(
          kind: StructureKind.toriiGate,
          rawPoint: const Vec3(-4, 0, 0.8),
          sampleGroundY: (_, _) => 0.4,
        );
        expect(gateSnap.snappedRoadId, const EntityId('lane_1'));
        expect(gateSnap.position.z, closeTo(0, 1e-6));
        expect(gateSnap.yawRadians, closeTo(math.pi / 2, 1e-6));
      },
    );
  });

  group('ShukubaSurfaceRole and WatchSightcone invariants', () {
    test(
      'defaultShukubaMaterial preserves ground, kit, lane, and preview layers',
      () {
        expect(
          defaultShukubaMaterial(ShukubaSurfaceRole.packedEarth).depthLayer,
          -1,
        );
        expect(
          defaultShukubaMaterial(ShukubaSurfaceRole.kuraPlaster).depthLayer,
          0,
        );
        expect(
          defaultShukubaMaterial(ShukubaSurfaceRole.laneOverlay).depthLayer,
          1,
        );
        expect(
          defaultShukubaMaterial(ShukubaSurfaceRole.ghostPreview).depthLayer,
          2,
        );
      },
    );

    test(
      'WatchSightcone clamps NaN alertLevel and tests sector containment',
      () {
        const cone = WatchSightcone(
          sourceId: EntityId('guard_1'),
          origin: Vec3.zero,
          yawRadians: math.pi / 2,
          rangeMeters: 10,
          halfAngleRadians: 0.4,
          alertLevel: double.nan,
        );

        expect(cone.alertLevel, 0);
        expect(cone.coneRangeNormalized, closeTo(10 / cone.decalBoxSize, 1e-9));
        expect(cone.containsPoint(const Vec3(6, 0.5, 0)), isTrue);
        expect(cone.containsPoint(const Vec3(0, 0, 6)), isFalse);
        expect(cone.containsPoint(const Vec3(12, 0, 0)), isFalse);
      },
    );

    test('alignedToTerrain faces uphill for reversed strokes', () {
      double slopeGround(double x, double z) => x * 0.25;
      final southToNorth = TerraceCourse.alignedToTerrain(
        id: const EntityId('t_fwd'),
        crestPoints: const [Vec3(6, 2, -12), Vec3(6, 2, 12)],
        topElevation: 2,
        depthMeters: 8,
        sampleGroundY: slopeGround,
      );
      final northToSouth = TerraceCourse.alignedToTerrain(
        id: const EntityId('t_rev'),
        crestPoints: const [Vec3(6, 2, 12), Vec3(6, 2, -12)],
        topElevation: 2,
        depthMeters: 8,
        sampleGroundY: slopeGround,
      );

      expect(southToNorth.samplePlatformElevation(const Vec3(10, 0, 0)), 2);
      expect(northToSouth.samplePlatformElevation(const Vec3(10, 0, 0)), 2);
      expect(southToNorth.samplePlatformElevation(const Vec3(3, 0, 0)), isNull);
      expect(northToSouth.samplePlatformElevation(const Vec3(3, 0, 0)), isNull);
      expect(
        TimeOfDayRig.goldenDusk.celestialRayDirection.dot(
          TimeOfDayRig.goldenDusk.celestialSkyDirection,
        ),
        closeTo(-1, 1e-9),
      );
      expect(
        TimeOfDayRig.goldenDusk.meadowTranslucency,
        greaterThan(TimeOfDayRig.blueHourNight.meadowTranslucency),
      );
      expect(
        TimeOfDayRig.goldenDusk.windGustStrength,
        greaterThan(TimeOfDayRig.blueHourNight.windGustStrength),
      );
      expect(StructureKind.pineTree.isBotanicalTree, isTrue);
      expect(StructureKind.weepingWillow.isBotanicalTree, isTrue);
      expect(StructureKind.machiya.isBotanicalTree, isFalse);
      expect(
        CameraPreset.verificationPresets,
        contains(CameraPreset.meadowCloseup),
      );
    });
  });
}
