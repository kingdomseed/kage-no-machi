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

enum RoofCraft { irimoyaKawara, ishiOkiYane, kayabukiThatch }

enum BootStageId {
  lookAndShaders(
    'Look & Shaders',
    'Compiling Gouache Lit and Sumi Ink shaders',
  ),
  audioSynthesis(
    'Audio Synthesis',
    'Synthesizing procedural WAV sound effects',
  ),
  valleyTerrain(
    'Valley Terrain',
    'Generating stepped terraces, kaidan stairs, and roads',
  ),
  townArchitecture(
    'Town Architecture',
    'Framing Edo post-and-beam machiya, chaya, and kura',
  ),
  floraAndAir(
    'Flora & Atmosphere',
    'Populating cedar groves, bamboo, and river mist',
  ),
  gpuWarmup(
    'GPU Warmup',
    'Prewarming GPU pipeline state objects and shadow maps',
  );

  new(this.label, this.detail);
  final String label;
  final String detail;
}

enum HudToolCategory {
  dwellingsAndShops('Dwellings & Shops'),
  roadsAndWalls('Roads & Walls'),
  treesAndRocks('Trees & Rocks'),
  shrinesAndCourtyards('Shrines & Courtyards');

  new(this.label);
  final String label;
}

enum StructureKind {
  machiya,
  minka,
  chaya,
  kura,
  marketStall,
  toriiGate,
  shoroBell,
  stoneWell,
  karesansuiGarden,
  yaguraTower,
  rockOutcrop,
  mapleCluster,
  bambooGrove,
  pineTree,
  weepingWillow;

  bool get isBotanicalTree => switch (this) {
    StructureKind.mapleCluster ||
    StructureKind.bambooGrove ||
    StructureKind.pineTree ||
    StructureKind.weepingWillow => true,
    _ => false,
  };

  bool get isNaturalFeature =>
      isBotanicalTree || this == StructureKind.rockOutcrop;

  StructureSpec get spec => switch (this) {
    StructureKind.machiya => StructureSpec.machiya,
    StructureKind.minka => StructureSpec.minka,
    StructureKind.chaya => StructureSpec.chaya,
    StructureKind.kura => StructureSpec.kura,
    StructureKind.marketStall => StructureSpec.marketStall,
    StructureKind.toriiGate => StructureSpec.toriiGate,
    StructureKind.shoroBell => StructureSpec.shoroBell,
    StructureKind.stoneWell => StructureSpec.stoneWell,
    StructureKind.karesansuiGarden => StructureSpec.karesansuiGarden,
    StructureKind.yaguraTower => StructureSpec.yaguraTower,
    StructureKind.rockOutcrop => StructureSpec.rockOutcrop,
    StructureKind.mapleCluster => StructureSpec.mapleCluster,
    StructureKind.bambooGrove => StructureSpec.bambooGrove,
    StructureKind.pineTree => StructureSpec.pineTree,
    StructureKind.weepingWillow => StructureSpec.weepingWillow,
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
    required this.displayName,
    required this.edoSubtitle,
    required this.footprintWidth,
    required this.footprintDepth,
    required this.height,
    required this.foundationSkirtDepth,
    required this.eaveAnchors,
    required this.instrument,
    this.roofCraft = RoofCraft.irimoyaKawara,
    this.variantLabels = const [],
    this.sightconeRange = 0,
    this.sightconeHalfAngleRad = 0,
    this.snapsToRoadTangent = true,
    this.straddlesRoad = false,
    this.hasShojiWindows = false,
  });

  static const StructureSpec machiya = StructureSpec(
    kind: StructureKind.machiya,
    displayName: 'Townhouse',
    edoSubtitle: 'Machiya shop',
    footprintWidth: 3.8,
    footprintDepth: 4.8,
    height: 4.18,
    foundationSkirtDepth: 1.2,
    eaveAnchors: [
      EaveAnchor(
        localOffset: Vec3(-1.55, 1.86, 2.70),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(1.55, 1.86, 2.70),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(0, 2.15, -2.48),
        localOutwardNormal: Vec3(0, 0, -1),
      ),
    ],
    instrument: EdoInstrument.koto,
    hasShojiWindows: true,
    variantLabels: [
      'Kawara Merchant',
      'Hoshidai Loft',
      'Udatsu Dyer Shop',
      'Nurigome Apothecary',
    ],
  );

  static const StructureSpec minka = StructureSpec(
    kind: StructureKind.minka,
    displayName: 'Farmhouse',
    edoSubtitle: 'Minka cottage',
    footprintWidth: 3.6,
    footprintDepth: 4.2,
    height: 3.8,
    foundationSkirtDepth: 1.2,
    eaveAnchors: [
      EaveAnchor(
        localOffset: Vec3(-1.45, 1.88, 2.28),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(1.45, 1.88, 2.28),
        localOutwardNormal: Vec3.forward,
      ),
    ],
    instrument: EdoInstrument.koto,
    hasShojiWindows: true,
    roofCraft: RoofCraft.kayabukiThatch,
    variantLabels: [
      'Kayabuki Thatch',
      'Magariya L-Farm',
      'Stone-Shingle Cottage',
      'Hisashi Homestead',
    ],
  );

  static const StructureSpec chaya = StructureSpec(
    kind: StructureKind.chaya,
    displayName: 'Teahouse',
    edoSubtitle: 'Chaya rest inn',
    footprintWidth: 4.4,
    footprintDepth: 4.4,
    height: 3.58,
    foundationSkirtDepth: 1.2,
    eaveAnchors: [
      EaveAnchor(
        localOffset: Vec3(-1.80, 1.92, 2.45),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(1.80, 1.92, 2.45),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(2.35, 1.92, 0),
        localOutwardNormal: Vec3(1, 0, 0),
      ),
    ],
    instrument: EdoInstrument.koto,
    hasShojiWindows: true,
    variantLabels: [
      'Garden Teahouse',
      'Highway Kakejaya',
      'Riverside Lantern Inn',
    ],
  );

  static const StructureSpec kura = StructureSpec(
    kind: StructureKind.kura,
    displayName: 'Storehouse',
    edoSubtitle: 'Kura plaster vault',
    footprintWidth: 3.4,
    footprintDepth: 4,
    height: 4.55,
    foundationSkirtDepth: 1.2,
    eaveAnchors: [
      EaveAnchor(
        localOffset: Vec3(0, 2.25, 2.28),
        localOutwardNormal: Vec3.forward,
      ),
    ],
    instrument: EdoInstrument.bonsho,
    roofCraft: RoofCraft.ishiOkiYane,
    variantLabels: [
      'Namako White Vault',
      'Kuro-Shikkui Vault',
      'Cedar Ita-Gura',
    ],
  );

  static const StructureSpec marketStall = StructureSpec(
    kind: StructureKind.marketStall,
    displayName: 'Market Stall',
    edoSubtitle: 'Yatai booth',
    footprintWidth: 2.2,
    footprintDepth: 1.9,
    height: 2.24,
    foundationSkirtDepth: 0.6,
    eaveAnchors: [
      EaveAnchor(
        localOffset: Vec3(-0.95, 1.84, 1.15),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(0.95, 1.84, 1.15),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(-0.95, 1.84, -1.15),
        localOutwardNormal: Vec3(0, 0, -1),
      ),
      EaveAnchor(
        localOffset: Vec3(0.95, 1.84, -1.15),
        localOutwardNormal: Vec3(0, 0, -1),
      ),
    ],
    instrument: EdoInstrument.hyoshigi,
    variantLabels: [
      'Striped Produce Booth',
      'Wheeled Noodle Yatai',
      'Wagasa Rice Stand',
      'Sakaya Cask Stall',
    ],
  );

  static const StructureSpec toriiGate = StructureSpec(
    kind: StructureKind.toriiGate,
    displayName: 'Lantern Gate',
    edoSubtitle: 'Highway archway',
    footprintWidth: 4,
    footprintDepth: 1.3,
    height: 4.3,
    foundationSkirtDepth: 0.8,
    eaveAnchors: [
      EaveAnchor(
        localOffset: Vec3(-1.8, 3.4, 0.4),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(1.8, 3.4, 0.4),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(0, 3.4, -0.4),
        localOutwardNormal: Vec3(0, 0, -1),
      ),
    ],
    instrument: EdoInstrument.koto,
    straddlesRoad: true,
  );

  static const StructureSpec shoroBell = StructureSpec(
    kind: StructureKind.shoroBell,
    displayName: 'Bell Pavilion',
    edoSubtitle: 'Shoro pavilion',
    footprintWidth: 3.2,
    footprintDepth: 3.2,
    height: 4.6,
    foundationSkirtDepth: 1.2,
    eaveAnchors: [
      EaveAnchor(
        localOffset: Vec3(-1.4, 2.3, 1.7),
        localOutwardNormal: Vec3.forward,
      ),
      EaveAnchor(
        localOffset: Vec3(1.4, 2.3, 1.7),
        localOutwardNormal: Vec3.forward,
      ),
    ],
    instrument: EdoInstrument.bonsho,
  );

  static const StructureSpec stoneWell = StructureSpec(
    kind: StructureKind.stoneWell,
    displayName: 'Courtyard Well',
    edoSubtitle: 'Idobata well',
    footprintWidth: 1.8,
    footprintDepth: 1.8,
    height: 2.35,
    foundationSkirtDepth: 0.8,
    eaveAnchors: [],
    instrument: EdoInstrument.hyoshigi,
    snapsToRoadTangent: false,
    roofCraft: RoofCraft.ishiOkiYane,
  );

  static const StructureSpec karesansuiGarden = StructureSpec(
    kind: StructureKind.karesansuiGarden,
    displayName: 'Zen Gravel Court',
    edoSubtitle: 'Karesansui court',
    footprintWidth: 4.2,
    footprintDepth: 3.6,
    height: 1.45,
    foundationSkirtDepth: 0.4,
    eaveAnchors: [],
    instrument: EdoInstrument.shakuhachi,
    snapsToRoadTangent: false,
  );

  static const StructureSpec yaguraTower = StructureSpec(
    kind: StructureKind.yaguraTower,
    displayName: 'Watchtower',
    edoSubtitle: 'Yagura lookout',
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

  static const StructureSpec rockOutcrop = StructureSpec(
    kind: StructureKind.rockOutcrop,
    displayName: 'Rock Outcrop',
    edoSubtitle: 'Layered Iwa',
    footprintWidth: 3.2,
    footprintDepth: 3,
    height: 2.4,
    foundationSkirtDepth: 0.8,
    eaveAnchors: [],
    instrument: EdoInstrument.bonsho,
    snapsToRoadTangent: false,
  );

  static const StructureSpec mapleCluster = StructureSpec(
    kind: StructureKind.mapleCluster,
    displayName: 'Maple & Rocks',
    edoSubtitle: 'Autumn momiji',
    footprintWidth: 3.8,
    footprintDepth: 3.8,
    height: 9.2,
    foundationSkirtDepth: 0.8,
    eaveAnchors: [],
    instrument: EdoInstrument.koto,
    snapsToRoadTangent: false,
  );

  static const StructureSpec bambooGrove = StructureSpec(
    kind: StructureKind.bambooGrove,
    displayName: 'Bamboo Grove',
    edoSubtitle: 'Take culms',
    footprintWidth: 4,
    footprintDepth: 4,
    height: 12.2,
    foundationSkirtDepth: 0.8,
    eaveAnchors: [],
    instrument: EdoInstrument.shakuhachi,
    snapsToRoadTangent: false,
  );

  static const StructureSpec pineTree = StructureSpec(
    kind: StructureKind.pineTree,
    displayName: 'Black Pine',
    edoSubtitle: 'Gnarled Matsu',
    footprintWidth: 3.8,
    footprintDepth: 3.8,
    height: 10.2,
    foundationSkirtDepth: 0.8,
    eaveAnchors: [],
    instrument: EdoInstrument.bonsho,
    snapsToRoadTangent: false,
  );

  static const StructureSpec weepingWillow = StructureSpec(
    kind: StructureKind.weepingWillow,
    displayName: 'Weeping Willow',
    edoSubtitle: 'Yanagi fronds',
    footprintWidth: 3.8,
    footprintDepth: 3.8,
    height: 7.8,
    foundationSkirtDepth: 0.8,
    eaveAnchors: [],
    instrument: EdoInstrument.shakuhachi,
    snapsToRoadTangent: false,
  );

  static final Map<StructureKind, StructureSpec> byKind = {
    for (final kind in StructureKind.values) kind: kind.spec,
  };

  final StructureKind kind;
  final String displayName;
  final String edoSubtitle;
  final double footprintWidth;
  final double footprintDepth;
  final double height;
  final double foundationSkirtDepth;
  final List<EaveAnchor> eaveAnchors;
  final EdoInstrument instrument;
  final RoofCraft roofCraft;
  final List<String> variantLabels;
  final double sightconeRange;
  final double sightconeHalfAngleRad;
  final bool snapsToRoadTangent;
  final bool straddlesRoad;
  final bool hasShojiWindows;

  int get variantCount => variantLabels.isEmpty ? 1 : variantLabels.length;

  String variantLabelAt(int variant) {
    if (variantLabels.isEmpty) {
      return edoSubtitle;
    }
    final idx =
        ((variant % variantLabels.length) + variantLabels.length) %
        variantLabels.length;
    return variantLabels[idx];
  }

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

  bool get isStrokeTool => switch (this) {
    DrawLaneTool() || BuildTerraceTool() || BuildWallTool() => true,
    ExploreTool() ||
    StampStructureTool() ||
    DemolishTool() ||
    InspectWatchTool() => false,
  };

  EdoInstrument? get placementInstrument => switch (this) {
    DrawLaneTool() ||
    BuildWallTool() ||
    DemolishTool() => EdoInstrument.hyoshigi,
    BuildTerraceTool() => EdoInstrument.bonsho,
    StampStructureTool(:final kind) => kind.spec.instrument,
    ExploreTool() || InspectWatchTool() => null,
  };

  HudToolCategory? get hudCategory => switch (this) {
    DrawLaneTool() ||
    BuildTerraceTool() ||
    BuildWallTool() => HudToolCategory.roadsAndWalls,
    StampStructureTool(:final kind) => switch (kind) {
      StructureKind.machiya ||
      StructureKind.minka ||
      StructureKind.chaya ||
      StructureKind.kura ||
      StructureKind.marketStall => HudToolCategory.dwellingsAndShops,
      StructureKind.rockOutcrop ||
      StructureKind.pineTree ||
      StructureKind.mapleCluster ||
      StructureKind.weepingWillow ||
      StructureKind.bambooGrove => HudToolCategory.treesAndRocks,
      StructureKind.toriiGate ||
      StructureKind.shoroBell ||
      StructureKind.karesansuiGarden ||
      StructureKind.stoneWell => HudToolCategory.shrinesAndCourtyards,
      _ => null,
    },
    _ => null,
  };

  MagistrateVisionState resolveVision(MagistrateVisionState explicit) {
    if (explicit == MagistrateVisionState.fullOverlay) {
      return MagistrateVisionState.fullOverlay;
    }
    return switch (this) {
      InspectWatchTool() => MagistrateVisionState.fullOverlay,
      StampStructureTool(kind: StructureKind.yaguraTower) =>
        MagistrateVisionState.watchtowerPreview,
      ExploreTool() ||
      DrawLaneTool() ||
      BuildTerraceTool() ||
      BuildWallTool() ||
      StampStructureTool() ||
      DemolishTool() => explicit,
    };
  }
}

final class ExploreTool extends PlacementTool {
  const new();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ExploreTool;

  @override
  int get hashCode => (ExploreTool).hashCode;
}

enum RoadStyle { kaidoRoad, gardenPath }

final class DrawLaneTool extends PlacementTool {
  const new({this.widthMeters = 3.2, this.style = RoadStyle.kaidoRoad})
    : assert(widthMeters > 0, 'widthMeters must be positive.');

  final double widthMeters;
  final RoadStyle style;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DrawLaneTool &&
          other.widthMeters == widthMeters &&
          other.style == style;

  @override
  int get hashCode => Object.hash(widthMeters, style);
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

final class BuildWallTool extends PlacementTool {
  const new({this.heightMeters = 1.95, this.thicknessMeters = 0.30})
    : assert(heightMeters > 0, 'heightMeters must be positive.'),
      assert(thicknessMeters > 0, 'thicknessMeters must be positive.');

  final double heightMeters;
  final double thicknessMeters;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BuildWallTool &&
          other.heightMeters == heightMeters &&
          other.thicknessMeters == thicknessMeters;

  @override
  int get hashCode => Object.hash(heightMeters, thicknessMeters);
}

final class StampStructureTool extends PlacementTool {
  const new({required this.kind, this.yawOffsetRadians = 0, this.variant = 0});

  final StructureKind kind;
  final double yawOffsetRadians;
  final int variant;

  int get resolvedVariant {
    final count = kind.spec.variantCount;
    return count <= 1 ? 0 : ((variant % count) + count) % count;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StampStructureTool &&
          other.kind == kind &&
          other.yawOffsetRadians == yawOffsetRadians &&
          other.variant == variant;

  @override
  int get hashCode => Object.hash(kind, yawOffsetRadians, variant);
}

final class DemolishTool extends PlacementTool {
  const new();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DemolishTool;

  @override
  int get hashCode => (DemolishTool).hashCode;
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

@immutable
class RoadSpline {
  const new({
    required this.id,
    required this.controlPoints,
    this.widthMeters = 3.2,
    this.style = RoadStyle.kaidoRoad,
    this.isBridgeApproach = false,
  }) : assert(controlPoints.length >= 2, 'RoadSpline requires >= 2 points.'),
       assert(widthMeters > 0, 'widthMeters must be positive.');

  factory validated({
    required EntityId id,
    required Iterable<Vec3> controlPoints,
    double widthMeters = 3.2,
    RoadStyle style = RoadStyle.kaidoRoad,
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
      style: style,
      isBridgeApproach: isBridgeApproach,
    );
  }

  final EntityId id;
  final List<Vec3> controlPoints;
  final double widthMeters;
  final RoadStyle style;
  final bool isBridgeApproach;

  static Vec3 _lerpKnot(Vec3 a, Vec3 b, double ta, double tb, double t) {
    final span = tb - ta;
    if (span.abs() <= 1e-9) {
      return a;
    }
    return Vec3.lerp(a, b, (t - ta) / span);
  }

  List<Vec3> smoothCenterline({double stepMeters = 0.65}) {
    final step = stepMeters <= 0.05 ? 0.05 : stepMeters;
    final clean = <Vec3>[controlPoints.first];
    for (var i = 1; i < controlPoints.length; i++) {
      final candidate = controlPoints[i];
      if (candidate.horizontalDistanceTo(clean.last) > 1e-4) {
        clean.add(candidate);
      }
    }
    if (clean.length < 2) {
      return [controlPoints.first, controlPoints.last];
    }
    if (clean.length == 2) {
      final dist = clean.first.horizontalDistanceTo(clean.last);
      final steps = math.max(1, (dist / step).ceil());
      return [
        for (var i = 0; i <= steps; i++)
          Vec3.lerp(clean.first, clean.last, i / steps),
      ];
    }

    final result = <Vec3>[clean.first];
    final n = clean.length;
    for (var i = 0; i < n - 1; i++) {
      final p1 = clean[i];
      final p2 = clean[i + 1];
      final p0 = i == 0 ? p1 + (p1 - p2) : clean[i - 1];
      final p3 = i + 2 < n ? clean[i + 2] : p2 + (p2 - p1);

      final dt01 = math.max(0.05, math.sqrt(p0.horizontalDistanceTo(p1)));
      final dt12 = math.max(0.05, math.sqrt(p1.horizontalDistanceTo(p2)));
      final dt23 = math.max(0.05, math.sqrt(p2.horizontalDistanceTo(p3)));
      const t0 = 0.0;
      final t1 = dt01;
      final t2 = t1 + dt12;
      final t3 = t2 + dt23;

      final chord = p1.horizontalDistanceTo(p2);
      final segSteps = math.max(2, (chord / step).ceil());
      for (var k = 1; k <= segSteps; k++) {
        final t = t1 + (t2 - t1) * (k / segSteps);
        final a1 = _lerpKnot(p0, p1, t0, t1, t);
        final a2 = _lerpKnot(p1, p2, t1, t2, t);
        final a3 = _lerpKnot(p2, p3, t2, t3, t);
        final b1 = _lerpKnot(a1, a2, t0, t2, t);
        final b2 = _lerpKnot(a2, a3, t1, t3, t);
        result.add(_lerpKnot(b1, b2, t1, t2, t));
      }
    }
    return result;
  }

  RoadSample nearestSample(Vec3 query) {
    final samples = controlPoints.length <= 2
        ? controlPoints
        : smoothCenterline(stepMeters: 0.75);
    var bestPoint = samples.first;
    var bestTangent = Vec3.forward;
    var bestDistSq = double.infinity;
    var bestArcMeters = 0.0;
    var cumulativeMeters = 0.0;
    for (var i = 0; i < samples.length - 1; i++) {
      final a = samples[i];
      final b = samples[i + 1];
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
          other.style == style &&
          other.isBridgeApproach == isBridgeApproach;

  @override
  int get hashCode => Object.hash(
    id,
    Object.hashAll(controlPoints),
    widthMeters,
    style,
    isBridgeApproach,
  );
}

@immutable
class TerraceCourse {
  const new({
    required this.id,
    required this.crestPoints,
    required this.topElevation,
    this.riseMeters = 1.6,
    this.depthMeters = 5.5,
    this.platformOnRight = true,
  }) : assert(crestPoints.length >= 2, 'TerraceCourse requires >= 2 points.'),
       assert(riseMeters > 0, 'riseMeters must be positive.'),
       assert(depthMeters > 0, 'depthMeters must be positive.');

  factory validated({
    required EntityId id,
    required Iterable<Vec3> crestPoints,
    required double topElevation,
    double riseMeters = 1.6,
    double depthMeters = 5.5,
    bool platformOnRight = true,
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
      platformOnRight: platformOnRight,
    );
  }

  factory alignedToTerrain({
    required EntityId id,
    required Iterable<Vec3> crestPoints,
    required double topElevation,
    required GroundHeightSampler sampleGroundY,
    double riseMeters = 1.6,
    double depthMeters = 5.5,
  }) {
    final frozen = List<Vec3>.unmodifiable(crestPoints);
    if (frozen.length < 2) {
      throw ArgumentError.value(
        frozen.length,
        'crestPoints',
        'TerraceCourse requires at least 2 crest points.',
      );
    }
    var rightScore = 0.0;
    for (var i = 0; i < frozen.length - 1; i++) {
      final a = frozen[i];
      final b = frozen[i + 1];
      final delta = b - a;
      final segLen = delta.horizontalLength;
      if (segLen <= 1e-6) {
        continue;
      }
      final rightNormal = Vec3(delta.z / segLen, 0, -delta.x / segLen);
      for (final frac in const [0.25, 0.5, 0.75]) {
        final probe = Vec3.lerp(a, b, frac);
        final hRight = sampleGroundY(
          probe.x + rightNormal.x * 2,
          probe.z + rightNormal.z * 2,
        );
        final hLeft = sampleGroundY(
          probe.x - rightNormal.x * 2,
          probe.z - rightNormal.z * 2,
        );
        rightScore += (hRight - hLeft) * segLen;
      }
    }
    return TerraceCourse.validated(
      id: id,
      crestPoints: frozen,
      topElevation: topElevation,
      riseMeters: riseMeters,
      depthMeters: depthMeters,
      platformOnRight: rightScore >= -1e-6,
    );
  }

  final EntityId id;
  final List<Vec3> crestPoints;
  final double topElevation;
  final double riseMeters;
  final double depthMeters;
  final bool platformOnRight;

  Vec3 platformNormalBetween(Vec3 a, Vec3 b) {
    final delta = b - a;
    final segLen = delta.horizontalLength;
    if (segLen <= 1e-9) {
      return const Vec3(1, 0, 0);
    }
    final sign = platformOnRight ? 1.0 : -1.0;
    return Vec3((delta.z / segLen) * sign, 0, (-delta.x / segLen) * sign);
  }

  Vec3 dropNormalBetween(Vec3 a, Vec3 b) => platformNormalBetween(a, b) * -1;

  static double _quinticSmooth(double t) => t * t * t * (t * (t * 6 - 15) + 10);

  (double inward, double wingOvershoot)? _projectQuery(double qx, double qz) {
    var firstValid = -1;
    var lastValid = -1;
    for (var i = 0; i < crestPoints.length - 1; i++) {
      if (crestPoints[i].horizontalDistanceTo(crestPoints[i + 1]) > 1e-9) {
        if (firstValid < 0) {
          firstValid = i;
        }
        lastValid = i;
      }
    }
    if (firstValid < 0) {
      return null;
    }

    var bestIdx = firstValid;
    var bestAlong = 0.0;
    var bestClamped = 0.0;
    var bestSegLen = 1.0;
    var bestCx = 0.0;
    var bestCz = 0.0;
    var bestDistSq = double.infinity;

    for (var i = firstValid; i <= lastValid; i++) {
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
      final along = (qx - a.x) * tx + (qz - a.z) * tz;
      final clamped = along.clamp(0.0, segLen);
      final cx = a.x + tx * clamped;
      final cz = a.z + tz * clamped;
      final dx = qx - cx;
      final dz = qz - cz;
      final distSq = dx * dx + dz * dz;
      if (distSq < bestDistSq) {
        bestDistSq = distSq;
        bestIdx = i;
        bestAlong = along;
        bestClamped = clamped;
        bestSegLen = segLen;
        bestCx = cx;
        bestCz = cz;
      }
    }

    final segA = crestPoints[bestIdx];
    final segB = crestPoints[bestIdx + 1];
    final nBest = platformNormalBetween(segA, segB);

    if (bestIdx == firstValid && bestAlong < 0) {
      final inward = (qx - segA.x) * nBest.x + (qz - segA.z) * nBest.z;
      return (inward, -bestAlong);
    }
    if (bestIdx == lastValid && bestAlong > bestSegLen) {
      final inward = (qx - segB.x) * nBest.x + (qz - segB.z) * nBest.z;
      return (inward, bestAlong - bestSegLen);
    }

    var effectiveNormal = nBest;
    if (bestClamped <= 1e-5 && bestIdx > firstValid) {
      var prevIdx = bestIdx - 1;
      while (prevIdx > firstValid &&
          crestPoints[prevIdx].horizontalDistanceTo(crestPoints[prevIdx + 1]) <=
              1e-9) {
        prevIdx--;
      }
      final nPrev = platformNormalBetween(
        crestPoints[prevIdx],
        crestPoints[prevIdx + 1],
      );
      effectiveNormal = (nPrev + nBest).normalizedHorizontal();
    } else if (bestClamped >= bestSegLen - 1e-5 && bestIdx < lastValid) {
      var nextIdx = bestIdx + 1;
      while (nextIdx < lastValid &&
          crestPoints[nextIdx].horizontalDistanceTo(crestPoints[nextIdx + 1]) <=
              1e-9) {
        nextIdx++;
      }
      final nNext = platformNormalBetween(
        crestPoints[nextIdx],
        crestPoints[nextIdx + 1],
      );
      effectiveNormal = (nBest + nNext).normalizedHorizontal();
    }

    final dx = qx - bestCx;
    final dz = qz - bestCz;
    final r = math.sqrt(bestDistSq);
    if (r <= 1e-9) {
      return (0, 0);
    }
    final sign = (dx * effectiveNormal.x + dz * effectiveNormal.z) >= -1e-9
        ? 1.0
        : -1.0;
    return (sign * r, 0);
  }

  double? samplePlatformElevation(Vec3 query) {
    final proj = _projectQuery(query.x, query.z);
    if (proj == null) {
      return null;
    }
    final (inward, wingOvershoot) = proj;
    if (wingOvershoot <= 1e-6 && inward >= 0 && inward <= depthMeters) {
      return topElevation;
    }
    return null;
  }

  double sampleGradedElevation(
    double x,
    double z,
    double rawY, {
    double backBermMeters = 4.6,
    double wingBermMeters = 3.8,
  }) {
    if (rawY >= topElevation) {
      return rawY;
    }
    final proj = _projectQuery(x, z);
    if (proj == null) {
      return rawY;
    }
    final (inward, wingOvershoot) = proj;
    if (inward <= 0.14 ||
        inward >= depthMeters + backBermMeters ||
        wingOvershoot >= wingBermMeters) {
      return rawY;
    }
    final tFront = ((inward - 0.14) / 0.76).clamp(0.0, 1.0);
    final tBack =
        1.0 - ((inward - depthMeters) / backBermMeters).clamp(0.0, 1.0);
    final tWing = 1.0 - (wingOvershoot / wingBermMeters).clamp(0.0, 1.0);
    final weight =
        _quinticSmooth(tFront) * _quinticSmooth(tBack) * _quinticSmooth(tWing);
    return rawY + (topElevation - rawY) * weight;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerraceCourse &&
          other.id == id &&
          listEquals(other.crestPoints, crestPoints) &&
          other.topElevation == topElevation &&
          other.riseMeters == riseMeters &&
          other.depthMeters == depthMeters &&
          other.platformOnRight == platformOnRight;

  @override
  int get hashCode => Object.hash(
    id,
    Object.hashAll(crestPoints),
    topElevation,
    riseMeters,
    depthMeters,
    platformOnRight,
  );
}

@immutable
class CourtyardWall {
  const new({
    required this.id,
    required this.controlPoints,
    this.heightMeters = 1.95,
    this.thicknessMeters = 0.30,
  }) : assert(controlPoints.length >= 2, 'CourtyardWall requires >= 2 points.'),
       assert(heightMeters > 0, 'heightMeters must be positive.'),
       assert(thicknessMeters > 0, 'thicknessMeters must be positive.');

  factory validated({
    required EntityId id,
    required Iterable<Vec3> controlPoints,
    double heightMeters = 1.95,
    double thicknessMeters = 0.30,
  }) {
    if (!id.isValid) {
      throw ArgumentError.value(
        id,
        'id',
        'CourtyardWall id must not be blank.',
      );
    }
    final frozen = List<Vec3>.unmodifiable(controlPoints);
    if (frozen.length < 2) {
      throw ArgumentError.value(
        frozen.length,
        'controlPoints',
        'CourtyardWall requires at least 2 control points.',
      );
    }
    if (heightMeters <= 0 || thicknessMeters <= 0) {
      throw ArgumentError('CourtyardWall dimensions must be positive.');
    }
    return CourtyardWall(
      id: id,
      controlPoints: frozen,
      heightMeters: heightMeters,
      thicknessMeters: thicknessMeters,
    );
  }

  final EntityId id;
  final List<Vec3> controlPoints;
  final double heightMeters;
  final double thicknessMeters;

  RoadSample nearestSample(Vec3 query) {
    final spline = RoadSpline(
      id: id,
      controlPoints: controlPoints,
      widthMeters: thicknessMeters,
    );
    return spline.nearestSample(query);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourtyardWall &&
          other.id == id &&
          listEquals(other.controlPoints, controlPoints) &&
          other.heightMeters == heightMeters &&
          other.thicknessMeters == thicknessMeters;

  @override
  int get hashCode => Object.hash(
    id,
    Object.hashAll(controlPoints),
    heightMeters,
    thicknessMeters,
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

  static const double decalRimPaddingFactor = 1.1;

  final EntityId sourceId;
  final Vec3 origin;
  final double yawRadians;
  final double rangeMeters;
  final double halfAngleRadians;
  final double alertLevel;
  final bool isWatchtower;

  Vec3 get forward => Vec3(math.sin(yawRadians), 0, math.cos(yawRadians));

  Vec3 get decalProjectionCenter => origin + forward * (rangeMeters * 0.5);

  double get decalBoxSize =>
      math.max(rangeMeters, 2 * rangeMeters * math.sin(halfAngleRadians)) *
      decalRimPaddingFactor;

  double get coneRangeNormalized => rangeMeters / decalBoxSize;

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
    this.variant = 0,
  });

  final EntityId id;
  final StructureKind kind;
  final Vec3 position;
  final double yawRadians;
  final int variant;

  StructureSpec get spec => kind.spec;

  int get resolvedVariant {
    final count = spec.variantCount;
    return count <= 1 ? 0 : ((variant % count) + count) % count;
  }

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
          other.yawRadians == yawRadians &&
          other.variant == variant;

  @override
  int get hashCode => Object.hash(id, kind, position, yawRadians, variant);
}

@immutable
class LanternSpan {
  const new({
    required this.id,
    required this.endpointA,
    required this.endpointB,
    required this.lengthMeters,
    required this.sagMeters,
  });

  static const double maxSpanMeters = 8.2;
  static const double minSpanMeters = 0.9;
  static const double minFacingCos = 0.5;
  static const double maxHeightDeltaMeters = 2.2;
  static const double sagRatio = 0.085;

  final EntityId id;
  final EaveEndpoint endpointA;
  final EaveEndpoint endpointB;
  final double lengthMeters;
  final double sagMeters;

  bool get hasFestivalStreamers {
    var hash = 0x811c9dc5;
    for (final unit in id.value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return (hash & 0x3) != 0;
  }

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
class DemolishCandidate {
  const new({
    required this.id,
    required this.center,
    required this.radiusMeters,
    required this.label,
  });

  final EntityId id;
  final Vec3 center;
  final double radiusMeters;
  final String label;
}

@immutable
sealed class BuildPreview {
  const new();
}

final class NoBuildPreview extends BuildPreview {
  const new();
}

final class StampGhostPreview extends BuildPreview {
  const new({
    required this.kind,
    required this.position,
    required this.yawRadians,
    this.variant = 0,
    this.lanternSpans = const [],
  });

  final StructureKind kind;
  final Vec3 position;
  final double yawRadians;
  final int variant;
  final List<LanternSpan> lanternSpans;
}

enum StrokePreviewStyle { lane, gardenPath, terrace, wall }

final class StrokeRibbonPreview extends BuildPreview {
  const new({
    required this.style,
    required this.points,
    required this.widthMeters,
  });

  final StrokePreviewStyle style;
  final List<Vec3> points;
  final double widthMeters;
}

final class DemolishHoverPreview extends BuildPreview {
  const new({required this.candidate});

  final DemolishCandidate candidate;
}

@immutable
class ShukubaGraph {
  new({
    Iterable<RoadSpline> roads = const [],
    Iterable<TerraceCourse> terraces = const [],
    Iterable<CourtyardWall> walls = const [],
    Iterable<PlacedStructure> structures = const [],
  }) : this._normalized(
         roads: _freezeRoads(roads),
         terraces: _freezeTerraces(terraces),
         walls: _freezeWalls(walls),
         structures: _freezeStructures(structures),
       );

  new _normalized({
    required this.roads,
    required this.terraces,
    required this.walls,
    required this.structures,
  }) : lanternSpans = List<LanternSpan>.unmodifiable(
         LanternSpan.deriveAll(structures.values),
       );

  static final ShukubaGraph empty = ShukubaGraph();

  final List<RoadSpline> roads;
  final List<TerraceCourse> terraces;
  final List<CourtyardWall> walls;
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
    walls: walls,
    structures: structures,
  );

  ShukubaGraph putTerrace(TerraceCourse terrace) => ShukubaGraph._normalized(
    roads: roads,
    terraces: _freezeTerraces([
      for (final existing in terraces)
        if (existing.id != terrace.id) existing,
      terrace,
    ]),
    walls: walls,
    structures: structures,
  );

  ShukubaGraph putWall(CourtyardWall wall) => ShukubaGraph._normalized(
    roads: roads,
    terraces: terraces,
    walls: _freezeWalls([
      for (final existing in walls)
        if (existing.id != wall.id) existing,
      wall,
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
      walls: walls,
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
    final hasWall = walls.any((w) => w.id == id);
    final hasStructure = structures.containsKey(id);
    if (!hasRoad && !hasTerrace && !hasWall && !hasStructure) {
      return this;
    }
    return ShukubaGraph._normalized(
      roads: hasRoad
          ? List<RoadSpline>.unmodifiable(roads.where((r) => r.id != id))
          : roads,
      terraces: hasTerrace
          ? List<TerraceCourse>.unmodifiable(terraces.where((t) => t.id != id))
          : terraces,
      walls: hasWall
          ? List<CourtyardWall>.unmodifiable(walls.where((w) => w.id != id))
          : walls,
      structures: hasStructure
          ? _freezeStructures(structures.values.where((s) => s.id != id))
          : structures,
    );
  }

  List<LanternSpan> previewLanternSpansFor(PlacedStructure candidate) {
    final combined = LanternSpan.deriveAll([...structures.values, candidate]);
    return [
      for (final span in combined)
        if (span.endpointA.structureId == candidate.id ||
            span.endpointB.structureId == candidate.id)
          span,
    ];
  }

  DemolishCandidate? findDemolishCandidate(
    Vec3 query, {
    double maxDistanceMeters = 4.2,
  }) {
    DemolishCandidate? best;
    var bestDist = maxDistanceMeters;

    for (final structure in structures.values) {
      final d = structure.position.horizontalDistanceTo(query);
      final hitRadius =
          math.max(
                structure.spec.footprintWidth,
                structure.spec.footprintDepth,
              ) *
              0.55 +
          0.9;
      if (d <= math.min(maxDistanceMeters, hitRadius) && d < bestDist) {
        bestDist = d;
        best = DemolishCandidate(
          id: structure.id,
          center: structure.position,
          radiusMeters:
              math.max(
                structure.spec.footprintWidth,
                structure.spec.footprintDepth,
              ) *
              0.55,
          label: structure.spec.displayName,
        );
      }
    }

    for (final wall in walls) {
      final sample = wall.nearestSample(query);
      if (sample.horizontalDistance < bestDist &&
          sample.horizontalDistance <= 2.4) {
        bestDist = sample.horizontalDistance;
        best = DemolishCandidate(
          id: wall.id,
          center: sample.point,
          radiusMeters: 1.6,
          label: 'Courtyard Wall',
        );
      }
    }

    for (final terrace in terraces) {
      final crestSpline = RoadSpline(
        id: terrace.id,
        controlPoints: terrace.crestPoints,
        widthMeters: 1.2,
      );
      final sample = crestSpline.nearestSample(query);
      if (sample.horizontalDistance < bestDist &&
          sample.horizontalDistance <= 2.8) {
        bestDist = sample.horizontalDistance;
        best = DemolishCandidate(
          id: terrace.id,
          center: sample.point,
          radiusMeters: 2.2,
          label: 'Stone Terrace',
        );
      }
    }

    for (final road in roads) {
      if (road.isBridgeApproach) {
        continue;
      }
      final sample = road.nearestSample(query);
      if (sample.horizontalDistance < bestDist &&
          sample.horizontalDistance <= 2.4) {
        bestDist = sample.horizontalDistance;
        best = DemolishCandidate(
          id: road.id,
          center: sample.point,
          radiusMeters: road.widthMeters * 0.65,
          label: road.style == RoadStyle.gardenPath ? 'Garden Path' : 'Road',
        );
      }
    }

    return best;
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
        if (spec.straddlesRoad &&
            nearestSample.horizontalDistance <= nearestRoad.widthMeters + 1.8) {
          x = nearestSample.point.x;
          z = nearestSample.point.z;
          yaw = math.atan2(nearestSample.tangent.x, nearestSample.tangent.z);
        } else {
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

  static List<CourtyardWall> _freezeWalls(Iterable<CourtyardWall> items) {
    final byId = <EntityId, CourtyardWall>{
      for (final wall in items) wall.id: wall,
    };
    final sorted = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    return List<CourtyardWall>.unmodifiable(sorted);
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
          listEquals(other.walls, walls) &&
          mapEquals(other.structures, structures);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(roads),
    Object.hashAll(terraces),
    Object.hashAll(walls),
    Object.hashAll(structures.values),
  );
}

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

  Vec3 get celestialRayDirection {
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

  Vec3 get celestialSkyDirection => (celestialRayDirection * -1).normalized();

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

  double get lanternPointLightIntensity => 1.6 + 11.8 * nightFactor;

  double get lanternPointLightRange => 7.9 + 4.5 * nightFactor;

  double get riverMurmurGain => 0.44 - 0.08 * nightFactor;

  double get bambooWindGain => 0.34 - 0.06 * nightFactor;

  double get nightCricketGain => math.max(0, (value - 0.38) / 0.62) * 0.42;

  double get dewFactor => 0.20 + 0.72 * nightFactor;

  double get riverMistOpacity =>
      0.50 + 0.28 * (1 - ((value - 0.42).abs() * 1.6).clamp(0.0, 1.0));

  double get duskMoteGain => 1 - nightFactor;

  double get nightFireflyGain => nightFactor;

  double get lanternHaloOpacity => 0.14 + 0.62 * nightFactor;

  double get meadowTranslucency => 1 - nightFactor * 0.88;

  double get windGustStrength => 0.88 + 0.14 * (1 - nightFactor);

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
    this.nearMeters = 6,
    this.farMeters = 300,
  });

  static const double defaultVerticalFovDegrees = 19;
  static const double defaultPitchDegrees = 38;

  static const CameraPreset duskOverview = CameraPreset(
    id: 'dusk_overview',
    label: 'Golden Dusk Crossing',
    eye: Vec3(-45.5, 51.6, -45.5),
    target: Vec3(0, 1.4, 0),
    timeOfDay: TimeOfDayRig.goldenDusk,
  );

  static const CameraPreset nightMarket = CameraPreset(
    id: 'night_market',
    label: 'Blue Hour Lantern Market',
    eye: Vec3(39.8, 46.3, -41.7),
    target: Vec3(1.5, 1.8, 0.5),
    timeOfDay: TimeOfDayRig.blueHourNight,
  );

  static const CameraPreset riverCrossing = CameraPreset(
    id: 'river_crossing',
    label: 'Misty Gorge Crossing',
    eye: Vec3(-38.2, 44.8, 39.6),
    target: Vec3(1.2, 1.4, -0.4),
    timeOfDay: TimeOfDayRig(0.08),
  );

  static const CameraPreset magistrateWatchtower = CameraPreset(
    id: 'magistrate_watchtower',
    label: "Magistrate's Eye Watch",
    eye: Vec3(-39.4, 48.6, 43.1),
    target: Vec3(1.5, 2, -0.5),
    timeOfDay: TimeOfDayRig.blueHourNight,
    visionState: MagistrateVisionState.fullOverlay,
  );

  static const CameraPreset meadowCloseup = CameraPreset(
    id: 'meadow_closeup',
    label: 'Riverbank & Garden Detail',
    eye: Vec3(-9.2, 4.8, 18.4),
    target: Vec3(2.6, 1.15, 0.8),
    timeOfDay: TimeOfDayRig(0.14),
    verticalFovDegrees: 21,
    nearMeters: 0.85,
    farMeters: 250,
  );

  static const CameraPreset motionOffset = CameraPreset(
    id: 'motion_offset',
    label: 'Telephoto Motion Probe',
    eye: Vec3(-33.4, 45.2, 43.2),
    target: Vec3(5.6, 1.6, 2.8),
    timeOfDay: TimeOfDayRig.blueHourNight,
  );

  static const CameraPreset countrysideVista = CameraPreset(
    id: 'countryside_vista',
    label: 'Terraced Countryside Vista',
    eye: Vec3(-66, 56, -66),
    target: Vec3(2, 2.2, 0),
    timeOfDay: TimeOfDayRig.goldenDusk,
    verticalFovDegrees: 22,
    nearMeters: 4,
    farMeters: 350,
  );

  static const List<CameraPreset> verificationPresets = [
    duskOverview,
    nightMarket,
    riverCrossing,
    meadowCloseup,
    motionOffset,
    countrysideVista,
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

enum ShukubaSurfaceRole {
  packedEarth(
    depthLayer: 0,
    defaultRoughness: 0.94,
    previewColor: Color(0xFF5C4E3E),
  ),
  ishigakiStone(
    depthLayer: 0,
    defaultRoughness: 0.88,
    previewColor: Color(0xFF6B6E72),
  ),
  steppingStone(
    depthLayer: 2,
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
  kuraPlaster(
    depthLayer: 0,
    defaultRoughness: 0.80,
    previewColor: Color(0xFFF3EFE6),
  ),
  charredTimber(
    depthLayer: 0,
    defaultRoughness: 0.82,
    previewColor: Color(0xFF3A2D25),
  ),
  kawaraTile(
    depthLayer: 0,
    defaultRoughness: 0.62,
    previewColor: Color(0xFF232B36),
  ),
  fabricAwning(
    depthLayer: 0,
    defaultRoughness: 0.86,
    previewColor: Color(0xFF9E3F2C),
  ),
  vermilionLacquer(
    depthLayer: 0,
    defaultRoughness: 0.56,
    previewColor: Color(0xFFB53324),
  ),
  ghostPreview(
    depthLayer: 2,
    defaultRoughness: 0.50,
    previewColor: Color(0xAAFFB85C),
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
    defaultRoughness: 0.985,
    previewColor: Color(0xFFC84628),
  ),
  bambooCanopy(
    depthLayer: 0,
    defaultRoughness: 0.985,
    previewColor: Color(0xFF4F7942),
  ),
  pineCanopy(
    depthLayer: 0,
    defaultRoughness: 0.985,
    previewColor: Color(0xFF1F4438),
  ),
  willowCanopy(
    depthLayer: 0,
    defaultRoughness: 0.985,
    previewColor: Color(0xFF6B8F56),
  ),
  groundMeadow(
    depthLayer: 0,
    defaultRoughness: 0.985,
    previewColor: Color(0xFF6B8448),
  ),
  livingMeadow(
    depthLayer: 0,
    defaultRoughness: 0.992,
    previewColor: Color(0xFF5A8038),
  ),
  riverWater(
    depthLayer: 1,
    defaultRoughness: 0.14,
    previewColor: Color(0xFF285864),
  ),
  riverMist(
    depthLayer: 3,
    defaultRoughness: 1,
    previewColor: Color(0x6688B8C8),
  ),
  lanternHaze(
    depthLayer: 4,
    defaultRoughness: 1,
    previewColor: Color(0x66FFB860),
  ),
  airborneMotes(
    depthLayer: 4,
    defaultRoughness: 1,
    previewColor: Color(0x99FFD88A),
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

  void syncPreview(BuildPreview preview);

  void step(double dtSeconds, {required TimeOfDayRig rig});

  double sampleGroundHeight(double x, double z);

  void dispose();
}

abstract interface class ShukubaAudioDriver {
  bool get isMuted;

  double get masterVolume;

  Future<void> prewarm();

  void setMuted(bool muted);

  void setMasterVolume(double volume);

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
