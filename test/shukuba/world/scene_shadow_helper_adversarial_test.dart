import 'dart:math';

import 'package:flutter_scene/scene.dart' show Node;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/world/scene_shadow_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  (int total, int staticCount) countSubtreeStats(Node root) {
    var total = 0;
    var staticCount = 0;
    final queue = <Node>[root];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      total++;
      if (current.shadowStatic) {
        staticCount++;
      }
      queue.addAll(current.children);
    }
    return (total, staticCount);
  }

  void assertAllShadowStatic(Node root, {required bool expectedStatic}) {
    final (total, staticCount) = countSubtreeStats(root);
    if (expectedStatic) {
      expect(
        staticCount,
        equals(total),
        reason:
            'Expected all $total nodes to have shadowStatic == true, '
            'but only $staticCount were static.',
      );
    } else {
      expect(
        staticCount,
        equals(0),
        reason:
            'Expected 0 nodes to have shadowStatic == true, '
            'but found $staticCount out of $total nodes.',
      );
    }
  }

  group('Dimension 1: Deep & Wide Synthetic Hierarchies', () {
    test(
      '10,000-node wide hierarchy (star topology: 1 root + 10,000 leaves)',
      () {
        final root = Node(name: 'wide_root');
        const leafCount = 10000;
        for (var i = 0; i < leafCount; i++) {
          root.add(Node(name: 'leaf_$i'));
        }

        final (totalBefore, staticBefore) = countSubtreeStats(root);
        expect(totalBefore, leafCount + 1);
        expect(staticBefore, 0);

        final sw = Stopwatch()..start();
        final returned = markSubtreeShadowStatic(root);
        sw.stop();

        expect(identical(returned, root), isTrue);
        assertAllShadowStatic(root, expectedStatic: true);

        expect(
          sw.elapsedMilliseconds,
          lessThan(100),
          reason:
              'Wide tree marking exceeded budget: ${sw.elapsedMilliseconds}ms',
        );
      },
    );

    test('1,000-node deep linear hierarchy (depth 1,000 chain)', () {
      final root = Node(name: 'depth_0');
      var current = root;
      const chainDepth = 1000;
      for (var i = 1; i <= chainDepth; i++) {
        final child = Node(name: 'depth_$i');
        current.add(child);
        current = child;
      }

      final (totalBefore, _) = countSubtreeStats(root);
      expect(totalBefore, chainDepth + 1);

      final sw = Stopwatch()..start();
      markSubtreeShadowStatic(root);
      sw.stop();

      assertAllShadowStatic(root, expectedStatic: true);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test('2,500-node deep linear hierarchy (depth 2,500 chain)', () {
      final root = Node(name: 'depth_0');
      var current = root;
      const chainDepth = 2500;
      for (var i = 1; i <= chainDepth; i++) {
        final child = Node(name: 'depth_$i');
        current.add(child);
        current = child;
      }

      final (totalBefore, _) = countSubtreeStats(root);
      expect(totalBefore, chainDepth + 1);

      final sw = Stopwatch()..start();
      markSubtreeShadowStatic(root);
      sw.stop();

      assertAllShadowStatic(root, expectedStatic: true);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });

    test(
      'Deep linear chains up to 10,000 nodes execute without stack overflow',
      () {
        const depths = [3000, 5000, 8000, 10000];
        for (final depth in depths) {
          final root = Node(name: 'depth_0');
          var current = root;
          for (var i = 1; i <= depth; i++) {
            final child = Node(name: 'depth_$i');
            current.add(child);
            current = child;
          }

          final sw = Stopwatch()..start();
          markSubtreeShadowStatic(root);
          sw.stop();

          assertAllShadowStatic(root, expectedStatic: true);
          expect(sw.elapsedMilliseconds, lessThan(50));

          markSubtreeShadowStatic(root, shadowStatic: false);
          assertAllShadowStatic(root, expectedStatic: false);
        }
      },
    );

    test('Balanced 10,000+ node hierarchy (branching factor 10, depth 4)', () {
      final root = Node(name: 'multi_root');
      var currentLevel = <Node>[root];
      const branchingFactor = 10;
      const depth = 4;

      for (var d = 0; d < depth; d++) {
        final nextLevel = <Node>[];
        for (final parent in currentLevel) {
          for (var b = 0; b < branchingFactor; b++) {
            final child = Node(name: 'n_${d}_$b');
            parent.add(child);
            nextLevel.add(child);
          }
        }
        currentLevel = nextLevel;
      }

      final (totalCount, staticBefore) = countSubtreeStats(root);
      expect(totalCount, equals(11111));
      expect(staticBefore, equals(0));

      final sw = Stopwatch()..start();
      markSubtreeShadowStatic(root);
      sw.stop();

      final (totalAfter, staticAfter) = countSubtreeStats(root);
      expect(totalAfter, equals(11111));
      expect(staticAfter, equals(11111));
      expect(
        sw.elapsedMilliseconds,
        lessThan(100),
        reason: '11,111-node tree marking took ${sw.elapsedMilliseconds}ms',
      );
    });

    test(
      'Highly unbalanced asymmetric tree (5,000+ nodes, mixed spurs & bushes)',
      () {
        final root = Node(name: 'unbalanced_root');
        final random = Random(42);
        var totalCreated = 1;

        void buildAsymmetric(
          Node parent,
          int remainingBudget,
          int currentDepth,
        ) {
          if (remainingBudget <= 0 || currentDepth > 500) {
            return;
          }

          if (random.nextDouble() < 0.3) {
            final child = Node(name: 'spike_$currentDepth');
            parent.add(child);
            totalCreated++;
            buildAsymmetric(child, remainingBudget - 1, currentDepth + 1);
          } else {
            final childrenCount = min(remainingBudget, 5 + random.nextInt(15));
            var budgetLeft = remainingBudget - childrenCount;
            for (var i = 0; i < childrenCount; i++) {
              final child = Node(name: 'bush_${currentDepth}_$i');
              parent.add(child);
              totalCreated++;
              if (budgetLeft > 0 && random.nextBool()) {
                final childBudget = budgetLeft ~/ 2;
                budgetLeft -= childBudget;
                buildAsymmetric(child, childBudget, currentDepth + 1);
              }
            }
          }
        }

        buildAsymmetric(root, 6000, 1);
        expect(totalCreated, greaterThan(1000));

        final (total, _) = countSubtreeStats(root);
        expect(total, equals(totalCreated));

        markSubtreeShadowStatic(root);
        assertAllShadowStatic(root, expectedStatic: true);

        markSubtreeShadowStatic(root, shadowStatic: false);
        assertAllShadowStatic(root, expectedStatic: false);
      },
    );
  });

  group('Dimension 2: Invariance & Isolation in Composite Scene Graph', () {
    test(
      'Static marking isolates static subtrees; dynamic nodes stay non-static',
      () {
        final worldRoot = Node(name: 'worldRoot');

        final terrainContainer = Node(name: 'terrainContainer');
        for (var chunk = 0; chunk < 16; chunk++) {
          final chunkNode = Node(name: 'terrain_chunk_$chunk')
            ..add(Node(name: 'ground_mesh'))
            ..add(Node(name: 'cliff_mesh'));
          terrainContainer.add(chunkNode);
        }

        final waterNode = Node(name: 'waterNode')
          ..add(Node(name: 'water_mesh'));
        final bridgeNode = Node(name: 'bridgeNode')
          ..add(Node(name: 'arch_mesh'))
          ..add(Node(name: 'piers_mesh'));
        final gorgeDressingNode = Node(name: 'gorgeDressingNode')
          ..add(Node(name: 'boulders'))
          ..add(Node(name: 'sediment'));

        final roadsNode = Node(name: 'roadsNode');
        for (var r = 0; r < 8; r++) {
          roadsNode.add(Node(name: 'road_$r')..add(Node(name: 'rutted_mesh')));
        }

        final terracesNode = Node(name: 'terracesNode');
        for (var t = 0; t < 4; t++) {
          terracesNode.add(
            Node(name: 'terrace_$t')..add(Node(name: 'retaining_wall')),
          );
        }

        final wallsNode = Node(name: 'wallsNode');
        for (var w = 0; w < 6; w++) {
          wallsNode.add(
            Node(name: 'wall_$w')
              ..add(Node(name: 'plaster_panel'))
              ..add(Node(name: 'tile_coping')),
          );
        }

        final structuresNode = Node(name: 'structuresNode');
        for (var s = 0; s < 25; s++) {
          final struct = Node(name: 'structure_$s')
            ..add(Node(name: 'stone_skirt'))
            ..add(Node(name: 'post_and_beam'))
            ..add(Node(name: 'shitami_ita'))
            ..add(Node(name: 'roof_kawara'))
            ..add(Node(name: 'smoke_vent'));
          structuresNode.add(struct);
        }

        final lanternSpansNode = Node(name: 'lanternSpansNode');
        for (var l = 0; l < 10; l++) {
          final span = Node(name: 'span_$l')
            ..add(Node(name: 'catenary_cord'))
            ..add(Node(name: 'lantern_1'))
            ..add(Node(name: 'lantern_2'));
          lanternSpansNode.add(span);
        }

        final floraNode = Node(name: 'floraNode');
        for (var f = 0; f < 100; f++) {
          final plant = Node(name: 'flora_$f')
            ..add(Node(name: 'trunk'))
            ..add(Node(name: 'canopy'));
          floraNode.add(plant);
        }

        final agentsNode = Node(name: 'agentsNode');
        for (var a = 0; a < 12; a++) {
          final agent = Node(name: 'agent_$a')
            ..add(Node(name: 'torso'))
            ..add(Node(name: 'legs'))
            ..add(Node(name: 'head'));
          if (a % 3 == 0) {
            agent.add(Node(name: 'held_lantern'));
          }
          agentsNode.add(agent);
        }

        final previewNode = Node(name: 'previewNode')
          ..add(Node(name: 'ghost_mesh'))
          ..add(Node(name: 'footprint_guide'));

        final atmosphereNode = Node(name: 'atmosphereNode')
          ..add(Node(name: 'dust_particles'))
          ..add(Node(name: 'mist_plane'))
          ..add(Node(name: 'celestial_ring'));

        worldRoot
          ..add(terrainContainer)
          ..add(waterNode)
          ..add(gorgeDressingNode)
          ..add(bridgeNode)
          ..add(roadsNode)
          ..add(terracesNode)
          ..add(wallsNode)
          ..add(structuresNode)
          ..add(lanternSpansNode)
          ..add(floraNode)
          ..add(agentsNode)
          ..add(previewNode)
          ..add(atmosphereNode);

        markSubtreeShadowStatic(terrainContainer);
        markSubtreeShadowStatic(waterNode);
        markSubtreeShadowStatic(gorgeDressingNode);
        markSubtreeShadowStatic(bridgeNode);
        markSubtreeShadowStatic(roadsNode);
        markSubtreeShadowStatic(terracesNode);
        markSubtreeShadowStatic(wallsNode);
        markSubtreeShadowStatic(structuresNode);
        markSubtreeShadowStatic(lanternSpansNode);
        markSubtreeShadowStatic(floraNode);

        assertAllShadowStatic(terrainContainer, expectedStatic: true);
        assertAllShadowStatic(waterNode, expectedStatic: true);
        assertAllShadowStatic(gorgeDressingNode, expectedStatic: true);
        assertAllShadowStatic(bridgeNode, expectedStatic: true);
        assertAllShadowStatic(roadsNode, expectedStatic: true);
        assertAllShadowStatic(terracesNode, expectedStatic: true);
        assertAllShadowStatic(wallsNode, expectedStatic: true);
        assertAllShadowStatic(structuresNode, expectedStatic: true);
        assertAllShadowStatic(lanternSpansNode, expectedStatic: true);
        assertAllShadowStatic(floraNode, expectedStatic: true);

        assertAllShadowStatic(agentsNode, expectedStatic: false);
        assertAllShadowStatic(previewNode, expectedStatic: false);
        assertAllShadowStatic(atmosphereNode, expectedStatic: false);

        expect(worldRoot.shadowStatic, isFalse);

        final newTownsperson = Node(name: 'new_townsperson')
          ..add(Node(name: 'torso'));
        agentsNode.add(newTownsperson);
        assertAllShadowStatic(agentsNode, expectedStatic: false);
      },
    );

    test(
      'Modifying sibling subtree does not leak shadowStatic flag to siblings',
      () {
        final parent = Node(name: 'parent');
        final staticBranch = Node(name: 'staticBranch')
          ..add(Node(name: 'staticChild'));
        final dynamicBranch = Node(name: 'dynamicBranch')
          ..add(Node(name: 'dynamicChild'));

        parent
          ..add(staticBranch)
          ..add(dynamicBranch);

        markSubtreeShadowStatic(staticBranch);

        expect(staticBranch.shadowStatic, isTrue);
        expect(staticBranch.children.first.shadowStatic, isTrue);

        expect(parent.shadowStatic, isFalse);
        expect(dynamicBranch.shadowStatic, isFalse);
        expect(dynamicBranch.children.first.shadowStatic, isFalse);
      },
    );
  });

  group('Dimension 3: Idempotency & Toggling Reliability', () {
    test(
      'Repeated applications of shadowStatic: true produce identical state',
      () {
        final root = Node(name: 'root');
        for (var i = 0; i < 50; i++) {
          final child = Node(name: 'child_$i');
          for (var j = 0; j < 10; j++) {
            child.add(Node(name: 'grandchild_${i}_$j'));
          }
          root.add(child);
        }

        final (totalNodes, _) = countSubtreeStats(root);
        expect(totalNodes, 551);

        markSubtreeShadowStatic(root);
        assertAllShadowStatic(root, expectedStatic: true);

        markSubtreeShadowStatic(root);
        assertAllShadowStatic(root, expectedStatic: true);

        markSubtreeShadowStatic(root);
        assertAllShadowStatic(root, expectedStatic: true);
      },
    );

    test(
      'Repeated applications of shadowStatic: false produce identical state',
      () {
        final root = Node(name: 'root');
        for (var i = 0; i < 20; i++) {
          root.add(Node(name: 'child_$i'));
        }

        markSubtreeShadowStatic(root, shadowStatic: false);
        assertAllShadowStatic(root, expectedStatic: false);

        markSubtreeShadowStatic(root, shadowStatic: false);
        assertAllShadowStatic(root, expectedStatic: false);
      },
    );

    test(
      '1,000 rapid toggle cycles between true and false without corruption',
      () {
        final root = Node(name: 'toggle_root');
        for (var i = 0; i < 100; i++) {
          final branch = Node(name: 'branch_$i')
            ..add(Node(name: 'sub_a'))
            ..add(Node(name: 'sub_b'));
          root.add(branch);
        }

        final (totalNodes, _) = countSubtreeStats(root);
        expect(totalNodes, equals(301));

        const cycles = 1000;
        final sw = Stopwatch()..start();

        for (var cycle = 0; cycle < cycles; cycle++) {
          final targetState = cycle.isEven;
          markSubtreeShadowStatic(root, shadowStatic: targetState);

          if (cycle % 200 == 0 || cycle == cycles - 1) {
            assertAllShadowStatic(root, expectedStatic: targetState);
          }
        }
        sw.stop();

        expect(
          sw.elapsedMilliseconds,
          lessThan(1000),
          reason: '1,000 toggle cycles took ${sw.elapsedMilliseconds}ms',
        );
      },
    );
  });

  group('Dimension 4: Boundary & Degenerate Cases', () {
    test('Single isolated leaf node without children', () {
      final singleNode = Node(name: 'solo');
      expect(singleNode.shadowStatic, isFalse);

      markSubtreeShadowStatic(singleNode);
      expect(singleNode.shadowStatic, isTrue);

      markSubtreeShadowStatic(singleNode, shadowStatic: false);
      expect(singleNode.shadowStatic, isFalse);
    });

    test('Node hierarchy with empty intermediate and leaf nodes', () {
      final root = Node(name: 'root');
      final emptyChild1 = Node(name: 'empty1');
      final emptyChild2 = Node(name: 'empty2');
      final deepEmpty = Node(name: 'deep_empty');

      root
        ..add(emptyChild1)
        ..add(emptyChild2..add(deepEmpty));

      markSubtreeShadowStatic(root);
      assertAllShadowStatic(root, expectedStatic: true);
    });
  });
}
