import 'dart:async';
import 'dart:ui' as ui show FrameTiming, ImageByteFormat;

import 'package:flutter/gestures.dart'
    show
        PointerScrollEvent,
        kMiddleMouseButton,
        kPrimaryMouseButton,
        kSecondaryMouseButton;
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter_scene/scene.dart' show Camera, Scene, SceneView;
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/look/look.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/capture_host.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness_api.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_shell_overlays.dart';
import 'package:kage_no_machi/shukuba/view/tactical_camera_rig.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';
import 'package:material_ui/material_ui.dart' hide Matrix4;

const bool _kProfilePerfLog = bool.fromEnvironment('FLUTTER_SCENE_PROFILE');

class ShukubaPage extends StatefulWidget {
  const new({
    this.lookDriver,
    this.worldDriver,
    this.audioDriver,
    this.initialMode,
    super.key,
  });

  final ShukubaLookDriver? lookDriver;
  final ShukubaWorldDriver? worldDriver;
  final ShukubaAudioDriver? audioDriver;
  final ShukubaShellMode? initialMode;

  @override
  State<ShukubaPage> createState() => _ShukubaPageState();
}

class _ShukubaPageState extends State<ShukubaPage> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final GlobalKey _uiRepaintBoundaryKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();
  late final TacticalCameraRig _cameraRig;
  late ShowcaseRealm _activeRealm;

  Scene? _scene;
  late final ShukubaController _controller;
  late ShukubaShellMode _shellMode;
  BootStageId _activeBootStage = BootStageId.lookAndShaders;
  final List<BootStageTiming> _completedBootTimings = [];
  BootReport? _bootReport;
  bool _showTelemetry = false;
  bool _forceRenderHudInCapture = false;
  final RollingFrameTimer _frameTimer = RollingFrameTimer(windowSize: 60);

  bool _gpuAvailable = false;
  bool _captureStarted = false;
  double _lastPerfLogSeconds = -10;
  int _bootEpoch = 0;
  int _activeButtons = 0;
  Offset? _primaryDownPos;
  bool _draggedDuringPrimary = false;
  bool _strokeDragActive = false;

  @override
  void initState() {
    super.initState();
    _activeRealm = ShowcaseRealm.fromId(kShukubaRealm);
    _cameraRig = TacticalCameraRig(initialPreset: _activeRealm.defaultPreset);
    _controller = ShukubaController(
      look: widget.lookDriver ?? EdoLookDriver(),
      world: widget.worldDriver ?? EdoWorldDriver(initialRealm: _activeRealm),
      audio: widget.audioDriver ?? EdoAudioDriver(),
      initialTimeOfDay: _activeRealm.defaultPreset.timeOfDay,
    );

    final defaultMode =
        (kShukubaCaptureDir.isNotEmpty ||
            widget.lookDriver != null ||
            widget.worldDriver != null ||
            widget.audioDriver != null)
        ? ShukubaShellMode.inValley
        : ShukubaShellMode.titleMenu;
    _shellMode = widget.initialMode ?? defaultMode;

    WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);

    unawaited(_controller.audio.prewarm());
    if (_shellMode == ShukubaShellMode.titleMenu &&
        kShukubaCaptureDir.isEmpty) {
      if (_controller.audio case final EdoAudioDriver edoAudio) {
        unawaited(edoAudio.startMenuMusic());
      }
    } else if (_shellMode == ShukubaShellMode.inValley ||
        _shellMode == ShukubaShellMode.loadingValley) {
      unawaited(_bootSceneStaged(epoch: ++_bootEpoch));
    }
  }

  void _onFrameTimings(List<ui.FrameTiming> timings) {
    if (!mounted) return;
    _frameTimer.ingestTimings(timings);
  }

  void _teardownActiveScene({bool stopAudio = true}) {
    final oldScene = _scene;
    _scene = null;
    _gpuAvailable = false;
    _lastPerfLogSeconds = -10.0;
    if (oldScene != null || stopAudio) {
      _controller.detachFromScene();
    }
    oldScene?.dispose();
  }

  void _returnToTitle() {
    _bootEpoch++;
    _teardownActiveScene();
    _controller.selectTool(const ExploreTool());
    if (_controller.audio case final EdoAudioDriver edoAudio) {
      unawaited(edoAudio.startMenuMusic());
    }
    setState(() => _shellMode = ShukubaShellMode.titleMenu);
  }

  void _enterValley() {
    unawaited(_enterRealm(ShowcaseRealm.shukubaValley));
  }

  Future<void> _enterRealm(ShowcaseRealm realm) async {
    if (_shellMode == ShukubaShellMode.loadingValley) {
      return;
    }
    final epoch = ++_bootEpoch;
    if (_scene != null) {
      _teardownActiveScene();
    }
    _activeRealm = realm;
    _cameraRig.applyPreset(realm.defaultPreset);
    setState(() {
      _shellMode = ShukubaShellMode.loadingValley;
      _completedBootTimings.clear();
      _activeBootStage = BootStageId.lookAndShaders;
    });
    await _controller.switchRealm(realm);
    if (!mounted || epoch != _bootEpoch) {
      return;
    }
    _controller.applyCameraPresetState(realm.defaultPreset);
    await _bootSceneStaged(epoch: epoch);
  }

  Future<void> _switchRealm(ShowcaseRealm nextRealm) async {
    if (nextRealm == _activeRealm) {
      return;
    }
    setState(() {
      _activeRealm = nextRealm;
    });
    _cameraRig.applyPreset(nextRealm.defaultPreset);
    await _controller.switchRealm(nextRealm);
    if (!mounted) {
      return;
    }
    _lastPerfLogSeconds = -10.0;
    setState(() {});
  }

  Future<void> _bootSceneStaged({required int epoch}) async {
    Scene? scene;
    var gpuReady = false;
    try {
      if (_scene != null) {
        _teardownActiveScene(stopAudio: false);
      }
      scene = Scene();
      _scene = scene;
      final report = await _controller.initializeStaged(
        scene: scene,
        camera: _cameraRig.camera,
        onStage: (stage, elapsedMs) {
          if (!mounted || epoch != _bootEpoch) return;
          setState(() {
            _completedBootTimings.add(
              BootStageTiming(stage: stage, durationMs: elapsedMs),
            );
            final nextIndex = stage.index + 1;
            if (nextIndex < BootStageId.values.length) {
              _activeBootStage = BootStageId.values[nextIndex];
            }
          });
        },
      );
      if (!mounted || epoch != _bootEpoch) {
        if (identical(_scene, scene)) {
          _teardownActiveScene(stopAudio: false);
        } else {
          scene.dispose();
        }
        return;
      }
      _bootReport = report;
      gpuReady = true;
      if (_kProfilePerfLog) {
        final stagesSummary = report.stages
            .map((s) => '${s.stage.name}:${s.durationMs.toStringAsFixed(1)}')
            .join(',');
        debugPrint(
          'SHUKUBA_PERF_BOOT realm=${_activeRealm.id} '
          'totalMs=${report.totalMs.toStringAsFixed(1)} '
          'tier=${scene.effectiveRenderQualityTier.name} '
          'scale=${scene.renderScale.toStringAsFixed(2)} '
          'stages=$stagesSummary',
        );
      }
    } on Object catch (error, stack) {
      if (!mounted || epoch != _bootEpoch) {
        if (scene != null) {
          if (identical(_scene, scene)) {
            _teardownActiveScene(stopAudio: false);
          } else {
            scene.dispose();
          }
        }
        return;
      }
      final isMissingImpeller = '$error'.contains('Impeller is not enabled');
      debugPrint(
        isMissingImpeller
            ? 'ShukubaPage._bootSceneStaged (headless fallback): $error'
            : 'ShukubaPage._bootSceneStaged failed: $error\n$stack',
      );
      if (kShukubaAutoExit || kShukubaCaptureDir.isNotEmpty) {
        captureWriteStderr('SHUKUBA_BOOT_ERROR:$error\n$stack');
      }
      if (kShukubaAutoExit) {
        captureExit(4);
      }
      if (scene != null) {
        if (identical(_scene, scene)) {
          _teardownActiveScene(stopAudio: false);
        } else {
          scene.dispose();
        }
      }
      await _controller.initialize();
    }
    if (!mounted || epoch != _bootEpoch) {
      return;
    }
    setState(() {
      _gpuAvailable = gpuReady;
      _shellMode = ShukubaShellMode.inValley;
    });

    if (kShukubaCaptureDir.isNotEmpty && !_captureStarted) {
      _captureStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _scene == null) {
          return;
        }
        final harness = ShukubaFrameHarness(
          scene: _scene!,
          look: _controller.look,
          world: _controller.world,
          audio: _controller.audio,
          repaintBoundaryKey: _repaintBoundaryKey,
          applyPreset: _applyPresetForCapture,
          captureUiAtlas: _captureUiAtlas,
          capturePixelRatio: _capturePixelRatio,
        );
        unawaited(_executeCaptureSuite(harness));
      });
    }
  }

  double get _capturePixelRatio {
    if (kShukubaCaptureReel) {
      return 1.35;
    }
    return 1;
  }

  Future<void> _saveUiPng(String filePath) async {
    for (var i = 0; i < 3; i++) {
      await ShukubaFrameHarness.pumpFrame();
    }
    final boundary = _uiRepaintBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      return;
    }
    final image = await boundary.toImage(pixelRatio: _capturePixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        await captureWriteFileBytes(
          filePath,
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
      }
    } finally {
      image.dispose();
    }
  }

  Future<List<String>> _captureUiAtlas(String uiDirPath) async {
    final saved = <String>[];
    _applyPresetForCapture(CameraPreset.duskOverview);
    if (mounted) {
      try {
        await Future.wait([
          precacheImage(
            const AssetImage('assets/ui/title_backdrop.jpg'),
            context,
          ),
          precacheImage(
            const AssetImage('assets/ui/urushi_crest.png'),
            context,
          ),
          precacheImage(
            const AssetImage('assets/ui/washi_card_bg.png'),
            context,
          ),
        ]);
      } on Object catch (_) {}
    }
    setState(() {
      _forceRenderHudInCapture = true;
      _shellMode = ShukubaShellMode.titleMenu;
    });
    final titlePath = '$uiDirPath/ui_title_menu.png';
    await _saveUiPng(titlePath);
    saved.add(titlePath);

    _controller.selectTool(const ExploreTool());
    setState(() => _shellMode = ShukubaShellMode.inValley);
    final calmPath = '$uiDirPath/ui_hud_calm_default.png';
    await _saveUiPng(calmPath);
    saved.add(calmPath);

    _controller.selectTool(
      const StampStructureTool(kind: StructureKind.minka, variant: 1),
    );
    setState(() {});
    final drawerPath = '$uiDirPath/ui_hud_dwellings_drawer.png';
    await _saveUiPng(drawerPath);
    saved.add(drawerPath);

    _controller.selectTool(const ExploreTool());
    setState(() => _shellMode = ShukubaShellMode.pauseMenu);
    final pausePath = '$uiDirPath/ui_pause_menu.png';
    await _saveUiPng(pausePath);
    saved.add(pausePath);

    setState(() {
      _forceRenderHudInCapture = false;
      _shellMode = ShukubaShellMode.inValley;
    });
    await ShukubaFrameHarness.pumpFrame();
    return saved;
  }

  Future<void> _executeCaptureSuite(ShukubaFrameHarness harness) async {
    try {
      captureWriteStdout(
        'SHUKUBA_REALM:raw="$kShukubaRealm" active=${_activeRealm.id}',
      );
      if (kShukubaVerifyReentry) {
        await _executeReentryVerification(harness);
        return;
      }
      final presets = kShukubaAudit360
          ? ShukubaFrameHarness.buildAudit360Presets(_activeRealm)
          : (_activeRealm == ShowcaseRealm.minatoJo
                ? CameraPreset.minatoVerificationPresets
                : CameraPreset.verificationPresets);
      final horizonPresets =
          kShukubaAudit360 || _activeRealm == ShowcaseRealm.minatoJo
          ? const <CameraPreset>[]
          : ShukubaFrameHarness.atmospherePresets;
      await harness.runCaptureSuite(
        outputDir: kShukubaCaptureDir,
        autoExit: kShukubaAutoExit,
        presets: presets,
        horizonPresets: horizonPresets,
      );
    } on Object catch (error, stack) {
      captureWriteStderr('SHUKUBA_CAPTURE_ERROR:$error\n$stack');
      if (kShukubaAutoExit) {
        captureExit(3);
      }
      rethrow;
    }
  }

  Future<void> _executeReentryVerification(
    ShukubaFrameHarness initialHarness,
  ) async {
    Future<void> pumpFrames(int count) async {
      for (var i = 0; i < count; i++) {
        await ShukubaFrameHarness.pumpFrame();
      }
    }

    if (!_gpuAvailable ||
        _scene == null ||
        _controller.graph.structures.isEmpty) {
      throw StateError(
        'Initial town failed to boot before re-entry verification',
      );
    }
    await pumpFrames(2);
    final step1 = await initialHarness.runCaptureSuite(
      outputDir: '$kShukubaCaptureDir/step1_shukuba',
      autoExit: false,
      presets: const [CameraPreset.duskOverview],
      horizonPresets: const [],
    );

    _returnToTitle();
    await pumpFrames(3);
    if (_scene != null ||
        _gpuAvailable ||
        _shellMode != ShukubaShellMode.titleMenu) {
      throw StateError('Return to title did not cleanly tear down scene 1');
    }

    await _enterRealm(ShowcaseRealm.minatoJo);
    await pumpFrames(4);
    final minatoScene = _scene;
    if (minatoScene == null ||
        !_gpuAvailable ||
        _shellMode != ShukubaShellMode.inValley ||
        _activeRealm != ShowcaseRealm.minatoJo ||
        _controller.activeRealm != ShowcaseRealm.minatoJo ||
        _controller.graph.structures.isEmpty) {
      throw StateError(
        'Second town (Minato-jō) failed to load after returning to title',
      );
    }
    final step2Harness = ShukubaFrameHarness(
      scene: minatoScene,
      look: _controller.look,
      world: _controller.world,
      audio: _controller.audio,
      repaintBoundaryKey: _repaintBoundaryKey,
      applyPreset: _applyPresetForCapture,
      captureUiAtlas: _captureUiAtlas,
      capturePixelRatio: _capturePixelRatio,
    );
    final step2 = await step2Harness.runCaptureSuite(
      outputDir: '$kShukubaCaptureDir/step2_minato',
      autoExit: false,
      presets: const [CameraPreset.minatoSunsetBoulevard],
      horizonPresets: const [],
    );

    _returnToTitle();
    await pumpFrames(3);
    if (_scene != null ||
        _gpuAvailable ||
        _shellMode != ShukubaShellMode.titleMenu) {
      throw StateError('Return to title did not cleanly tear down scene 2');
    }

    await _enterRealm(ShowcaseRealm.shukubaValley);
    await pumpFrames(4);
    final valleyScene = _scene;
    if (valleyScene == null ||
        !_gpuAvailable ||
        _shellMode != ShukubaShellMode.inValley ||
        _activeRealm != ShowcaseRealm.shukubaValley ||
        _controller.activeRealm != ShowcaseRealm.shukubaValley ||
        _controller.graph.structures.isEmpty) {
      throw StateError(
        'Third town entry (Shukuba Valley) failed after returning to title',
      );
    }
    final step3Harness = ShukubaFrameHarness(
      scene: valleyScene,
      look: _controller.look,
      world: _controller.world,
      audio: _controller.audio,
      repaintBoundaryKey: _repaintBoundaryKey,
      applyPreset: _applyPresetForCapture,
      captureUiAtlas: _captureUiAtlas,
      capturePixelRatio: _capturePixelRatio,
    );
    final step3 = await step3Harness.runCaptureSuite(
      outputDir: '$kShukubaCaptureDir/step3_shukuba',
      autoExit: false,
      presets: const [CameraPreset.duskOverview],
      horizonPresets: const [],
    );

    final allPassed = step1.allPassed && step2.allPassed && step3.allPassed;
    captureWriteStdout(
      'SHUKUBA_REENTRY_VERIFY:allPassed=$allPassed '
      'step1=${step1.allPassed} step2=${step2.allPassed} '
      'step3=${step3.allPassed}',
    );
    await captureFlushStdout();
    if (kShukubaAutoExit) {
      captureExit(allPassed ? 0 : 2);
    }
  }

  Camera _applyPresetForCapture(CameraPreset preset) {
    final camera = _cameraRig.applyPreset(preset);
    _controller.applyCameraPresetState(preset);
    setState(() {});
    return camera;
  }

  void _selectPreset(CameraPreset preset) {
    _cameraRig.applyPreset(preset);
    _controller.applyCameraPresetState(preset);
    setState(() {});
  }

  void _onSceneTick(Duration elapsed, double deltaSeconds) {
    _pollPanKeys(deltaSeconds);
    _controller.onFrameTick(elapsed, deltaSeconds);
    final activeScene = _scene;
    if (_kProfilePerfLog && _gpuAvailable && activeScene != null) {
      final elapsedSeconds = elapsed.inMicroseconds / 1e6;
      if (elapsedSeconds - _lastPerfLogSeconds >= 2.0) {
        _lastPerfLogSeconds = elapsedSeconds;
        debugPrint(
          'SHUKUBA_PERF_FRAME realm=${_activeRealm.id} '
          'fps=${_frameTimer.fps.toStringAsFixed(1)} '
          'uiMs=${_frameTimer.uiMs.toStringAsFixed(2)} '
          'rasterMs=${_frameTimer.rasterMs.toStringAsFixed(2)} '
          'tier=${activeScene.effectiveRenderQualityTier.name} '
          'scale=${activeScene.renderScale.toStringAsFixed(2)} '
          'structures=${_controller.graph.structures.length}',
        );
      }
    }
  }

  bool get _isSpacePressed => HardwareKeyboard.instance.logicalKeysPressed
      .contains(LogicalKeyboardKey.space);

  void _pollPanKeys(double dtSeconds) {
    if (_shellMode != ShukubaShellMode.inValley) {
      return;
    }
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    if (pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight)) {
      return;
    }
    var right = 0.0;
    var forward = 0.0;
    if (pressed.contains(LogicalKeyboardKey.keyD) ||
        pressed.contains(LogicalKeyboardKey.arrowRight)) {
      right += 1;
    }
    if (pressed.contains(LogicalKeyboardKey.keyA) ||
        pressed.contains(LogicalKeyboardKey.arrowLeft)) {
      right -= 1;
    }
    if (pressed.contains(LogicalKeyboardKey.keyW) ||
        pressed.contains(LogicalKeyboardKey.arrowUp)) {
      forward += 1;
    }
    if (pressed.contains(LogicalKeyboardKey.keyS) ||
        pressed.contains(LogicalKeyboardKey.arrowDown)) {
      forward -= 1;
    }
    if (right != 0 || forward != 0) {
      setState(() {
        _cameraRig.panByAxes(
          rightInput: right,
          forwardInput: forward,
          dtSeconds: dtSeconds <= 0 ? 1 / 60 : dtSeconds,
          sampleGroundY: _controller.world.sampleGroundHeight,
        );
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.f3) {
      setState(() => _showTelemetry = !_showTelemetry);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_shellMode == ShukubaShellMode.pauseMenu) {
        setState(() => _shellMode = ShukubaShellMode.inValley);
        return KeyEventResult.handled;
      }
      if (_controller.strokePoints.isNotEmpty) {
        _controller.cancelActiveStroke();
        return KeyEventResult.handled;
      }
      if (_controller.activeTool is! ExploreTool) {
        _controller.selectTool(const ExploreTool());
        return KeyEventResult.handled;
      }
      if (_shellMode == ShukubaShellMode.inValley) {
        setState(() => _shellMode = ShukubaShellMode.pauseMenu);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }
    if (_shellMode != ShukubaShellMode.inValley) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyQ) {
      setState(() => _cameraRig.orbitByRadians(-0.22));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyE) {
      setState(() => _cameraRig.orbitByRadians(0.22));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyR) {
      _controller.rotateStampYaw();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyV) {
      _controller.cycleStampVariant();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyZ) {
      _controller.undo();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.keyX) {
      _controller.selectTool(const DemolishTool());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _controller.commitActiveStroke();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      final nextRealm = _activeRealm == ShowcaseRealm.shukubaValley
          ? ShowcaseRealm.minatoJo
          : ShowcaseRealm.shukubaValley;
      unawaited(_switchRealm(nextRealm));
      return KeyEventResult.handled;
    }
    final presets = _activeRealm.hudPresets;
    if (key == LogicalKeyboardKey.digit1 && presets.isNotEmpty) {
      _selectPreset(presets[0]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 && presets.length > 1) {
      _selectPreset(presets[1]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3 && presets.length > 2) {
      _selectPreset(presets[2]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4 && presets.length > 3) {
      _selectPreset(presets[3]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit5 && presets.length > 4) {
      _selectPreset(presets[4]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit6 && presets.length > 5) {
      _selectPreset(presets[5]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Vec3? _raycast(Offset localPosition, Size viewportSize) =>
      _cameraRig.raycastGround(
        localPosition,
        viewportSize,
        _controller.world.sampleGroundHeight,
      );

  @override
  void dispose() {
    _bootEpoch++;
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    _focusNode.dispose();
    _controller.dispose();
    _scene?.dispose();
    _scene = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showHud =
        (kShukubaCaptureDir.isEmpty || _forceRenderHudInCapture) &&
        (_shellMode == ShukubaShellMode.inValley ||
            _shellMode == ShukubaShellMode.pauseMenu);
    return Scaffold(
      backgroundColor: const Color(0xFF0E131B),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
            final scene = _scene;
            return RepaintBoundary(
              key: _uiRepaintBoundaryKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MouseRegion(
                    onHover: (event) {
                      if (kShukubaCaptureDir.isNotEmpty ||
                          _shellMode != ShukubaShellMode.inValley) {
                        return;
                      }
                      _controller.updateHoverPoint(
                        _raycast(event.localPosition, viewSize),
                      );
                    },
                    onExit: (_) => _controller.updateHoverPoint(null),
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (event) {
                        _focusNode.requestFocus();
                        _activeButtons = event.buttons;
                        final isPrimary =
                            (event.buttons & kPrimaryMouseButton) != 0;
                        if (isPrimary && !_isSpacePressed) {
                          _primaryDownPos = event.localPosition;
                          _draggedDuringPrimary = false;
                          if (_controller.activeTool.isStrokeTool &&
                              _controller.strokePoints.isEmpty) {
                            final hit = _raycast(event.localPosition, viewSize);
                            if (hit != null) {
                              _strokeDragActive = true;
                              _controller.beginStrokeAt(hit);
                            }
                          } else {
                            _strokeDragActive = false;
                          }
                        } else {
                          _primaryDownPos = null;
                          _strokeDragActive = false;
                        }
                      },
                      onPointerMove: (event) {
                        final down = _primaryDownPos;
                        if (down != null &&
                            (event.localPosition - down).distance > 8) {
                          _draggedDuringPrimary = true;
                        }

                        if ((_activeButtons & kSecondaryMouseButton) != 0) {
                          setState(() {
                            _cameraRig.orbitByScreenDelta(
                              event.delta,
                              viewSize,
                            );
                          });
                          return;
                        }

                        final isPanGesture =
                            (_activeButtons & kMiddleMouseButton) != 0 ||
                            ((_activeButtons & kPrimaryMouseButton) != 0 &&
                                _isSpacePressed);

                        if (isPanGesture) {
                          setState(() {
                            _cameraRig.panByScreenDelta(
                              event.delta,
                              viewSize,
                              sampleGroundY:
                                  _controller.world.sampleGroundHeight,
                            );
                          });
                          return;
                        }

                        if (_strokeDragActive && _draggedDuringPrimary) {
                          final hit = _raycast(event.localPosition, viewSize);
                          if (hit != null) {
                            _controller.extendStrokeTo(hit);
                          }
                          return;
                        }

                        if (_draggedDuringPrimary &&
                            !_controller.activeTool.isStrokeTool) {
                          setState(() {
                            _cameraRig.panByScreenDelta(
                              event.delta,
                              viewSize,
                              sampleGroundY:
                                  _controller.world.sampleGroundHeight,
                            );
                          });
                        }
                      },
                      onPointerUp: (event) {
                        if (_strokeDragActive) {
                          if (_draggedDuringPrimary) {
                            _controller.finishDragStroke();
                          }
                        } else if (_primaryDownPos != null &&
                            !_draggedDuringPrimary) {
                          final hit = _raycast(event.localPosition, viewSize);
                          if (hit != null) {
                            _controller.handlePrimaryPlotTap(hit);
                          }
                        } else {
                          _controller.updateHoverPoint(
                            _raycast(event.localPosition, viewSize),
                          );
                        }
                        _primaryDownPos = null;
                        _draggedDuringPrimary = false;
                        _strokeDragActive = false;
                        _activeButtons = 0;
                      },
                      onPointerSignal: (signal) {
                        if (signal is PointerScrollEvent) {
                          setState(() {
                            _cameraRig.zoomByScrollDelta(signal.scrollDelta.dy);
                          });
                        }
                      },
                      child: RepaintBoundary(
                        key: _repaintBoundaryKey,
                        child: _gpuAvailable && scene != null
                            ? SceneView(
                                scene,
                                key: ValueKey(scene),
                                camera: _cameraRig.camera,
                                autoTick: kShukubaCaptureDir.isEmpty,
                                onTick: _onSceneTick,
                              )
                            : const ColoredBox(color: Color(0xFF0E131B)),
                      ),
                    ),
                  ),
                  if (showHud)
                    ShukubaHud(
                      controller: _controller,
                      onSelectPreset: _selectPreset,
                      onSwitchRealm: (nextRealm) =>
                          unawaited(_switchRealm(nextRealm)),
                      onOpenMenu: () => setState(
                        () => _shellMode = ShukubaShellMode.pauseMenu,
                      ),
                    ),
                  if (_shellMode == ShukubaShellMode.titleMenu)
                    TitleMenuOverlay(
                      onEnterValley: _enterValley,
                      onEnterRealm: (realm) => unawaited(_enterRealm(realm)),
                      audioDriver: _controller.audio,
                    ),
                  if (_shellMode == ShukubaShellMode.loadingValley)
                    LoadingCurtainOverlay(
                      activeStage: _activeBootStage,
                      completedTimings: _completedBootTimings,
                      realm: _activeRealm,
                    ),
                  if (_shellMode == ShukubaShellMode.pauseMenu)
                    PauseMenuOverlay(
                      onResume: () => setState(
                        () => _shellMode = ShukubaShellMode.inValley,
                      ),
                      onReturnToTitle: _returnToTitle,
                      audioDriver: _controller.audio,
                    ),
                  if (_showTelemetry &&
                      _shellMode != ShukubaShellMode.titleMenu)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: TelemetryMonitorPill(
                        snapshot: FrameTelemetrySnapshot(
                          uiMs: _frameTimer.uiMs,
                          rasterMs: _frameTimer.rasterMs,
                          fps: _frameTimer.fps,
                          structureCount: _controller.graph.structures.length,
                          lanternSpanCount:
                              _controller.graph.lanternSpans.length,
                          bootReport: _bootReport ?? _controller.bootReport,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
