import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_scene/scene.dart' show Camera, RenderView, Scene;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/world/edo_world_driver.dart'
    show EdoWorldDriver;

class ShukubaController extends ChangeNotifier {
  new({
    required this.look,
    required this.world,
    required this.audio,
    TimeOfDayRig initialTimeOfDay = TimeOfDayRig.goldenDusk,
  }) : _timeOfDay = initialTimeOfDay;

  static const int _maxUndoEntries = 30;

  final ShukubaLookDriver look;
  final ShukubaWorldDriver world;
  final ShukubaAudioDriver audio;

  TimeOfDayRig _timeOfDay;
  PlacementTool _activeTool = const ExploreTool();
  MagistrateVisionState _explicitVision = MagistrateVisionState.hidden;
  final List<Vec3> _strokePoints = [];
  final List<ShukubaGraph> _undoStack = [];
  Vec3? _hoverPoint;
  BuildPreview _activePreview = const NoBuildPreview();
  bool _isReady = false;
  int _nextEntitySeq = 1;
  double _elapsedSeconds = 0;

  bool get isReady => _isReady;

  TimeOfDayRig get timeOfDay => _timeOfDay;

  PlacementTool get activeTool => _activeTool;

  MagistrateVisionState get explicitVision => _explicitVision;

  MagistrateVisionState get effectiveVision =>
      _activeTool.resolveVision(_explicitVision);

  List<Vec3> get strokePoints => List<Vec3>.unmodifiable(_strokePoints);

  bool get canUndo => _undoStack.isNotEmpty;

  BuildPreview get activePreview => _activePreview;

  ShukubaGraph get graph => world.graph;

  BootReport? _bootReport;

  BootReport? get bootReport => _bootReport;

  Future<void> initialize([Scene? scene]) async {
    if (scene != null) {
      await look.attach(scene);
      await world.attach(scene, resolveMaterial: look.materialFor);
      await audio.attach(scene, loopAnchors: world.ambientLoopAnchors);
    }
    look.syncFrame(
      rig: _timeOfDay,
      vision: effectiveVision,
      sightcones: world.activeSightcones,
      lanternOrigins: world.activeLanternOrigins,
      elapsedSeconds: 0,
    );
    audio.syncAtmosphere(
      rig: _timeOfDay,
      loopAnchors: world.ambientLoopAnchors,
    );
    _isReady = true;
    notifyListeners();
  }

  Future<BootReport> initializeStaged({
    required Scene scene,
    required Camera camera,
    void Function(BootStageId stage, double elapsedMs)? onStage,
  }) async {
    final timings = <BootStageTiming>[];
    final totalSw = Stopwatch()..start();
    final stageSw = Stopwatch()..start();

    await Scene.initializeStaticResources();
    await look.attach(scene);
    var elapsed = stageSw.elapsedMicroseconds / 1000.0;
    timings.add(
      BootStageTiming(stage: BootStageId.lookAndShaders, durationMs: elapsed),
    );
    onStage?.call(BootStageId.lookAndShaders, elapsed);
    await Future<void>.delayed(Duration.zero);

    stageSw.reset();
    await audio.prewarm();
    elapsed = stageSw.elapsedMicroseconds / 1000.0;
    timings.add(
      BootStageTiming(stage: BootStageId.audioSynthesis, durationMs: elapsed),
    );
    onStage?.call(BootStageId.audioSynthesis, elapsed);
    await Future<void>.delayed(Duration.zero);

    if (world is EdoWorldDriver) {
      await (world as EdoWorldDriver).attachStaged(
        scene,
        resolveMaterial: look.materialFor,
        onStage: (stage, ms) async {
          timings.add(BootStageTiming(stage: stage, durationMs: ms));
          onStage?.call(stage, ms);
        },
      );
    } else {
      await world.attach(scene, resolveMaterial: look.materialFor);
      for (final stage in [
        BootStageId.valleyTerrain,
        BootStageId.townArchitecture,
        BootStageId.floraAndAir,
      ]) {
        timings.add(BootStageTiming(stage: stage, durationMs: 1));
        onStage?.call(stage, 1);
        await Future<void>.delayed(Duration.zero);
      }
    }
    await audio.attach(scene, loopAnchors: world.ambientLoopAnchors);

    stageSw.reset();
    look.syncFrame(
      rig: _timeOfDay,
      vision: effectiveVision,
      sightcones: world.activeSightcones,
      lanternOrigins: world.activeLanternOrigins,
      elapsedSeconds: 0,
    );
    audio.syncAtmosphere(
      rig: _timeOfDay,
      loopAnchors: world.ambientLoopAnchors,
    );
    try {
      await scene.warmUp([
        RenderView(
          camera: camera,
          viewport: const Rect.fromLTWH(0, 0, 1440, 778),
        ),
      ], allShadingTiers: true);
    } on Object catch (_) {}
    elapsed = stageSw.elapsedMicroseconds / 1000.0;
    timings.add(
      BootStageTiming(stage: BootStageId.gpuWarmup, durationMs: elapsed),
    );
    onStage?.call(BootStageId.gpuWarmup, elapsed);

    final report = BootReport(
      stages: timings,
      totalMs: totalSw.elapsedMicroseconds / 1000.0,
    );
    _bootReport = report;
    _isReady = true;
    notifyListeners();
    return report;
  }

  void setTimeOfDay(double rawValue) {
    final next = TimeOfDayRig(rawValue);
    if (next == _timeOfDay) {
      return;
    }
    _timeOfDay = next;
    audio.syncAtmosphere(
      rig: _timeOfDay,
      loopAnchors: world.ambientLoopAnchors,
    );
    if (_isReady) {
      look.syncFrame(
        rig: _timeOfDay,
        vision: effectiveVision,
        sightcones: world.activeSightcones,
        lanternOrigins: world.activeLanternOrigins,
        elapsedSeconds: _elapsedSeconds,
      );
    }
    notifyListeners();
  }

  void selectTool(PlacementTool tool) {
    if (tool == _activeTool) {
      return;
    }
    _strokePoints.clear();
    _activeTool = tool;
    _refreshPreview();
    _syncLookImmediate();
    notifyListeners();
  }

  void toggleTool(PlacementTool tool) {
    final isSameKind = switch ((_activeTool, tool)) {
      (StampStructureTool(kind: final a), StampStructureTool(kind: final b)) =>
        a == b,
      (DrawLaneTool(style: final a), DrawLaneTool(style: final b)) => a == b,
      _ => _activeTool.runtimeType == tool.runtimeType,
    };
    selectTool(isSameKind ? const ExploreTool() : tool);
  }

  void rotateStampYaw([double deltaRadians = math.pi / 4]) {
    if (_activeTool case StampStructureTool(
      :final kind,
      :final yawOffsetRadians,
    )) {
      _activeTool = StampStructureTool(
        kind: kind,
        yawOffsetRadians: yawOffsetRadians + deltaRadians,
      );
      _refreshPreview();
      notifyListeners();
    }
  }

  void toggleMagistrateEye() {
    _explicitVision = _explicitVision == MagistrateVisionState.fullOverlay
        ? MagistrateVisionState.hidden
        : MagistrateVisionState.fullOverlay;
    _syncLookImmediate();
    notifyListeners();
  }

  void applyCameraPresetState(CameraPreset preset) {
    _strokePoints.clear();
    _hoverPoint = null;
    _timeOfDay = preset.timeOfDay;
    _explicitVision = preset.visionState;
    _refreshPreview();
    _syncLookImmediate();
    audio.syncAtmosphere(
      rig: _timeOfDay,
      loopAnchors: world.ambientLoopAnchors,
    );
    notifyListeners();
  }

  void updateHoverPoint(Vec3? rawWorldPoint) {
    _hoverPoint = rawWorldPoint;
    final prev = _activePreview;
    _refreshPreview();
    if (_activePreview != prev) {
      notifyListeners();
    }
  }

  bool undo() {
    if (_undoStack.isEmpty) {
      return false;
    }
    _strokePoints.clear();
    final previous = _undoStack.removeLast();
    world.applyGraph(previous);
    audio.playPlacementNote(
      PlacementNoteEvent(
        instrument: EdoInstrument.hyoshigi,
        scale: _timeOfDay.scale,
        scaleDegree: 0,
        position: _hoverPoint ?? Vec3.zero,
        volume: 0.36,
      ),
    );
    _refreshPreview();
    _syncLookImmediate();
    notifyListeners();
    return true;
  }

  void beginStrokeAt(Vec3 rawWorldPoint) {
    if (!_activeTool.isStrokeTool) {
      return;
    }
    final snappedY = world.sampleGroundHeight(rawWorldPoint.x, rawWorldPoint.z);
    final point = rawWorldPoint.withY(snappedY);
    _hoverPoint = rawWorldPoint;
    _strokePoints
      ..clear()
      ..add(point);
    _playBrushTick(point, volume: 0.35);
    _refreshPreview();
    notifyListeners();
  }

  void extendStrokeTo(Vec3 rawWorldPoint) {
    _hoverPoint = rawWorldPoint;
    if (!_activeTool.isStrokeTool || _strokePoints.isEmpty) {
      _refreshPreview();
      return;
    }
    final snappedY = world.sampleGroundHeight(rawWorldPoint.x, rawWorldPoint.z);
    final point = rawWorldPoint.withY(snappedY);
    if (_strokePoints.last.horizontalDistanceTo(point) >= 1.25) {
      _strokePoints.add(point);
      if (_strokePoints.length.isOdd) {
        _playBrushTick(point, volume: 0.22);
      }
    }
    _refreshPreview();
    notifyListeners();
  }

  bool finishDragStroke() {
    if (_strokePoints.length >= 2) {
      return commitActiveStroke();
    }
    _refreshPreview();
    notifyListeners();
    return false;
  }

  void handlePrimaryPlotTap(Vec3 rawWorldPoint) {
    _hoverPoint = rawWorldPoint;
    switch (_activeTool) {
      case StampStructureTool(:final kind, :final yawOffsetRadians):
        _stampStructure(
          kind: kind,
          rawWorldPoint: rawWorldPoint,
          yawOffsetRadians: yawOffsetRadians,
        );
      case DrawLaneTool() || BuildTerraceTool() || BuildWallTool():
        final snappedY = world.sampleGroundHeight(
          rawWorldPoint.x,
          rawWorldPoint.z,
        );
        final point = rawWorldPoint.withY(snappedY);
        if (_strokePoints.isNotEmpty &&
            _strokePoints.last.horizontalDistanceTo(point) < 1.1) {
          commitActiveStroke();
          return;
        }
        _strokePoints.add(point);
        _playBrushTick(point, volume: 0.42);
        _refreshPreview();
        notifyListeners();
      case DemolishTool():
        _demolishAt(rawWorldPoint);
      case ExploreTool():
        break;
      case InspectWatchTool():
        toggleMagistrateEye();
    }
  }

  bool commitActiveStroke() {
    if (_strokePoints.length < 2) {
      return false;
    }
    final points = List<Vec3>.unmodifiable(_strokePoints);
    _strokePoints.clear();

    switch (_activeTool) {
      case DrawLaneTool(:final widthMeters, :final style):
        _pushUndoSnapshot();
        final prefix = style == RoadStyle.gardenPath ? 'path' : 'road';
        final id = EntityId.validated('${prefix}_user_${_nextEntitySeq++}');
        final road = RoadSpline.validated(
          id: id,
          controlPoints: points,
          widthMeters: widthMeters,
          style: style,
        );
        world.applyGraph(world.graph.putRoad(road));
        _emitStrokeChord(EdoInstrument.hyoshigi, points.last);
      case BuildTerraceTool(:final riseMeters, :final depthMeters):
        _pushUndoSnapshot();
        final id = EntityId.validated('terrace_user_${_nextEntitySeq++}');
        final maxGround = points
            .map((p) => world.sampleGroundHeight(p.x, p.z))
            .reduce(math.max);
        final topY = maxGround + riseMeters;
        final crest = [for (final p in points) p.withY(topY)];
        final terrace = TerraceCourse.alignedToTerrain(
          id: id,
          crestPoints: crest,
          topElevation: topY,
          sampleGroundY: world.sampleGroundHeight,
          riseMeters: riseMeters,
          depthMeters: depthMeters,
        );
        world.applyGraph(world.graph.putTerrace(terrace));
        _emitStrokeChord(EdoInstrument.bonsho, crest.last);
      case BuildWallTool(:final heightMeters, :final thicknessMeters):
        _pushUndoSnapshot();
        final id = EntityId.validated('wall_user_${_nextEntitySeq++}');
        final wall = CourtyardWall.validated(
          id: id,
          controlPoints: points,
          heightMeters: heightMeters,
          thicknessMeters: thicknessMeters,
        );
        world.applyGraph(world.graph.putWall(wall));
        _emitStrokeChord(EdoInstrument.hyoshigi, points.last);
      case ExploreTool() ||
          StampStructureTool() ||
          DemolishTool() ||
          InspectWatchTool():
        return false;
    }

    _refreshPreview();
    _syncLookImmediate();
    notifyListeners();
    return true;
  }

  void cancelActiveStroke() {
    if (_strokePoints.isEmpty) {
      return;
    }
    _strokePoints.clear();
    _refreshPreview();
    notifyListeners();
  }

  void onFrameTick(Duration elapsed, double deltaSeconds) {
    if (!_isReady) {
      return;
    }
    final clampedDt = deltaSeconds <= 0
        ? 1 / 60
        : deltaSeconds > 0.1
        ? 0.1
        : deltaSeconds;
    _elapsedSeconds = elapsed.inMicroseconds / 1e6;
    world.step(clampedDt, rig: _timeOfDay);
    look.syncFrame(
      rig: _timeOfDay,
      vision: effectiveVision,
      sightcones: world.activeSightcones,
      lanternOrigins: world.activeLanternOrigins,
      elapsedSeconds: _elapsedSeconds,
    );
  }

  void _pushUndoSnapshot() {
    _undoStack.add(world.graph);
    if (_undoStack.length > _maxUndoEntries) {
      _undoStack.removeAt(0);
    }
  }

  void _stampStructure({
    required StructureKind kind,
    required Vec3 rawWorldPoint,
    required double yawOffsetRadians,
  }) {
    final snapped = world.graph.snapStructure(
      kind: kind,
      rawPoint: rawWorldPoint,
      sampleGroundY: world.sampleGroundHeight,
    );
    _pushUndoSnapshot();
    final id = EntityId.validated('${kind.name}_user_${_nextEntitySeq++}');
    final placed = PlacedStructure(
      id: id,
      kind: kind,
      position: snapped.position,
      yawRadians: snapped.yawRadians + yawOffsetRadians,
    );
    world.applyGraph(world.graph.putStructure(placed));
    audio.playPlacementNote(
      PlacementNoteEvent.fromSnap(
        instrument: placed.spec.instrument,
        rig: _timeOfDay,
        snapped: snapped,
      ),
    );
    _refreshPreview();
    _syncLookImmediate();
    notifyListeners();
  }

  void _demolishAt(Vec3 rawWorldPoint) {
    final hit = world.graph.findDemolishCandidate(rawWorldPoint);
    if (hit == null) {
      return;
    }
    _pushUndoSnapshot();
    world.applyGraph(world.graph.removeEntity(hit.id));
    audio.playPlacementNote(
      PlacementNoteEvent(
        instrument: EdoInstrument.hyoshigi,
        scale: _timeOfDay.scale,
        scaleDegree: 1,
        position: hit.center,
        volume: 0.48,
      ),
    );
    _refreshPreview();
    _syncLookImmediate();
    notifyListeners();
  }

  void _refreshPreview() {
    final hover = _hoverPoint;
    BuildPreview next = const NoBuildPreview();

    switch (_activeTool) {
      case StampStructureTool(:final kind, :final yawOffsetRadians):
        if (hover != null) {
          final snapped = world.graph.snapStructure(
            kind: kind,
            rawPoint: hover,
            sampleGroundY: world.sampleGroundHeight,
          );
          final finalYaw = snapped.yawRadians + yawOffsetRadians;
          final candidate = PlacedStructure(
            id: const EntityId('__ghost_preview__'),
            kind: kind,
            position: snapped.position,
            yawRadians: finalYaw,
          );
          next = StampGhostPreview(
            kind: kind,
            position: snapped.position,
            yawRadians: finalYaw,
            lanternSpans: world.graph.previewLanternSpansFor(candidate),
          );
        }
      case DrawLaneTool(:final widthMeters, :final style):
        next = _buildStrokePreview(
          style: style == RoadStyle.gardenPath
              ? StrokePreviewStyle.gardenPath
              : StrokePreviewStyle.lane,
          widthMeters: widthMeters,
          hover: hover,
        );
      case BuildTerraceTool():
        next = _buildStrokePreview(
          style: StrokePreviewStyle.terrace,
          widthMeters: 1.4,
          hover: hover,
        );
      case BuildWallTool(:final thicknessMeters):
        next = _buildStrokePreview(
          style: StrokePreviewStyle.wall,
          widthMeters: thicknessMeters,
          hover: hover,
        );
      case DemolishTool():
        if (hover != null) {
          final hit = world.graph.findDemolishCandidate(hover);
          if (hit != null) {
            next = DemolishHoverPreview(candidate: hit);
          }
        }
      case ExploreTool() || InspectWatchTool():
        next = const NoBuildPreview();
    }

    _activePreview = next;
    world.syncPreview(next);
  }

  BuildPreview _buildStrokePreview({
    required StrokePreviewStyle style,
    required double widthMeters,
    required Vec3? hover,
  }) {
    final pts = <Vec3>[..._strokePoints];
    if (hover != null) {
      final gy = world.sampleGroundHeight(hover.x, hover.z);
      final hp = hover.withY(gy);
      if (pts.isEmpty || pts.last.horizontalDistanceTo(hp) > 0.30) {
        pts.add(hp);
      }
    }
    if (pts.isEmpty) {
      return const NoBuildPreview();
    }
    return StrokeRibbonPreview(
      style: style,
      points: List<Vec3>.unmodifiable(pts),
      widthMeters: widthMeters,
    );
  }

  void _playBrushTick(Vec3 point, {required double volume}) {
    final instrument = _activeTool.placementInstrument;
    if (instrument == null) {
      return;
    }
    final degree = ((point.x.abs() + point.z.abs()) / 3).floor();
    audio.playPlacementNote(
      PlacementNoteEvent(
        instrument: instrument,
        scale: _timeOfDay.scale,
        scaleDegree: degree,
        position: point,
        volume: volume,
      ),
    );
  }

  void _emitStrokeChord(EdoInstrument instrument, Vec3 anchor) {
    final baseDegree = ((anchor.x.abs() + anchor.z.abs()) / 2.6).floor();
    audio.playPlacementNote(
      PlacementNoteEvent(
        instrument: instrument,
        scale: _timeOfDay.scale,
        scaleDegree: baseDegree,
        position: anchor,
      ),
    );
  }

  void _syncLookImmediate() {
    if (!_isReady) {
      return;
    }
    look.syncFrame(
      rig: _timeOfDay,
      vision: effectiveVision,
      sightcones: world.activeSightcones,
      lanternOrigins: world.activeLanternOrigins,
      elapsedSeconds: _elapsedSeconds,
    );
  }

  @override
  void dispose() {
    audio.dispose();
    world.dispose();
    look.dispose();
    super.dispose();
  }
}
