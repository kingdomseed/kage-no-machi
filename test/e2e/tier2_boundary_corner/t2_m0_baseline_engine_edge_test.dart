import 'dart:isolate';

import 'package:flutter_scene/scene.dart' show Node;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Feature 1 Edge: Eave & Lantern Span Boundaries', () {
    test(
      'Degenerate worldNormal zero-vector on EaveEndpoint handled safely',
      () {
        const degenerateEndpoint = EaveEndpoint(
          structureId: EntityId('machiya_edge_0'),
          anchorIndex: 0,
          worldPosition: Vec3(10, 2, 10),
          worldNormal: Vec3.zero,
        );

        expect(degenerateEndpoint.worldNormal, equals(Vec3.zero));

        const otherEndpoint = EaveEndpoint(
          structureId: EntityId('machiya_edge_1'),
          anchorIndex: 0,
          worldPosition: Vec3(14, 2, 10),
          worldNormal: Vec3(1, 0, 0),
        );

        const span = LanternSpan(
          id: EntityId('span_degenerate_norm'),
          endpointA: degenerateEndpoint,
          endpointB: otherEndpoint,
          lengthMeters: 4,
          sagMeters: 0.34,
        );

        expect(span.lengthMeters, equals(4));
        expect(
          span.midpoint.x.isFinite &&
              span.midpoint.y.isFinite &&
              span.midpoint.z.isFinite,
          isTrue,
        );
        expect(span.lanternHangPoints(), hasLength(span.lanternCount));
      },
    );

    test(
      'Collinear and parallel eave endpoints maintain well-defined catenary',
      () {
        const epA = EaveEndpoint(
          structureId: EntityId('house_collinear_a'),
          anchorIndex: 0,
          worldPosition: Vec3(0, 3, 0),
          worldNormal: Vec3.forward,
        );
        const epB = EaveEndpoint(
          structureId: EntityId('house_collinear_b'),
          anchorIndex: 0,
          worldPosition: Vec3(0, 3, 5),
          worldNormal: Vec3.forward,
        );

        const span = LanternSpan(
          id: EntityId('span_collinear'),
          endpointA: epA,
          endpointB: epB,
          lengthMeters: 5,
          sagMeters: 0.425,
        );

        final hangPoints = span.lanternHangPoints();
        expect(hangPoints, isNotEmpty);
        for (final pt in hangPoints) {
          expect(pt.x.isFinite && pt.y.isFinite && pt.z.isFinite, isTrue);
          expect(pt.y, lessThan(3));
        }
      },
    );

    test('Extreme distance span (>500m) exceeds maxSpanMeters and sags '
        'predictably', () {
      const epA = EaveEndpoint(
        structureId: EntityId('tower_a'),
        anchorIndex: 0,
        worldPosition: Vec3(0, 10, 0),
        worldNormal: Vec3(1, 0, 0),
      );
      const epB = EaveEndpoint(
        structureId: EntityId('tower_b'),
        anchorIndex: 0,
        worldPosition: Vec3(600, 10, 0),
        worldNormal: Vec3(-1, 0, 0),
      );

      const extremeSpan = LanternSpan(
        id: EntityId('span_extreme_600m'),
        endpointA: epA,
        endpointB: epB,
        lengthMeters: 600,
        sagMeters: 600 * LanternSpan.sagRatio,
      );

      expect(extremeSpan.lengthMeters, greaterThan(LanternSpan.maxSpanMeters));
      expect(extremeSpan.sagMeters, closeTo(51, 1e-4));
      expect(extremeSpan.lanternCount, greaterThan(500));
      expect(extremeSpan.midpoint.y, closeTo(10 - 51, 1e-4));
    });

    test('Coincident eave endpoints at identical coordinates produce '
        'zero-length span', () {
      const epCoincidentA = EaveEndpoint(
        structureId: EntityId('touching_a'),
        anchorIndex: 0,
        worldPosition: Vec3(12.5, 3.2, -8),
        worldNormal: Vec3(1, 0, 0),
      );
      const epCoincidentB = EaveEndpoint(
        structureId: EntityId('touching_b'),
        anchorIndex: 0,
        worldPosition: Vec3(12.5, 3.2, -8),
        worldNormal: Vec3(-1, 0, 0),
      );

      const span = LanternSpan(
        id: EntityId('span_coincident'),
        endpointA: epCoincidentA,
        endpointB: epCoincidentB,
        lengthMeters: 0,
        sagMeters: 0,
      );

      expect(span.lengthMeters, equals(0));
      expect(span.lanternCount, equals(2));
      expect(span.midpoint, equals(const Vec3(12.5, 3.2, -8)));
      final hangPoints = span.lanternHangPoints();
      expect(hangPoints, hasLength(2));
      expect(hangPoints.first, equals(const Vec3(12.5, 3.2, -8)));
    });

    test('Extreme vertical height delta (> maxHeightDeltaMeters) evaluates '
        'stable hang points', () {
      const epLow = EaveEndpoint(
        structureId: EntityId('low_shed'),
        anchorIndex: 0,
        worldPosition: Vec3(0, 1.5, 0),
        worldNormal: Vec3(1, 0, 0),
      );
      const epHigh = EaveEndpoint(
        structureId: EntityId('cliff_shrine'),
        anchorIndex: 0,
        worldPosition: Vec3(5, 25, 0),
        worldNormal: Vec3(-1, 0, 0),
      );

      final deltaY = (epHigh.worldPosition.y - epLow.worldPosition.y).abs();
      expect(deltaY, greaterThan(LanternSpan.maxHeightDeltaMeters));

      final dist = (epHigh.worldPosition - epLow.worldPosition).length;
      final span = LanternSpan(
        id: const EntityId('span_steep_cliff'),
        endpointA: epLow,
        endpointB: epHigh,
        lengthMeters: dist,
        sagMeters: dist * LanternSpan.sagRatio,
      );

      final hangPoints = span.lanternHangPoints();
      expect(hangPoints, isNotEmpty);
      for (final pt in hangPoints) {
        expect(pt.x.isFinite && pt.y.isFinite && pt.z.isFinite, isTrue);
        expect(pt.y, inExclusiveRange(0, 26));
      }
    });
  });

  group('Feature 2 Edge: Audio Isolate & Buffer Boundaries', () {
    test(
      'Rapid concurrent isolate prewarm calls complete without race condition',
      () async {
        final driver = EdoAudioDriver();
        expect(driver.isWavBankLoaded, isFalse);

        await Future.wait([
          driver.prewarm(),
          driver.prewarm(),
          driver.prewarm(),
        ]);

        expect(driver.isWavBankLoaded, isTrue);
        expect(driver.wavBank.kotoWav, isNotEmpty);
        expect(driver.wavBank.bonshoWav, isNotEmpty);
      },
    );

    test('Synthesized EdoWavBank total byte size stays strictly within '
        '32MB budget', () {
      final bank = EdoWavBank.synthesizeAll();
      final totalBytes =
          bank.kotoWav.lengthInBytes +
          bank.shakuhachiWav.lengthInBytes +
          bank.hyoshigiWav.lengthInBytes +
          bank.bonshoWav.lengthInBytes +
          bank.riverMurmurWav.lengthInBytes +
          bank.bambooWindWav.lengthInBytes +
          bank.nightCricketsWav.lengthInBytes;

      expect(totalBytes, greaterThan(10 * 1024));
      expect(totalBytes, lessThan(32 * 1024 * 1024));
    });

    test('Audio driver volume clamp enforces bounds on negative, excessive, '
        'and NaN values', () {
      final driver = EdoAudioDriver()..setMasterVolume(-0.4);
      expect(driver.masterVolume, equals(0));

      driver.setMasterVolume(1.6);
      expect(driver.masterVolume, equals(1));

      driver.setMasterVolume(double.nan);
      expect(driver.masterVolume, equals(0));

      driver.setMasterVolume(0.75);
      expect(driver.masterVolume, closeTo(0.75, 1e-4));
    });

    test(
      'Isolate synthesis future completes within 5,000ms latency budget',
      () async {
        final sw = Stopwatch()..start();
        final bank = await Isolate.run(EdoWavBank.synthesizeAll);
        sw.stop();

        expect(sw.elapsedMilliseconds, lessThan(5000));
        expect(bank.sampleRate, equals(EdoWavSynth.defaultSampleRate));
      },
    );

    test('Rapid burst of 100 consecutive placement notes queues without '
        'state error', () {
      final driver = EdoAudioDriver(maxRecentNotes: 32);

      for (var i = 0; i < 100; i++) {
        driver.playPlacementNote(
          PlacementNoteEvent(
            instrument: EdoInstrument.hyoshigi,
            scale: PentatonicScale.yo,
            scaleDegree: i % 5,
            position: Vec3(i.toDouble(), 0, 0),
            volume: 0.5,
          ),
        );
      }

      expect(driver.recentNotes, hasLength(32));
      expect(driver.recentNotes.last.position.x, equals(99));
    });
  });

  group('Feature 3 Edge: Scene Graph & Shadow Static Boundaries', () {
    test('markSubtreeShadowStatic marks tree hierarchy recursively', () {
      final nodeA = Node(name: 'parent_node_a');
      final nodeB = Node(name: 'child_node_b');
      nodeA.add(nodeB);

      markSubtreeShadowStatic(nodeA);

      expect(nodeA.shadowStatic, isTrue);
      expect(nodeB.shadowStatic, isTrue);
    });

    test('markSubtreeShadowStatic traverses deeply nested 50-level hierarchy '
        'without stack overflow', () {
      final root = Node(name: 'deep_root');
      var current = root;
      for (var i = 1; i <= 50; i++) {
        final child = Node(name: 'level_$i');
        current.add(child);
        current = child;
      }

      markSubtreeShadowStatic(root);

      expect(countNodes(root), equals(51));
      final deepest = findNode(root, 'level_50');
      expect(deepest, isNotNull);
      expect(deepest!.shadowStatic, isTrue);
    });

    test('Dynamic node promoted to static propagates shadowStatic to newly '
        'added children', () {
      final root = Node(name: 'dynamic_parent');
      final childInitial = Node(name: 'child_initial');
      root.add(childInitial);

      expect(root.shadowStatic, isFalse);
      expect(childInitial.shadowStatic, isFalse);

      markSubtreeShadowStatic(root);
      expect(root.shadowStatic, isTrue);
      expect(childInitial.shadowStatic, isTrue);

      final childLater = Node(name: 'child_later');
      root.add(childLater);
      markSubtreeShadowStatic(root);

      expect(childLater.shadowStatic, isTrue);
    });

    test('Demolition of shadow-static child leaves remaining tree intact and '
        'static', () {
      final root = Node(name: 'town_ward');
      final machiya1 = Node(name: 'machiya_1');
      final machiya2 = Node(name: 'machiya_2');
      final machiya3 = Node(name: 'machiya_3');

      root
        ..add(machiya1)
        ..add(machiya2)
        ..add(machiya3);

      markSubtreeShadowStatic(root);
      expect(countNodes(root), equals(4));

      root.remove(machiya2);
      expect(countNodes(root), equals(3));
      expect(machiya1.shadowStatic, isTrue);
      expect(machiya3.shadowStatic, isTrue);
      expect(findNode(root, 'machiya_2'), isNull);
    });

    test('Isolated single leaf node handles markSubtreeShadowStatic and '
        'countNodes safely', () {
      final leaf = Node(name: 'lone_stone');
      expect(leaf.children, isEmpty);

      markSubtreeShadowStatic(leaf);

      expect(leaf.shadowStatic, isTrue);
      expect(countNodes(leaf), equals(1));
      expect(findNode(leaf, 'lone_stone'), equals(leaf));
      expect(findNode(leaf, 'non_existent'), isNull);
    });
  });
}
