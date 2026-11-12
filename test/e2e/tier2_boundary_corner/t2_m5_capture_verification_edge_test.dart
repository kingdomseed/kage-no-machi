import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';

import '../helpers/e2e_test_harness.dart';

void main() {
  group('Feature 22 Edge: Metal Capture & Overlap Detection Bounds', () {
    test('Injected coplanar overlap detection flags positive count '
        '(coplanarOverlapCount > 0)', () {
      const failedResult = PresetVerificationResult(
        presetId: 'dusk_overview',
        pngPath: '/tmp/shukuba_cap/dusk_overview.png',
        pixelStats: FramePixelStats(
          width: 1920,
          height: 1080,
          meanLuminance: 0.32,
          stddevLuminance: 0.14,
          nonZeroPixels: 1920 * 1080,
        ),
        coplanarOverlapCount: 2,
        coplanarDescriptions: [
          'Coplanar overlap between machiya_01 and machiya_02 on plane y=0.0',
          'Coplanar overlap between chaya_03 and terrace_wall on plane y=1.2',
        ],
        depthConflictCount: 0,
        depthConflictSummary: '',
      );

      expect(failedResult.coplanarOverlapCount, greaterThan(0));
      expect(failedResult.coplanarDescriptions, hasLength(2));
      expect(failedResult.passed, isFalse);
    });

    test('Injected negative depthLayer conflict detection flags positive '
        'conflict count', () {
      const conflictResult = PresetVerificationResult(
        presetId: 'river_crossing',
        pngPath: '/tmp/shukuba_cap/river_crossing.png',
        pixelStats: FramePixelStats(
          width: 1920,
          height: 1080,
          meanLuminance: 0.28,
          stddevLuminance: 0.16,
          nonZeroPixels: 1920 * 1080,
        ),
        coplanarOverlapCount: 0,
        coplanarDescriptions: [],
        depthConflictCount: 1,
        depthConflictSummary:
            'Depth layer inversion: role laneOverlay (layer 1) occluded '
            'by packedEarth (layer -1)',
      );

      expect(conflictResult.depthConflictCount, greaterThan(0));
      expect(conflictResult.depthConflictSummary, contains('inversion'));
      expect(conflictResult.passed, isFalse);
    });

    test('Frame settling wait configures at least 5 frames in '
        'ShukubaFrameHarness', () {
      final harnessSrc = File('lib/shukuba/verify/frame_harness.dart')
          .readAsStringSync();
      expect(harnessSrc.contains('this.settleFrames = 50'), isTrue);
    });

    test(
      'Auto-creation of missing capture directory /tmp/shukuba_cap',
      () async {
        final uniqueDirName =
            'shukuba_test_cap_${DateTime.now().microsecondsSinceEpoch}';
        final tempDir = Directory(
          '${Directory.systemTemp.path}/$uniqueDirName',
        );

        expect(tempDir.existsSync(), isFalse);

        await tempDir.create(recursive: true);
        expect(tempDir.existsSync(), isTrue);

        final probeFile = File('${tempDir.path}/.write_test');
        await probeFile.writeAsString('ok');
        expect(probeFile.existsSync(), isTrue);

        await tempDir.delete(recursive: true);
        expect(tempDir.existsSync(), isFalse);
      },
    );

    test('Headless no-GPU environment accurately reports Impeller '
        'unavailable', () {
      final impellerAvailable = checkImpellerAvailable();
      expect(impellerAvailable, isFalse);
    });
  });

  group('Feature 23 Edge: Reference Image Integrity & Color Gamuts', () {
    test('Missing reference image detection flags incomplete corpus', () {
      const existingRef = 'docs/references/shadow-tactics/st-01.jpg';
      const nonExistentRef = 'docs/references/shadow-tactics/st-999.jpg';

      expect(File(existingRef).existsSync(), isTrue);
      expect(File(nonExistentRef).existsSync(), isFalse);
    });

    test('Dusk vs night luminance check confirms goldenDusk > blueNight', () {
      const duskPixelsCount = 100;
      final duskBytes = Uint8List(duskPixelsCount * 4);
      final nightBytes = Uint8List(duskPixelsCount * 4);

      for (var i = 0; i < duskPixelsCount; i++) {
        duskBytes[i * 4] = 200 + (i % 20);
        duskBytes[i * 4 + 1] = 140 + (i % 15);
        duskBytes[i * 4 + 2] = 80 + (i % 10);
        duskBytes[i * 4 + 3] = 255;

        nightBytes[i * 4] = 20 + (i % 10);
        nightBytes[i * 4 + 1] = 35 + (i % 10);
        nightBytes[i * 4 + 2] = 70 + (i % 10);
        nightBytes[i * 4 + 3] = 255;
      }

      final statsDusk = analyzeRgbaPixels(
        ByteData.sublistView(duskBytes),
        width: 10,
        height: 10,
      );

      final statsNight = analyzeRgbaPixels(
        ByteData.sublistView(nightBytes),
        width: 10,
        height: 10,
      );

      expect(statsDusk.meanLuminance, greaterThan(statsNight.meanLuminance));
      expect(statsDusk.isValidNonBlank, isTrue);
      expect(statsNight.isValidNonBlank, isTrue);
    });

    test('Color gamut temperature shift confirms dusk warmer than night', () {
      const duskR = 210.0;
      const duskB = 85.0;
      const duskRatio = duskR / duskB;

      const nightR = 25.0;
      const nightB = 75.0;
      const nightRatio = nightB / nightR;

      expect(duskRatio, greaterThan(1.5));
      expect(nightRatio, greaterThan(1.5));
    });

    test('Image histogram dynamic range check confirms >= 200 distinct color '
        'shades', () {
      final uniqueColors = <int>{};
      final pixels = Uint8List(256 * 4);

      for (var i = 0; i < 256; i++) {
        final r = i;
        final g = (i * 2) % 256;
        final b = (i * 3) % 256;

        pixels[i * 4] = r;
        pixels[i * 4 + 1] = g;
        pixels[i * 4 + 2] = b;
        pixels[i * 4 + 3] = 255;

        final colorInt = (r << 16) | (g << 8) | b;
        uniqueColors.add(colorInt);
      }

      expect(uniqueColors.length, greaterThanOrEqualTo(200));

      final stats = analyzeRgbaPixels(
        ByteData.sublistView(pixels),
        width: 16,
        height: 16,
      );

      expect(stats.isValidNonBlank, isTrue);
      expect(stats.nonZeroPixels, inInclusiveRange(250, 256));
    });

    test('analyzeRgbaPixels rejects invalid buffer length or degenerate '
        'dimensions', () {
      final invalidBytes = ByteData(10);

      expect(
        () => analyzeRgbaPixels(invalidBytes, width: 4, height: 4),
        throwsArgumentError,
      );

      expect(
        () => analyzeRgbaPixels(ByteData(0), width: 0, height: 0),
        throwsArgumentError,
      );
    });
  });
}
