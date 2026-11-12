import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';

export 'package:kage_no_machi/shukuba/model/shukuba_types.dart'
    show BootStageId;

enum ShukubaShellMode { titleMenu, loadingValley, inValley, pauseMenu }

@immutable
class BootStageTiming {
  const new({required this.stage, required this.durationMs});

  final BootStageId stage;
  final double durationMs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BootStageTiming &&
          other.stage == stage &&
          other.durationMs == durationMs;

  @override
  int get hashCode => Object.hash(stage, durationMs);
}

@immutable
class BootReport {
  new({required List<BootStageTiming> stages, required this.totalMs})
    : stages = List<BootStageTiming>.unmodifiable(stages);

  final List<BootStageTiming> stages;
  final double totalMs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BootReport &&
          other.totalMs == totalMs &&
          _listEquals(other.stages, stages);

  @override
  int get hashCode => Object.hash(totalMs, Object.hashAll(stages));

  static bool _listEquals(List<BootStageTiming> a, List<BootStageTiming> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

@immutable
class FrameTelemetrySnapshot {
  const new({
    required this.uiMs,
    required this.rasterMs,
    required this.fps,
    required this.structureCount,
    required this.lanternSpanCount,
    this.bootReport,
  });

  static const zero = FrameTelemetrySnapshot(
    uiMs: 0,
    rasterMs: 0,
    fps: 0,
    structureCount: 0,
    lanternSpanCount: 0,
  );

  final double uiMs;
  final double rasterMs;
  final double fps;
  final int structureCount;
  final int lanternSpanCount;
  final BootReport? bootReport;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrameTelemetrySnapshot &&
          other.uiMs == uiMs &&
          other.rasterMs == rasterMs &&
          other.fps == fps &&
          other.structureCount == structureCount &&
          other.lanternSpanCount == lanternSpanCount &&
          other.bootReport == bootReport;

  @override
  int get hashCode => Object.hash(
    uiMs,
    rasterMs,
    fps,
    structureCount,
    lanternSpanCount,
    bootReport,
  );
}

class RollingFrameTimer {
  new({this.windowSize = 30})
    : assert(windowSize > 0, 'windowSize must be positive.');

  final int windowSize;
  final List<double> _buildTimes = [];
  final List<double> _rasterTimes = [];

  int get sampleCount => _buildTimes.length;

  void ingestDurations({required double buildMs, required double rasterMs}) {
    final cleanBuild = buildMs.isNaN || buildMs.isInfinite || buildMs < 0
        ? 0.0
        : buildMs;
    final cleanRaster = rasterMs.isNaN || rasterMs.isInfinite || rasterMs < 0
        ? 0.0
        : rasterMs;
    _buildTimes.add(cleanBuild);
    _rasterTimes.add(cleanRaster);
    if (_buildTimes.length > windowSize) {
      _buildTimes.removeAt(0);
      _rasterTimes.removeAt(0);
    }
  }

  void ingestTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      ingestDurations(
        buildMs: timing.buildDuration.inMicroseconds / 1000,
        rasterMs: timing.rasterDuration.inMicroseconds / 1000,
      );
    }
  }

  void ingestRecords(
    Iterable<({Duration buildDuration, Duration rasterDuration})> records,
  ) {
    for (final record in records) {
      ingestDurations(
        buildMs: record.buildDuration.inMicroseconds / 1000,
        rasterMs: record.rasterDuration.inMicroseconds / 1000,
      );
    }
  }

  double get uiMs {
    if (_buildTimes.isEmpty) return 0;
    final sum = _buildTimes.fold<double>(0, (acc, v) => acc + v);
    return sum / _buildTimes.length;
  }

  double get rasterMs {
    if (_rasterTimes.isEmpty) return 0;
    final sum = _rasterTimes.fold<double>(0, (acc, v) => acc + v);
    return sum / _rasterTimes.length;
  }

  double get fps {
    final avgUi = uiMs;
    final avgRaster = rasterMs;
    final maxFrameMs = math.max(avgUi, avgRaster);
    if (maxFrameMs <= 0) return 60;
    return math.min(120, 1000 / math.max(16.6667, maxFrameMs));
  }

  void reset() {
    _buildTimes.clear();
    _rasterTimes.clear();
  }
}
