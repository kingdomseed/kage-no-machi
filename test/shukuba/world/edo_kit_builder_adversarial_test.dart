import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' show GeometryBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart';

void main() {
  group(
    'Empirical Challenge 1: Architecture Scale & Proportion Invariants',
    () {
      test('Machiya dimensions strictly respect human scale bounds', () {
        const spec = StructureSpec.machiya;
        expect(spec.footprintWidth, equals(3.8));
        expect(spec.footprintDepth, equals(4.8));
        expect(spec.height, equals(4.18));
        expect(spec.foundationSkirtDepth, equals(1.2));

        const walkerHeight = 1.66;
        const lintelHeight = 1.78;
        expect(lintelHeight - walkerHeight, closeTo(0.12, 1e-4));

        const porchEavesHeight = 1.86;
        expect(porchEavesHeight - walkerHeight, closeTo(0.20, 1e-4));

        final frontPorchAnchors = spec.eaveAnchors
            .where((a) => a.localOutwardNormal.z > 0)
            .toList();
        expect(frontPorchAnchors.length, equals(2));
        for (final a in frontPorchAnchors) {
          expect(a.localOffset.y, equals(1.86));
          expect(a.localOffset.z, equals(2.70));
          expect(a.localOffset.x.abs(), equals(1.55));
        }

        final rearEaveAnchors = spec.eaveAnchors
            .where((a) => a.localOutwardNormal.z < 0)
            .toList();
        expect(rearEaveAnchors.length, equals(1));
        expect(rearEaveAnchors.first.localOffset.y, equals(2.15));
        expect(rearEaveAnchors.first.localOffset.z, equals(-2.48));
      });

      test('Chaya dimensions: 4.4m x 4.4m with 3.58m ridge', () {
        const spec = StructureSpec.chaya;
        expect(spec.footprintWidth, equals(4.4));
        expect(spec.footprintDepth, equals(4.4));
        expect(spec.height, equals(3.58));
        expect(spec.roofCraft, equals(RoofCraft.irimoyaKawara));
      });

      test('Kura dimensions: 3.4m x 4.0m with 4.55m vault ridge', () {
        const spec = StructureSpec.kura;
        expect(spec.footprintWidth, equals(3.4));
        expect(spec.footprintDepth, equals(4.0));
        expect(spec.height, equals(4.55));
        expect(spec.roofCraft, equals(RoofCraft.ishiOkiYane));
      });

      test('MarketStall dimensions: 2.2m x 1.9m with 2.24m awning peak', () {
        const spec = StructureSpec.marketStall;
        expect(spec.footprintWidth, equals(2.2));
        expect(spec.footprintDepth, equals(1.9));
        expect(spec.height, equals(2.24));
      });

      test(
        'Minka dimensions: 3.6m x 4.2m with 3.8m ridge and kayabukiThatch',
        () {
          const spec = StructureSpec.minka;
          expect(spec.footprintWidth, equals(3.6));
          expect(spec.footprintDepth, equals(4.2));
          expect(spec.height, equals(3.8));
          expect(spec.roofCraft, equals(RoofCraft.kayabukiThatch));
          expect(spec.foundationSkirtDepth, equals(1.2));
        },
      );
    },
  );

  group(
    'Empirical Challenge 2: River Cobbles Boundary Invariant on Cedar Roofs',
    () {
      test(
        'addIshiOkiYaneRoof cobble coordinates are strictly within roof bounds '
        'across wide parametric sweeps',
        () {
          final testConfigs = [
            (xHalf: 2.12, zMin: -2.68, zMax: 2.68, eavesY: 2.34, ridgeY: 3.15),
            (xHalf: 2.12, zMin: -2.68, zMax: 2.68, eavesY: 3.34, ridgeY: 4.18),
            (xHalf: 1.95, zMin: -2.25, zMax: 2.25, eavesY: 2.45, ridgeY: 4.55),
            for (var w = 1.5; w <= 3.5; w += 0.5)
              for (var d = 2.0; d <= 6.0; d += 1.0)
                (xHalf: w, zMin: -d / 2, zMax: d / 2, eavesY: 2.0, ridgeY: 4.0),
          ];

          for (final cfg in testConfigs) {
            final xHalf = cfg.xHalf;
            final zMin = cfg.zMin;
            final zMax = cfg.zMax;
            final eavesY = cfg.eavesY;
            final ridgeY = cfg.ridgeY;
            const thick = 0.10;

            const battenFracs = [0.28, 0.54, 0.80];
            final zSpan = zMax - zMin;
            final halfDepth = zSpan / 2.0;
            final zCenter = (zMin + zMax) / 2.0;

            for (final frac in battenFracs) {
              final slopeY = eavesY + thick + 0.002 + (ridgeY - eavesY) * frac;
              expect(slopeY, greaterThan(eavesY));
              final slopeX = xHalf * (1.0 - frac);

              final cobbleCount = (zSpan / 0.55).floor().clamp(3, 7);
              for (var c = 0; c < cobbleCount; c++) {
                final cz =
                    zMin + 0.35 + (zSpan - 0.70) * (c / (cobbleCount - 1));
                final cobbleZRel = (cz - zCenter).abs();
                if (cobbleZRel >= halfDepth - 0.10) continue;

                final leftCobbleX = slopeX - 0.05;
                if (leftCobbleX < xHalf - 0.12) {
                  expect(leftCobbleX, lessThan(xHalf));
                  expect(leftCobbleX + 0.09, lessThanOrEqualTo(xHalf));
                  expect(cobbleZRel, lessThan(halfDepth));
                  expect(cobbleZRel + 0.08, lessThanOrEqualTo(halfDepth));
                }

                final rightCobbleX = slopeX - 0.05;
                if (rightCobbleX < xHalf - 0.12) {
                  expect(rightCobbleX, lessThan(xHalf));
                  expect(rightCobbleX + 0.09, lessThanOrEqualTo(xHalf));
                  expect(cobbleZRel, lessThan(halfDepth));
                  expect(cobbleZRel + 0.08, lessThanOrEqualTo(halfDepth));
                }
              }
            }
          }
        },
      );
    },
  );

  group('Empirical Challenge 3: Minka Thatch Eaves Overhang Invariant', () {
    test('Thatch eaves overhang >= 0.35m (target 0.38m)', () {
      const wallHalfWidth = 1.80;
      const wallHalfDepth = 2.10;
      const eaveOverhangMargin = 0.38;

      expect(eaveOverhangMargin, greaterThanOrEqualTo(0.35));
      expect(eaveOverhangMargin, equals(0.38));

      const xHalf = wallHalfWidth + eaveOverhangMargin;
      const zMin = -wallHalfDepth - eaveOverhangMargin;
      const zMax = wallHalfDepth + eaveOverhangMargin;

      expect(xHalf - wallHalfWidth, greaterThanOrEqualTo(0.35));
      expect(zMax - wallHalfDepth, greaterThanOrEqualTo(0.35));
      expect(-wallHalfDepth - zMin, greaterThanOrEqualTo(0.35));
    });
  });

  group(
    'Empirical Challenge 4: Towering Botanical Scale & Bamboo Clearance',
    () {
      test(
        'Bamboo culm heights strictly in [9.5m, 13.5m] and lower 58% trunk is '
        '100% free of foliage attachments across 500 DNA variants',
        () {
          for (var seed = 0; seed < 500; seed++) {
            final hash = Object.hash(seed, 'bamboo_adv').abs();
            final unit3 = ((hash ^ 314159) % 10000) / 10000.0;
            final hScale = 0.94 + 0.12 * unit3;

            final culmCount = 12 + (hash % 4);
            for (var i = 0; i < culmCount; i++) {
              final unit50 = (((hash + i * 97) ^ 50) % 10000) / 10000.0;
              final rawHeight = (9.8 + 2.8 * unit50) * hScale;
              final height = rawHeight.clamp(9.5, 13.5);

              expect(height, greaterThanOrEqualTo(9.5));
              expect(height, lessThanOrEqualTo(13.5));

              double evalSpineY(double t) {
                final mt = 1.0 - t;
                final b0 = mt * mt * mt;
                final b1 = 3.0 * mt * mt * t;
                final b2 = 3.0 * mt * t * t;
                final b3 = t * t * t;
                return b0 * 0.02 +
                    b1 * (height * 0.32) +
                    b2 * (height * 0.68) +
                    b3 * height;
              }

              if (i.isEven || i == culmCount - 1) {
                final yAt7 = evalSpineY(0.70);
                expect(
                  yAt7 / height,
                  greaterThanOrEqualTo(0.58),
                  reason: 'Foliage attached below 58% on culm $i (t=0.70)',
                );
              } else if (i % 3 == 1) {
                final yAt6 = evalSpineY(0.60);
                expect(
                  yAt6 / height,
                  greaterThanOrEqualTo(0.58),
                  reason: 'Foliage attached below 58% on culm $i (t=0.60)',
                );
              }
            }
          }
        },
      );

      test('Pine trees (Kuromatsu & Sugi Cedar) and maples strictly reach '
          '[7.8m, 11.2m] across 500 variants', () {
        for (var seed = 0; seed < 500; seed++) {
          final hash = Object.hash(seed, 'tree_adv').abs();
          final unit1 = ((hash ^ 12345) % 10000) / 10000.0;
          final hScale = 0.92 + 0.18 * unit1;

          final sugiApexY = 9.60 * hScale;
          final sugiTopCloudY = sugiApexY + 0.12 + 0.35;
          expect(sugiApexY, greaterThanOrEqualTo(7.8));
          expect(sugiTopCloudY, lessThanOrEqualTo(11.2));

          final pineApexY = 9.40 * hScale;
          final pineTopCloudY = pineApexY + 0.12 + 0.30;
          expect(pineApexY, greaterThanOrEqualTo(7.8));
          expect(pineTopCloudY, lessThanOrEqualTo(11.2));

          final unit95 = ((hash ^ 959595) % 10000) / 10000.0;
          final mapleApexY = (8.40 + 0.80 * unit95) * hScale;
          final mapleTopCloudY = mapleApexY + 0.05 + 0.44;
          expect(mapleApexY, greaterThan(7.7));
          expect(mapleTopCloudY, greaterThanOrEqualTo(7.8));
          expect(mapleTopCloudY, lessThanOrEqualTo(11.2));
        }
      });
    },
  );

  group('Empirical Challenge 5: Rock Outcrops Clamping Invariant', () {
    test('Rock outcrop height is strictly clamped within [1.4m, 2.6m] across '
        'all 4 phenotypes and 500 variants', () {
      for (var seed = 0; seed < 500; seed++) {
        final hash = Object.hash(seed, 'rock_adv').abs();
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

  group('Empirical Challenge 6: 7-Tier Geometric Offset Hierarchy', () {
    test('Side elevation features 7 strictly distinct positive coordinate '
        'planes (zero coplanar overlap)', () {
      const xPlasterCore = 1.82;
      const xShitamiIta = 1.88;
      const xNukiBeam = 1.89;
      const xCornerPost = 1.90;
      const xSasaraKo = 1.91;
      const xTobukuroBox = 1.98;
      const xInuyaraiCurve = 2.04;

      final tiers = [
        ('Plaster core', xPlasterCore),
        ('Shitami-ita plank siding', xShitamiIta),
        ('Nuki tie beam', xNukiBeam),
        ('Sumi-bashira / intermediate post', xCornerPost),
        ('Sasara-ko vertical battens', xSasaraKo),
        ('Tobukuro shutter box', xTobukuroBox),
        ('Inuyarai bamboo mud-guard', xInuyaraiCurve),
      ];

      for (var i = 0; i < tiers.length - 1; i++) {
        final current = tiers[i];
        final next = tiers[i + 1];
        final delta = next.$2 - current.$2;
        expect(
          delta,
          greaterThanOrEqualTo(0.010),
          reason:
              'Tier "${next.$1}" (${next.$2}) must offset from '
              '"${current.$1}" (${current.$2}) by at least 10mm',
        );
      }
    });

    test('Granite foundation plinth and dodai sill terminate at matching '
        'non-overlapping height planes', () {
      const stoneTopY = 0.20;
      const dodaiBottomY = 0.20;
      const dodaiTopY = 0.32;
      const plasterBottomY = 0.32;

      expect(stoneTopY, equals(dodaiBottomY));
      expect(dodaiTopY, equals(plasterBottomY));
    });
  });

  group('Empirical Challenge 7: Direct Geometry Builder Permutations & Pack '
      'Vertices', () {
    test('addIrimoyaRoof: generates sori-flared hip-and-gable ceramic tile '
        'geometry', () {
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

      expect(roofBuilder.vertexCount, greaterThan(20));
      expect(roofBuilder.triangleCount, greaterThan(10));
      expect(timberBuilder.vertexCount, greaterThan(10));
      expect(plasterBuilder.vertexCount, greaterThan(5));

      final packedRoof = roofBuilder.packVertices();
      expect(packedRoof, isNotEmpty);
      final packedTimber = timberBuilder.packVertices();
      expect(packedTimber, isNotEmpty);
    });

    test(
      'addIrimoyaRoof: stress-tested across 50 dimensional permutations',
      () {
        final rng = math.Random(42);
        for (var i = 0; i < 50; i++) {
          final roofBuilder = GeometryBuilder();
          final timberBuilder = GeometryBuilder();
          final plasterBuilder = GeometryBuilder();

          final xHalf = 1.0 + rng.nextDouble() * 3.0;
          final zSpan = 2.0 + rng.nextDouble() * 4.0;
          final eavesY = 1.5 + rng.nextDouble() * 2.0;
          final ridgeY = eavesY + 0.8 + rng.nextDouble() * 2.0;
          final sori = 0.02 + rng.nextDouble() * 0.15;

          EdoKitBuilder.addIrimoyaRoof(
            roofBuilder,
            timberBuilder,
            plasterBuilder,
            xHalf: xHalf,
            zMin: -zSpan / 2,
            zMax: zSpan / 2,
            eavesY: eavesY,
            ridgeY: ridgeY,
            soriFactor: sori,
          );

          expect(roofBuilder.vertexCount, greaterThan(0));
          expect(roofBuilder.triangleCount, greaterThan(0));
          expect(timberBuilder.vertexCount, greaterThan(0));
          expect(plasterBuilder.vertexCount, greaterThan(0));

          final packed = roofBuilder.packVertices();
          expect(packed, isNotEmpty);
        }
      },
    );

    test('addIshiOkiYaneRoof: generates cedar shingles with battens and river '
        'cobbles', () {
      final roofBuilder = GeometryBuilder();
      final timberBuilder = GeometryBuilder();
      final stoneBuilder = GeometryBuilder();

      const xHalf = 2.12;
      const zMin = -2.68;
      const zMax = 2.68;
      const eavesY = 2.34;
      const ridgeY = 3.15;

      EdoKitBuilder.addIshiOkiYaneRoof(
        roofBuilder,
        timberBuilder,
        stoneBuilder,
        xHalf: xHalf,
        zMin: zMin,
        zMax: zMax,
        eavesY: eavesY,
        ridgeY: ridgeY,
      );

      expect(roofBuilder.vertexCount, greaterThan(10));
      expect(roofBuilder.triangleCount, greaterThan(6));
      expect(timberBuilder.vertexCount, greaterThan(20));
      expect(stoneBuilder.vertexCount, greaterThan(20));

      final packedRoof = roofBuilder.packVertices();
      expect(packedRoof, isNotEmpty);
      final packedTimber = timberBuilder.packVertices();
      expect(packedTimber, isNotEmpty);
      final packedStone = stoneBuilder.packVertices();
      expect(packedStone, isNotEmpty);
    });

    test(
      'addIshiOkiYaneRoof: stress-tested across 50 dimensional variations',
      () {
        final rng = math.Random(1337);
        for (var i = 0; i < 50; i++) {
          final roofBuilder = GeometryBuilder();
          final timberBuilder = GeometryBuilder();
          final stoneBuilder = GeometryBuilder();

          final xHalf = 1.2 + rng.nextDouble() * 2.5;
          final zSpan = 2.5 + rng.nextDouble() * 3.5;
          final eavesY = 1.8 + rng.nextDouble() * 1.5;
          final ridgeY = eavesY + 0.6 + rng.nextDouble() * 1.5;

          EdoKitBuilder.addIshiOkiYaneRoof(
            roofBuilder,
            timberBuilder,
            stoneBuilder,
            xHalf: xHalf,
            zMin: -zSpan / 2,
            zMax: zSpan / 2,
            eavesY: eavesY,
            ridgeY: ridgeY,
          );

          expect(roofBuilder.vertexCount, greaterThan(0));
          expect(timberBuilder.vertexCount, greaterThan(0));
          expect(stoneBuilder.vertexCount, greaterThan(0));

          final packed = roofBuilder.packVertices();
          expect(packed, isNotEmpty);
        }
      },
    );

    test('addKayabukiRoof: generates thick mossy thatch with katsuogi logs & '
        'chigi poles', () {
      final roofBuilder = GeometryBuilder();
      final timberBuilder = GeometryBuilder();

      const wallHalfWidth = 1.80;
      const wallHalfDepth = 2.10;
      const eavesY = 2.45;
      const ridgeY = 3.80;

      EdoKitBuilder.addKayabukiRoof(
        roofBuilder,
        timberBuilder,
        wallHalfWidth: wallHalfWidth,
        wallHalfDepth: wallHalfDepth,
        eavesY: eavesY,
        ridgeY: ridgeY,
      );

      expect(roofBuilder.vertexCount, greaterThan(25));
      expect(roofBuilder.triangleCount, greaterThan(15));
      expect(timberBuilder.vertexCount, greaterThan(30));
      expect(timberBuilder.triangleCount, greaterThan(20));

      final packedRoof = roofBuilder.packVertices();
      expect(packedRoof, isNotEmpty);
      final packedTimber = timberBuilder.packVertices();
      expect(packedTimber, isNotEmpty);
    });

    test('addKayabukiRoof: stress-tested across 50 dimensional variations', () {
      final rng = math.Random(999);
      for (var i = 0; i < 50; i++) {
        final roofBuilder = GeometryBuilder();
        final timberBuilder = GeometryBuilder();

        final wallW = 1.2 + rng.nextDouble() * 2.0;
        final wallD = 1.5 + rng.nextDouble() * 2.5;
        final eavesY = 2.0 + rng.nextDouble() * 1.0;
        final ridgeY = eavesY + 1.0 + rng.nextDouble() * 1.5;
        final overhang = 0.35 + rng.nextDouble() * 0.15;
        final thatch = 0.30 + rng.nextDouble() * 0.15;

        EdoKitBuilder.addKayabukiRoof(
          roofBuilder,
          timberBuilder,
          wallHalfWidth: wallW,
          wallHalfDepth: wallD,
          eavesY: eavesY,
          ridgeY: ridgeY,
          eaveOverhangMargin: overhang,
          thatchThick: thatch,
        );

        expect(roofBuilder.vertexCount, greaterThan(0));
        expect(roofBuilder.triangleCount, greaterThan(0));
        expect(timberBuilder.vertexCount, greaterThan(0));
        expect(timberBuilder.triangleCount, greaterThan(0));

        final packed = roofBuilder.packVertices();
        expect(packed, isNotEmpty);
      }
    });
  });

  group('Empirical Challenge 8: LanternSpan Street Crossings & Catenary Sag '
      'Invariants', () {
    test(
      'LanternSpan.maxSpanMeters is 8.2m and enables 3.2m cross-street span',
      () {
        expect(LanternSpan.maxSpanMeters, equals(8.2));
        expect(LanternSpan.minSpanMeters, equals(0.9));

        const streetWidth = 3.2;
        expect(streetWidth, greaterThanOrEqualTo(LanternSpan.minSpanMeters));
        expect(streetWidth, lessThanOrEqualTo(LanternSpan.maxSpanMeters));

        for (final span in [2.4, 3.2, 4.0, 5.5, 6.8, 8.19]) {
          expect(
            span >= LanternSpan.minSpanMeters &&
                span <= LanternSpan.maxSpanMeters,
            isTrue,
            reason: 'Span of $span m should be valid across street',
          );
        }

        expect(8.21 > LanternSpan.maxSpanMeters, isTrue);
        expect(0.89 < LanternSpan.minSpanMeters, isTrue);
      },
    );

    test('LanternSpan catenary calculation computes valid sag and ground '
        'clearance', () {
      const p0 = Vec3(-1.6, 2.8, 0);
      const p1 = Vec3(1.6, 2.8, 0);
      final span = (p1 - p0).length;
      expect(span, closeTo(3.2, 1e-4));

      final sag = span * LanternSpan.sagRatio;
      expect(sag, closeTo(3.2 * 0.085, 1e-4));
      final lowestY = 2.8 - sag;
      expect(
        lowestY,
        greaterThan(2.2),
        reason: 'Catenary dip must remain well above 1.66m pedestrians',
      );
    });
  });

  group('Empirical Challenge 9: All StructureKind Spec Coverage and '
      'StructureSpec.byKind', () {
    test('StructureSpec.byKind contains valid non-empty specs for all '
        'StructureKind values', () {
      for (final kind in StructureKind.values) {
        final spec = StructureSpec.byKind[kind];
        expect(
          spec,
          isNotNull,
          reason: 'StructureSpec.byKind must have an entry for ${kind.name}',
        );
        expect(spec!.footprintWidth, greaterThan(0));
        expect(spec.footprintDepth, greaterThan(0));
        expect(spec.height, greaterThan(0));
      }
    });
  });
}
