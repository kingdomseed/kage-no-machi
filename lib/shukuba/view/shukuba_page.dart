import 'dart:async';
import 'dart:io' show exit, stderr;

import 'package:flutter/gestures.dart'
    show PointerScrollEvent, kPrimaryMouseButton, kSecondaryMouseButton;
import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:flutter_scene/scene.dart' show Camera, Scene, SceneView;
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/look/look.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:kage_no_machi/shukuba/view/tactical_camera_rig.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';

class ShukubaPage extends StatefulWidget {
  const new({this.lookDriver, this.worldDriver, this.audioDriver, super.key});

  final ShukubaLookDriver? lookDriver;
  final ShukubaWorldDriver? worldDriver;
  final ShukubaAudioDriver? audioDriver;

  @override
  State<ShukubaPage> createState() => _ShukubaPageState();
}

class _ShukubaPageState extends State<ShukubaPage> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();
  final TacticalCameraRig _cameraRig = TacticalCameraRig();

  Scene? _scene;
  late final ShukubaController _controller;
  bool _gpuAvailable = false;
  bool _captureStarted = false;
  int _activeButtons = 0;
  Offset? _primaryDownPos;
  bool _draggedDuringPrimary = false;

  @override
  void initState() {
    super.initState();
    _controller = ShukubaController(
      look: widget.lookDriver ?? EdoLookDriver(),
      world: widget.worldDriver ?? EdoWorldDriver(),
      audio: widget.audioDriver ?? EdoAudioDriver(),
    );
    unawaited(_bootScene());
  }

  Future<void> _bootScene() async {
    try {
      await Scene.initializeStaticResources();
      if (!mounted) {
        return;
      }
      final scene = Scene();
      _scene = scene;
      await _controller.initialize(scene);
    } on Object catch (error, stack) {
      if (kShukubaAutoExit || kShukubaCaptureDir.isNotEmpty) {
        stderr.writeln('SHUKUBA_BOOT_ERROR:$error\n$stack');
      }
      if (kShukubaAutoExit) {
        exit(4);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _gpuAvailable = true;
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
        );
        unawaited(_executeCaptureSuite(harness));
      });
    }
  }

  Future<void> _executeCaptureSuite(ShukubaFrameHarness harness) async {
    try {
      await harness.runCaptureSuite(
        outputDir: kShukubaCaptureDir,
        autoExit: kShukubaAutoExit,
      );
    } on Object catch (error, stack) {
      stderr.writeln('SHUKUBA_CAPTURE_ERROR:$error\n$stack');
      if (kShukubaAutoExit) {
        exit(3);
      }
      rethrow;
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
  }

  void _pollPanKeys(double dtSeconds) {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
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
      _cameraRig.panByAxes(
        rightInput: right,
        forwardInput: forward,
        dtSeconds: dtSeconds <= 0 ? 1 / 60 : dtSeconds,
        sampleGroundY: _controller.world.sampleGroundHeight,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.tab) {
      _controller.toggleMagistrateEye();
      return KeyEventResult.handled;
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
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _controller.commitActiveStroke();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _controller.cancelActiveStroke();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit1) {
      _selectPreset(CameraPreset.duskOverview);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2) {
      _selectPreset(CameraPreset.nightMarket);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3) {
      _selectPreset(CameraPreset.magistrateWatchtower);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4) {
      _selectPreset(CameraPreset.motionOffset);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleViewportTap(Offset localPosition, Size viewportSize) {
    final hit = _cameraRig.raycastGround(
      localPosition,
      viewportSize,
      _controller.world.sampleGroundHeight,
    );
    if (hit != null) {
      _controller.handlePrimaryPlotTap(hit);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _scene?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            return Stack(
              fit: StackFit.expand,
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) {
                    _focusNode.requestFocus();
                    _activeButtons = event.buttons;
                    if ((event.buttons & kPrimaryMouseButton) != 0) {
                      _primaryDownPos = event.localPosition;
                      _draggedDuringPrimary = false;
                    }
                  },
                  onPointerMove: (event) {
                    final down = _primaryDownPos;
                    if (down != null &&
                        (event.localPosition - down).distance > 6) {
                      _draggedDuringPrimary = true;
                    }
                    final isRightDrag =
                        (_activeButtons & kSecondaryMouseButton) != 0;
                    if (isRightDrag || _draggedDuringPrimary) {
                      setState(() {
                        _cameraRig.panByScreenDelta(
                          event.delta,
                          viewSize,
                          sampleGroundY: _controller.world.sampleGroundHeight,
                        );
                      });
                    }
                  },
                  onPointerUp: (event) {
                    if (_primaryDownPos != null && !_draggedDuringPrimary) {
                      _handleViewportTap(event.localPosition, viewSize);
                    }
                    _primaryDownPos = null;
                    _draggedDuringPrimary = false;
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
                            camera: _cameraRig.camera,
                            autoTick: kShukubaCaptureDir.isEmpty,
                            onTick: _onSceneTick,
                          )
                        : const ColoredBox(color: Color(0xFF0E131B)),
                  ),
                ),
                if (kShukubaCaptureDir.isEmpty)
                  ShukubaHud(
                    controller: _controller,
                    onSelectPreset: _selectPreset,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
