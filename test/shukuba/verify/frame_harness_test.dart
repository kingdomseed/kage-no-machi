import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';

void main() {
  group('analyzeRgbaPixels and HarnessSummary', () {
    test('rejects all-black and solid-white buffers as blank', () {
      final black = ByteData(4 * 4 * 4);
      final blackStats = analyzeRgbaPixels(black, width: 4, height: 4);
      expect(blackStats.isValidNonBlank, isFalse);

      final whiteList = Uint8List.fromList(List<int>.filled(4 * 4 * 4, 255));
      final whiteStats = analyzeRgbaPixels(
        ByteData.sublistView(whiteList),
        width: 4,
        height: 4,
      );
      expect(whiteStats.isValidNonBlank, isFalse);
    });

    test('accepts finite textured RGBA frame and requires zero conflicts', () {
      final pixels = Uint8List(4 * 2 * 4);
      const colors = [
        [28, 36, 54, 255],
        [214, 146, 78, 255],
        [68, 92, 74, 255],
        [182, 72, 48, 255],
        [22, 28, 42, 255],
        [238, 188, 112, 255],
        [94, 82, 68, 255],
        [44, 132, 108, 255],
      ];
      for (var i = 0; i < colors.length; i++) {
        pixels[i * 4] = colors[i][0];
        pixels[i * 4 + 1] = colors[i][1];
        pixels[i * 4 + 2] = colors[i][2];
        pixels[i * 4 + 3] = colors[i][3];
      }

      final stats = analyzeRgbaPixels(
        ByteData.sublistView(pixels),
        width: 4,
        height: 2,
      );
      expect(stats.isValidNonBlank, isTrue);
      expect(stats.nonZeroPixels, 8);

      final passSummary = HarnessSummary(
        outputDir: '/tmp/shukuba',
        results: [
          PresetVerificationResult(
            presetId: 'dusk_overview',
            pngPath: '/tmp/shukuba/dusk_overview.png',
            pixelStats: stats,
            coplanarOverlapCount: 0,
            coplanarDescriptions: const [],
            depthConflictCount: 0,
            depthConflictSummary: 'No depth conflicts in a 960x540 probe.',
          ),
        ],
      );
      expect(passSummary.allPassed, isTrue);

      final conflictSummary = HarnessSummary(
        outputDir: '/tmp/shukuba',
        results: [
          PresetVerificationResult(
            presetId: 'dusk_overview',
            pngPath: '/tmp/shukuba/dusk_overview.png',
            pixelStats: stats,
            coplanarOverlapCount: 1,
            coplanarDescriptions: const ['ground and lane overlap'],
            depthConflictCount: 0,
            depthConflictSummary: 'No depth conflicts in a 960x540 probe.',
          ),
        ],
      );
      expect(conflictSummary.allPassed, isFalse);
    });
  });
}
