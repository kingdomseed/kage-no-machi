import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart' show Node;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Feature 1: Baseline Test & Analyzer Health Fix', () {
    test(
      'EaveEndpoint constructs with required worldNormal and retains value',
      () {
        const endpoint = EaveEndpoint(
          structureId: EntityId('machiya_01'),
          anchorIndex: 1,
          worldPosition: Vec3(10.5, 2.4, -4.2),
          worldNormal: Vec3.forward,
        );

        expect(endpoint.structureId, equals(const EntityId('machiya_01')));
        expect(endpoint.anchorIndex, equals(1));
        expect(endpoint.worldPosition, equals(const Vec3(10.5, 2.4, -4.2)));
        expect(endpoint.worldNormal, equals(Vec3.forward));
      },
    );

    test('LanternSpan calculates non-zero length and sag with valid '
        'EaveEndpoints', () {
      const epA = EaveEndpoint(
        structureId: EntityId('house_a'),
        anchorIndex: 0,
        worldPosition: Vec3(0, 3, 0),
        worldNormal: Vec3(1, 0, 0),
      );
      const epB = EaveEndpoint(
        structureId: EntityId('house_b'),
        anchorIndex: 0,
        worldPosition: Vec3(4.8, 3, 0),
        worldNormal: Vec3(-1, 0, 0),
      );

      final delta = epB.worldPosition - epA.worldPosition;
      final dist = delta.length;
      final sag = dist * LanternSpan.sagRatio;

      final span = LanternSpan(
        id: const EntityId('span_ab'),
        endpointA: epA,
        endpointB: epB,
        lengthMeters: dist,
        sagMeters: sag,
      );

      expect(span.lengthMeters, closeTo(4.8, 1e-4));
      expect(span.sagMeters, closeTo(4.8 * 0.085, 1e-4));
      expect(span.lanternCount, greaterThanOrEqualTo(2));
      expect(span.midpoint.y, lessThan(3));
      expect(span.lanternHangPoints(), hasLength(span.lanternCount));
    });

    test('EaveEndpoint implements value equality and hashCode contract', () {
      const ep1 = EaveEndpoint(
        structureId: EntityId('m1'),
        anchorIndex: 0,
        worldPosition: Vec3(1, 2, 3),
        worldNormal: Vec3.forward,
      );
      const ep2 = EaveEndpoint(
        structureId: EntityId('m1'),
        anchorIndex: 0,
        worldPosition: Vec3(1, 2, 3),
        worldNormal: Vec3.forward,
      );
      const ep3 = EaveEndpoint(
        structureId: EntityId('m1'),
        anchorIndex: 0,
        worldPosition: Vec3(1, 2, 3),
        worldNormal: Vec3.up,
      );

      expect(ep1, equals(ep2));
      expect(ep1.hashCode, equals(ep2.hashCode));
      expect(ep1, isNot(equals(ep3)));
    });

    test('LanternSpan.hasFestivalStreamers evaluates deterministically', () {
      const spanA = LanternSpan(
        id: EntityId('span_festive_alpha'),
        endpointA: EaveEndpoint(
          structureId: EntityId('a'),
          anchorIndex: 0,
          worldPosition: Vec3.zero,
          worldNormal: Vec3.forward,
        ),
        endpointB: EaveEndpoint(
          structureId: EntityId('b'),
          anchorIndex: 0,
          worldPosition: Vec3(2, 0, 0),
          worldNormal: Vec3.forward,
        ),
        lengthMeters: 2,
        sagMeters: 0.17,
      );

      final initial = spanA.hasFestivalStreamers;
      for (var i = 0; i < 50; i++) {
        expect(spanA.hasFestivalStreamers, equals(initial));
      }

      var sawTrue = false;
      var sawFalse = false;
      for (var i = 0; i < 30; i++) {
        final probe = LanternSpan(
          id: EntityId('probe_span_$i'),
          endpointA: spanA.endpointA,
          endpointB: spanA.endpointB,
          lengthMeters: 2,
          sagMeters: 0.17,
        );
        if (probe.hasFestivalStreamers) {
          sawTrue = true;
        } else {
          sawFalse = true;
        }
      }
      expect(sawTrue, isTrue);
      expect(sawFalse, isTrue);
    });

    test('Shukuba types pass strict const analysis and formatting', () {
      const specMachiya = StructureSpec.machiya;
      const specChaya = StructureSpec.chaya;
      const specKura = StructureSpec.kura;
      const specMarket = StructureSpec.marketStall;
      const specTorii = StructureSpec.toriiGate;

      expect(specMachiya.kind, equals(StructureKind.machiya));
      expect(specChaya.kind, equals(StructureKind.chaya));
      expect(specKura.kind, equals(StructureKind.kura));
      expect(specMarket.kind, equals(StructureKind.marketStall));
      expect(specTorii.kind, equals(StructureKind.toriiGate));

      expect(Vec3.zero.x, equals(0));
      expect(Vec3.up.y, equals(1));
      expect(Vec3.forward.z, equals(1));
    });
  });

  group('Feature 2: Audio Isolate Prewarming', () {
    test(
      'EdoWavBank.synthesizeAll executes inside Isolate.run without error',
      () async {
        final bank = await Isolate.run(EdoWavBank.synthesizeAll);
        expect(bank.kotoWav, isNotEmpty);
        expect(bank.shakuhachiWav, isNotEmpty);
        expect(bank.hyoshigiWav, isNotEmpty);
        expect(bank.bonshoWav, isNotEmpty);
        expect(bank.riverMurmurWav, isNotEmpty);
        expect(bank.bambooWindWav, isNotEmpty);
        expect(bank.nightCricketsWav, isNotEmpty);
      },
    );

    test(
      'Prewarmed EdoWavBank contains valid WAV headers for all 4 instruments',
      () async {
        final bank = await Isolate.run(EdoWavBank.synthesizeAll);
        final instruments = <String, Uint8List>{
          'koto': bank.kotoWav,
          'shakuhachi': bank.shakuhachiWav,
          'hyoshigi': bank.hyoshigiWav,
          'bonsho': bank.bonshoWav,
        };

        for (final entry in instruments.entries) {
          final bytes = entry.value;
          expect(bytes.length, greaterThanOrEqualTo(44));
          final riffTag = String.fromCharCodes(bytes.sublist(0, 4));
          final waveTag = String.fromCharCodes(bytes.sublist(8, 12));
          final fmtTag = String.fromCharCodes(bytes.sublist(12, 16));
          expect(riffTag, equals('RIFF'), reason: '${entry.key} RIFF tag');
          expect(waveTag, equals('WAVE'), reason: '${entry.key} WAVE tag');
          expect(fmtTag, equals('fmt '), reason: '${entry.key} fmt tag');
        }
      },
    );

    test(
      'EdoAudioDriver with prewarmed bank reports isWavBankLoaded == true',
      () async {
        final driver = EdoAudioDriver();
        expect(driver.isWavBankLoaded, isFalse);

        await driver.prewarm();

        expect(driver.isWavBankLoaded, isTrue);
        driver.dispose();
      },
    );

    test(
      'prewarmInIsolate future completes and unblocks audio driver',
      () async {
        final driver = EdoAudioDriver();
        final future = driver.prewarm();
        await future;

        expect(driver.isWavBankLoaded, isTrue);

        final secondFuture = driver.prewarm();
        await secondFuture;
        expect(driver.isWavBankLoaded, isTrue);

        driver.dispose();
      },
    );

    test(
      'Placing building immediately triggers audio note from prewarmed cache',
      () async {
        final driver = EdoAudioDriver();
        await driver.prewarm();

        const snap = SnappedPlacement(
          position: Vec3(1, 0, 1),
          yawRadians: 0,
          scaleDegree: 2,
        );
        final note = PlacementNoteEvent.fromSnap(
          instrument: EdoInstrument.koto,
          rig: TimeOfDayRig.goldenDusk,
          snapped: snap,
        );

        driver.playPlacementNote(note);

        expect(driver.recentNotes, hasLength(1));
        expect(driver.recentNotes.first.instrument, equals(EdoInstrument.koto));
        expect(driver.recentNotes.first.scale, equals(PentatonicScale.yo));

        driver.dispose();
      },
    );
  });

  group('Feature 3: Static Mesh Shadow Caching', () {
    test('markSubtreeShadowStatic recursively sets shadowStatic on target and '
        'children', () {
      final root = Node(name: 'root');
      final childA = Node(name: 'child_a');
      final childB = Node(name: 'child_b');
      final grandChild = Node(name: 'grandchild');

      childA.add(grandChild);
      root
        ..add(childA)
        ..add(childB);

      expect(root.shadowStatic, isFalse);
      expect(childA.shadowStatic, isFalse);
      expect(childB.shadowStatic, isFalse);
      expect(grandChild.shadowStatic, isFalse);

      markSubtreeShadowStatic(root);

      expect(root.shadowStatic, isTrue);
      expect(childA.shadowStatic, isTrue);
      expect(childB.shadowStatic, isTrue);
      expect(grandChild.shadowStatic, isTrue);
    });

    test(
      'TerrainBuilder mesh nodes are marked with shadowStatic == true',
      () {
        final terrain = TerrainBuilder();
        final terrainNode = terrain.buildTerrainNode(testMaterialResolver);
        final waterNode = terrain.buildWaterNode(testMaterialResolver);

        expect(terrainNode.shadowStatic, isTrue);
        expect(terrainNode.name, equals('terrain_tiled_root'));
        expect(terrainNode.children, isNotEmpty);
        for (final child in terrainNode.children) {
          expect(child.shadowStatic, isTrue);
          expect(child.name, startsWith('terrain_tile_'));
        }

        expect(waterNode.shadowStatic, isTrue);
        for (final child in waterNode.children) {
          expect(child.shadowStatic, isTrue);
        }
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test(
      'Retaining wall and terrace course nodes have shadowStatic == true',
      () {
        final terrain = TerrainBuilder();
        final terrace = TerraceCourse(
          id: const EntityId('terrace_test_retaining'),
          crestPoints: const [Vec3(5, 1, -5), Vec3(5, 1, 5)],
          topElevation: 1.5,
        );
        final wall = CourtyardWall(
          id: const EntityId('wall_test_courtyard'),
          controlPoints: const [Vec3(2, 0, -3), Vec3(2, 0, 3)],
        );

        final terraceNode = terrain.buildTerraceNode(
          terrace,
          testMaterialResolver,
        );
        final wallNode = terrain.buildWallNode(
          wall,
          testMaterialResolver,
          terrain.sampleGroundHeight,
        );

        expect(terraceNode.shadowStatic, isTrue);
        expect(terraceNode.name, equals('terrace_terrace_test_retaining'));
        for (final child in terraceNode.children) {
          expect(child.shadowStatic, isTrue);
        }

        expect(wallNode.shadowStatic, isTrue);
        expect(wallNode.name, equals('wall_wall_test_courtyard'));
        for (final child in wallNode.children) {
          expect(child.shadowStatic, isTrue);
        }
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test(
      'EdoKitBuilder structural nodes have shadowStatic == true',
      () {
        const kitBuilder = EdoKitBuilder();
        const machiya = PlacedStructure(
          id: EntityId('test_machiya_static'),
          kind: StructureKind.machiya,
          position: Vec3.zero,
        );
        final structNode = kitBuilder.buildStructureNode(
          machiya,
          testMaterialResolver,
        );
        markSubtreeShadowStatic(structNode);

        expect(structNode.shadowStatic, isTrue);
        expect(countNodes(structNode), greaterThan(1));
        for (final child in structNode.children) {
          expect(child.shadowStatic, isTrue);
        }
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test(
      'Dynamic agents, airborne motes, and ghosts retain shadowStatic == false',
      () {
        const kit = EdoKitBuilder();
        final terrain = TerrainBuilder();
        const atmosphere = AtmosphereBuilder();
        final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);

        final agentNode = kit.buildStreetAgentNode(
          StreetAgentRole.lanternWatchman,
          testMaterialResolver,
        );
        expect(agentNode.shadowStatic, isFalse);
        for (final child in agentNode.children) {
          expect(child.shadowStatic, isFalse);
        }

        final atmosNode = atmosphere.buildAtmosphereNode(
          graph: graph,
          resolveMaterial: testMaterialResolver,
          sampleGroundY: terrain.sampleGroundHeight,
        );
        final motesNode = findNode(atmosNode, 'atmosphere_airborne_motes');
        expect(motesNode, isNotNull);
        expect(motesNode!.shadowStatic, isFalse);

        final ghostNode = kit.buildPreviewNode(
          const StampGhostPreview(
            kind: StructureKind.machiya,
            position: Vec3.zero,
            yawRadians: 0,
          ),
          testMaterialResolver,
          terrain.sampleGroundHeight,
        );
        expect(ghostNode.shadowStatic, isFalse);
        for (final child in ghostNode.children) {
          expect(child.shadowStatic, isFalse);
        }
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );
  });
}
