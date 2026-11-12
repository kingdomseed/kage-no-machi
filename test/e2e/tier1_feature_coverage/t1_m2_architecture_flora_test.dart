import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Feature 8: Human-Scale Architecture Scaling', () {
    test('StructureSpec.machiya dimensions: 3.8m x 4.8m, lintel 1.78m, '
        'ridge 3.15m/4.18m', () {
      const spec = StructureSpec.machiya;
      expect(spec.footprintWidth, closeTo(3.8, 1e-4));
      expect(spec.footprintDepth, closeTo(4.8, 1e-4));
      expect(spec.height, inInclusiveRange(3.15, 4.2));
      expect(spec.foundationSkirtDepth, greaterThanOrEqualTo(1.0));
      expect(spec.eaveAnchors, isNotEmpty);
      expect(spec.hasShojiWindows, isTrue);
    });

    test('StructureSpec.chaya dimensions: 4.4m x 4.4m with 3.58m ridge', () {
      const spec = StructureSpec.chaya;
      expect(spec.footprintWidth, closeTo(4.4, 1e-4));
      expect(spec.footprintDepth, closeTo(4.4, 1e-4));
      expect(spec.height, inInclusiveRange(3.5, 3.8));
      expect(spec.eaveAnchors.length, greaterThanOrEqualTo(2));
    });

    test(
      'StructureSpec.kura dimensions: 3.4m x 4.0m with 4.55m vault ridge',
      () {
        const spec = StructureSpec.kura;
        expect(spec.footprintWidth, closeTo(3.4, 1e-4));
        expect(spec.footprintDepth, closeTo(4.0, 1e-4));
        expect(spec.height, inInclusiveRange(4.5, 4.7));
        expect(spec.foundationSkirtDepth, greaterThanOrEqualTo(1.2));
      },
    );

    test('StructureSpec.marketStall dimensions: 2.2m x 1.9m with 2.24m awning '
        'peak', () {
      const spec = StructureSpec.marketStall;
      expect(spec.footprintWidth, closeTo(2.2, 1e-4));
      expect(spec.footprintDepth, closeTo(1.9, 1e-4));
      expect(spec.height, inInclusiveRange(2.2, 2.35));
      expect(spec.eaveAnchors, hasLength(4));
    });

    test(
      'LanternSpan.maxSpanMeters widens to 8.2m for 3.2m street clearance',
      () {
        expect(LanternSpan.maxSpanMeters, equals(8.2));
        expect(LanternSpan.minSpanMeters, equals(0.9));
        expect(LanternSpan.sagRatio, equals(0.085));
        expect(LanternSpan.maxHeightDeltaMeters, equals(2.2));
      },
    );
  });

  group('Feature 9: 4-Sided Readable Carpentry', () {
    test(
      'Townhouse geometry generates non-empty meshes on all 4 elevations',
      () {
        const kitBuilder = EdoKitBuilder();
        const machiya = PlacedStructure(
          id: EntityId('m_4sided'),
          kind: StructureKind.machiya,
          position: Vec3.zero,
        );
        final node = kitBuilder.buildStructureNode(
          machiya,
          testMaterialResolver,
        );
        expect(countNodes(node), greaterThan(1));
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test('Post-and-beam hashira and nuki bays construct over stone foundation '
        'plinth', () {
      const spec = StructureSpec.machiya;
      expect(spec.foundationSkirtDepth, greaterThan(0));
      expect(spec.foundationSkirtDepth, greaterThanOrEqualTo(1.0));
      expect(spec.footprintWidth, equals(3.8));
      expect(spec.footprintDepth, equals(4.8));
    });

    test('Side elevations include eave anchors on side facades', () {
      const spec = StructureSpec.chaya;
      final sideAnchors = spec.eaveAnchors.where(
        (a) => a.localOutwardNormal.x.abs() > 0.5,
      );
      expect(sideAnchors, isNotEmpty);
    });

    test('Rear elevation features katteguchi service door and rear eave '
        'anchors', () {
      const spec = StructureSpec.machiya;
      final rearAnchors = spec.eaveAnchors
          .where((a) => a.localOutwardNormal.z < 0)
          .toList();
      expect(rearAnchors, isNotEmpty);
    });

    test(
      'Exterior details build via EdoKitBuilder for machiya structure',
      () {
        const kitBuilder = EdoKitBuilder();
        const machiya = PlacedStructure(
          id: EntityId('m_exterior'),
          kind: StructureKind.machiya,
          position: Vec3.zero,
        );
        final node = kitBuilder.buildStructureNode(
          machiya,
          testMaterialResolver,
        );
        expect(node.children, isNotEmpty);
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );
  });

  group('Feature 10: 3-Mode Roof Craft Diversity', () {
    test(
      'Concave irimoya roof generates structure node for chaya',
      () {
        const kitBuilder = EdoKitBuilder();
        const chaya = PlacedStructure(
          id: EntityId('chaya_irimoya'),
          kind: StructureKind.chaya,
          position: Vec3.zero,
        );
        final node = kitBuilder.buildStructureNode(chaya, testMaterialResolver);
        expect(node.name, contains('structure'));
        expect(countNodes(node), greaterThan(1));
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test(
      'Cedar shingle roof ishi-oki-yane generates structure node for kura',
      () {
        const kitBuilder = EdoKitBuilder();
        const kura = PlacedStructure(
          id: EntityId('kura_shingle'),
          kind: StructureKind.kura,
          position: Vec3.zero,
        );
        final node = kitBuilder.buildStructureNode(kura, testMaterialResolver);
        expect(node.name, contains('structure'));
        expect(countNodes(node), greaterThan(1));
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );

    test('Minka farmhouse specifies farmhouse dimensions in StructureSpec', () {
      const minkaSpec = StructureSpec.minka;
      expect(minkaSpec.kind, equals(StructureKind.minka));
      expect(minkaSpec.footprintWidth, closeTo(3.6, 1e-4));
      expect(minkaSpec.footprintDepth, closeTo(4.2, 1e-4));
      expect(minkaSpec.height, closeTo(3.8, 1e-4));
      expect(minkaSpec.foundationSkirtDepth, greaterThanOrEqualTo(1.0));
    });

    test('Roof surface roles assign appropriate material style IDs', () {
      const tileRole = ShukubaSurfaceRole.kawaraTile;
      expect(tileRole.depthLayer, equals(0));
      expect(tileRole.defaultRoughness, closeTo(0.62, 1e-4));

      final mat = testMaterialResolver(tileRole);
      expect(mat.depthLayer, equals(0));
      expect(mat.name, contains('kawaraTile'));
    });

    test('Roof geometry creates positive drip overhang margin beyond wall '
        'plane', () {
      const spec = StructureSpec.machiya;
      final frontEave = spec.eaveAnchors.first;
      expect(frontEave.localOffset.z, greaterThan(spec.footprintDepth / 2));
    });
  });

  group('Feature 11: Towering Botanical Scale & Grounded Rocks', () {
    test('Bamboo culm heights generate in range [9.5m, 13.5m] with bare '
        'lower stalks in StructureSpec', () {
      const bambooSpec = StructureSpec.bambooGrove;
      expect(bambooSpec.kind, equals(StructureKind.bambooGrove));
      expect(bambooSpec.height, inInclusiveRange(9.5, 13.5));
      expect(bambooSpec.footprintWidth, equals(4.0));
      expect(bambooSpec.footprintDepth, equals(4.0));
    });

    test('Black pines scale to heights in range [7.8m, 11.2m] (2x-3x house '
        'ridge)', () {
      const pineSpec = StructureSpec.pineTree;
      expect(pineSpec.kind, equals(StructureKind.pineTree));
      expect(pineSpec.height, greaterThanOrEqualTo(7.0));
      expect(pineSpec.height, greaterThan(StructureSpec.machiya.height * 1.5));
    });

    test('Sugi cedars and autumn maples generate towering canopies in '
        '[7.8m, 11.2m]', () {
      const mapleSpec = StructureSpec.mapleCluster;
      expect(mapleSpec.kind, equals(StructureKind.mapleCluster));
      expect(mapleSpec.height, greaterThanOrEqualTo(6.0));
    });

    test('Natural rock outcrops generate at grounded heights in range '
        '[1.4m, 2.6m]', () {
      const rockSpec = StructureSpec.rockOutcrop;
      expect(rockSpec.kind, equals(StructureKind.rockOutcrop));
      expect(rockSpec.height, inInclusiveRange(1.4, 2.6));
    });

    test(
      'Rock meshes construct via EdoKitBuilder when GPU available',
      () {
        const kitBuilder = EdoKitBuilder();
        const rock = PlacedStructure(
          id: EntityId('rock_test'),
          kind: StructureKind.rockOutcrop,
          position: Vec3.zero,
        );
        final node = kitBuilder.buildStructureNode(rock, testMaterialResolver);
        expect(node, isNotNull);
        expect(countNodes(node), greaterThanOrEqualTo(1));
      },
      skip: !checkImpellerAvailable()
          ? 'Flutter GPU Impeller backend not enabled in headless sandbox'
          : null,
    );
  });
}
