import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:flutter_scene/scene.dart' show Scene;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';

class ShukubaController extends ChangeNotifier {
  new({
    required this.look,
    required this.world,
    required this.audio,
    TimeOfDayRig initialTimeOfDay = TimeOfDayRig.goldenDusk,
  }) : _timeOfDay = initialTimeOfDay;

  final ShukubaLookDriver look;
  final ShukubaWorldDriver world;
  final ShukubaAudioDriver audio;

  TimeOfDayRig _timeOfDay;
  PlacementTool _activeTool = const StampStructureTool(
    kind: StructureKind.machiya,
  );
  MagistrateVisionState _explicitVision = MagistrateVisionState.hidden;
  final List<Vec3> _strokePoints = [];
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

  ShukubaGraph get graph => world.graph;

  Future<void> initialize(Scene scene) async {
    await look.attach(scene);
    await world.attach(scene, resolveMaterial: look.materialFor);
    await audio.attach(scene, loopAnchors: world.ambientLoopAnchors);
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
    _syncLookImmediate();
    notifyListeners();
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
    _timeOfDay = preset.timeOfDay;
    _explicitVision = preset.visionState;
    _syncLookImmediate();
    audio.syncAtmosphere(
      rig: _timeOfDay,
      loopAnchors: world.ambientLoopAnchors,
    );
    notifyListeners();
  }

  void handlePrimaryPlotTap(Vec3 rawWorldPoint) {
    switch (_activeTool) {
      case StampStructureTool(:final kind, :final yawOffsetRadians):
        _stampStructure(
          kind: kind,
          rawWorldPoint: rawWorldPoint,
          yawOffsetRadians: yawOffsetRadians,
        );
      case DrawLaneTool() || BuildTerraceTool():
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
        final degree = ((point.x.abs() + point.z.abs()) / 3).floor();
        final instrument = _activeTool.placementInstrument;
        if (instrument != null) {
          audio.playPlacementNote(
            PlacementNoteEvent(
              instrument: instrument,
              scale: _timeOfDay.scale,
              scaleDegree: degree,
              position: point,
              volume: 0.42,
            ),
          );
        }
        notifyListeners();
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
      case DrawLaneTool(:final widthMeters):
        final id = EntityId.validated('lane_user_${_nextEntitySeq++}');
        final road = RoadSpline.validated(
          id: id,
          controlPoints: points,
          widthMeters: widthMeters,
        );
        world.applyGraph(world.graph.putRoad(road));
        _emitStrokeChord(EdoInstrument.hyoshigi, points.last);
      case BuildTerraceTool(:final riseMeters, :final depthMeters):
        final id = EntityId.validated('terrace_user_${_nextEntitySeq++}');
        final maxGround = points
            .map((p) => world.sampleGroundHeight(p.x, p.z))
            .reduce(math.max);
        final topY = maxGround + riseMeters;
        final crest = [for (final p in points) p.withY(topY)];
        final terrace = TerraceCourse.validated(
          id: id,
          crestPoints: crest,
          topElevation: topY,
          riseMeters: riseMeters,
          depthMeters: depthMeters,
        );
        world.applyGraph(world.graph.putTerrace(terrace));
        _emitStrokeChord(EdoInstrument.bonsho, crest.last);
      case StampStructureTool() || InspectWatchTool():
        return false;
    }

    _syncLookImmediate();
    notifyListeners();
    return true;
  }

  void cancelActiveStroke() {
    if (_strokePoints.isEmpty) {
      return;
    }
    _strokePoints.clear();
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

  void _stampStructure({
    required StructureKind kind,
    required Vec3 rawWorldPoint,
    required double yawOffsetRadians,
  }) {
    final snapped = world.graph.snapStructure(
      kind: kind,
      rawPoint: rawWorldPoint,
      sampleGroundY: world.sampleGroundHeight,
      fallbackYawRadians: yawOffsetRadians,
    );
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
    _syncLookImmediate();
    notifyListeners();
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
