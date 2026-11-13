import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:flutter_scene/scene.dart'
    show
        Camera,
        CoplanarOverlap,
        DirectionalLightComponent,
        GeometryBuilder,
        Mesh,
        Node,
        PointLightComponent,
        Scene;
import 'package:kage_no_machi/shukuba/audio/edo_audio_driver.dart'
    show EdoAudioDriver;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/world/edo_kit_builder.dart'
    show EdoKitBuilder;
import 'package:vector_math/vector_math.dart' show Vector3, Vector4;

const String kShukubaCaptureDir = String.fromEnvironment('SHUKUBA_CAPTURE_DIR');

const bool kShukubaAutoExit = bool.fromEnvironment('SHUKUBA_AUTO_EXIT');

const bool kShukubaCaptureAtlas = bool.fromEnvironment('SHUKUBA_CAPTURE_ATLAS');

const String kShukubaCaptureFilter = String.fromEnvironment(
  'SHUKUBA_CAPTURE_FILTER',
);

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

@immutable
class _CaptureFilter {
  factory parse(String raw) {
    final tokens = raw
        .split(',')
        .map((token) => token.trim().toLowerCase())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    return _CaptureFilter._(tokens);
  }

  const new _(this.tokens);

  final List<String> tokens;

  bool get isUnfiltered => tokens.isEmpty;

  bool matchesPreset({required String category, required String presetId}) {
    if (tokens.isEmpty) return true;
    final lowerId = presetId.toLowerCase();
    for (final token in tokens) {
      if (token == category || lowerId.contains(token)) {
        return true;
      }
    }
    return false;
  }

  bool get matchesHoverPreview =>
      tokens.isEmpty ||
      tokens.any(
        (token) =>
            token == 'valley' ||
            token == 'hover' ||
            'hover_preview_sample'.contains(token),
      );

  bool get matchesUiAtlas =>
      tokens.isEmpty ||
      tokens.any((token) => token == 'ui' || 'ui_atlas'.contains(token));
}

@immutable
class _TurntableSpecimenPlan {
  const new({required this.specimen, required this.angles});

  final PlacedStructure specimen;
  final List<(String, CameraPreset)> angles;
}

@immutable
class _CapturedShot {
  const new({
    required this.result,
    required this.pngWrite,
    required this.elapsedMs,
    required this.overlaps,
  });

  final PresetVerificationResult result;
  final Future<void> pngWrite;
  final int elapsedMs;
  final List<CoplanarOverlap> overlaps;
}

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

  static const List<CameraPreset> atmospherePresets = [
    CameraPreset.horizonSunCanopy,
    CameraPreset.horizonHillsideTilt,
  ];

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

  static bool _isSceneLightNode(Node node) =>
      node.name == 'edo_fill_light' ||
      node.name.startsWith('lantern_light_') ||
      node.getComponent<DirectionalLightComponent>() != null ||
      node.getComponent<PointLightComponent>() != null;

  static void _clearSubtreeShadowStatic(Node root) {
    root.shadowStatic = false;
    root.children.forEach(_clearSubtreeShadowStatic);
  }

  static Node _buildTurntableStageNode(ShukubaLookDriver look) {
    final stageRoot = Node(name: 'turntable_stage_root');
    final plinthBuilder = GeometryBuilder();
    EdoKitBuilder.addBox(
      plinthBuilder,
      Vector3(-4, -1.35, -4),
      Vector3(4, 0, 4),
      color: Vector4(1, 1, 1, 0.30),
    );
    final plinthNode = Node(
      name: 'turntable_stage_plinth',
      mesh: Mesh(
        plinthBuilder.build(),
        look.materialFor(ShukubaSurfaceRole.packedEarth),
      ),
    );
    stageRoot.add(plinthNode);
    return stageRoot;
  }

  static List<_TurntableSpecimenPlan> _buildTurntablePlans(
    _CaptureFilter filter,
  ) {
    const orbitAngles = <(String, double)>[
      ('front_ne', math.pi * 0.25),
      ('front_nw', -math.pi * 0.25),
      ('rear_sw', -math.pi * 0.75),
      ('rear_se', math.pi * 0.75),
    ];
    const fovDeg = 20.0;
    const pitchRad = 34 * math.pi / 180;
    final halfFovTan = math.tan(fovDeg * math.pi / 360);
    final cosPitch = math.cos(pitchRad);
    final sinPitch = math.sin(pitchRad);

    final plans = <_TurntableSpecimenPlan>[];
    for (final kind in turntableStructureKinds) {
      final spec = kind.spec;
      final span = math.max(spec.footprintWidth, spec.footprintDepth);
      final desiredWorldSpan = math.max(4.6, spec.height * 1.65 + span * 0.58);
      final slantDist = desiredWorldSpan / (2 * halfFovTan);
      final horizRadius = slantDist * cosPitch;
      final eyeRise = slantDist * sinPitch;
      final target = Vec3(0, spec.height * 0.40, 0);

      for (var variant = 0; variant < spec.variantCount; variant++) {
        final angles = <(String, CameraPreset)>[];
        for (final (angleName, azimuth) in orbitAngles) {
          final presetId = '${kind.name}_v${variant}_$angleName';
          if (!filter.matchesPreset(
            category: 'buildings',
            presetId: presetId,
          )) {
            continue;
          }
          final eye = Vec3(
            target.x + math.sin(azimuth) * horizRadius,
            target.y + eyeRise,
            target.z + math.cos(azimuth) * horizRadius,
          );
          angles.add((
            angleName,
            CameraPreset(
              id: presetId,
              label: '${spec.displayName} v$variant ($angleName)',
              eye: eye,
              target: target,
              timeOfDay: TimeOfDayRig.goldenDusk,
              verticalFovDegrees: fovDeg,
              nearMeters: 1,
              farMeters: 180,
            ),
          ));
        }
        if (angles.isNotEmpty) {
          plans.add(
            _TurntableSpecimenPlan(
              specimen: PlacedStructure(
                id: EntityId('specimen_${kind.name}_v$variant'),
                kind: kind,
                position: Vec3.zero,
                variant: variant,
              ),
              angles: angles,
            ),
          );
        }
      }
    }
    return plans;
  }

  static Future<void> _encodeAndWritePng({
    required ui.Image image,
    required String outputPath,
    required String presetId,
  }) async {
    final ByteData? pngData;
    try {
      pngData = await image.toByteData(format: ui.ImageByteFormat.png);
    } finally {
      image.dispose();
    }
    if (pngData == null) {
      throw StateError('Failed to encode PNG bytes for $presetId');
    }
    final pngFile = File(outputPath);
    await pngFile.parent.create(recursive: true);
    await pngFile.writeAsBytes(
      pngData.buffer.asUint8List(pngData.offsetInBytes, pngData.lengthInBytes),
    );
  }

  Future<_CapturedShot> _capturePresetFrame({
    required CameraPreset preset,
    required String outputPath,
    required int framesToSettle,
    required double startElapsedSeconds,
    int pumpCount = 2,
    bool stepWorld = true,
    List<WatchSightcone>? sightconesOverride,
    List<Vec3>? lanternOriginsOverride,
    List<CoplanarOverlap>? cachedOverlaps,
    bool probeDepth = true,
    int? probeWidth,
    int? probeHeight,
  }) async {
    final shotSw = Stopwatch()..start();
    var elapsedSeconds = startElapsedSeconds;
    final activeCamera = applyPreset(preset);
    for (var frame = 0; frame < framesToSettle; frame++) {
      elapsedSeconds += 1 / 60;
      if (stepWorld) {
        world.step(1 / 60, rig: preset.timeOfDay);
      }
    }
    look.syncFrame(
      rig: preset.timeOfDay,
      vision: preset.visionState,
      sightcones: sightconesOverride ?? world.activeSightcones,
      lanternOrigins: lanternOriginsOverride ?? world.activeLanternOrigins,
      elapsedSeconds: elapsedSeconds,
    );
    if (stepWorld) {
      audio?.syncAtmosphere(
        rig: preset.timeOfDay,
        loopAnchors: world.ambientLoopAnchors,
      );
    }
    for (var i = 0; i < pumpCount; i++) {
      await pumpFrame();
    }

    final boundaryObject = repaintBoundaryKey.currentContext
        ?.findRenderObject();
    if (boundaryObject is! RenderRepaintBoundary) {
      throw StateError('Missing RenderRepaintBoundary for frame capture.');
    }

    final image = await boundaryObject.toImage(pixelRatio: capturePixelRatio);
    var imageTransferred = false;
    final FramePixelStats pixelStats;
    final List<CoplanarOverlap> overlaps;
    final int depthConflictCount;
    final String depthConflictSummary;
    try {
      final imageWidth = image.width;
      final imageHeight = image.height;
      final rgbaFuture = image.toByteData();

      overlaps =
          cachedOverlaps ?? scene.findCoplanarOverlaps(camera: activeCamera);
      if (probeDepth) {
        final depthReport = probeWidth != null && probeHeight != null
            ? await scene.probeDepthConflicts(
                camera: activeCamera,
                width: probeWidth,
                height: probeHeight,
              )
            : await scene.probeDepthConflicts(camera: activeCamera);
        depthConflictCount = depthReport.conflicts.length;
        depthConflictSummary = depthReport.describe();
      } else {
        depthConflictCount = 0;
        depthConflictSummary =
            'No depth conflicts in antipodal 640x360 turntable probes.';
      }

      final rgbaData = await rgbaFuture;
      if (rgbaData == null) {
        throw StateError('Failed to read RGBA bytes for ${preset.id}');
      }
      pixelStats = analyzeRgbaPixels(
        rgbaData,
        width: imageWidth,
        height: imageHeight,
      );
      imageTransferred = true;
    } finally {
      if (!imageTransferred) {
        image.dispose();
      }
    }

    final pngFile = File(outputPath);
    final pngWrite = _encodeAndWritePng(
      image: image,
      outputPath: pngFile.path,
      presetId: preset.id,
    );
    shotSw.stop();

    final result = PresetVerificationResult(
      presetId: preset.id,
      pngPath: pngFile.path,
      pixelStats: pixelStats,
      coplanarOverlapCount: overlaps.length,
      coplanarDescriptions: [
        for (final overlap in overlaps.take(12)) overlap.describe(),
      ],
      depthConflictCount: depthConflictCount,
      depthConflictSummary: depthConflictSummary,
    );
    return _CapturedShot(
      result: result,
      pngWrite: pngWrite,
      elapsedMs: shotSw.elapsedMilliseconds,
      overlaps: overlaps,
    );
  }

  Future<HarnessSummary> runCaptureSuite({
    required String outputDir,
    required bool autoExit,
    bool includeAtlas = kShukubaCaptureAtlas,
    List<CameraPreset> presets = CameraPreset.verificationPresets,
    String captureFilter = kShukubaCaptureFilter,
  }) async {
    final directory = await _prepareOutputDir(outputDir);
    stdout.writeln('SHUKUBA_CAPTURE_OUT:${directory.path}');

    await Scene.initializeStaticResources();
    await Scene.preload();

    final filter = _CaptureFilter.parse(captureFilter);
    if (filter.matchesHoverPreview) {
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
    }

    final valleyPresets = [
      for (final preset in presets)
        if (filter.matchesPreset(category: 'valley', presetId: preset.id))
          preset,
    ];
    final horizonPresets = [
      for (final preset in atmospherePresets)
        if (filter.matchesPreset(category: 'horizon', presetId: preset.id))
          preset,
    ];
    final considerAtlas = includeAtlas || !filter.isUnfiltered;
    final seamPresets = considerAtlas
        ? [
            for (final seamPreset in geometrySeamPresets)
              if (filter.matchesPreset(
                category: 'seams',
                presetId: seamPreset.id,
              ))
                seamPreset,
          ]
        : const <CameraPreset>[];
    final specimenPlans = considerAtlas
        ? _buildTurntablePlans(filter)
        : const <_TurntableSpecimenPlan>[];

    final totalShots =
        valleyPresets.length +
        horizonPresets.length +
        seamPresets.length +
        specimenPlans.fold<int>(0, (sum, plan) => sum + plan.angles.length);

    final results = <PresetVerificationResult>[];
    final pendingPngWrites = <Future<void>>[];
    var shotIndex = 0;
    var elapsedSeconds = 0.0;
    var ranUiAtlas = false;

    Future<void> flushPendingWrites() async {
      if (pendingPngWrites.isEmpty) return;
      final batch = List<Future<void>>.of(pendingPngWrites);
      pendingPngWrites.clear();
      await Future.wait(batch);
    }

    Future<void> recordShot(_CapturedShot shot) async {
      shotIndex++;
      results.add(shot.result);
      pendingPngWrites.add(shot.pngWrite);
      stdout.writeln(
        'SHUKUBA_SHOT:[$shotIndex/$totalShots] ${shot.result.presetId} '
        'overlaps=${shot.result.coplanarOverlapCount} '
        'conflicts=${shot.result.depthConflictCount} (${shot.elapsedMs}ms)',
      );
      if (shotIndex % 8 == 0 || shotIndex == totalShots) {
        await flushPendingWrites();
        final partialSummary = HarnessSummary(
          outputDir: directory.path,
          results: List<PresetVerificationResult>.unmodifiable(results),
        );
        final partialEncoded = const JsonEncoder.withIndent('  ')
            .convert(partialSummary.toJson());
        await File('${directory.path}/summary.partial.json')
            .writeAsString('$partialEncoded\n', flush: true);
      }
    }

    final savedDebugCoplanar = scene.debugCheckCoplanarOverlaps;
    scene.debugCheckCoplanarOverlaps = false;
    try {
      List<CoplanarOverlap>? staticValleyOverlaps;
      var lastTimeValue = -1.0;
      int resolvePumpCount(CameraPreset preset) {
        final changed = (preset.timeOfDay.value - lastTimeValue).abs() > 0.008;
        lastTimeValue = preset.timeOfDay.value;
        return changed ? 18 : 2;
      }

      for (var i = 0; i < valleyPresets.length; i++) {
        final preset = valleyPresets[i];
        final frames = math.min(settleFrames, i == 0 ? 24 : 8);
        final shot = await _capturePresetFrame(
          preset: preset,
          outputPath: '${directory.path}/${preset.id}.png',
          framesToSettle: frames,
          startElapsedSeconds: elapsedSeconds,
          pumpCount: resolvePumpCount(preset),
          cachedOverlaps: staticValleyOverlaps,
        );
        staticValleyOverlaps ??= shot.overlaps;
        elapsedSeconds += frames / 60;
        await recordShot(shot);
      }

      for (var i = 0; i < horizonPresets.length; i++) {
        final horizonPreset = horizonPresets[i];
        final shot = await _capturePresetFrame(
          preset: horizonPreset,
          outputPath: '${directory.path}/${horizonPreset.id}.png',
          framesToSettle: 4,
          startElapsedSeconds: elapsedSeconds,
          pumpCount: resolvePumpCount(horizonPreset),
          cachedOverlaps: staticValleyOverlaps,
        );
        staticValleyOverlaps ??= shot.overlaps;
        elapsedSeconds += 4 / 60;
        await recordShot(shot);
      }

      for (var i = 0; i < seamPresets.length; i++) {
        final seamPreset = seamPresets[i];
        final shot = await _capturePresetFrame(
          preset: seamPreset,
          outputPath: '${directory.path}/seams/${seamPreset.id}.png',
          framesToSettle: 4,
          startElapsedSeconds: elapsedSeconds,
          pumpCount: resolvePumpCount(seamPreset),
          cachedOverlaps: staticValleyOverlaps,
        );
        staticValleyOverlaps ??= shot.overlaps;
        elapsedSeconds += 4 / 60;
        await recordShot(shot);
      }

      if (specimenPlans.isNotEmpty) {
        final savedVisibility = <Node, bool>{};
        for (final child in List<Node>.of(scene.root.children)) {
          if (_isSceneLightNode(child)) continue;
          savedVisibility[child] = child.visible;
          child.visible = false;
        }
        final stageRoot = _buildTurntableStageNode(look);
        scene.root.add(stageRoot);
        const kitBuilder = EdoKitBuilder();

        try {
          for (final plan in specimenPlans) {
            final specimen = plan.specimen;
            final specimenNode = kitBuilder.buildStructureNode(
              specimen,
              look.materialFor,
            );
            _clearSubtreeShadowStatic(specimenNode);
            final specimenLanternOrigins = [
              for (final local in EdoKitBuilder.structureLanternLocalOffsets(
                specimen,
              ))
                specimen.position + local.rotateY(specimen.yawRadians),
            ];
            stageRoot.add(specimenNode);

            try {
              List<CoplanarOverlap>? cachedOverlaps;
              var hasProbedDepth = false;
              var specimenHadDepthConflict = false;

              for (final (angleName, specimenPreset) in plan.angles) {
                final shouldProbeDepth =
                    angleName == 'front_ne' ||
                    angleName == 'rear_sw' ||
                    !hasProbedDepth ||
                    specimenHadDepthConflict;
                final shot = await _capturePresetFrame(
                  preset: specimenPreset,
                  outputPath:
                      '${directory.path}/buildings/${specimenPreset.id}.png',
                  framesToSettle: 2,
                  startElapsedSeconds: elapsedSeconds,
                  pumpCount: resolvePumpCount(specimenPreset),
                  stepWorld: false,
                  sightconesOverride: const [],
                  lanternOriginsOverride: specimenLanternOrigins,
                  cachedOverlaps: cachedOverlaps,
                  probeDepth: shouldProbeDepth,
                  probeWidth: 640,
                  probeHeight: 360,
                );
                elapsedSeconds += 2 / 60;
                cachedOverlaps ??= shot.overlaps;
                if (shouldProbeDepth) {
                  hasProbedDepth = true;
                  if (shot.result.depthConflictCount > 0) {
                    specimenHadDepthConflict = true;
                  }
                }
                await recordShot(shot);
              }
            } finally {
              stageRoot.remove(specimenNode);
            }
          }
        } finally {
          scene.root.remove(stageRoot);
          for (final entry in savedVisibility.entries) {
            entry.key.visible = entry.value;
          }
        }
      }

      if (filter.matchesHoverPreview) {
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
        final hoverPumps = resolvePumpCount(CameraPreset.duskOverview);
        for (var i = 0; i < hoverPumps; i++) {
          await pumpFrame();
        }
        final hoverBoundary = repaintBoundaryKey.currentContext
            ?.findRenderObject();
        if (hoverBoundary is RenderRepaintBoundary) {
          final hoverImg = await hoverBoundary.toImage(
            pixelRatio: capturePixelRatio,
          );
          pendingPngWrites.add(
            _encodeAndWritePng(
              image: hoverImg,
              outputPath: '${directory.path}/hover_preview_sample.png',
              presetId: 'hover_preview_sample',
            ),
          );
        }
        world.syncPreview(const NoBuildPreview());
        final savedBenchGraph = world.graph;
        final benchGraph = savedBenchGraph.putStructure(candidate);
        final placeBenchSw = Stopwatch()..start();
        world.applyGraph(benchGraph);
        placeBenchSw.stop();
        final placeBenchMs = placeBenchSw.elapsedMicroseconds / 1000.0;
        stdout.writeln('SHUKUBA_INCREMENTAL_PLACE_MS:$placeBenchMs');
        world.applyGraph(savedBenchGraph);
        final singleTileCandidate = PlacedStructure(
          id: EntityId.validated('bench_single_tile_probe'),
          kind: StructureKind.machiya,
          position: Vec3(-22, world.sampleGroundHeight(-22, -22), -22),
          yawRadians: 0,
        );
        final singleTileGraph = savedBenchGraph.putStructure(
          singleTileCandidate,
        );
        final singleBenchSw = Stopwatch()..start();
        world.applyGraph(singleTileGraph);
        singleBenchSw.stop();
        final singleBenchMs = singleBenchSw.elapsedMicroseconds / 1000.0;
        stdout.writeln('SHUKUBA_INCREMENTAL_SINGLE_TILE_MS:$singleBenchMs');
        world.applyGraph(savedBenchGraph);
      } else if (specimenPlans.isNotEmpty) {
        applyPreset(CameraPreset.duskOverview);
        look.syncFrame(
          rig: CameraPreset.duskOverview.timeOfDay,
          vision: MagistrateVisionState.hidden,
          sightcones: world.activeSightcones,
          lanternOrigins: world.activeLanternOrigins,
          elapsedSeconds: elapsedSeconds,
        );
      }

      if (audio case final EdoAudioDriver edoAudio) {
        applyPreset(CameraPreset.duskOverview);
        edoAudio
          ..syncAtmosphere(
            rig: CameraPreset.duskOverview.timeOfDay,
            loopAnchors: world.ambientLoopAnchors,
          )
          ..playPlacementNote(
            PlacementNoteEvent.fromSnap(
              instrument: EdoInstrument.koto,
              rig: CameraPreset.duskOverview.timeOfDay,
              snapped: SnappedPlacement(
                position: CameraPreset.duskOverview.target,
                yawRadians: 0,
                scaleDegree: 0,
              ),
            ),
          );
        scene.update(1 / 60);
        await pumpFrame();
        final listenerPos = edoAudio.listenerWorldPosition;
        final status = <String, Object?>{
          'isNativeAudioActive': edoAudio.isNativeAudioActive,
          'loadedClipCount': edoAudio.loadedClipCount,
          'playingAmbientSourceCount': edoAudio.playingAmbientSourceCount,
          'oneShotVoicePlaying': edoAudio.lastOneShotVoicePlaying,
          'listenerPosition': listenerPos == null
              ? null
              : [listenerPos.x, listenerPos.y, listenerPos.z],
          'lastAttachError': edoAudio.lastAttachError,
        };
        stdout.writeln('SHUKUBA_AUDIO_STATUS:${jsonEncode(status)}');
      }

      if (considerAtlas && filter.matchesUiAtlas && captureUiAtlas != null) {
        final uiSw = Stopwatch()..start();
        final uiDir = Directory('${directory.path}/ui');
        await uiDir.create(recursive: true);
        final uiSaved = await captureUiAtlas!(uiDir);
        uiSw.stop();
        ranUiAtlas = true;
        stdout.writeln(
          'SHUKUBA_UI_ATLAS:${uiSaved.length} (${uiSw.elapsedMilliseconds}ms)',
        );
      }

      await flushPendingWrites();
    } finally {
      scene.debugCheckCoplanarOverlaps = savedDebugCoplanar;
      if (pendingPngWrites.isNotEmpty) {
        try {
          await flushPendingWrites();
        } on Object catch (_) {}
      }
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
      final exitClean =
          summary.allPassed ||
          (results.isEmpty && ranUiAtlas && !filter.isUnfiltered);
      exit(exitClean ? 0 : 2);
    }
    return summary;
  }
}
