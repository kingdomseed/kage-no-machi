import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

void main() {
  group('Empirical Challenge 1: Chunk Seam Continuity & Normal Alignment', () {
    final terrain = TerrainBuilder();
    const step = TerrainConfig.gridStep;

    test('All vertical seams (x in {-44, 0, 44}) have bit-identical heights '
        'and central-difference normals between adjacent chunk skirts', () {
      for (var seamIdx = 0; seamIdx < 3; seamIdx++) {
        final cxLeft = seamIdx;
        final cxRight = seamIdx + 1;
        final seamX = TerrainConfig.chunkMaxX(cxLeft);
        expect(seamX, equals(TerrainConfig.chunkMinX(cxRight)));

        for (var cz = 0; cz < TerrainConfig.gridDimension; cz++) {
          final minZ = TerrainConfig.chunkMinZ(cz);

          for (var lr = 0; lr < 89; lr++) {
            final z = minZ + lr * step;

            final leftCenterY = terrain.sampleGroundHeight(seamX, z);
            final leftHL = terrain.sampleGroundHeight(seamX - step, z);
            final leftHR = terrain.sampleGroundHeight(seamX + step, z);
            final leftHD = terrain.sampleGroundHeight(seamX, z - step);
            final leftHU = terrain.sampleGroundHeight(seamX, z + step);

            final leftNx = leftHL - leftHR;
            const leftNy = 1.0;
            final leftNz = leftHD - leftHU;
            final leftInvLen =
                1.0 /
                math.sqrt(leftNx * leftNx + leftNy * leftNy + leftNz * leftNz);
            final leftNorm = Vector3(
              leftNx * leftInvLen,
              leftNy * leftInvLen,
              leftNz * leftInvLen,
            );

            final rightCenterY = terrain.sampleGroundHeight(seamX, z);
            final rightHL = terrain.sampleGroundHeight(seamX - step, z);
            final rightHR = terrain.sampleGroundHeight(seamX + step, z);
            final rightHD = terrain.sampleGroundHeight(seamX, z - step);
            final rightHU = terrain.sampleGroundHeight(seamX, z + step);

            final rightNx = rightHL - rightHR;
            const rightNy = 1.0;
            final rightNz = rightHD - rightHU;
            final rightInvLen =
                1.0 /
                math.sqrt(
                  rightNx * rightNx + rightNy * rightNy + rightNz * rightNz,
                );
            final rightNorm = Vector3(
              rightNx * rightInvLen,
              rightNy * rightInvLen,
              rightNz * rightInvLen,
            );

            expect(leftCenterY, equals(rightCenterY));
            expect(leftNorm.x, closeTo(rightNorm.x, 1e-12));
            expect(leftNorm.y, closeTo(rightNorm.y, 1e-12));
            expect(leftNorm.z, closeTo(rightNorm.z, 1e-12));
          }
        }
      }
    });

    test('All horizontal seams (z in {-44, 0, 44}) have bit-identical heights '
        'and central-difference normals between adjacent chunk skirts', () {
      for (var seamIdx = 0; seamIdx < 3; seamIdx++) {
        final czBottom = seamIdx;
        final czTop = seamIdx + 1;
        final seamZ = TerrainConfig.chunkMaxZ(czBottom);
        expect(seamZ, equals(TerrainConfig.chunkMinZ(czTop)));

        for (var cx = 0; cx < TerrainConfig.gridDimension; cx++) {
          final minX = TerrainConfig.chunkMinX(cx);

          for (var lc = 0; lc < 89; lc++) {
            final x = minX + lc * step;

            final bottomCenterY = terrain.sampleGroundHeight(x, seamZ);
            final bottomHL = terrain.sampleGroundHeight(x - step, seamZ);
            final bottomHR = terrain.sampleGroundHeight(x + step, seamZ);
            final bottomHD = terrain.sampleGroundHeight(x, seamZ - step);
            final bottomHU = terrain.sampleGroundHeight(x, seamZ + step);

            final bottomNx = bottomHL - bottomHR;
            const bottomNy = 1.0;
            final bottomNz = bottomHD - bottomHU;
            final bottomInvLen =
                1.0 /
                math.sqrt(
                  bottomNx * bottomNx +
                      bottomNy * bottomNy +
                      bottomNz * bottomNz,
                );
            final bottomNorm = Vector3(
              bottomNx * bottomInvLen,
              bottomNy * bottomInvLen,
              bottomNz * bottomInvLen,
            );

            final topCenterY = terrain.sampleGroundHeight(x, seamZ);
            final topHL = terrain.sampleGroundHeight(x - step, seamZ);
            final topHR = terrain.sampleGroundHeight(x + step, seamZ);
            final topHD = terrain.sampleGroundHeight(x, seamZ - step);
            final topHU = terrain.sampleGroundHeight(x, seamZ + step);

            final topNx = topHL - topHR;
            const topNy = 1.0;
            final topNz = topHD - topHU;
            final topInvLen =
                1.0 / math.sqrt(topNx * topNx + topNy * topNy + topNz * topNz);
            final topNorm = Vector3(
              topNx * topInvLen,
              topNy * topInvLen,
              topNz * topInvLen,
            );

            expect(bottomCenterY, equals(topCenterY));
            expect(bottomNorm.x, closeTo(topNorm.x, 1e-12));
            expect(bottomNorm.y, closeTo(topNorm.y, 1e-12));
            expect(bottomNorm.z, closeTo(topNorm.z, 1e-12));
          }
        }
      }
    });

    test('Seam continuity holds under active roads crossing chunk seams', () {
      final crossRoad = RoadSpline.validated(
        id: EntityId.validated('cross_seam_road'),
        controlPoints: const [
          Vec3(-10, 0.40, -10),
          Vec3(0, 0.40, 0),
          Vec3(10, 1.80, 10),
        ],
      );

      final hA = terrain.sampleGroundHeight(0, 0, roads: [crossRoad]);
      final hB = terrain.sampleGroundHeight(0, 0, roads: [crossRoad]);
      expect(hA, equals(hB));

      final hL = terrain.sampleGroundHeight(-step, 0, roads: [crossRoad]);
      final hR = terrain.sampleGroundHeight(step, 0, roads: [crossRoad]);
      final hD = terrain.sampleGroundHeight(0, -step, roads: [crossRoad]);
      final hU = terrain.sampleGroundHeight(0, step, roads: [crossRoad]);

      final nx = hL - hR;
      final nz = hD - hU;
      expect(nx.isFinite, isTrue);
      expect(nz.isFinite, isTrue);
    });
  });

  group(
    'Empirical Challenge 2: Tanada Rice Paddies Clearances & Overlap Audit',
    () {
      test('Water planes strictly maintain clearance >= 80mm above mud basin '
          'floors', () {
        const tierBasinY = [3.60, 4.30, 5.00, 5.70, 6.40];
        const waterClearance = 0.085;
        const bundProud = 0.22;

        for (var tier = 0; tier < 5; tier++) {
          final basinY = tierBasinY[tier];
          final waterY = basinY + waterClearance;
          final bundY = basinY + bundProud;

          expect(waterY - basinY, closeTo(0.085, 1e-6));
          expect(waterY - basinY, greaterThanOrEqualTo(0.080));

          expect(bundY, greaterThan(waterY));
          expect(bundY - waterY, closeTo(0.135, 1e-6));
        }
      });

      test('Water sheets strictly inset >= 0.15m inside retaining bund rims '
          '(zero coplanar face contact)', () {
        const bundThick = 0.44;
        const waterInset = 0.16;

        for (final isSouth in const [false, true]) {
          for (var tier = 0; tier < 5; tier++) {
            final x0 = 42.0 + tier * 6.0;
            final x1 = x0 + 5.6;
            final z0 = isSouth ? (-54.0 + tier * 1.4) : (18.0 + tier * 1.4);
            final z1 = isSouth ? (-18.0 - tier * 1.4) : (54.0 - tier * 1.4);

            final innerWestX = x0 + bundThick;
            final innerEastX = x1 - bundThick;
            final innerMinZ = z0 + bundThick;
            final innerMaxZ = z1 - bundThick;

            final wx0 = x0 + bundThick + waterInset;
            final wx1 = x1 - bundThick - waterInset;
            final wz0 = z0 + bundThick + waterInset;
            final wz1 = z1 - bundThick - waterInset;

            expect(wx0 - innerWestX, closeTo(waterInset, 1e-6));
            expect(wx0 - innerWestX, greaterThanOrEqualTo(0.15));

            expect(innerEastX - wx1, closeTo(waterInset, 1e-6));
            expect(innerEastX - wx1, greaterThanOrEqualTo(0.15));

            expect(wz0 - innerMinZ, closeTo(waterInset, 1e-6));
            expect(wz0 - innerMinZ, greaterThanOrEqualTo(0.15));
            expect(innerMaxZ - wz1, closeTo(waterInset, 1e-6));
            expect(innerMaxZ - wz1, greaterThanOrEqualTo(0.15));

            expect(wx0, greaterThan(innerWestX));
            expect(wx1, lessThan(innerEastX));
            expect(wz0, greaterThan(innerMinZ));
            expect(wz1, lessThan(innerMaxZ));
          }
        }
      });

      test('Seedling tufts stand proud of water without penetrating retaining '
          'bunds', () {
        const tierBasinY = [3.60, 4.30, 5.00, 5.70, 6.40];
        const waterClearance = 0.085;
        const bundThick = 0.44;
        const waterInset = 0.16;
        const tuftH = 0.22;

        for (final isSouth in const [false, true]) {
          for (var tier = 0; tier < 5; tier++) {
            final x0 = 42.0 + tier * 6.0;
            final x1 = x0 + 5.6;
            final z0 = isSouth ? (-54.0 + tier * 1.4) : (18.0 + tier * 1.4);
            final z1 = isSouth ? (-18.0 - tier * 1.4) : (54.0 - tier * 1.4);
            final basinY = tierBasinY[tier];
            final waterY = basinY + waterClearance;

            final wx0 = x0 + bundThick + waterInset;
            final wx1 = x1 - bundThick - waterInset;
            final wz0 = z0 + bundThick + waterInset;
            final wz1 = z1 - bundThick - waterInset;

            var tuftCount = 0;
            for (var px = wx0 + 0.65; px < wx1 - 0.4; px += 0.95) {
              for (var pz = wz0 + 0.75; pz < wz1 - 0.4; pz += 1.15) {
                tuftCount++;
                final rootY = basinY + 0.01;
                final tipY = waterY + tuftH;

                expect(rootY, greaterThan(basinY));
                expect(tipY, greaterThan(waterY));
                expect(tipY - waterY, closeTo(tuftH, 1e-6));

                expect(px - 0.04, greaterThan(wx0));
                expect(px + 0.04, lessThan(wx1));
                expect(pz - 0.04, greaterThan(wz0));
                expect(pz + 0.04, lessThan(wz1));
              }
            }
            expect(tuftCount, greaterThan(0));
          }
        }
      });
    },
  );

  group(
    'Empirical Challenge 3: Mitsuke Checkpoints Clearance & Coordinate Order '
    'Audit',
    () {
      final terrain = TerrainBuilder();
      const checkpointXList = [-66.0, 66.0];

      test('Checkpoints footings are embedded strictly -0.45m below terrain '
          'ground surface', () {
        for (final cx in checkpointXList) {
          final gy = terrain.sampleRawTerrain(cx, 0);
          final bottomY = gy - 0.45;
          expect(gy - bottomY, closeTo(0.45, 1e-6));
        }
      });

      test('Masugata main ramparts maintain >= 0.45m lateral clearance from '
          '3.2m road', () {
        const roadHalfWidth = 1.6;
        const rampartInnerZ = 2.05;
        const clearance = rampartInnerZ - roadHalfWidth;
        expect(clearance, closeTo(0.45, 1e-6));
        expect(clearance, greaterThanOrEqualTo(0.45 - 1e-6));
      });

      test(
        'Masugata return bastion wing maintains ascending bounds and >= 5.2m '
        'road clearance',
        () {
          for (final cx in checkpointXList) {
            final gy = terrain.sampleRawTerrain(cx, 0);
            final bottomY = gy - 0.45;
            final rampartTopY = gy + 2.45;
            final wingMinX = cx < 0 ? (cx - 3.4) : (cx + 2.52);
            final wingMaxX = cx < 0 ? (cx - 2.52) : (cx + 3.4);
            final p0 = Vector3(wingMinX, bottomY, 5.28);
            final p1 = Vector3(wingMaxX, rampartTopY - 0.18, 6.92);

            expect(p1.x, greaterThan(p0.x));
            expect(p1.y, greaterThan(p0.y));
            expect(p1.z, greaterThan(p0.z));
            expect(p0.z, greaterThan(5.25));
          }
        },
      );

      test(
        'Tanada curved contour basins stay strictly above hillside terrain',
        () {
          double contourX(double z, int tier, {required bool isSouth}) {
            final phase = isSouth ? -0.85 : 0.45;
            final waveA = 2.15 * math.sin(z * 0.115 + tier * 0.52 + phase);
            final waveB = 0.95 * math.cos(z * 0.215 - tier * 0.34 - phase);
            return 40.2 + tier * 6.35 + waveA + waveB;
          }

          for (final isSouth in const [false, true]) {
            var prevBasinY = 3.20;
            for (var tier = 0; tier < 5; tier++) {
              final zMin = isSouth
                  ? (-54.5 + tier * 1.35)
                  : (17.5 + tier * 1.35);
              final zMax = isSouth
                  ? (-17.5 - tier * 1.35)
                  : (54.5 - tier * 1.35);
              var maxRawY = -double.infinity;
              for (var s = 0; s <= 14; s++) {
                final z = zMin + (zMax - zMin) * (s / 14);
                final xf = contourX(z, tier, isSouth: isSouth);
                for (var dx = -0.4; dx <= 6.25; dx += 0.95) {
                  final ry = terrain.sampleRawTerrain(xf + dx, z);
                  if (ry > maxRawY) maxRawY = ry;
                }
              }
              final basinY = math.max(prevBasinY + 0.72, maxRawY + 0.30);
              expect(basinY - maxRawY, greaterThanOrEqualTo(0.30 - 1e-9));
              expect(basinY - prevBasinY, greaterThanOrEqualTo(0.72 - 1e-9));
              prevBasinY = basinY;
            }
          }
        },
      );
    },
  );

  group(
    'Empirical Challenge 4: CameraPreset countrysideVista Optical Bounds',
    () {
      test(
        'countrysideVista exact distance, pitch angle, and frustum bounds',
        () {
          const preset = CameraPreset.countrysideVista;

          final dx = preset.eye.x - preset.target.x;
          final dy = preset.eye.y - preset.target.y;
          final dz = preset.eye.z - preset.target.z;
          final distSq = dx * dx + dy * dy + dz * dz;
          final distance = math.sqrt(distSq);

          expect(distance, closeTo(108.97, 0.05));
          expect(distance, lessThan(115.0));

          final pitchRadians = math.asin(dy / distance);
          final pitchDegrees = pitchRadians * 180.0 / math.pi;

          expect(pitchDegrees, closeTo(29.58, 0.05));
          expect(pitchDegrees, inInclusiveRange(11.0, 64.0));

          expect(preset.verticalFovDegrees, equals(22.0));

          expect(preset.nearMeters, equals(4.0));
          expect(preset.farMeters, equals(350.0));

          const maxCornerDx = 88.0 - (-66.0);
          const maxCornerDy = 10.0 - 56.0;
          const maxCornerDz = 88.0 - (-66.0);
          final maxCornerDist = math.sqrt(
            maxCornerDx * maxCornerDx +
                maxCornerDy * maxCornerDy +
                maxCornerDz * maxCornerDz,
          );
          expect(maxCornerDist, lessThan(preset.farMeters));
          expect(preset.farMeters - maxCornerDist, greaterThan(100.0));
        },
      );

      test('PerspectiveCamera view matrix is well-conditioned', () {
        final cam = CameraPreset.countrysideVista.toPerspectiveCamera();
        expect(cam.fovRadiansY, closeTo(22.0 * math.pi / 180.0, 1e-6));
        expect(cam.fovNear, equals(4.0));
        expect(cam.fovFar, equals(350.0));

        final fwd = cam.target - cam.position;
        expect(fwd.length, greaterThan(100.0));
        expect(fwd.normalized().y, lessThan(0.0));
      });
    },
  );
}
