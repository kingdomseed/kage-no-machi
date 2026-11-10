import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable, listEquals, mapEquals;
import 'package:flutter_scene/scene.dart'
    show
        Material,
        PerspectiveCamera,
        PerspectiveProjection,
        PhysicallyBasedMaterial,
        Scene;
import 'package:vector_math/vector_math.dart'
    show Vector3, Vector4, degrees2Radians;

typedef GroundHeightSampler = double Function(double x, double z);

typedef ShukubaMaterialResolver = Material Function(ShukubaSurfaceRole role);

extension type const EntityId(String value) implements Object {
  factory validated(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(raw, 'raw', 'EntityId must not be empty.');
    }
    return EntityId(trimmed);
  }

  bool get isValid => value.trim().isNotEmpty;

  int compareTo(EntityId other) => value.compareTo(other.value);
}

/// Immutable 3D coordinate in left-handed world meters (`+X` right, `+Y` up,
/// `+Z` forward).
@immutable
class Vec3 {
  const new(this.x, this.y, this.z);

  factory fromVector3(Vector3 v) => Vec3(v.x, v.y, v.z);

  factory lerp(Vec3 a, Vec3 b, double t) =>
      Vec3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);

  static const Vec3 zero = Vec3(0, 0, 0);
  static const Vec3 up = Vec3(0, 1, 0);
  static const Vec3 forward = Vec3(0, 0, 1);

  final double x;
  final double y;
  final double z;

  double get length => math.sqrt(x * x + y * y + z * z);

  double get horizontalLength => math.sqrt(x * x + z * z);

  /// Heading around `+Y` matching `DecalNode.project` (`0` faces `+Z`,
  /// `pi / 2` faces `+X`).
  double get yawRadians => math.atan2(x, z);

  Vector3 toVector3() => Vector3(x, y, z);

  Vec3 withY(double nextY) => Vec3(x, nextY, z);

  Vec3 operator +(Vec3 other) => Vec3(x + other.x, y + other.y, z + other.z);

  Vec3 operator -(Vec3 other) => Vec3(x - other.x, y - other.y, z - other.z);

  Vec3 operator *(double scalar) => Vec3(x * scalar, y * scalar, z * scalar);

  double dot(Vec3 other) => x * other.x + y * other.y + z * other.z;

  double distanceTo(Vec3 other) => (this - other).length;

  double horizontalDistanceTo(Vec3 other) => (this - other).horizontalLength;

  Vec3 normalized() {
    final len = length;
    if (len <= 1e-9) {
      return forward;
    }
    return Vec3(x / len, y / len, z / len);
  }

  Vec3 normalizedHorizontal() {
    final len = horizontalLength;
    if (len <= 1e-9) {
      return forward;
    }
    return Vec3(x / len, 0, z / len);
  }

  /// Rotates around `+Y` by [radians], matching `Quaternion.axisAngle` on
  /// `(0, 1, 0)` and `DecalNode.project(rotation: radians)`.
  Vec3 rotateY(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Vec3(x * c + z * s, y, -x * s + z * c);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3($x, $y, $z)';
}

extension Vector3ShukubaX on Vector3 {
  Vec3 toVec3() => Vec3(x, y, z);
}

enum EdoInstrument { koto, shakuhachi, hyoshigi, bonsho }

enum AmbientLoopKind { riverMurmur, bambooWind, nightCrickets }

/// Five-note Edo scales rooted on concert `D4` (`293.665` Hz).
enum PentatonicScale {
  yo(
    label: 'Yo (D E G A B)',
    semitones: [0, 2, 5, 7, 9],
    pitchRatios: [
      1,
      1.122462048309373,
      1.3348398541700344,
      1.4983070768766815,
      1.681792830507429,
    ],
    frequenciesHz: [
      293.6647679174076,
      329.6275569128699,
      391.99543598174927,
      440,
      493.8833012561241,
    ],
  ),
  inSen(
    label: 'In-sen (D Eb G A C)',
    semitones: [0, 1, 5, 7, 10],
    pitchRatios: [
      1,
      1.0594630943592953,
      1.3348398541700344,
      1.4983070768766815,
      1.7817974362806785,
    ],
    frequenciesHz: [
      293.6647679174076,
      311.1269837220809,
      391.99543598174927,
      440,
      523.2511306011972,
    ],
  );

  new({
    required this.label,
    required this.semitones,
    required this.pitchRatios,
    required this.frequenciesHz,
  });

  /// Selects [yo] below `0.55` and [inSen] at or above `0.55`.
  factory forTimeOfDay(double timeOfDay) =>
      timeOfDay < nightThreshold ? yo : inSen;

  static const double rootD4Hz = 293.6647679174076;
  static const double nightThreshold = 0.55;

  final String label;
  final List<int> semitones;
  final List<double> pitchRatios;
  final List<double> frequenciesHz;

  double pitchRatioAt(int degree) {
    final count = pitchRatios.length;
    final mod = degree % count;
    final octave = (degree - mod) ~/ count;
    final clampedOctave = octave < -1
        ? -1
        : octave > 2
        ? 2
        : octave;
    final base = pitchRatios[mod];
    if (clampedOctave == 0) {
      return base;
    }
    return base * math.pow(2, clampedOctave).toDouble();
  }

  double frequencyHzAt(int degree) => rootD4Hz * pitchRatioAt(degree);
}

enum StructureKind {
  machiya,
  marketStall,
  yaguraTower,
  mapleCluster,
  bambooGrove;

  StructureSpec get spec => switch (this) {
    StructureKind.machiya => StructureSpec.machiya,
    StructureKind.marketStall => StructureSpec.marketStall,
    StructureKind.yaguraTower => StructureSpec.yaguraTower,
    StructureKind.mapleCluster => StructureSpec.mapleCluster,
    StructureKind.bambooGrove => StructureSpec.bambooGrove,
  };
}

@immutable
class EaveAnchor {
  const new({required this.localOffset, required this.localOutwardNormal});

  final Vec3 localOffset;
  final Vec3 localOutwardNormal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EaveAnchor &&
          other.localOffset == localOffset &&
          other.localOutwardNormal == localOutwardNormal;

  @override
  int get hashCode => Object.hash(localOffset, localOutwardNormal);
}

@immutable
class StructureSpec {
  const new({
    required this.kind,
    required this.footprintWidth,
    required this.footprintDepth,
    required this.height,
    required this.foundationSkirtDepth,
    required this.eaveAnchors,
    required this.instrument,
    this.sightconeRange = 0,
    this.sightconeHalfAngleRad = 0,
    this.snapsToRoadTangent = true,
    this.hasShojiWindows = false,
  });

  static const StructureSpec machiya = StructureSpec(
    kind: StructureKind.machiya,
    footprintWidth: 5.4,
    footprintDepth: 6.8,
    height: 5.6,
    foundationSkirtDepth: 1.4,
    eaveAnchors: [
      EaveAnchor(
        localOffset: Vec3(-2.3, 3.15, 3.45),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(2.3, 3.15, 3.45),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(0, 3.15, -3.45),
        localOutwardNormal: Vec3(0, 0, -1),
      ),
    ],
    instrument: EdoInstrument.koto,
    hasShojiWindows: true,
  );

  static const StructureSpec marketStall = StructureSpec(
    kind: StructureKind.marketStall,
    footprintWidth: 2.6,
    footprintDepth: 2.2,
    height: 2.7,
    foundationSkirtDepth: 0.6,
    eaveAnchors: [
      EaveAnchor(
        localOffset: Vec3(-1.15, 2.25, 1.15),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(1.15, 2.25, 1.15),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(-1.3, 2.25, 0),
        localOutwardNormal: Vec3(-1, 0, 0),
      ),
      EaveAnchor(
        localOffset: Vec3(1.3, 2.25, 0),
        localOutwardNormal: Vec3(1, 0, 0),
      ),
    ],
    instrument: EdoInstrument.hyoshigi,
  );

  static const StructureSpec yaguraTower = StructureSpec(
    kind: StructureKind.yaguraTower,
    footprintWidth: 3.8,
    footprintDepth: 3.8,
    height: 8.8,
    foundationSkirtDepth: 1.8,
    eaveAnchors: [
      EaveAnchor(
        localOffset: Vec3(0, 4.6, 1.95),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(0, 4.6, -1.95),
        localOutwardNormal: Vec3(0, 0, -1),
      ),
      EaveAnchor(
        localOffset: Vec3(-1.95, 4.6, 0),
        localOutwardNormal: Vec3(-1, 0, 0),
      ),
      EaveAnchor(
        localOffset: Vec3(1.95, 4.6, 0),
        localOutwardNormal: Vec3(1, 0, 0),
      ),
    ],
    instrument: EdoInstrument.bonsho,
    sightconeRange: 16,
    sightconeHalfAngleRad: 0.45,
    hasShojiWindows: true,
  );

  static const StructureSpec mapleCluster = StructureSpec(
    kind: StructureKind.mapleCluster,
    footprintWidth: 3.2,
    footprintDepth: 3.2,
    height: 5.8,
    foundationSkirtDepth: 0.5,
    eaveAnchors: [],
    instrument: EdoInstrument.koto,
    snapsToRoadTangent: false,
  );

  static const StructureSpec bambooGrove = StructureSpec(
    kind: StructureKind.bambooGrove,
    footprintWidth: 3.6,
    footprintDepth: 3.6,
    height: 7.2,
    foundationSkirtDepth: 0.5,
    eaveAnchors: [],
    instrument: EdoInstrument.shakuhachi,
    snapsToRoadTangent: false,
  );

  static const Map<StructureKind, StructureSpec> byKind = {
    StructureKind.machiya: machiya,
    StructureKind.marketStall: marketStall,
    StructureKind.yaguraTower: yaguraTower,
    StructureKind.mapleCluster: mapleCluster,
    StructureKind.bambooGrove: bambooGrove,
  };

  final StructureKind kind;
  final double footprintWidth;
  final double footprintDepth;
  final double height;
  final double foundationSkirtDepth;
  final List<EaveAnchor> eaveAnchors;
  final EdoInstrument instrument;
  final double sightconeRange;
  final double sightconeHalfAngleRad;
  final bool snapsToRoadTangent;
  final bool hasShojiWindows;

  bool get castsSightcone => sightconeRange > 0 && sightconeHalfAngleRad > 0;
}

enum MagistrateVisionState {
  hidden,
  watchtowerPreview,
  fullOverlay;

  double decalOpacity({required bool isWatchtower}) => switch (this) {
    MagistrateVisionState.hidden => 0,
    MagistrateVisionState.watchtowerPreview => isWatchtower ? 0.68 : 0,
    MagistrateVisionState.fullOverlay => 1,
  };
}

@immutable
sealed class PlacementTool {
  const new();

  EdoInstrument? get placementInstrument => switch (this) {
    DrawLaneTool() => EdoInstrument.hyoshigi,
    BuildTerraceTool() => EdoInstrument.bonsho,
    StampStructureTool(:final kind) => kind.spec.instrument,
    InspectWatchTool() => null,
  };

  MagistrateVisionState resolveVision(MagistrateVisionState explicit) {
    if (explicit == MagistrateVisionState.fullOverlay) {
      return MagistrateVisionState.fullOverlay;
    }
    return switch (this) {
      InspectWatchTool() => MagistrateVisionState.fullOverlay,
      StampStructureTool(kind: StructureKind.yaguraTower) =>
        MagistrateVisionState.watchtowerPreview,
      DrawLaneTool() || BuildTerraceTool() || StampStructureTool() => explicit,
    };
  }
}

final class DrawLaneTool extends PlacementTool {
  const new({this.widthMeters = 3.2})
    : assert(widthMeters > 0, 'widthMeters must be positive.');

  final double widthMeters;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawLaneTool && other.widthMeters == widthMeters;

  @override
  int get hashCode => widthMeters.hashCode;
}

final class BuildTerraceTool extends PlacementTool {
  const new({this.riseMeters = 1.6, this.depthMeters = 5.5})
    : assert(riseMeters > 0, 'riseMeters must be positive.'),
      assert(depthMeters > 0, 'depthMeters must be positive.');

  final double riseMeters;
  final double depthMeters;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuildTerraceTool &&
          other.riseMeters == riseMeters &&
          other.depthMeters == depthMeters;

  @override
  int get hashCode => Object.hash(riseMeters, depthMeters);
}

final class StampStructureTool extends PlacementTool {
  const new({required this.kind, this.yawOffsetRadians = 0});

  final StructureKind kind;
  final double yawOffsetRadians;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StampStructureTool &&
          other.kind == kind &&
          other.yawOffsetRadians == yawOffsetRadians;

  @override
  int get hashCode => Object.hash(kind, yawOffsetRadians);
}

final class InspectWatchTool extends PlacementTool {
  const new();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InspectWatchTool;

  @override
  int get hashCode => (InspectWatchTool).hashCode;
}

@immutable
class RoadSample {
  const new({
    required this.point,
    required this.tangent,
    required this.horizontalDistance,
    required this.arcMeters,
  });

  final Vec3 point;
  final Vec3 tangent;
  final double horizontalDistance;
  final double arcMeters;
}

/// Dirt lane polyline rendered at `depthLayer = 1` over ground terrain.
@immutable
class RoadSpline {
  const new({
    required this.id,
    required this.controlPoints,
    this.widthMeters = 3.2,
    this.isBridgeApproach = false,
  }) : assert(controlPoints.length >= 2, 'RoadSpline requires >= 2 points.'),
       assert(widthMeters > 0, 'widthMeters must be positive.');

  factory validated({
    required EntityId id,
    required Iterable<Vec3> controlPoints,
    double widthMeters = 3.2,
    bool isBridgeApproach = false,
  }) {
    if (!id.isValid) {
      throw ArgumentError.value(id, 'id', 'RoadSpline id must not be blank.');
    }
    final frozen = List<Vec3>.unmodifiable(controlPoints);
    if (frozen.length < 2) {
      throw ArgumentError.value(
        frozen.length,
        'controlPoints',
        'RoadSpline requires at least 2 control points.',
      );
    }
    if (widthMeters <= 0) {
      throw ArgumentError.value(
        widthMeters,
        'widthMeters',
        'widthMeters must be positive.',
      );
    }
    return RoadSpline(
      id: id,
      controlPoints: frozen,
      widthMeters: widthMeters,
      isBridgeApproach: isBridgeApproach,
    );
  }

  final EntityId id;
  final List<Vec3> controlPoints;
  final double widthMeters;
  final bool isBridgeApproach;

  RoadSample nearestSample(Vec3 query) {
    var bestPoint = controlPoints.first;
    var bestTangent = Vec3.forward;
    var bestDistSq = double.infinity;
    var bestArcMeters = 0.0;
    var cumulativeMeters = 0.0;
    for (var i = 0; i < controlPoints.length - 1; i++) {
      final a = controlPoints[i];
      final b = controlPoints[i + 1];
      final abX = b.x - a.x;
      final abZ = b.z - a.z;
      final segLenSq = abX * abX + abZ * abZ;
      final segLen = math.sqrt(segLenSq);
      final rawT = segLenSq <= 1e-12
          ? 0.0
          : ((query.x - a.x) * abX + (query.z - a.z) * abZ) / segLenSq;
      final t = rawT >= 1
          ? 1.0
          : rawT > 0
          ? rawT
          : 0.0;
      final proj = Vec3.lerp(a, b, t);
      final dx = query.x - proj.x;
      final dz = query.z - proj.z;
      final distSq = dx * dx + dz * dz;
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestPoint = proj;
        bestTangent = segLen <= 1e-9
            ? Vec3.forward
            : Vec3(abX / segLen, 0, abZ / segLen);
        bestArcMeters = cumulativeMeters + segLen * t;
      }
      cumulativeMeters += segLen;
    }
    return RoadSample(
      point: bestPoint,
      tangent: bestTangent,
      horizontalDistance: math.sqrt(bestDistSq),
      arcMeters: bestArcMeters,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadSpline &&
          other.id == id &&
          listEquals(other.controlPoints, controlPoints) &&
          other.widthMeters == widthMeters &&
          other.isBridgeApproach == isBridgeApproach;

  @override
  int get hashCode => Object.hash(
    id,
    Object.hashAll(controlPoints),
    widthMeters,
    isBridgeApproach,
  );
}

/// Looking along [crestPoints] from start to end, the level platform extends
/// [depthMeters] to the right (`(tz, 0, -tx)`) at [topElevation], and the
/// battered *ishigaki* wall drops [riseMeters] to the left.
@immutable
class TerraceCourse {
  const new({
    required this.id,
    required this.crestPoints,
    required this.topElevation,
    this.riseMeters = 1.6,
    this.depthMeters = 5.5,
  }) : assert(crestPoints.length >= 2, 'TerraceCourse requires >= 2 points.'),
       assert(riseMeters > 0, 'riseMeters must be positive.'),
       assert(depthMeters > 0, 'depthMeters must be positive.');

  factory validated({
    required EntityId id,
    required Iterable<Vec3> crestPoints,
    required double topElevation,
    double riseMeters = 1.6,
    double depthMeters = 5.5,
  }) {
    if (!id.isValid) {
      throw ArgumentError.value(id, 'id', 'TerraceCourse id must be valid.');
    }
    final frozen = List<Vec3>.unmodifiable(crestPoints);
    if (frozen.length < 2) {
      throw ArgumentError.value(
        frozen.length,
        'crestPoints',
        'TerraceCourse requires at least 2 crest points.',
      );
    }
    if (riseMeters <= 0 || depthMeters <= 0) {
      throw ArgumentError('riseMeters and depthMeters must be positive.');
    }
    return TerraceCourse(
      id: id,
      crestPoints: frozen,
      topElevation: topElevation,
      riseMeters: riseMeters,
      depthMeters: depthMeters,
    );
  }

  final EntityId id;
  final List<Vec3> crestPoints;
  final double topElevation;
  final double riseMeters;
  final double depthMeters;

  double? samplePlatformElevation(Vec3 query) {
    for (var i = 0; i < crestPoints.length - 1; i++) {
      final a = crestPoints[i];
      final b = crestPoints[i + 1];
      final abX = b.x - a.x;
      final abZ = b.z - a.z;
      final segLen = math.sqrt(abX * abX + abZ * abZ);
      if (segLen <= 1e-9) {
        continue;
      }
      final tx = abX / segLen;
      final tz = abZ / segLen;
      final relX = query.x - a.x;
      final relZ = query.z - a.z;
      final along = relX * tx + relZ * tz;
      if (along < 0 || along > segLen) {
        continue;
      }
      final inward = relX * tz - relZ * tx;
      if (inward >= 0 && inward <= depthMeters) {
        return topElevation;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerraceCourse &&
          other.id == id &&
          listEquals(other.crestPoints, crestPoints) &&
          other.topElevation == topElevation &&
          other.riseMeters == riseMeters &&
          other.depthMeters == depthMeters;

  @override
  int get hashCode => Object.hash(
    id,
    Object.hashAll(crestPoints),
    topElevation,
    riseMeters,
    depthMeters,
  );
}

@immutable
class EaveEndpoint {
  const new({
    required this.structureId,
    required this.anchorIndex,
    required this.worldPosition,
    required this.worldNormal,
  });

  final EntityId structureId;
  final int anchorIndex;
  final Vec3 worldPosition;
  final Vec3 worldNormal;

  int compareTo(EaveEndpoint other) {
    final byId = structureId.compareTo(other.structureId);
    if (byId != 0) {
      return byId;
    }
    return anchorIndex.compareTo(other.anchorIndex);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EaveEndpoint &&
          other.structureId == structureId &&
          other.anchorIndex == anchorIndex &&
          other.worldPosition == worldPosition &&
          other.worldNormal == worldNormal;

  @override
  int get hashCode =>
      Object.hash(structureId, anchorIndex, worldPosition, worldNormal);
}

@immutable
class WatchSightcone {
  const new({
    required this.sourceId,
    required this.origin,
    required this.yawRadians,
    required this.rangeMeters,
    required this.halfAngleRadians,
    double alertLevel = 0,
    this.isWatchtower = false,
  }) : alertLevel = alertLevel >= 1
           ? 1
           : alertLevel > 0
           ? alertLevel
           : 0,
       assert(rangeMeters > 0, 'rangeMeters must be positive.'),
       assert(halfAngleRadians > 0, 'halfAngleRadians must be positive.');

  final EntityId sourceId;
  final Vec3 origin;
  final double yawRadians;
  final double rangeMeters;
  final double halfAngleRadians;

  /// Intrusion blend in `[0, 1]` (`0` jade calm, `1` vermilion alert).
  final double alertLevel;
  final bool isWatchtower;

  Vec3 get forward => Vec3(math.sin(yawRadians), 0, math.cos(yawRadians));

  Vec3 get decalProjectionCenter => origin + forward * (rangeMeters * 0.5);

  /// Square `DecalNode.project(size: ...)` side length padded so wide cones
  /// and anti-aliased rims never clip the `[-0.5, 0.5]` decal box.
  double get decalBoxSize =>
      math.max(rangeMeters, 2 * rangeMeters * math.sin(halfAngleRadians)) * 1.1;

  bool containsPoint(Vec3 point, {double maxVerticalDelta = 4}) {
    if ((point.y - origin.y).abs() > maxVerticalDelta) {
      return false;
    }
    final dx = point.x - origin.x;
    final dz = point.z - origin.z;
    final dist = math.sqrt(dx * dx + dz * dz);
    if (dist <= 1e-6) {
      return true;
    }
    if (dist > rangeMeters) {
      return false;
    }
    final dir = Vec3(dx / dist, 0, dz / dist);
    return forward.dot(dir) >= math.cos(halfAngleRadians);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchSightcone &&
          other.sourceId == sourceId &&
          other.origin == origin &&
          other.yawRadians == yawRadians &&
          other.rangeMeters == rangeMeters &&
          other.halfAngleRadians == halfAngleRadians &&
          other.alertLevel == alertLevel &&
          other.isWatchtower == isWatchtower;

  @override
  int get hashCode => Object.hash(
    sourceId,
    origin,
    yawRadians,
    rangeMeters,
    halfAngleRadians,
    alertLevel,
    isWatchtower,
  );
}

@immutable
class PlacedStructure {
  const new({
    required this.id,
    required this.kind,
    required this.position,
    this.yawRadians = 0,
  });

  final EntityId id;
  final StructureKind kind;
  final Vec3 position;
  final double yawRadians;

  StructureSpec get spec => kind.spec;

  Vec3 get forward => Vec3(math.sin(yawRadians), 0, math.cos(yawRadians));

  List<EaveEndpoint> resolveEaveEndpoints() {
    final anchors = spec.eaveAnchors;
    return [
      for (var i = 0; i < anchors.length; i++)
        EaveEndpoint(
          structureId: id,
          anchorIndex: i,
          worldPosition: position + anchors[i].localOffset.rotateY(yawRadians),
          worldNormal: anchors[i].localOutwardNormal
              .rotateY(yawRadians)
              .normalizedHorizontal(),
        ),
    ];
  }

  WatchSightcone? toStructuralSightcone({double alertLevel = 0}) {
    if (!spec.castsSightcone) {
      return null;
    }
    return WatchSightcone(
      sourceId: id,
      origin: position,
      yawRadians: yawRadians,
      rangeMeters: spec.sightconeRange,
      halfAngleRadians: spec.sightconeHalfAngleRad,
      alertLevel: alertLevel,
      isWatchtower: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlacedStructure &&
          other.id == id &&
          other.kind == kind &&
          other.position == position &&
          other.yawRadians == yawRadians;

  @override
  int get hashCode => Object.hash(id, kind, position, yawRadians);
}

/// Deterministic catenary lantern cord spanning two mutually facing eaves
/// within [maxSpanMeters] (`6.5` m).
@immutable
class LanternSpan {
  const new({
    required this.id,
    required this.endpointA,
    required this.endpointB,
    required this.lengthMeters,
    required this.sagMeters,
  });

  static const double maxSpanMeters = 6.5;
  static const double minSpanMeters = 0.9;
  static const double minFacingCos = 0.5;
  static const double maxHeightDeltaMeters = 2.2;
  static const double sagRatio = 0.085;

  final EntityId id;
  final EaveEndpoint endpointA;
  final EaveEndpoint endpointB;
  final double lengthMeters;
  final double sagMeters;

  Vec3 get startWorld => endpointA.worldPosition;

  Vec3 get endWorld => endpointB.worldPosition;

  Vec3 get midpoint => sampleCatenary(0.5);

  int get lanternCount => math.max(2, (lengthMeters / 1.15).floor());

  Vec3 sampleCatenary(double t) {
    final clamped = t >= 1
        ? 1.0
        : t > 0
        ? t
        : 0.0;
    final chord = Vec3.lerp(startWorld, endWorld, clamped);
    final drop = 4 * sagMeters * clamped * (1 - clamped);
    return Vec3(chord.x, chord.y - drop, chord.z);
  }

  List<Vec3> lanternHangPoints() {
    final count = lanternCount;
    return [
      for (var i = 0; i < count; i++) sampleCatenary((i + 1) / (count + 1)),
    ];
  }

  static List<LanternSpan> deriveAll(Iterable<PlacedStructure> structures) {
    final sortedStructures = structures.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final endpoints = <EaveEndpoint>[
      for (final structure in sortedStructures)
        ...structure.resolveEaveEndpoints(),
    ];
    final candidates = <_SpanCandidate>[];
    for (var i = 0; i < endpoints.length; i++) {
      for (var j = i + 1; j < endpoints.length; j++) {
        final rawA = endpoints[i];
        final rawB = endpoints[j];
        if (rawA.structureId == rawB.structureId) {
          continue;
        }
        final ordered = rawA.compareTo(rawB) <= 0 ? (rawA, rawB) : (rawB, rawA);
        final a = ordered.$1;
        final b = ordered.$2;
        final delta = b.worldPosition - a.worldPosition;
        final dist = delta.length;
        final horizDist = delta.horizontalLength;
        if (dist < minSpanMeters ||
            dist > maxSpanMeters ||
            horizDist < 0.8 ||
            delta.y.abs() > maxHeightDeltaMeters) {
          continue;
        }
        final dirAb = Vec3(delta.x / horizDist, 0, delta.z / horizDist);
        final cosA = a.worldNormal.dot(dirAb);
        final cosB = b.worldNormal.dot(dirAb * -1);
        if (cosA < minFacingCos || cosB < minFacingCos) {
          continue;
        }
        final alignment = (cosA + cosB) * 0.5;
        candidates.add(
          _SpanCandidate(
            endpointA: a,
            endpointB: b,
            lengthMeters: dist,
            score: dist / alignment,
          ),
        );
      }
    }
    candidates.sort();
    final claimedHooks = <(EntityId, int)>{};
    final spans = <LanternSpan>[];
    for (final candidate in candidates) {
      final keyA = (
        candidate.endpointA.structureId,
        candidate.endpointA.anchorIndex,
      );
      final keyB = (
        candidate.endpointB.structureId,
        candidate.endpointB.anchorIndex,
      );
      if (claimedHooks.contains(keyA) || claimedHooks.contains(keyB)) {
        continue;
      }
      claimedHooks
        ..add(keyA)
        ..add(keyB);
      final rawSag = candidate.lengthMeters * sagRatio;
      final sag = math.min(0.55, math.max(0.12, rawSag));
      final spanId = EntityId(
        'span_${keyA.$1.value}_${keyA.$2}'
        '__${keyB.$1.value}_${keyB.$2}',
      );
      spans.add(
        LanternSpan(
          id: spanId,
          endpointA: candidate.endpointA,
          endpointB: candidate.endpointB,
          lengthMeters: candidate.lengthMeters,
          sagMeters: sag,
        ),
      );
    }
    spans.sort((a, b) => a.id.compareTo(b.id));
    return spans;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanternSpan &&
          other.id == id &&
          other.endpointA == endpointA &&
          other.endpointB == endpointB &&
          other.lengthMeters == lengthMeters &&
          other.sagMeters == sagMeters;

  @override
  int get hashCode =>
      Object.hash(id, endpointA, endpointB, lengthMeters, sagMeters);
}

class _SpanCandidate implements Comparable<_SpanCandidate> {
  const new({
    required this.endpointA,
    required this.endpointB,
    required this.lengthMeters,
    required this.score,
  });

  final EaveEndpoint endpointA;
  final EaveEndpoint endpointB;
  final double lengthMeters;
  final double score;

  @override
  int compareTo(_SpanCandidate other) {
    final byScore = score.compareTo(other.score);
    if (byScore != 0) {
      return byScore;
    }
    final byA = endpointA.compareTo(other.endpointA);
    if (byA != 0) {
      return byA;
    }
    return endpointB.compareTo(other.endpointB);
  }
}

@immutable
class SnappedPlacement {
  const new({
    required this.position,
    required this.yawRadians,
    required this.scaleDegree,
    this.snappedRoadId,
  });

  final Vec3 position;
  final double yawRadians;
  final int scaleDegree;
  final EntityId? snappedRoadId;
}

@immutable
class ShukubaGraph {
  new({
    Iterable<RoadSpline> roads = const [],
    Iterable<TerraceCourse> terraces = const [],
    Iterable<PlacedStructure> structures = const [],
  }) : this._normalized(
         roads: _freezeRoads(roads),
         terraces: _freezeTerraces(terraces),
         structures: _freezeStructures(structures),
       );

  new _normalized({
    required this.roads,
    required this.terraces,
    required this.structures,
  }) : lanternSpans = List<LanternSpan>.unmodifiable(
         LanternSpan.deriveAll(structures.values),
       );

  static final ShukubaGraph empty = ShukubaGraph();

  final List<RoadSpline> roads;
  final List<TerraceCourse> terraces;
  final Map<EntityId, PlacedStructure> structures;
  final List<LanternSpan> lanternSpans;

  List<WatchSightcone> get structuralSightcones => [
    for (final structure in structures.values)
      ?structure.toStructuralSightcone(),
  ];

  List<Vec3> get catenaryLightOrigins => [
    for (final span in lanternSpans) span.midpoint,
  ];

  ShukubaGraph putRoad(RoadSpline road) => ShukubaGraph._normalized(
    roads: _freezeRoads([
      for (final existing in roads)
        if (existing.id != road.id) existing,
      road,
    ]),
    terraces: terraces,
    structures: structures,
  );

  ShukubaGraph putTerrace(TerraceCourse terrace) => ShukubaGraph._normalized(
    roads: roads,
    terraces: _freezeTerraces([
      for (final existing in terraces)
        if (existing.id != terrace.id) existing,
      terrace,
    ]),
    structures: structures,
  );

  ShukubaGraph putStructure(PlacedStructure structure) {
    final existing = structures[structure.id];
    if (existing == structure) {
      return this;
    }
    return ShukubaGraph._normalized(
      roads: roads,
      terraces: terraces,
      structures: _freezeStructures([
        for (final entry in structures.values)
          if (entry.id != structure.id) entry,
        structure,
      ]),
    );
  }

  ShukubaGraph removeEntity(EntityId id) {
    final hasRoad = roads.any((r) => r.id == id);
    final hasTerrace = terraces.any((t) => t.id == id);
    final hasStructure = structures.containsKey(id);
    if (!hasRoad && !hasTerrace && !hasStructure) {
      return this;
    }
    return ShukubaGraph._normalized(
      roads: hasRoad
          ? List<RoadSpline>.unmodifiable(roads.where((r) => r.id != id))
          : roads,
      terraces: hasTerrace
          ? List<TerraceCourse>.unmodifiable(terraces.where((t) => t.id != id))
          : terraces,
      structures: hasStructure
          ? _freezeStructures(structures.values.where((s) => s.id != id))
          : structures,
    );
  }

  SnappedPlacement snapStructure({
    required StructureKind kind,
    required Vec3 rawPoint,
    required GroundHeightSampler sampleGroundY,
    double fallbackYawRadians = 0,
    double snapRadiusMeters = 7.5,
  }) {
    final spec = kind.spec;
    var x = rawPoint.x;
    var z = rawPoint.z;
    var yaw = fallbackYawRadians;
    EntityId? roadId;
    var arcMeters = 0.0;

    if (roads.isNotEmpty) {
      RoadSpline? nearestRoad;
      RoadSample? nearestSample;
      for (final road in roads) {
        final sample = road.nearestSample(rawPoint);
        if (nearestSample == null ||
            sample.horizontalDistance < nearestSample.horizontalDistance) {
          nearestRoad = road;
          nearestSample = sample;
        }
      }
      if (nearestRoad != null &&
          nearestSample != null &&
          nearestSample.horizontalDistance <= snapRadiusMeters) {
        roadId = nearestRoad.id;
        arcMeters = nearestSample.arcMeters;
        final minSetback =
            nearestRoad.widthMeters * 0.5 + spec.footprintDepth * 0.5 + 0.35;
        final toPlotX = rawPoint.x - nearestSample.point.x;
        final toPlotZ = rawPoint.z - nearestSample.point.z;
        final toPlotLen = math.sqrt(toPlotX * toPlotX + toPlotZ * toPlotZ);
        final normalX = toPlotLen > 1e-6
            ? toPlotX / toPlotLen
            : nearestSample.tangent.z;
        final normalZ = toPlotLen > 1e-6
            ? toPlotZ / toPlotLen
            : -nearestSample.tangent.x;
        if (spec.snapsToRoadTangent) {
          if (toPlotLen < minSetback) {
            x = nearestSample.point.x + normalX * minSetback;
            z = nearestSample.point.z + normalZ * minSetback;
          }
          yaw = math.atan2(-normalX, -normalZ);
        }
      }
    }

    final probe = Vec3(x, rawPoint.y, z);
    var groundY = sampleGroundY(x, z);
    for (final terrace in terraces) {
      final platformY = terrace.samplePlatformElevation(probe);
      if (platformY != null && platformY > groundY) {
        groundY = platformY;
      }
    }

    final degreeSeed = arcMeters > 0 ? arcMeters : (x.abs() + z.abs()) * 0.5;
    final degree = (degreeSeed / 2.4).floor() + (groundY / 1.5).round();
    return SnappedPlacement(
      position: Vec3(x, groundY, z),
      yawRadians: yaw,
      scaleDegree: degree,
      snappedRoadId: roadId,
    );
  }

  static List<RoadSpline> _freezeRoads(Iterable<RoadSpline> items) {
    final byId = <EntityId, RoadSpline>{
      for (final road in items) road.id: road,
    };
    final sorted = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return List<RoadSpline>.unmodifiable(sorted);
  }

  static List<TerraceCourse> _freezeTerraces(Iterable<TerraceCourse> items) {
    final byId = <EntityId, TerraceCourse>{
      for (final terrace in items) terrace.id: terrace,
    };
    final sorted = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return List<TerraceCourse>.unmodifiable(sorted);
  }

  static Map<EntityId, PlacedStructure> _freezeStructures(
    Iterable<PlacedStructure> items,
  ) {
    final deduped = <EntityId, PlacedStructure>{
      for (final structure in items) structure.id: structure,
    };
    final entries = deduped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Map<EntityId, PlacedStructure>.unmodifiable({
      for (final entry in entries) entry.key: entry.value,
    });
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShukubaGraph &&
          listEquals(other.roads, roads) &&
          listEquals(other.terraces, terraces) &&
          mapEquals(other.structures, structures);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(roads),
    Object.hashAll(terraces),
    Object.hashAll(structures.values),
  );
}

/// Clamped `[0, 1]` Golden Dusk (`0`) to Blue Hour Night (`1`) rig. Inputs
/// outside `[0, 1]` or `NaN` clamp safely into `[0, 1]`.
@immutable
class TimeOfDayRig {
  const new(double rawValue)
    : value = rawValue >= 1
          ? 1
          : rawValue > 0
          ? rawValue
          : 0;

  static const double goldenDuskScalar = 0.15;
  static const double scaleSwitchScalar = PentatonicScale.nightThreshold;
  static const double blueHourNightScalar = 0.9;

  static const TimeOfDayRig goldenDusk = TimeOfDayRig(goldenDuskScalar);
  static const TimeOfDayRig blueHourNight = TimeOfDayRig(blueHourNightScalar);

  final double value;

  double get nightFactor => value * value * (3 - 2 * value);

  bool get isMoonlit => value >= scaleSwitchScalar;

  PentatonicScale get scale => PentatonicScale.forTimeOfDay(value);

  /// Unit ray travel direction from sun or moon toward the ground, matching
  /// `DirectionalLight.direction`.
  Vec3 get celestialDirection {
    if (!isMoonlit) {
      final duskT = value / scaleSwitchScalar;
      final elevation = (24 - 11 * duskT) * degrees2Radians;
      final azimuth = (-58 - 18 * duskT) * degrees2Radians;
      final horiz = math.cos(elevation);
      return Vec3(
        math.sin(azimuth) * horiz,
        -math.sin(elevation),
        math.cos(azimuth) * horiz,
      ).normalized();
    }
    final moonT = (value - scaleSwitchScalar) / (1 - scaleSwitchScalar);
    final elevation = (30 + 14 * moonT) * degrees2Radians;
    final azimuth = (36 + 16 * moonT) * degrees2Radians;
    final horiz = math.cos(elevation);
    return Vec3(
      math.sin(azimuth) * horiz,
      -math.sin(elevation),
      math.cos(azimuth) * horiz,
    ).normalized();
  }

  Vec3 get celestialLinearRgb => Vec3.lerp(
    const Vec3(1, 0.72, 0.44),
    const Vec3(0.46, 0.64, 0.96),
    nightFactor,
  );

  Color get celestialHudColor =>
      isMoonlit ? const Color(0xFF8AB4F8) : const Color(0xFFFFB86C);

  double get celestialIntensity => 3.35 - 2.4 * nightFactor;

  double get shojiEmissiveGain => 0.12 + 2.55 * nightFactor;

  double get lanternEmissiveGain => 0.35 + 3.1 * nightFactor;

  double get lanternPointLightIntensity => 0.3 + 11.2 * nightFactor;

  double get lanternPointLightRange => 6.5 + 4.5 * nightFactor;

  double get riverMurmurGain => 0.44 - 0.08 * nightFactor;

  double get bambooWindGain => 0.34 - 0.06 * nightFactor;

  double get nightCricketGain => math.max(0, (value - 0.38) / 0.62) * 0.42;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TimeOfDayRig && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

@immutable
class CameraPreset {
  const new({
    required this.id,
    required this.label,
    required this.eye,
    required this.target,
    required this.timeOfDay,
    this.visionState = MagistrateVisionState.hidden,
    this.verticalFovDegrees = defaultVerticalFovDegrees,
    this.nearMeters = 4,
    this.farMeters = 240,
  });

  static const double defaultVerticalFovDegrees = 25;
  static const double defaultPitchDegrees = 38;

  static const CameraPreset duskOverview = CameraPreset(
    id: 'dusk_overview',
    label: 'Golden Dusk Crossing',
    eye: Vec3(-35, 38.5, -35),
    target: Vec3(0, 1.4, 0),
    timeOfDay: TimeOfDayRig.goldenDusk,
  );

  static const CameraPreset nightMarket = CameraPreset(
    id: 'night_market',
    label: 'Blue Hour Lantern Market',
    eye: Vec3(30.5, 33.5, -31.5),
    target: Vec3(1.5, 1.8, 0.5),
    timeOfDay: TimeOfDayRig.blueHourNight,
  );

  static const CameraPreset magistrateWatchtower = CameraPreset(
    id: 'magistrate_watchtower',
    label: "Magistrate's Eye Watch",
    eye: Vec3(-29.5, 36, 32.5),
    target: Vec3(1.5, 2, -0.5),
    timeOfDay: TimeOfDayRig.blueHourNight,
    visionState: MagistrateVisionState.fullOverlay,
  );

  static const CameraPreset motionOffset = CameraPreset(
    id: 'motion_offset',
    label: 'Telephoto Motion Probe',
    eye: Vec3(-24.2, 36, 36.2),
    target: Vec3(6.8, 2, 3.2),
    timeOfDay: TimeOfDayRig.blueHourNight,
    visionState: MagistrateVisionState.fullOverlay,
  );

  static const List<CameraPreset> verificationPresets = [
    duskOverview,
    nightMarket,
    magistrateWatchtower,
    motionOffset,
  ];

  final String id;
  final String label;
  final Vec3 eye;
  final Vec3 target;
  final TimeOfDayRig timeOfDay;
  final MagistrateVisionState visionState;
  final double verticalFovDegrees;
  final double nearMeters;
  final double farMeters;

  PerspectiveCamera toPerspectiveCamera() => PerspectiveCamera(
    fovRadiansY: verticalFovDegrees * degrees2Radians,
    position: eye.toVector3(),
    target: target.toVector3(),
    fovNear: nearMeters,
    fovFar: farMeters,
  );

  PerspectiveProjection toPerspectiveProjection() => PerspectiveProjection(
    fovRadiansY: verticalFovDegrees * degrees2Radians,
    near: nearMeters,
    far: farMeters,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraPreset &&
          other.id == id &&
          other.label == label &&
          other.eye == eye &&
          other.target == target &&
          other.timeOfDay == timeOfDay &&
          other.visionState == visionState &&
          other.verticalFovDegrees == verticalFovDegrees &&
          other.nearMeters == nearMeters &&
          other.farMeters == farMeters;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    eye,
    target,
    timeOfDay,
    visionState,
    verticalFovDegrees,
    nearMeters,
    farMeters,
  );
}

/// Encodes `depthLayer` (`-1` ground, `0` kit, `1` lane overlay) so headless
/// PBR fallbacks and compiled `.fmat` materials share identical depth ordering.
enum ShukubaSurfaceRole {
  packedEarth(
    depthLayer: -1,
    defaultRoughness: 0.94,
    previewColor: Color(0xFF5C4E3E),
  ),
  ishigakiStone(
    depthLayer: 0,
    defaultRoughness: 0.88,
    previewColor: Color(0xFF6B6E72),
  ),
  laneOverlay(
    depthLayer: 1,
    defaultRoughness: 0.92,
    previewColor: Color(0xFF7D6850),
  ),
  plasterWall(
    depthLayer: 0,
    defaultRoughness: 0.85,
    previewColor: Color(0xFFD8CEBE),
  ),
  charredTimber(
    depthLayer: 0,
    defaultRoughness: 0.82,
    previewColor: Color(0xFF3A2D25),
  ),
  kawaraTile(
    depthLayer: 0,
    defaultRoughness: 0.64,
    previewColor: Color(0xFF28303B),
  ),
  fabricAwning(
    depthLayer: 0,
    defaultRoughness: 0.86,
    previewColor: Color(0xFF9E3F2C),
  ),
  shojiScreen(
    depthLayer: 0,
    defaultRoughness: 0.78,
    previewColor: Color(0xFFFFCA7A),
  ),
  chochinLantern(
    depthLayer: 0,
    defaultRoughness: 0.74,
    previewColor: Color(0xFFFF9E44),
  ),
  mapleCanopy(
    depthLayer: 0,
    defaultRoughness: 0.84,
    previewColor: Color(0xFFC84628),
  ),
  bambooCanopy(
    depthLayer: 0,
    defaultRoughness: 0.8,
    previewColor: Color(0xFF4F7942),
  ),
  riverWater(
    depthLayer: 0,
    defaultRoughness: 0.14,
    previewColor: Color(0xFF285864),
  );

  new({
    required this.depthLayer,
    required this.defaultRoughness,
    required this.previewColor,
  });

  final int depthLayer;
  final double defaultRoughness;
  final Color previewColor;

  Vector4 toLinearRgba() =>
      Vector4(previewColor.r, previewColor.g, previewColor.b, previewColor.a);
}

Material defaultShukubaMaterial(ShukubaSurfaceRole role) =>
    PhysicallyBasedMaterial()
      ..baseColorFactor = role.toLinearRgba()
      ..metallicFactor = 0
      ..roughnessFactor = role.defaultRoughness
      ..depthLayer = role.depthLayer;

enum StreetAgentRole { townsfolk, lanternWatchman, nightSmuggler }

@immutable
class StreetAgentSnapshot {
  const new({
    required this.id,
    required this.role,
    required this.position,
    required this.yawRadians,
    this.carriesLantern = false,
  });

  final EntityId id;
  final StreetAgentRole role;
  final Vec3 position;
  final double yawRadians;
  final bool carriesLantern;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreetAgentSnapshot &&
          other.id == id &&
          other.role == role &&
          other.position == position &&
          other.yawRadians == yawRadians &&
          other.carriesLantern == carriesLantern;

  @override
  int get hashCode =>
      Object.hash(id, role, position, yawRadians, carriesLantern);
}

@immutable
class PlacementNoteEvent {
  const new({
    required this.instrument,
    required this.scale,
    required this.scaleDegree,
    required this.position,
    this.volume = 0.65,
  });

  factory fromSnap({
    required EdoInstrument instrument,
    required TimeOfDayRig rig,
    required SnappedPlacement snapped,
    double volume = 0.65,
  }) => PlacementNoteEvent(
    instrument: instrument,
    scale: rig.scale,
    scaleDegree: snapped.scaleDegree,
    position: snapped.position,
    volume: volume,
  );

  final EdoInstrument instrument;
  final PentatonicScale scale;
  final int scaleDegree;
  final Vec3 position;
  final double volume;

  double get pitchRatio => scale.pitchRatioAt(scaleDegree);

  double get frequencyHz => scale.frequencyHzAt(scaleDegree);
}

abstract interface class ShukubaLookDriver {
  Future<void> attach(Scene scene);

  Material materialFor(ShukubaSurfaceRole role);

  void syncFrame({
    required TimeOfDayRig rig,
    required MagistrateVisionState vision,
    required List<WatchSightcone> sightcones,
    required List<Vec3> lanternOrigins,
    required double elapsedSeconds,
  });

  void dispose();
}

abstract interface class ShukubaWorldDriver {
  ShukubaGraph get graph;

  List<WatchSightcone> get activeSightcones;

  List<Vec3> get activeLanternOrigins;

  Map<AmbientLoopKind, Vec3> get ambientLoopAnchors;

  List<StreetAgentSnapshot> get agents;

  Future<void> attach(
    Scene scene, {
    ShukubaMaterialResolver resolveMaterial = defaultShukubaMaterial,
    ShukubaGraph? initialGraph,
  });

  void applyGraph(ShukubaGraph nextGraph);

  void step(double dtSeconds, {required TimeOfDayRig rig});

  double sampleGroundHeight(double x, double z);

  void dispose();
}

abstract interface class ShukubaAudioDriver {
  Future<void> attach(
    Scene scene, {
    Map<AmbientLoopKind, Vec3> loopAnchors = const {},
  });

  void syncAtmosphere({
    required TimeOfDayRig rig,
    Map<AmbientLoopKind, Vec3>? loopAnchors,
  });

  void playPlacementNote(PlacementNoteEvent event);

  void dispose();
}
