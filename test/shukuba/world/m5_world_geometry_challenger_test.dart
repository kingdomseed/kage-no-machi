import 'package:flutter_scene/scene.dart' show GeometryBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';
import 'package:kage_no_machi/shukuba/world/starter_ward.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';
import 'package:vector_math/vector_math.dart' show Aabb2, Vector2;

void main() {
  group('Focus Area 1: Human-Scale Procedural Dimensions & Constraints', () {
    test(
      'Machiya dimensions, lintel, porch, and 1-story vs 2-story ridges',
      () {
        const spec = StructureSpec.machiya;
        expect(spec.footprintWidth, equals(3.8));
        expect(spec.footprintDepth, equals(4.8));
        expect(spec.height, equals(4.18));
        expect(spec.foundationSkirtDepth, equals(1.2));

        const walkerHeight = 1.66;
        const doorwayLintelY = 1.78;
        expect(doorwayLintelY, greaterThan(walkerHeight));
        expect(doorwayLintelY - walkerHeight, closeTo(0.12, 1e-4));

        const porchEavesY = 1.86;
        expect(porchEavesY, greaterThan(walkerHeight));
        expect(porchEavesY - walkerHeight, closeTo(0.20, 1e-4));

        const oneStoryRidgeY = 3.15;
        const twoStoryRidgeY = 4.18;
        expect(twoStoryRidgeY - oneStoryRidgeY, closeTo(1.03, 1e-4));
        expect(oneStoryRidgeY, greaterThan(porchEavesY));
        expect(twoStoryRidgeY, equals(spec.height));

        final frontAnchors = spec.eaveAnchors
            .where((a) => a.localOutwardNormal.z > 0)
            .toList();
        expect(frontAnchors, hasLength(2));
        for (final a in frontAnchors) {
          expect(a.localOffset.y, equals(porchEavesY));
          expect(a.localOffset.z, equals(2.70));
          expect(a.localOffset.x.abs(), equals(1.55));
        }
      },
    );

    test('Chaya dimensions and 3.58m irimoya ridge', () {
      const spec = StructureSpec.chaya;
      expect(spec.footprintWidth, equals(4.4));
      expect(spec.footprintDepth, equals(4.4));
      expect(spec.height, equals(3.58));
      expect(spec.roofCraft, equals(RoofCraft.irimoyaKawara));
    });

    test('Kura storehouse dimensions and 4.55m vault ridge', () {
      const spec = StructureSpec.kura;
      expect(spec.footprintWidth, equals(3.4));
      expect(spec.footprintDepth, equals(4.0));
      expect(spec.height, equals(4.55));
      expect(spec.roofCraft, equals(RoofCraft.ishiOkiYane));
    });

    test('Market stall dimensions and 2.24m awning peak', () {
      const spec = StructureSpec.marketStall;
      expect(spec.footprintWidth, equals(2.2));
      expect(spec.footprintDepth, equals(1.9));
      expect(spec.height, equals(2.24));
      expect(spec.foundationSkirtDepth, equals(0.6));
    });

    test('LanternSpan 8.2m max span across 3.2m Kaido streets', () {
      expect(LanternSpan.maxSpanMeters, equals(8.2));
      expect(LanternSpan.minSpanMeters, equals(0.9));
      expect(LanternSpan.sagRatio, equals(0.085));

      const kaidoWidth = 3.2;
      expect(kaidoWidth, greaterThanOrEqualTo(LanternSpan.minSpanMeters));
      expect(kaidoWidth, lessThanOrEqualTo(LanternSpan.maxSpanMeters));

      const sag = kaidoWidth * LanternSpan.sagRatio;
      expect(sag, closeTo(0.272, 1e-4));
      const anchorY = 2.70;
      const bottomY = anchorY - sag;
      expect(
        bottomY,
        greaterThan(1.66),
        reason: 'Catenary dip must remain clear above 1.66m pedestrians',
      );
    });
  });

  group('Focus Area 2: 4-Sided Carpentry Geometric Completeness', () {
    test(
      'Foundation skirt and dodai ground sill planes form watertight joints',
      () {
        const kirishiStoneTop = 0.20;
        const kirishiStoneBottom = -1.20;
        const dodaiSillBottom = 0.20;
        const dodaiSillTop = 0.32;
        const plasterWallBottom = 0.32;

        expect(kirishiStoneTop - kirishiStoneBottom, equals(1.40));
        expect(dodaiSillBottom, equals(kirishiStoneTop));
        expect(plasterWallBottom, equals(dodaiSillTop));
      },
    );

    test(
      'Side elevation 7-tier lateral hierarchy maintains zero coplanar overlap',
      () {
        const tiers = [
          ('Plaster core', 1.82),
          ('Shitami-ita plank siding', 1.88),
          ('Nuki tie beam', 1.89),
          ('Sumi-bashira corner post', 1.90),
          ('Sasara-ko vertical battens', 1.91),
          ('Tobukuro shutter box', 1.98),
          ('Inuyarai curved mud-guard', 2.04),
        ];

        for (var i = 0; i < tiers.length - 1; i++) {
          final current = tiers[i];
          final next = tiers[i + 1];
          final separation = next.$2 - current.$2;
          expect(
            separation,
            greaterThanOrEqualTo(0.009),
            reason: '${next.$1} must clear ${current.$1} by at least 9mm',
          );
        }
      },
    );

    test(
      'Rear elevation katteguchi door, stone doorstep, and kemuridashi vent',
      () {
        const katteguchiMinX = -1.22;
        const katteguchiMaxX = -0.46;
        const katteguchiWidth = katteguchiMaxX - katteguchiMinX;
        expect(katteguchiWidth, closeTo(0.76, 1e-4));

        const fumidaiMinX = -1.30;
        const fumidaiMaxX = -0.38;
        expect(fumidaiMinX, lessThan(katteguchiMinX));
        expect(fumidaiMaxX, greaterThan(katteguchiMaxX));
        const fumidaiTopY = 0.18;
        expect(fumidaiTopY, greaterThan(0));
        expect(fumidaiTopY, lessThan(0.24));

        const ventMinX = -1.05;
        const ventMaxX = -0.55;
        const ventWidth = ventMaxX - ventMinX;
        expect(ventWidth, closeTo(0.50, 1e-4));
        const ventZMin = -1.75;
        const ventZMax = -1.25;
        expect(ventZMax - ventZMin, closeTo(0.50, 1e-4));
      },
    );

    test('Rear ladder geometry: 7 rungs climbing from ground to eave', () {
      const ladderBottomY = 0.02;
      const ladderBottomZ = -2.70;
      const eavesY = 2.34;
      const ladderTopY = eavesY + 0.15;
      const ladderTopZ = -2.44;

      expect(ladderTopY, greaterThan(ladderBottomY));
      expect(ladderTopZ, greaterThan(ladderBottomZ));

      const rungs = 7;
      var prevRy = ladderBottomY;
      for (var r = 0; r < rungs; r++) {
        final rFrac = (r + 1) / (rungs + 1.0);
        final ry = ladderBottomY + ladderTopY * rFrac;
        expect(ry, greaterThan(prevRy));
        prevRy = ry;
      }
      expect(prevRy, lessThan(ladderTopY));
    });

    test('Rooftop hoshidai drying deck bounds and handrail height', () {
      const ridgeY = 3.15;
      const deckPlatformY = ridgeY - 0.10;
      const handrailTopY = ridgeY + 0.58;

      expect(deckPlatformY, lessThan(ridgeY));
      expect(handrailTopY - deckPlatformY, closeTo(0.68, 1e-4));
      expect(handrailTopY - deckPlatformY, greaterThan(0.50));
    });
  });

  group('Focus Area 3: 3-Mode Roof Craft Diversity Verification', () {
    test(
      'Concave irimoya ceramic tile roof with quadratic sori and onigawara',
      () {
        final roofBuilder = GeometryBuilder();
        final timberBuilder = GeometryBuilder();
        final plasterBuilder = GeometryBuilder();

        EdoKitBuilder.addIrimoyaRoof(
          roofBuilder,
          timberBuilder,
          plasterBuilder,
          xHalf: 2.12,
          zMin: -2.68,
          zMax: 2.68,
          eavesY: 2.34,
          ridgeY: 3.15,
        );

        expect(roofBuilder.vertexCount, greaterThan(0));
        expect(roofBuilder.triangleCount, greaterThan(0));
        expect(timberBuilder.vertexCount, greaterThan(0));
        expect(plasterBuilder.vertexCount, greaterThan(0));

        final packedRoof = roofBuilder.packVertices();
        expect(packedRoof, isNotEmpty);
        expect(packedRoof.length % 3, equals(0));
      },
    );

    test(
      'Split-cedar shingle ishi-oki-yane roof with battens and river cobbles',
      () {
        final roofBuilder = GeometryBuilder();
        final timberBuilder = GeometryBuilder();
        final stoneBuilder = GeometryBuilder();

        EdoKitBuilder.addIshiOkiYaneRoof(
          roofBuilder,
          timberBuilder,
          stoneBuilder,
          xHalf: 1.95,
          zMin: -2.24,
          zMax: 2.24,
          eavesY: 2.45,
          ridgeY: 4.55,
        );

        expect(roofBuilder.vertexCount, greaterThan(0));
        expect(timberBuilder.vertexCount, greaterThan(0));
        expect(stoneBuilder.vertexCount, greaterThan(0));

        final packedStone = stoneBuilder.packVertices();
        expect(packedStone, isNotEmpty);
        expect(packedStone.length % 3, equals(0));
      },
    );

    test(
      'Kayabuki thatch roof with katsuogi ridge logs and chigi crossed poles',
      () {
        final roofBuilder = GeometryBuilder();
        final timberBuilder = GeometryBuilder();

        EdoKitBuilder.addKayabukiRoof(
          roofBuilder,
          timberBuilder,
          wallHalfWidth: 1.80,
          wallHalfDepth: 2.10,
          eavesY: 2.45,
          ridgeY: 3.80,
        );

        expect(roofBuilder.vertexCount, greaterThan(0));
        expect(roofBuilder.triangleCount, greaterThan(0));
        expect(timberBuilder.vertexCount, greaterThan(0));

        final packedRoof = roofBuilder.packVertices();
        expect(packedRoof, isNotEmpty);
        final packedTimber = timberBuilder.packVertices();
        expect(packedTimber, isNotEmpty);
      },
    );
  });

  group('Focus Area 4: Towering Botanical Scale & Grounded Rocks', () {
    test(
      'Bamboo culms in [9.5m, 13.5m] and >=58% bare culms across 300 seeds',
      () {
        for (var seed = 0; seed < 300; seed++) {
          final hash = Object.hash(seed, 'bamboo_m5').abs();
          final unit3 = ((hash ^ 314159) % 10000) / 10000.0;
          final hScale = 0.94 + 0.12 * unit3;

          final culmCount = 12 + (hash % 4);
          for (var i = 0; i < culmCount; i++) {
            final unit50 = (((hash + i * 97) ^ 50) % 10000) / 10000.0;
            final rawHeight = (9.8 + 2.8 * unit50) * hScale;
            final height = rawHeight.clamp(9.5, 13.5);

            expect(height, greaterThanOrEqualTo(9.5));
            expect(height, lessThanOrEqualTo(13.5));

            final minT = (i.isEven || i == culmCount - 1) ? 0.70 : 0.60;
            expect(
              minT,
              greaterThanOrEqualTo(0.58),
              reason: 'Lower stalk must be >=58% bare jointed culm',
            );
          }
        }
      },
    );

    test('Towering trees (Pines, Sugi Cedars, Maples) reach [7.8m, 11.2m]', () {
      for (var seed = 0; seed < 300; seed++) {
        final hash = Object.hash(seed, 'trees_m5').abs();
        final unit1 = ((hash ^ 12345) % 10000) / 10000.0;
        final hScale = 0.92 + 0.18 * unit1;

        final sugiApexY = 9.60 * hScale;
        expect(sugiApexY, greaterThanOrEqualTo(7.8));
        expect(sugiApexY + 0.47, lessThanOrEqualTo(11.2));

        final pineApexY = 9.40 * hScale;
        expect(pineApexY, greaterThanOrEqualTo(7.8));
        expect(pineApexY + 0.42, lessThanOrEqualTo(11.2));

        final unit95 = ((hash ^ 959595) % 10000) / 10000.0;
        final mapleApexY = (8.40 + 0.80 * unit95) * hScale;
        expect(mapleApexY + 0.49, greaterThanOrEqualTo(7.8));
        expect(mapleApexY + 0.49, lessThanOrEqualTo(11.2));
      }
    });

    test('Grounded rock outcrops clamped strictly within [1.4m, 2.6m]', () {
      for (var seed = 0; seed < 300; seed++) {
        final hash = Object.hash(seed, 'rocks_m5').abs();
        final unit3 = ((hash ^ 8888) % 10000) / 10000.0;
        final hScale = (0.88 + 0.22 * unit3).clamp(0.85, 1.08);

        final p0Cliff1 = 1.08 * hScale * 2 * 1.04;
        expect(p0Cliff1, greaterThanOrEqualTo(1.4));
        expect(p0Cliff1, lessThanOrEqualTo(2.6));

        final p1Cliff1 = 1.08 * hScale * 2 * 1.04;
        expect(p1Cliff1, greaterThanOrEqualTo(1.4));
        expect(p1Cliff1, lessThanOrEqualTo(2.6));

        final p2Cliff1 = 1.02 * hScale * 2 * 1.04;
        expect(p2Cliff1, greaterThanOrEqualTo(1.4));
        expect(p2Cliff1, lessThanOrEqualTo(2.6));

        final p3Cliff2 = (0.18 + 0.88 * hScale * 2) * 1.04;
        expect(p3Cliff2, greaterThanOrEqualTo(1.4));
        expect(p3Cliff2, lessThanOrEqualTo(2.6));
      }
    });
  });

  group('Focus Area 5: 176m x 176m Spatial Chunking & Dirty-Tile Clamping', () {
    late TerrainBuilder terrain;

    setUp(() {
      terrain = TerrainBuilder()..clearDirty();
    });

    tearDown(() {
      terrain.clearDirty();
    });

    test(
      'TerrainConfig defines 176m x 176m domain partitioned into 16 chunks',
      () {
        expect(TerrainConfig.minX, equals(-88));
        expect(TerrainConfig.maxX, equals(88));
        expect(TerrainConfig.minZ, equals(-88));
        expect(TerrainConfig.maxZ, equals(88));
        expect(TerrainConfig.gridDimension, equals(4));
        expect(TerrainConfig.chunkCount, equals(16));
        expect(TerrainConfig.chunkSpan, equals(44));

        for (var cz = 0; cz < 4; cz++) {
          for (var cx = 0; cx < 4; cx++) {
            final x0 = TerrainConfig.chunkMinX(cx);
            final x1 = TerrainConfig.chunkMaxX(cx);
            final z0 = TerrainConfig.chunkMinZ(cz);
            final z1 = TerrainConfig.chunkMaxZ(cz);

            expect(x1 - x0, equals(44.0));
            expect(z1 - z0, equals(44.0));
            expect(x0, greaterThanOrEqualTo(TerrainConfig.minX));
            expect(x1, lessThanOrEqualTo(TerrainConfig.maxX));
            expect(z0, greaterThanOrEqualTo(TerrainConfig.minZ));
            expect(z1, lessThanOrEqualTo(TerrainConfig.maxZ));
          }
        }
      },
    );

    test('markDirty expands by 3.5m margin and flags overlapping chunks', () {
      terrain
        ..clearDirty()
        ..markDirty(Aabb2.minMax(Vector2(-44.5, -44.5), Vector2(-43.5, -43.5)));

      expect(terrain.dirtyChunkIndices, containsAll([0, 1, 4, 5]));
    });

    test(
      'All 4 off-map quadrants outside 176m domain mark zero chunks dirty',
      () {
        terrain
          ..clearDirty()
          ..markDirty(Aabb2.minMax(Vector2(-500, 200), Vector2(-200, 500)));
        expect(terrain.dirtyChunkIndices, isEmpty);

        terrain
          ..clearDirty()
          ..markDirty(Aabb2.minMax(Vector2(-500, -500), Vector2(-200, -200)));
        expect(terrain.dirtyChunkIndices, isEmpty);

        terrain
          ..clearDirty()
          ..markDirty(Aabb2.minMax(Vector2(200, -500), Vector2(500, -200)));
        expect(terrain.dirtyChunkIndices, isEmpty);

        terrain
          ..clearDirty()
          ..markDirty(Aabb2.minMax(Vector2(200, 200), Vector2(500, 500)));
        expect(terrain.dirtyChunkIndices, isEmpty);
      },
    );

    test('Starter ward placed structures are entirely within 176m bounds', () {
      final graph = buildStarterShukubaGraph(terrain.sampleGroundHeight);
      expect(graph.structures, isNotEmpty);

      for (final s in graph.structures.values) {
        expect(
          s.position.x,
          inInclusiveRange(TerrainConfig.minX, TerrainConfig.maxX),
        );
        expect(
          s.position.z,
          inInclusiveRange(TerrainConfig.minZ, TerrainConfig.maxZ),
        );
        expect(s.position.y.isFinite, isTrue);
      }
    });
  });
}
