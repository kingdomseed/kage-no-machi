import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:flutter_scene/scene.dart' show Camera, Scene;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';

const String kShukubaCaptureDir = String.fromEnvironment('SHUKUBA_CAPTURE_DIR');

const bool kShukubaAutoExit = bool.fromEnvironment('SHUKUBA_AUTO_EXIT');

@immutable
class FramePixelStats {
  const new({
    required this.width,
    required this.height,
    required this.meanLuminance,
    required this.stddevLuminance,
    required this.nonZeroPixels,
  });

  final int width;
  final int height;
  final double meanLuminance;
  final double stddevLuminance;
  final int nonZeroPixels;

  bool get isValidNonBlank =>
      width > 0 &&
      height > 0 &&
      nonZeroPixels > 0 &&
      meanLuminance.isFinite &&
      stddevLuminance.isFinite &&
      meanLuminance > 0.004 &&
      meanLuminance < 0.996 &&
      stddevLuminance > 0.004;

  Map<String, Object> toJson() => {
    'width': width,
    'height': height,
    'meanLuminance': meanLuminance,
    'stddevLuminance': stddevLuminance,
    'nonZeroPixels': nonZeroPixels,
    'isValidNonBlank': isValidNonBlank,
  };
}

FramePixelStats analyzeRgbaPixels(
  ByteData rgbaBytes, {
  required int width,
  required int height,
}) {
  final expectedBytes = width * height * 4;
  if (width <= 0 || height <= 0 || rgbaBytes.lengthInBytes != expectedBytes) {
    throw ArgumentError(
      'Expected $expectedBytes RGBA bytes for ${width}x$height image, '
      'got ${rgbaBytes.lengthInBytes}.',
    );
  }
  final data = rgbaBytes.buffer.asUint8List(
    rgbaBytes.offsetInBytes,
    rgbaBytes.lengthInBytes,
  );
  final totalPixels = width * height;
  var sum = 0.0;
  var sumSq = 0.0;
  var nonZero = 0;
  for (var offset = 0; offset < data.length; offset += 4) {
    final r = data[offset] / 255;
    final g = data[offset + 1] / 255;
    final b = data[offset + 2] / 255;
    if (data[offset] != 0 || data[offset + 1] != 0 || data[offset + 2] != 0) {
      nonZero++;
    }
    final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    sum += luma;
    sumSq += luma * luma;
  }
  final mean = sum / totalPixels;
  final variance = math.max<double>(0, sumSq / totalPixels - mean * mean);
  return FramePixelStats(
    width: width,
    height: height,
    meanLuminance: mean,
    stddevLuminance: math.sqrt(variance),
    nonZeroPixels: nonZero,
  );
}

@immutable
class PresetVerificationResult {
  const new({
    required this.presetId,
    required this.pngPath,
    required this.pixelStats,
    required this.coplanarOverlapCount,
    required this.coplanarDescriptions,
    required this.depthConflictCount,
    required this.depthConflictSummary,
  });

  final String presetId;
  final String pngPath;
  final FramePixelStats pixelStats;
  final int coplanarOverlapCount;
  final List<String> coplanarDescriptions;
  final int depthConflictCount;
  final String depthConflictSummary;

  bool get passed =>
      pixelStats.isValidNonBlank &&
      coplanarOverlapCount == 0 &&
      depthConflictCount == 0;

  Map<String, Object> toJson() => {
    'presetId': presetId,
    'pngPath': pngPath,
    'passed': passed,
    'coplanarOverlapCount': coplanarOverlapCount,
    'coplanarDescriptions': coplanarDescriptions,
    'depthConflictCount': depthConflictCount,
    'depthConflictSummary': depthConflictSummary,
    'pixelStats': pixelStats.toJson(),
  };
}

@immutable
class HarnessSummary {
  const new({required this.outputDir, required this.results});

  final String outputDir;
  final List<PresetVerificationResult> results;

  bool get allPassed =>
      results.isNotEmpty && results.every((result) => result.passed);

  Map<String, Object> toJson() => {
    'outputDir': outputDir,
    'allPassed': allPassed,
    'presets': [for (final result in results) result.toJson()],
  };
}

typedef ApplyPresetCallback = Camera Function(CameraPreset preset);

class ShukubaFrameHarness {
  const new({
    required this.scene,
    required this.look,
    required this.world,
    required this.repaintBoundaryKey,
    required this.applyPreset,
    this.audio,
    this.settleFrames = 50,
    this.capturePixelRatio = 1,
  });

  final Scene scene;
  final ShukubaLookDriver look;
  final ShukubaWorldDriver world;
  final ShukubaAudioDriver? audio;
  final GlobalKey repaintBoundaryKey;
  final ApplyPresetCallback applyPreset;
  final int settleFrames;
  final double capturePixelRatio;

  static Future<Directory> _prepareOutputDir(String requestedDir) async {
    final direct = Directory(requestedDir);
    try {
      await direct.create(recursive: true);
      final probe = File('${direct.path}/.write_probe');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return direct;
    } on FileSystemException catch (_) {
      final parts = requestedDir
          .split(RegExp(r'[/\\]'))
          .where((segment) => segment.isNotEmpty)
          .toList();
      final leaf = parts.isEmpty ? 'captures' : parts.last;
      final fallback = Directory(
        '${Directory.systemTemp.path}/shukuba_captures/$leaf',
      );
      await fallback.create(recursive: true);
      return fallback;
    }
  }

  Future<HarnessSummary> runCaptureSuite({
    required String outputDir,
    required bool autoExit,
    List<CameraPreset> presets = CameraPreset.verificationPresets,
  }) async {
    final directory = await _prepareOutputDir(outputDir);
    stdout.writeln('SHUKUBA_CAPTURE_OUT:${directory.path}');

    await Scene.initializeStaticResources();
    await Scene.preload();

    final results = <PresetVerificationResult>[];
    var elapsedSeconds = 0.0;

    for (final preset in presets) {
      final activeCamera = applyPreset(preset);
      for (var frame = 0; frame < settleFrames; frame++) {
        elapsedSeconds += 1 / 60;
        world.step(1 / 60, rig: preset.timeOfDay);
        look.syncFrame(
          rig: preset.timeOfDay,
          vision: preset.visionState,
          sightcones: world.activeSightcones,
          lanternOrigins: world.activeLanternOrigins,
          elapsedSeconds: elapsedSeconds,
        );
        audio?.syncAtmosphere(
          rig: preset.timeOfDay,
          loopAnchors: world.ambientLoopAnchors,
        );
        SchedulerBinding.instance.scheduleFrame();
        await SchedulerBinding.instance.endOfFrame;
      }

      final overlaps = scene.findCoplanarOverlaps(camera: activeCamera);
      final depthReport = await scene.probeDepthConflicts(camera: activeCamera);

      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;

      final boundaryObject = repaintBoundaryKey.currentContext
          ?.findRenderObject();
      if (boundaryObject is! RenderRepaintBoundary) {
        throw StateError('Missing RenderRepaintBoundary for frame capture.');
      }

      final image = await boundaryObject.toImage(pixelRatio: capturePixelRatio);
      final ByteData? rgbaData;
      final ByteData? pngData;
      final int imageWidth;
      final int imageHeight;
      try {
        imageWidth = image.width;
        imageHeight = image.height;
        rgbaData = await image.toByteData();
        pngData = await image.toByteData(format: ui.ImageByteFormat.png);
      } finally {
        image.dispose();
      }

      if (rgbaData == null || pngData == null) {
        throw StateError('Failed to encode RGBA or PNG bytes for ${preset.id}');
      }

      final pixelStats = analyzeRgbaPixels(
        rgbaData,
        width: imageWidth,
        height: imageHeight,
      );
      final pngFile = File('${directory.path}/${preset.id}.png');
      await pngFile.writeAsBytes(
        pngData.buffer.asUint8List(
          pngData.offsetInBytes,
          pngData.lengthInBytes,
        ),
        flush: true,
      );

      results.add(
        PresetVerificationResult(
          presetId: preset.id,
          pngPath: pngFile.path,
          pixelStats: pixelStats,
          coplanarOverlapCount: overlaps.length,
          coplanarDescriptions: [
            for (final overlap in overlaps.take(12)) overlap.describe(),
          ],
          depthConflictCount: depthReport.conflicts.length,
          depthConflictSummary: depthReport.describe(),
        ),
      );
    }

    final summary = HarnessSummary(outputDir: directory.path, results: results);
    final summaryFile = File('${directory.path}/summary.json');
    final encoded = const JsonEncoder.withIndent('  ')
        .convert(summary.toJson());
    await summaryFile.writeAsString('$encoded\n', flush: true);

    stdout
      ..writeln('SHUKUBA_CAPTURE_SUMMARY:$encoded')
      ..writeln('SHUKUBA_CAPTURE_COMPLETE:${summaryFile.path}');
    await stdout.flush();

    if (autoExit) {
      exit(summary.allPassed ? 0 : 2);
    }
    return summary;
  }
}
