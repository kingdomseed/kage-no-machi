import 'dart:async';
import 'dart:io' show Directory, File, exit, stderr;
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
import 'package:kage_no_machi/shukuba/verify/frame_harness.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_boot_models.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_hud.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_shell_overlays.dart';
import 'package:kage_no_machi/shukuba/view/tactical_camera_rig.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';
import 'package:material_ui/material_ui.dart' hide Matrix4;

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
  final TacticalCameraRig _cameraRig = TacticalCameraRig();

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
  int _activeButtons = 0;
  Offset? _primaryDownPos;
  bool _draggedDuringPrimary = false;
  bool _strokeDragActive = false;

  @override
  void initState() {
    super.initState();
    _controller = ShukubaController(
      look: widget.lookDriver ?? EdoLookDriver(),
      world: widget.worldDriver ?? EdoWorldDriver(),
      audio: widget.audioDriver ?? EdoAudioDriver(),
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
    if (_shellMode == ShukubaShellMode.inValley ||
        _shellMode == ShukubaShellMode.loadingValley) {
      unawaited(_bootSceneStaged());
    }
  }

  void _onFrameTimings(List<ui.FrameTiming> timings) {
    if (!mounted) return;
    _frameTimer.ingestTimings(timings);
  }

  void _enterValley() {
    setState(() {
      _shellMode = ShukubaShellMode.loadingValley;
      _completedBootTimings.clear();
      _activeBootStage = BootStageId.lookAndShaders;
    });
    unawaited(_bootSceneStaged());
  }

  Future<void> _bootSceneStaged() async {
    try {
      final scene = Scene();
      _scene = scene;
      final report = await _controller.initializeStaged(
        scene: scene,
        camera: _cameraRig.camera,
        onStage: (stage, elapsedMs) {
          if (!mounted) return;
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
      _bootReport = report;
    } on Object catch (error, stack) {
      if (kShukubaAutoExit || kShukubaCaptureDir.isNotEmpty) {
        stderr.writeln('SHUKUBA_BOOT_ERROR:$error\n$stack');
      }
      if (kShukubaAutoExit) {
        exit(4);
      }
      await _controller.initialize();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _gpuAvailable = true;
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
        );
        unawaited(_executeCaptureSuite(harness));
      });
    }
  }

  Future<void> _saveUiPng(String filePath) async {
    for (var i = 0; i < 3; i++) {
      await ShukubaFrameHarness.pumpFrame();
    }
    final boundary = _uiRepaintBoundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      return;
    }
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        await File(filePath).writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
      }
    } finally {
      image.dispose();
    }
  }

  Future<List<String>> _captureUiAtlas(Directory uiDir) async {
    final saved = <String>[];
    _applyPresetForCapture(CameraPreset.duskOverview);
    setState(() {
      _forceRenderHudInCapture = true;
      _shellMode = ShukubaShellMode.titleMenu;
    });
    final titlePath = '${uiDir.path}/ui_title_menu.png';
    await _saveUiPng(titlePath);
    saved.add(titlePath);

    _controller.selectTool(const ExploreTool());
    setState(() => _shellMode = ShukubaShellMode.inValley);
    final calmPath = '${uiDir.path}/ui_hud_calm_default.png';
    await _saveUiPng(calmPath);
    saved.add(calmPath);

    _controller.selectTool(
      const StampStructureTool(kind: StructureKind.minka, variant: 1),
    );
    setState(() {});
    final drawerPath = '${uiDir.path}/ui_hud_dwellings_drawer.png';
    await _saveUiPng(drawerPath);
    saved.add(drawerPath);

    _controller.selectTool(const ExploreTool());
    setState(() => _shellMode = ShukubaShellMode.pauseMenu);
    final pausePath = '${uiDir.path}/ui_pause_menu.png';
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
    if (key == LogicalKeyboardKey.digit1) {
      _selectPreset(CameraPreset.duskOverview);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2) {
      _selectPreset(CameraPreset.nightMarket);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3) {
      _selectPreset(CameraPreset.riverCrossing);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4) {
      _selectPreset(CameraPreset.meadowCloseup);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit5) {
      _selectPreset(CameraPreset.countrysideVista);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit6) {
      _selectPreset(CameraPreset.horizonSunCanopy);
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
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    _focusNode.dispose();
    _controller.dispose();
    _scene?.dispose();
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
                      onOpenMenu: () => setState(
                        () => _shellMode = ShukubaShellMode.pauseMenu,
                      ),
                    ),
                  if (_shellMode == ShukubaShellMode.titleMenu)
                    TitleMenuOverlay(
                      onEnterValley: _enterValley,
                      audioDriver: _controller.audio,
                    ),
                  if (_shellMode == ShukubaShellMode.loadingValley)
                    LoadingCurtainOverlay(
                      activeStage: _activeBootStage,
                      completedTimings: _completedBootTimings,
                    ),
                  if (_shellMode == ShukubaShellMode.pauseMenu)
                    PauseMenuOverlay(
                      onResume: () => setState(
                        () => _shellMode = ShukubaShellMode.inValley,
                      ),
                      onReturnToTitle: () {
                        _controller.audio.dispose();
                        setState(() => _shellMode = ShukubaShellMode.titleMenu);
                      },
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
