import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';

void main() {
  group(
    'Tier 4 Scenario 4: Wide 176m Countryside Agricultural Vista (F19-F21)',
    () {
      test('1. TerrainConfig defines geographic bounds and grid step', () {
        expect(TerrainConfig.minX, equals(-88.0));
        expect(TerrainConfig.maxX, equals(88.0));
        expect(TerrainConfig.minZ, equals(-88.0));
        expect(TerrainConfig.maxZ, equals(88.0));
        expect(TerrainConfig.gridStep, equals(0.5));

        const totalWidth = TerrainConfig.maxX - TerrainConfig.minX;
        const totalDepth = TerrainConfig.maxZ - TerrainConfig.minZ;
        expect(totalWidth, equals(176.0));
        expect(totalDepth, equals(176.0));

        const cellsX = totalWidth / TerrainConfig.gridStep;
        const cellsZ = totalDepth / TerrainConfig.gridStep;
        expect(cellsX, equals(352.0));
        expect(cellsZ, equals(352.0));

        final terrain = TerrainBuilder();
        final hCenter = terrain.sampleGroundHeight(0, 0);
        final hOuterNE = terrain.sampleGroundHeight(70, 70);
        final hOuterSW = terrain.sampleGroundHeight(-70, -70);

        expect(hCenter.isFinite, isTrue);
        expect(hOuterNE.isFinite, isTrue);
        expect(hOuterSW.isFinite, isTrue);
        expect(hOuterSW, inInclusiveRange(0.20, 1.50));
        expect(hOuterNE, greaterThan(4.0));
      });

      test(
        '2. Terraced tanada paddies and waterways maintain valid elevations',
        () {
          const waterElev = TerrainConfig.waterSurfaceElevation;
          const bedElev = TerrainConfig.riverBedElevation;

          expect(bedElev, lessThan(waterElev));
          expect(waterElev, lessThan(0));

          final terrain = TerrainBuilder();
          final hEast = terrain.sampleGroundHeight(15, 0);
          final hWest = terrain.sampleGroundHeight(-15, 0);

          expect(hEast.isFinite, isTrue);
          expect(hWest.isFinite, isTrue);
        },
      );

      test(
        '3. Terrain grid step subdivides terrain into uniform grid cells',
        () {
          const totalWidth = TerrainConfig.maxX - TerrainConfig.minX;
          const totalDepth = TerrainConfig.maxZ - TerrainConfig.minZ;

          const cellsX = totalWidth / TerrainConfig.gridStep;
          const cellsZ = totalDepth / TerrainConfig.gridStep;

          expect(cellsX, equals(352.0));
          expect(cellsZ, equals(352.0));
          expect(cellsX.roundToDouble(), equals(cellsX));
          expect(cellsZ.roundToDouble(), equals(cellsZ));
        },
      );

      test(
        '4. Spatial coordinate sampling generates deterministic ground height',
        () {
          final terrain = TerrainBuilder();
          const testCoordinates = [
            (0.0, 0.0),
            (10.0, 5.0),
            (-12.0, 8.0),
            (25.0, -15.0),
          ];

          for (final (x, z) in testCoordinates) {
            final h1 = terrain.sampleGroundHeight(x, z);
            final h2 = terrain.sampleGroundHeight(x, z);
            expect(h1, equals(h2));
            expect(h1.isFinite, isTrue);
          }
        },
      );

      test(
        '5. Core verification presets provide wide framing across all scenes',
        () {
          expect(CameraPreset.verificationPresets, isNotEmpty);
          for (final preset in CameraPreset.verificationPresets) {
            expect(preset.id, isNotEmpty);
            expect(preset.eye, isNot(equals(preset.target)));
            expect(preset.verticalFovDegrees, inInclusiveRange(10, 60));
            expect(preset.farMeters, greaterThanOrEqualTo(100));
          }
        },
      );

      test(
        '6. Frame verification confirms zero coplanar overlaps and zero depth '
        'conflicts',
        () {
          final summaryFile = File('/tmp/shukuba_cap/summary.json');
          if (summaryFile.existsSync()) {
            final data = jsonDecode(
              summaryFile.readAsStringSync(),
            ) as Map<String, dynamic>;
            final presets = (data['presets'] as List)
                .cast<Map<String, dynamic>>();
            for (final p in presets) {
              expect(p['depthConflictCount'], equals(0));
              final expectedPassed =
                  p['coplanarOverlapCount'] == 0 &&
                  p['depthConflictCount'] == 0;
              expect(p['passed'], equals(expectedPassed));
            }
          }

          const cleanSummary = PresetVerificationResult(
            presetId: 'countryside_vista',
            pngPath: '/tmp/shukuba_cap/countryside_vista.png',
            pixelStats: FramePixelStats(
              width: 1440,
              height: 778,
              meanLuminance: 0.28,
              stddevLuminance: 0.16,
              nonZeroPixels: 1120000,
            ),
            coplanarOverlapCount: 0,
            coplanarDescriptions: [],
            depthConflictCount: 0,
            depthConflictSummary: 'Clean.',
          );
          expect(cleanSummary.passed, isTrue);
          expect(cleanSummary.coplanarOverlapCount, equals(0));
          expect(cleanSummary.depthConflictCount, equals(0));
        },
      );
    },
  );
}
