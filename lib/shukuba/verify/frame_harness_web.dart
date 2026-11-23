import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show GlobalKey;
import 'package:flutter_scene/scene.dart' show Camera, Scene;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';

const String kShukubaCaptureDir = String.fromEnvironment('SHUKUBA_CAPTURE_DIR');

const bool kShukubaAutoExit = bool.fromEnvironment('SHUKUBA_AUTO_EXIT');

const bool kShukubaCaptureAtlas = bool.fromEnvironment('SHUKUBA_CAPTURE_ATLAS');

const String kShukubaCaptureFilter = String.fromEnvironment(
  'SHUKUBA_CAPTURE_FILTER',
);

const bool kShukubaCaptureReel = bool.fromEnvironment('SHUKUBA_CAPTURE_REEL');

const bool kShukubaAudit360 = bool.fromEnvironment('SHUKUBA_AUDIT_360');

const String kShukubaRealm = String.fromEnvironment('SHUKUBA_REALM');

const bool kShukubaVerifyReentry = bool.fromEnvironment(
  'SHUKUBA_VERIFY_REENTRY',
);

typedef ApplyPresetCallback = Camera Function(CameraPreset preset);
typedef CaptureUiAtlasCallback =
    Future<List<String>> Function(String uiDirPath);

@immutable
class HarnessSummary {
  const new({required this.outputDir});

  final String outputDir;

  bool get allPassed => false;
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

  static List<CameraPreset> buildAudit360Presets(ShowcaseRealm realm) =>
      const [];

  static Future<void> pumpFrame() => Future<void>.value();

  Future<HarnessSummary> runCaptureSuite({
    required String outputDir,
    required bool autoExit,
    bool includeAtlas = kShukubaCaptureAtlas,
    List<CameraPreset> presets = CameraPreset.verificationPresets,
    List<CameraPreset> horizonPresets = atmospherePresets,
    String captureFilter = kShukubaCaptureFilter,
    bool captureReel = kShukubaCaptureReel,
  }) => Future<HarnessSummary>.error(
    UnsupportedError('Frame capture harness is native-only.'),
  );
}
