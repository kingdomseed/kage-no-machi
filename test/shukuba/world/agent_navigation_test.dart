import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';

void _auditPatrolRun({
  required EdoWorldDriver world,
  required int ticks,
  required double dt,
  required double minDryGroundY,
}) {
  final prevPos = <EntityId, Vec3>{
    for (final a in world.agents) a.id: a.position,
  };
  final prevDir = <EntityId, ({double x, double z})>{};
  final turnGraceTicks = <EntityId, int>{};
  final steadyMovingTicks = <EntityId, int>{};

  for (var tick = 0; tick < ticks; tick++) {
    world.step(dt, rig: TimeOfDayRig.goldenDusk);

    for (final agent in world.agents) {
      final pos = agent.position;
      expect(pos.x.isFinite && pos.y.isFinite && pos.z.isFinite, isTrue);
      expect(agent.yawRadians.isFinite, isTrue);

      final hit = world.agentObstacles.firstCollisionLabel(pos.x, pos.z);
      expect(
        hit,
        isNull,
        reason:
            '${agent.id.value} collided with $hit at '
            '(${pos.x.toStringAsFixed(2)}, ${pos.z.toStringAsFixed(2)}) '
            'on tick $tick',
      );

      final groundY = world.sampleGroundHeight(pos.x, pos.z);
      expect(
        groundY,
        greaterThanOrEqualTo(minDryGroundY),
        reason:
            '${agent.id.value} entered water (groundY=$groundY) at tick $tick',
      );

      final prev = prevPos[agent.id]!;
      final dx = pos.x - prev.x;
      final dz = pos.z - prev.z;
      final moveDist = math.sqrt(dx * dx + dz * dz);
      prevPos[agent.id] = pos;

      if (moveDist <= 0.02) {
        turnGraceTicks[agent.id] = 9;
        prevDir.remove(agent.id);
        continue;
      }

      final nx = dx / moveDist;
      final nz = dz / moveDist;
      final last = prevDir[agent.id];
      if (last != null && last.x * nx + last.z * nz < 0.5) {
        turnGraceTicks[agent.id] = 9;
      }
      prevDir[agent.id] = (x: nx, z: nz);

      final grace = turnGraceTicks[agent.id] ?? 0;
      if (grace > 0) {
        turnGraceTicks[agent.id] = grace - 1;
        continue;
      }

      if (moveDist > 0.04) {
        steadyMovingTicks[agent.id] = (steadyMovingTicks[agent.id] ?? 0) + 1;
        final fwdX = math.sin(agent.yawRadians);
        final fwdZ = math.cos(agent.yawRadians);
        final alignDot = fwdX * nx + fwdZ * nz;
        expect(
          alignDot,
          greaterThan(0.50),
          reason:
              '${agent.id.value} walked misaligned (dot=$alignDot, '
              'yaw=${agent.yawRadians}) on tick $tick',
        );
      }
    }
  }

  for (final agent in world.agents) {
    expect(
      steadyMovingTicks[agent.id] ?? 0,
      greaterThan(80),
      reason: '${agent.id.value} failed to patrol steadily over $ticks ticks',
    );
  }
}

Map<String, dynamic> _readGlbJson(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  expect(bytes.lengthInBytes, greaterThan(20));
  final jsonLen = data.getUint32(12, Endian.little);
  final jsonStr = utf8.decode(bytes.sublist(20, 20 + jsonLen));
  return jsonDecode(jsonStr) as Map<String, dynamic>;
}

void main() {
  group('Agent navigation & orientation audits', () {
    test('Minato-jo 10 citizens patrol 30s without collisions or walking '
        'backwards', () {
      final world = EdoWorldDriver(initialRealm: ShowcaseRealm.minatoJo)
        ..initSimulation(rebuildAgentNodes: false);

      expect(world.agents.length, 10);
      _auditPatrolRun(world: world, ticks: 600, dt: 0.05, minDryGroundY: 0.42);
    });

    test(
      'Shukuba Valley citizens patrol 30s without crossing river or walls',
      () {
        final world = EdoWorldDriver()
          ..initSimulation(rebuildAgentNodes: false);

        expect(world.agents.length, 3);
        _auditPatrolRun(
          world: world,
          ticks: 600,
          dt: 0.05,
          minDryGroundY: -0.25,
        );
      },
    );

    test(
      'Dynamic player-placed wall and building block & reverse agents cleanly',
      () {
        // Shukuba Kaido blockade
        final shukuba = EdoWorldDriver()
          ..initSimulation(rebuildAgentNodes: false);
        final shukubaNext = shukuba.graph
            .putWall(
              CourtyardWall.validated(
                id: EntityId.validated('player_roadblock_kaido'),
                controlPoints: [
                  Vec3(-11.5, shukuba.sampleGroundHeight(-11.5, -2.5), -2.5),
                  Vec3(-11.5, shukuba.sampleGroundHeight(-11.5, 2.5), 2.5),
                ],
              ),
            )
            .putStructure(
              PlacedStructure(
                id: EntityId.validated('player_blocking_machiya'),
                kind: StructureKind.machiya,
                position: Vec3(14, shukuba.sampleGroundHeight(14, 0), 0),
                yawRadians: 0,
              ),
            );
        shukuba.applyGraph(shukubaNext);

        for (var i = 0; i < 240; i++) {
          shukuba.step(0.05, rig: TimeOfDayRig.goldenDusk);
          for (final a in shukuba.agents) {
            expect(
              a.position.x.isFinite &&
                  a.position.y.isFinite &&
                  a.position.z.isFinite,
              isTrue,
            );
            expect(
              shukuba.agentObstacles.firstCollisionLabel(
                a.position.x,
                a.position.z,
              ),
              isNull,
            );
          }
        }

        // Minato boulevard blockade
        final minato = EdoWorldDriver(initialRealm: ShowcaseRealm.minatoJo)
          ..initSimulation(rebuildAgentNodes: false);
        final minatoNext = minato.graph
            .putWall(
              CourtyardWall.validated(
                id: EntityId.validated('player_roadblock_minato'),
                controlPoints: [
                  Vec3(-11, minato.sampleGroundHeight(-11, 5), 5),
                  Vec3(-11, minato.sampleGroundHeight(-11, 9), 9),
                ],
              ),
            )
            .putStructure(
              PlacedStructure(
                id: EntityId.validated('player_blocking_kura'),
                kind: StructureKind.kura,
                position: Vec3(-27, minato.sampleGroundHeight(-27, 11), 11),
                yawRadians: 0.2,
              ),
            );
        minato.applyGraph(minatoNext);

        for (var i = 0; i < 240; i++) {
          minato.step(0.05, rig: TimeOfDayRig.goldenDusk);
          for (final a in minato.agents) {
            expect(
              a.position.x.isFinite &&
                  a.position.y.isFinite &&
                  a.position.z.isFinite,
              isTrue,
            );
            expect(
              minato.agentObstacles.firstCollisionLabel(
                a.position.x,
                a.position.z,
              ),
              isNull,
            );
          }
        }
      },
    );

    test(
      'All sculpted character GLBs face native +Z forward with lantern front',
      () {
        final watchman = _readGlbJson('assets/models/edo_person_watchman.glb');
        final nodes = (watchman['nodes'] as List).cast<Map<String, dynamic>>();
        final meshes = (watchman['meshes'] as List)
            .cast<Map<String, dynamic>>();
        final accessors = (watchman['accessors'] as List)
            .cast<Map<String, dynamic>>();

        final lanternNode = nodes.firstWhere(
          (n) => n['name'] == 'person_lantern_glow',
        );
        final lanternPrims =
            (meshes[lanternNode['mesh'] as int]['primitives'] as List)
                .cast<Map<String, dynamic>>();
        var lanMinX = double.infinity;
        var lanMaxZ = double.negativeInfinity;
        for (final pr in lanternPrims) {
          final attrs = pr['attributes'] as Map<String, dynamic>;
          final acc = accessors[attrs['POSITION'] as int];
          final bmin = (acc['min'] as List).cast<num>();
          final bmax = (acc['max'] as List).cast<num>();
          if (bmin[0] < lanMinX) lanMinX = bmin[0].toDouble();
          if (bmax[2] > lanMaxZ) lanMaxZ = bmax[2].toDouble();
        }
        // Native Z = -glTF_Z under bakeNative -> gltf_z < 0 is native +Z front.
        expect(lanMinX, greaterThan(0));
        expect(lanMaxZ, lessThan(-0.3));

        for (final path in const <String>[
          'assets/models/edo_person_merchant.glb',
          'assets/models/edo_person_townswoman.glb',
          'assets/models/edo_person_porter.glb',
          'assets/models/edo_person_watchman.glb',
          'assets/models/edo_person_samurai.glb',
          'assets/models/edo_person_monk.glb',
        ]) {
          final glb = _readGlbJson(path);
          final charNodes = (glb['nodes'] as List).cast<Map<String, dynamic>>();
          final charMeshes = (glb['meshes'] as List)
              .cast<Map<String, dynamic>>();
          final charAccessors = (glb['accessors'] as List)
              .cast<Map<String, dynamic>>();

          final legL = charNodes.firstWhere((n) => n['name'] == 'person_leg_l');
          final legR = charNodes.firstWhere((n) => n['name'] == 'person_leg_r');
          expect((legL['translation'] as List)[0] as num, lessThan(0));
          expect((legR['translation'] as List)[0] as num, greaterThan(0));

          for (final leg in [legL, legR]) {
            final prims = (charMeshes[leg['mesh'] as int]['primitives'] as List)
                .cast<Map<String, dynamic>>();
            var minZ = double.infinity;
            var maxZ = double.negativeInfinity;
            for (final pr in prims) {
              final attrs = pr['attributes'] as Map<String, dynamic>;
              final acc = charAccessors[attrs['POSITION'] as int];
              final z0 = ((acc['min'] as List)[2] as num).toDouble();
              final z1 = ((acc['max'] as List)[2] as num).toDouble();
              if (z0 < minZ) minZ = z0;
              if (z1 > maxZ) maxZ = z1;
            }
            expect(
              minZ.abs(),
              greaterThan(maxZ.abs()),
              reason: '$path leg toes must extend further toward glTF -Z',
            );
          }
        }
      },
    );
  });
}
