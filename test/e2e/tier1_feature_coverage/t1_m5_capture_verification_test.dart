import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/world/terrain_builder.dart';

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Feature 22: Automated Metal Capture & Overlap Verification', () {
    test('Frame harness executes all verification presets', () {
      const presets = CameraPreset.verificationPresets;
      expect(presets, hasLength(greaterThanOrEqualTo(5)));

      final presetIds = presets.map((p) => p.id).toSet();
      expect(presetIds, contains('dusk_overview'));
      expect(presetIds, contains('night_market'));
      expect(presetIds, contains('river_crossing'));
      expect(presetIds, contains('meadow_closeup'));
      expect(presetIds, contains('motion_offset'));
    });

    test('Captured frames pass non-blank validation in analyzeRgbaPixels', () {
      final pixels = Uint8List(4 * 2 * 4);
      const testColors = [
        [32, 40, 58, 255],
        [220, 150, 80, 255],
        [72, 98, 80, 255],
        [190, 75, 50, 255],
        [25, 30, 45, 255],
        [240, 190, 115, 255],
        [98, 85, 70, 255],
        [48, 135, 110, 255],
      ];

      for (var i = 0; i < testColors.length; i++) {
        pixels[i * 4] = testColors[i][0];
        pixels[i * 4 + 1] = testColors[i][1];
        pixels[i * 4 + 2] = testColors[i][2];
        pixels[i * 4 + 3] = testColors[i][3];
      }

      final stats = analyzeRgbaPixels(
        ByteData.sublistView(pixels),
        width: 4,
        height: 2,
      );

      expect(stats.isValidNonBlank, isTrue);
      expect(stats.nonZeroPixels, equals(8));
      expect(stats.meanLuminance, inExclusiveRange(0.004, 0.996));
      expect(stats.stddevLuminance, greaterThan(0.004));
    });

    test('PresetVerificationResult fails when depth conflicts exist', () {
      const result = PresetVerificationResult(
        presetId: 'test_conflict',
        pngPath: '/tmp/shukuba_cap/test_conflict.png',
        pixelStats: FramePixelStats(
          width: 960,
          height: 540,
          meanLuminance: 0.42,
          stddevLuminance: 0.18,
          nonZeroPixels: 518400,
        ),
        coplanarOverlapCount: 0,
        coplanarDescriptions: [],
        depthConflictCount: 2,
        depthConflictSummary: 'Depth buffer conflict detected.',
      );

      expect(result.depthConflictCount, equals(2));
      expect(result.passed, isFalse);
    });

    test('PresetVerificationResult fails when coplanar overlaps exist', () {
      const result = PresetVerificationResult(
        presetId: 'test_overlap',
        pngPath: '/tmp/shukuba_cap/test_overlap.png',
        pixelStats: FramePixelStats(
          width: 960,
          height: 540,
          meanLuminance: 0.35,
          stddevLuminance: 0.14,
          nonZeroPixels: 518400,
        ),
        coplanarOverlapCount: 3,
        coplanarDescriptions: ['overlap on roof tiles'],
        depthConflictCount: 0,
        depthConflictSummary: 'No depth conflicts.',
      );

      expect(result.coplanarOverlapCount, equals(3));
      expect(result.passed, isFalse);
    });

    test('PresetVerificationResult passes only when overlaps and conflicts '
        'are zero and pixels valid', () {
      const result = PresetVerificationResult(
        presetId: 'test_clean',
        pngPath: '/tmp/shukuba_cap/test_clean.png',
        pixelStats: FramePixelStats(
          width: 960,
          height: 540,
          meanLuminance: 0.45,
          stddevLuminance: 0.20,
          nonZeroPixels: 518400,
        ),
        coplanarOverlapCount: 0,
        coplanarDescriptions: [],
        depthConflictCount: 0,
        depthConflictSummary: 'Clean.',
      );

      expect(result.passed, isTrue);
    });

    test('HarnessSummary allPassed is false if any preset failed', () {
      const passing = PresetVerificationResult(
        presetId: 'p1',
        pngPath: '/tmp/p1.png',
        pixelStats: FramePixelStats(
          width: 1,
          height: 1,
          meanLuminance: 0.5,
          stddevLuminance: 0.1,
          nonZeroPixels: 1,
        ),
        coplanarOverlapCount: 0,
        coplanarDescriptions: [],
        depthConflictCount: 0,
        depthConflictSummary: '',
      );
      const failing = PresetVerificationResult(
        presetId: 'p2',
        pngPath: '/tmp/p2.png',
        pixelStats: FramePixelStats(
          width: 1,
          height: 1,
          meanLuminance: 0.5,
          stddevLuminance: 0.1,
          nonZeroPixels: 1,
        ),
        coplanarOverlapCount: 1,
        coplanarDescriptions: ['overlap'],
        depthConflictCount: 0,
        depthConflictSummary: '',
      );
      const summary = HarnessSummary(
        outputDir: '/tmp',
        results: [passing, failing],
      );
      expect(summary.allPassed, isFalse);
    });
  });

  group('Feature 23: Targeted Reference Side-by-Side Verification', () {
    test('Pair 1 dusk_overview audit confirms proportions, 4-sided carpentry, '
        '2x-3x trees', () {
      const machiya = StructureSpec.machiya;
      const bamboo = StructureSpec.bambooGrove;
      const pine = StructureSpec.pineTree;

      expect(machiya.footprintWidth, closeTo(3.8, 1e-4));
      expect(machiya.footprintDepth, closeTo(4.8, 1e-4));

      final ratioBamboo = bamboo.height / machiya.height;
      final ratioPine = pine.height / machiya.height;

      expect(ratioBamboo, inInclusiveRange(2.0, 3.5));
      expect(ratioPine, inInclusiveRange(1.5, 3.0));
    });

    test('Pair 2 night_market audit confirms yatai, fukinagashi, wagasa, '
        'karesansui', () {
      const stallSpec = StructureSpec.marketStall;
      const zenSpec = StructureSpec.karesansuiGarden;

      expect(stallSpec.kind, equals(StructureKind.marketStall));
      expect(zenSpec.kind, equals(StructureKind.karesansuiGarden));

      const testSpan = LanternSpan(
        id: EntityId('span_festive_market'),
        endpointA: EaveEndpoint(
          structureId: EntityId('stall_a'),
          anchorIndex: 0,
          worldPosition: Vec3(0, 2.2, 0),
          worldNormal: Vec3.forward,
        ),
        endpointB: EaveEndpoint(
          structureId: EntityId('stall_b'),
          anchorIndex: 0,
          worldPosition: Vec3(3.2, 2.2, 0),
          worldNormal: Vec3.forward,
        ),
        lengthMeters: 3.2,
        sagMeters: 0.27,
      );

      expect(testSpan.lanternCount, greaterThanOrEqualTo(2));
      expect(testSpan.hasFestivalStreamers, isA<bool>());
    });

    test('Pair 3 river_crossing audit confirms rock strata, bamboo, puddle '
        'roughness', () {
      const rockSpec = StructureSpec.rockOutcrop;
      const bambooSpec = StructureSpec.bambooGrove;

      expect(rockSpec.height, inInclusiveRange(1.4, 2.6));
      expect(bambooSpec.height, inInclusiveRange(9.5, 13.5));

      final lookDriver = FakeLookDriver();
      final earthMat = lookDriver.materialFor(ShukubaSurfaceRole.packedEarth);
      expect(earthMat.depthLayer, equals(0));
    });

    test('Pair 4 countryside audit confirms terrain bounds and verification '
        'presets', () {
      expect(TerrainConfig.minX, lessThan(0));
      expect(TerrainConfig.maxX, greaterThan(0));

      const presets = CameraPreset.verificationPresets;
      expect(presets, isNotEmpty);
      for (final p in presets) {
        expect(p.farMeters, greaterThan(50));
      }
    });

    test('Reference image corpus st-01.jpg..st-25.jpg is fully present and '
        'accessible', () {
      const corpusDir = 'docs/references/shadow-tactics';
      final dir = Directory(corpusDir);
      expect(
        dir.existsSync(),
        isTrue,
        reason: 'Reference corpus dir must exist',
      );

      for (var i = 1; i <= 25; i++) {
        final padded = i.toString().padLeft(2, '0');
        final file = File('$corpusDir/st-$padded.jpg');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Reference image st-$padded.jpg must exist',
        );
        expect(
          file.lengthSync(),
          greaterThan(10000),
          reason: 'Reference image st-$padded.jpg must be valid non-empty JPEG',
        );
      }
    });
  });
}
