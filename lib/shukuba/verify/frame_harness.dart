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

const bool kShukubaCaptureAtlas = bool.fromEnvironment('SHUKUBA_CAPTURE_ATLAS');

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
typedef CaptureUiAtlasCallback = Future<List<String>> Function(Directory uiDir);

class ShukubaFrameHarness {
  const new({
    required this.scene,
    required this.look,
    required this.world,
    required this.repaintBoundaryKey,
    required this.applyPreset,
    this.audio,
    this.captureUiAtlas,
    this.settleFrames = 50,
    this.capturePixelRatio = 1,
  });

  final Scene scene;
  final ShukubaLookDriver look;
  final ShukubaWorldDriver world;
  final ShukubaAudioDriver? audio;
  final GlobalKey repaintBoundaryKey;
  final ApplyPresetCallback applyPreset;
  final CaptureUiAtlasCallback? captureUiAtlas;
  final int settleFrames;
  final double capturePixelRatio;

  static const List<CameraPreset> geometrySeamPresets = [
    CameraPreset(
      id: 'seam_stair_upper_east_foot',
      label: 'Upper East Staircase Foot & Kaido Junction',
      eye: Vec3(2.8, 12.8, -11.6),
      target: Vec3(14.3, 2.35, -0.15),
      timeOfDay: TimeOfDayRig.goldenDusk,
      verticalFovDegrees: 21,
      nearMeters: 1.5,
      farMeters: 240,
    ),
    CameraPreset(
      id: 'seam_stair_upper_east_crest',
      label: 'Upper East Staircase Crest & Cheek Walls',
      eye: Vec3(26.8, 13.6, 11.2),
      target: Vec3(15.6, 3.25, -0.15),
      timeOfDay: TimeOfDayRig.goldenDusk,
      verticalFovDegrees: 21,
      nearMeters: 1.5,
      farMeters: 240,
    ),
    CameraPreset(
      id: 'seam_stair_south_roji',
      label: 'Southern Stepped Roji Terrace Crossings',
      eye: Vec3(-1.2, 13.8, -27.4),
      target: Vec3(11.4, 2.45, -15.2),
      timeOfDay: TimeOfDayRig.goldenDusk,
      verticalFovDegrees: 21,
      nearMeters: 1.5,
      farMeters: 240,
    ),
    CameraPreset(
      id: 'seam_bridge_west_abutment',
      label: 'West Bridge Sill & Kaido Abutment',
      eye: Vec3(-16.4, 11.6, -11.2),
      target: Vec3(-5.2, 1.35, 0),
      timeOfDay: TimeOfDayRig.goldenDusk,
      verticalFovDegrees: 21,
      nearMeters: 1.5,
      farMeters: 240,
    ),
    CameraPreset(
      id: 'seam_bridge_east_abutment',
      label: 'East Bridge Sill & Lower Terrace Stair',
      eye: Vec3(16.8, 11.8, 11.2),
      target: Vec3(5.8, 1.55, 0),
      timeOfDay: TimeOfDayRig.goldenDusk,
      verticalFovDegrees: 21,
      nearMeters: 1.5,
      farMeters: 240,
    ),
    CameraPreset(
      id: 'seam_tanada_north_terraces',
      label: 'North Contour-Graded Tanada Paddies',
      eye: Vec3(31, 22.5, 11),
      target: Vec3(54, 4.3, 33),
      timeOfDay: TimeOfDayRig.goldenDusk,
      verticalFovDegrees: 22,
      nearMeters: 2,
      farMeters: 280,
    ),
    CameraPreset(
      id: 'seam_tanada_south_terraces',
      label: 'South Contour-Graded Tanada Paddies',
      eye: Vec3(31, 22.5, -11),
      target: Vec3(54, 4.3, -33),
      timeOfDay: TimeOfDayRig.goldenDusk,
      verticalFovDegrees: 22,
      nearMeters: 2,
      farMeters: 280,
    ),
    CameraPreset(
      id: 'seam_mitsuke_west_gate',
      label: 'West Mitsuke Checkpoint Threshold',
      eye: Vec3(-51.5, 14.6, -14.5),
      target: Vec3(-66, 2.2, 0),
      timeOfDay: TimeOfDayRig.goldenDusk,
      verticalFovDegrees: 21,
      nearMeters: 1.5,
      farMeters: 260,
    ),
    CameraPreset(
      id: 'seam_mitsuke_east_gate',
      label: 'East Mitsuke Checkpoint Threshold',
      eye: Vec3(51.5, 16, 14.5),
      target: Vec3(66, 3.6, 0),
      timeOfDay: TimeOfDayRig.goldenDusk,
      verticalFovDegrees: 21,
      nearMeters: 1.5,
      farMeters: 260,
    ),
    CameraPreset(
      id: 'seam_sloped_plinth_and_wall',
      label: 'Sloped Terrace Hei Wall & House Plinths',
      eye: Vec3(5.2, 14.8, -25.6),
      target: Vec3(18.6, 3.3, -12.8),
      timeOfDay: TimeOfDayRig.goldenDusk,
      verticalFovDegrees: 21,
      nearMeters: 1.5,
      farMeters: 240,
    ),
  ];

  static const List<StructureKind> turntableStructureKinds = [
    StructureKind.minka,
    StructureKind.machiya,
    StructureKind.chaya,
    StructureKind.kura,
    StructureKind.marketStall,
    StructureKind.toriiGate,
    StructureKind.shoroBell,
    StructureKind.stoneWell,
    StructureKind.karesansuiGarden,
  ];

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

  static Future<void> pumpFrame() async {
    final binding = SchedulerBinding.instance..scheduleFrame();
    var completed = false;
    final frameDone = binding.endOfFrame.whenComplete(() => completed = true);
    await Future.any<void>([
      frameDone,
      Future<void>.delayed(const Duration(milliseconds: 50)),
    ]);
    if (!completed) {
      binding.scheduleWarmUpFrame();
    }
    await frameDone;
  }

  Future<PresetVerificationResult> _capturePresetFrame({
    required CameraPreset preset,
    required String outputPath,
    required int framesToSettle,
    required double startElapsedSeconds,
  }) async {
    var elapsedSeconds = startElapsedSeconds;
    final activeCamera = applyPreset(preset);
    for (var frame = 0; frame < framesToSettle; frame++) {
      elapsedSeconds += 1 / 60;
      world.step(1 / 60, rig: preset.timeOfDay);
    }
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
    await pumpFrame();
    await pumpFrame();

    final overlaps = scene.findCoplanarOverlaps(camera: activeCamera);
    final depthReport = await scene.probeDepthConflicts(camera: activeCamera);

    await pumpFrame();

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
    final pngFile = File(outputPath);
    await pngFile.parent.create(recursive: true);
    await pngFile.writeAsBytes(
      pngData.buffer.asUint8List(pngData.offsetInBytes, pngData.lengthInBytes),
      flush: true,
    );

    return PresetVerificationResult(
      presetId: preset.id,
      pngPath: pngFile.path,
      pixelStats: pixelStats,
      coplanarOverlapCount: overlaps.length,
      coplanarDescriptions: [
        for (final overlap in overlaps.take(12)) overlap.describe(),
      ],
      depthConflictCount: depthReport.conflicts.length,
      depthConflictSummary: depthReport.describe(),
    );
  }

  Future<HarnessSummary> runCaptureSuite({
    required String outputDir,
    required bool autoExit,
    bool includeAtlas = kShukubaCaptureAtlas,
    List<CameraPreset> presets = CameraPreset.verificationPresets,
  }) async {
    final directory = await _prepareOutputDir(outputDir);
    stdout.writeln('SHUKUBA_CAPTURE_OUT:${directory.path}');

    await Scene.initializeStaticResources();
    await Scene.preload();

    for (var i = 0; i < 24; i++) {
      final hx = -10.0 + i * 0.9;
      final hz = -4.0 + (i % 5) * 2.0;
      final hy = world.sampleGroundHeight(hx, hz);
      world.syncPreview(
        StampGhostPreview(
          kind: StructureKind.machiya,
          position: Vec3(hx, hy, hz),
          yawRadians: (i % 4) * (math.pi / 4),
          variant: i % 4,
        ),
      );
    }
    world.syncPreview(const NoBuildPreview());

    final results = <PresetVerificationResult>[];
    var elapsedSeconds = 0.0;

    for (final preset in presets) {
      final res = await _capturePresetFrame(
        preset: preset,
        outputPath: '${directory.path}/${preset.id}.png',
        framesToSettle: settleFrames,
        startElapsedSeconds: elapsedSeconds,
      );
      elapsedSeconds += settleFrames / 60;
      results.add(res);
    }

    if (includeAtlas) {
      for (final seamPreset in geometrySeamPresets) {
        final res = await _capturePresetFrame(
          preset: seamPreset,
          outputPath: '${directory.path}/seams/${seamPreset.id}.png',
          framesToSettle: 10,
          startElapsedSeconds: elapsedSeconds,
        );
        elapsedSeconds += 10 / 60;
        results.add(res);
      }

      final originalGraph = world.graph;
      const stageX = -22.0;
      const stageZ = 14.0;
      try {
        world.applyGraph(ShukubaGraph());
        final stageY = world.sampleGroundHeight(stageX, stageZ);
        const orbitAngles = <(String, double)>[
          ('front_ne', math.pi * 0.25),
          ('front_nw', -math.pi * 0.25),
          ('rear_sw', -math.pi * 0.75),
          ('rear_se', math.pi * 0.75),
        ];

        for (final kind in turntableStructureKinds) {
          final spec = kind.spec;
          final variantCount = spec.variantCount;
          final span = math.max(spec.footprintWidth, spec.footprintDepth);
          final desiredWorldSpan = math.max(
            4.6,
            spec.height * 1.65 + span * 0.58,
          );
          const fovDeg = 20.0;
          final slantDist =
              desiredWorldSpan / (2 * math.tan(fovDeg * math.pi / 360));
          const pitchRad = 34 * math.pi / 180;
          final horizRadius = slantDist * math.cos(pitchRad);
          final eyeRise = slantDist * math.sin(pitchRad);
          final target = Vec3(stageX, stageY + spec.height * 0.40, stageZ);

          for (var variant = 0; variant < variantCount; variant++) {
            final specimen = PlacedStructure(
              id: EntityId('specimen_${kind.name}_v$variant'),
              kind: kind,
              position: Vec3(stageX, stageY, stageZ),
              variant: variant,
            );
            world.applyGraph(ShukubaGraph(structures: [specimen]));

            for (final (angleName, azimuth) in orbitAngles) {
              final presetId = '${kind.name}_v${variant}_$angleName';
              final eye = Vec3(
                target.x + math.sin(azimuth) * horizRadius,
                target.y + eyeRise,
                target.z + math.cos(azimuth) * horizRadius,
              );
              final specimenPreset = CameraPreset(
                id: presetId,
                label: '${spec.displayName} v$variant ($angleName)',
                eye: eye,
                target: target,
                timeOfDay: TimeOfDayRig.goldenDusk,
                verticalFovDegrees: fovDeg,
                nearMeters: 1,
                farMeters: 180,
              );
              final res = await _capturePresetFrame(
                preset: specimenPreset,
                outputPath: '${directory.path}/buildings/$presetId.png',
                framesToSettle: 6,
                startElapsedSeconds: elapsedSeconds,
              );
              elapsedSeconds += 6 / 60;
              results.add(res);
            }
          }
        }
      } finally {
        world.applyGraph(originalGraph);
      }
    }

    applyPreset(CameraPreset.duskOverview);
    final snappedHover = world.graph.snapStructure(
      kind: StructureKind.machiya,
      rawPoint: const Vec3(19.6, 0, -2.5),
      sampleGroundY: world.sampleGroundHeight,
    );
    final candidate = PlacedStructure(
      id: const EntityId('__harness_hover__'),
      kind: StructureKind.machiya,
      position: snappedHover.position,
      yawRadians: snappedHover.yawRadians,
    );
    world.syncPreview(
      StampGhostPreview(
        kind: StructureKind.machiya,
        position: snappedHover.position,
        yawRadians: snappedHover.yawRadians,
        lanternSpans: world.graph.previewLanternSpansFor(candidate),
      ),
    );
    look.syncFrame(
      rig: CameraPreset.duskOverview.timeOfDay,
      vision: MagistrateVisionState.hidden,
      sightcones: world.activeSightcones,
      lanternOrigins: world.activeLanternOrigins,
      elapsedSeconds: elapsedSeconds,
    );
    await pumpFrame();
    await pumpFrame();
    final hoverBoundary = repaintBoundaryKey.currentContext?.findRenderObject();
    if (hoverBoundary is RenderRepaintBoundary) {
      final hoverImg = await hoverBoundary.toImage(
        pixelRatio: capturePixelRatio,
      );
      try {
        final hoverPng = await hoverImg.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (hoverPng != null) {
          await File('${directory.path}/hover_preview_sample.png').writeAsBytes(
            hoverPng.buffer.asUint8List(
              hoverPng.offsetInBytes,
              hoverPng.lengthInBytes,
            ),
            flush: true,
          );
        }
      } finally {
        hoverImg.dispose();
      }
    }
    world.syncPreview(const NoBuildPreview());

    if (includeAtlas && captureUiAtlas != null) {
      final uiDir = Directory('${directory.path}/ui');
      await uiDir.create(recursive: true);
      await captureUiAtlas!(uiDir);
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
