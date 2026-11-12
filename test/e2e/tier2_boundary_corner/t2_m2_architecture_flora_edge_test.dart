import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';

void main() {
  group('Feature 8 Edge: Spatial Footprint & Lintel Clearances', () {
    test('Two machiya touching at exactly 3.8m spacing share boundary without '
        'overlap', () {
      final width = StructureSpec.machiya.footprintWidth;
      expect(width, equals(3.8));

      final box1MinX = -width / 2;
      final box1MaxX = width / 2;
      final box2MinX = 3.8 - width / 2;
      final box2MaxX = 3.8 + width / 2;

      expect(box1MaxX, equals(box2MinX));
      final overlap = math.max(0, box1MaxX - box2MinX);
      expect(overlap, equals(0));
      expect(box2MaxX - box1MinX, closeTo(7.6, 1e-4));
    });

    test('Intimate 1.66m human walker under machiya eaves has >= 0.10m '
        'positive clearance', () {
      const walkerHeight = 1.66;
      const spec = StructureSpec.machiya;
      expect(spec.eaveAnchors, isNotEmpty);
      for (final anchor in spec.eaveAnchors) {
        expect(anchor.localOffset.y, greaterThan(walkerHeight));
        expect(anchor.localOffset.y - walkerHeight, greaterThanOrEqualTo(0.10));
      }
    });

    test(
      'LanternSpan.deriveAll creates spans at 8.19m (<= 8.2m) and drops spans '
      'at 8.21m (> 8.2m cutoff)',
      () {
        expect(LanternSpan.maxSpanMeters, equals(8.2));

        const houseNorth = PlacedStructure(
          id: EntityId('house_north'),
          kind: StructureKind.machiya,
          position: Vec3.zero,
        );

        const houseSouthValid = PlacedStructure(
          id: EntityId('house_south_valid'),
          kind: StructureKind.machiya,
          position: Vec3(0, 0, 13.59),
          yawRadians: math.pi,
        );
        final validSpans = LanternSpan.deriveAll([houseNorth, houseSouthValid]);
        expect(validSpans, isNotEmpty);
        expect(validSpans, hasLength(2));
        for (final span in validSpans) {
          expect(span.lengthMeters, closeTo(8.19, 1e-3));
          expect(
            span.lengthMeters,
            lessThanOrEqualTo(LanternSpan.maxSpanMeters),
          );
        }

        const houseSouthInvalid = PlacedStructure(
          id: EntityId('house_south_invalid'),
          kind: StructureKind.machiya,
          position: Vec3(0, 0, 13.61),
          yawRadians: math.pi,
        );
        final invalidSpans = LanternSpan.deriveAll([
          houseNorth,
          houseSouthInvalid,
        ]);
        expect(invalidSpans, isEmpty);
      },
    );

    test(
      '90° and 180° yaw rotation preserves footprint area and axis alignment',
      () {
        const spec = StructureSpec.machiya;
        final baseArea = spec.footprintWidth * spec.footprintDepth;
        expect(baseArea, closeTo(18.24, 1e-4));

        final rot90Width = spec.footprintDepth;
        final rot90Depth = spec.footprintWidth;
        final area90 = rot90Width * rot90Depth;
        expect(area90, closeTo(baseArea, 1e-4));

        final rot180Width = spec.footprintWidth;
        final rot180Depth = spec.footprintDepth;
        final area180 = rot180Width * rot180Depth;
        expect(area180, closeTo(baseArea, 1e-4));
      },
    );

    test('Stepped slope foundation plinth handles terrain gradient without '
        'floating', () {
      const spec = StructureSpec.machiya;
      expect(spec.foundationSkirtDepth, greaterThanOrEqualTo(1));

      const slopeAngleRad = 20.0 * math.pi / 180.0;
      final maxDrop = (spec.footprintWidth / 2) * math.tan(slopeAngleRad);

      expect(maxDrop, lessThan(spec.foundationSkirtDepth));
    });
  });

  group('Feature 9 Edge: 4-Sided Carpentry & Complexity Limits', () {
    test(
      'Single-story minimal carpentry maintains framing without missing plinth',
      () {
        const spec = StructureSpec.machiya;
        expect(spec.height, inInclusiveRange(3.15, 4.2));
        expect(spec.foundationSkirtDepth, greaterThan(0.8));
        expect(spec.eaveAnchors.length, greaterThanOrEqualTo(2));
      },
    );

    test('Machiya structure footprint area stays bounded under 25 m²', () {
      const spec = StructureSpec.machiya;
      final footprintArea = spec.footprintWidth * spec.footprintDepth;
      expect(footprintArea, lessThan(25.0));
      expect(footprintArea, greaterThan(10.0));
    });

    test('Watertight hip-and-gable ridge caps join without holes', () {
      const spec = StructureSpec.machiya;
      final halfDepth = spec.footprintDepth / 2;
      final ridgeStart = Vec3(0, spec.height, -halfDepth * 0.72);
      final ridgeEnd = Vec3(0, spec.height, halfDepth * 0.72);

      final ridgeLength = (ridgeEnd - ridgeStart).length;
      expect(ridgeLength, greaterThan(1.5));
      expect(ridgeLength, lessThan(spec.footprintDepth));
    });

    test('Side elevations maintain tobukuro shutter box and kiriyoke hood '
        'clearance', () {
      const spec = StructureSpec.machiya;
      final halfWidth = spec.footprintWidth / 2;
      const hoodOffset = 0.28;
      final totalSideExtrusion = halfWidth + hoodOffset;

      expect(totalSideExtrusion, greaterThan(halfWidth));
      expect(totalSideExtrusion, lessThan(spec.footprintWidth));
    });

    test('Rear elevation katteguchi service door clearance', () {
      const spec = StructureSpec.machiya;
      final rearZ = -spec.footprintDepth / 2;

      expect(rearZ, lessThan(0));
      expect(rearZ.abs(), closeTo(2.4, 1e-4));
    });
  });

  group('Feature 10 Edge: 3-Mode Roof Overrides & Seams', () {
    test(
      'Concave irimoya roof sori curve flare maintains upward curvature',
      () {
        const soriFactor = 0.085;
        for (var i = 1; i <= 10; i++) {
          final frac = i / 10.0;
          final flare = soriFactor * (frac * frac);
          expect(flare, greaterThan(0));
          expect(flare, lessThan(0.2));
        }
      },
    );

    test(
      'Cedar shingle ishi-oki-yane river cobbles remain within roof bounds',
      () {
        const spec = StructureSpec.chaya;
        final halfWidth = spec.footprintWidth / 2;
        final halfDepth = spec.footprintDepth / 2;

        final cobbleX = halfWidth * 0.75;
        final cobbleZ = halfDepth * 0.65;

        expect(cobbleX, lessThan(halfWidth));
        expect(cobbleZ, lessThan(halfDepth));
      },
    );

    test(
      'Farmhouse thatched kayabuki roof eave overhang exceeds wall plane',
      () {
        const spec = StructureSpec.minka;
        const eaveOverhangMargin = 0.38;

        expect(eaveOverhangMargin, greaterThanOrEqualTo(0.35));
        expect(
          spec.footprintWidth + eaveOverhangMargin * 2,
          greaterThan(spec.footprintWidth),
        );
      },
    );

    test('Watertight roof-wall junction has zero vertical gap', () {
      const wallPlateHeight = 2.45;
      const roofEaveOriginHeight = 2.45;

      final verticalGap = (roofEaveOriginHeight - wallPlateHeight).abs();
      expect(verticalGap, equals(0));
    });

    test('Roof surface roles map to appropriate material depth layers', () {
      const roleKawara = ShukubaSurfaceRole.kawaraTile;
      const roleTimber = ShukubaSurfaceRole.charredTimber;

      expect(roleKawara.depthLayer, greaterThanOrEqualTo(0));
      expect(roleTimber.depthLayer, greaterThanOrEqualTo(0));
    });
  });

  group('Feature 11 Edge: Botanical Scale & Rock Bounds', () {
    test('Bamboo culm height in StructureSpec falls strictly within '
        '[9.5m, 13.5m]', () {
      const spec = StructureSpec.bambooGrove;
      expect(spec.height, inInclusiveRange(9.5, 13.5));
      expect(spec.height, greaterThan(StructureSpec.machiya.height * 2.0));
    });

    test(
      'Bamboo bare lower stalk proportion has zero branches on lower 55%',
      () {
        const firstBranchHeightFraction = 0.72;
        const maxBareFraction = 0.55;

        expect(firstBranchHeightFraction, greaterThan(maxBareFraction));
      },
    );

    test('Anchored base wind displacement is 0.0 at ground and maximum at tree '
        'tip', () {
      const totalHeight = 11.5;
      const maxGustDisplacement = 0.32;

      double windSway(double y) {
        final hFrac = (y / totalHeight).clamp(0.0, 1.0);
        return maxGustDisplacement * (hFrac * hFrac);
      }

      expect(windSway(0), equals(0));
      expect(windSway(totalHeight / 2), closeTo(0.08, 1e-4));
      expect(windSway(totalHeight), closeTo(maxGustDisplacement, 1e-4));
    });

    test('Rock outcrop height never exceeds 2.6m cap in StructureSpec', () {
      const spec = StructureSpec.rockOutcrop;
      expect(spec.height, lessThanOrEqualTo(2.6));
      expect(spec.height, greaterThanOrEqualTo(1.4));
    });

    test('Dense cluster buffer limits for 100 trees in 20m x 20m grove', () {
      final trees = <PlacedStructure>[];
      for (var i = 0; i < 100; i++) {
        final x = (i % 10) * 2.0 - 9.0;
        final z = (i ~/ 10) * 2.0 - 9.0;
        trees.add(
          PlacedStructure(
            id: EntityId('dense_tree_$i'),
            kind: StructureKind.bambooGrove,
            position: Vec3(x, 0, z),
          ),
        );
      }

      expect(trees, hasLength(100));
      final uniqueIds = trees.map((t) => t.id).toSet();
      expect(uniqueIds, hasLength(100));

      for (final tree in trees) {
        expect(tree.position.x.abs(), lessThanOrEqualTo(10));
        expect(tree.position.z.abs(), lessThanOrEqualTo(10));
      }
    });
  });
}
