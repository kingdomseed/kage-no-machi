import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_scene/audio.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_scene_soloud/flutter_scene_soloud.dart';
import 'package:kage_no_machi/shukuba/audio/edo_wav_synth.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart';

class _ValleyAudioListenerFollower extends Component {
  new(this._scene);

  final Scene _scene;

  @override
  void onMount() {
    _syncPose();
  }

  @override
  void update(double deltaSeconds) {
    _syncPose();
  }

  void _syncPose() {
    final (earPos, forward) = EdoAudioDriver.computeListenerPose(_scene.camera);
    final earVec = earPos.toVector3();
    node.lookAtFrom(earVec, earVec + forward.toVector3());
  }
}

class EdoAudioDriver implements ShukubaAudioDriver {
  new({this._wavBank, this.maxRecentNotes = 64});

  EdoWavBank? _wavBank;
  Future<void>? _prewarmFuture;
  final int maxRecentNotes;

  bool _isMuted = false;
  double _masterVolume = 1;

  final List<PlacementNoteEvent> _recentNotes = [];
  final Map<AmbientLoopKind, double> _currentLoopGains = {
    AmbientLoopKind.riverMurmur: 0.44,
    AmbientLoopKind.bambooWind: 0.34,
    AmbientLoopKind.nightCrickets: 0,
  };
  final Map<AmbientLoopKind, Vec3> _loopAnchors = {};

  final Map<EdoInstrument, AudioClip> _instrumentClips = {};
  final Map<AmbientLoopKind, AudioClip> _ambientClips = {};
  final Map<AmbientLoopKind, Node> _ambientNodes = {};
  final Map<AmbientLoopKind, ClipAudioSource> _ambientSources = {};
  final List<AudioVoice> _activeOneShotVoices = [];

  Scene? _scene;
  Node? _listenerNode;
  SoloudAudioEngine? _engine;
  AudioBus? _ambientBus;
  AudioBus? _instrumentsBus;
  AudioVoice? _lastOneShotVoice;
  String? _lastAttachError;
  bool _isNativeAudioActive = false;

  double get _effectiveGain => _isMuted ? 0.0 : _masterVolume;

  @override
  bool get isMuted => _isMuted;

  @override
  double get masterVolume => _masterVolume;

  bool get isWavBankLoaded => _wavBank != null;

  EdoWavBank get wavBank => _wavBank ??= EdoWavBank.synthesizeAll();

  bool get isNativeAudioActive => _isNativeAudioActive;

  int get loadedClipCount => _instrumentClips.length + _ambientClips.length;

  int get playingAmbientSourceCount =>
      _ambientSources.values.where((source) => source.isPlaying).length;

  Vec3? get listenerWorldPosition =>
      _listenerNode?.globalTransform.getTranslation().toVec3();

  bool get lastOneShotVoicePlaying => _lastOneShotVoice?.isPlaying ?? false;

  String? get lastAttachError => _lastAttachError;

  List<PlacementNoteEvent> get recentNotes =>
      List<PlacementNoteEvent>.unmodifiable(_recentNotes);

  Map<AmbientLoopKind, double> get currentLoopGains =>
      Map<AmbientLoopKind, double>.unmodifiable(_currentLoopGains);

  Map<AmbientLoopKind, Vec3> get loopAnchors =>
      Map<AmbientLoopKind, Vec3>.unmodifiable(_loopAnchors);

  static (Vec3 position, Vec3 forward) computeListenerPose(Camera? camera) {
    if (camera == null) {
      return (const Vec3(0, 10.5, 0), Vec3.forward);
    }
    final rawForward = camera.horizontalForward;
    final forward = rawForward.length2 > 1e-9
        ? Vec3(rawForward.x, 0, rawForward.z).normalized()
        : Vec3.forward;
    if (camera is PerspectiveCamera) {
      final target = camera.target;
      final dist = (camera.position - target).length;
      final earHeight = 3.5 + 0.18 * (dist - 12.0).clamp(0.0, 95.0);
      return (Vec3(target.x, target.y + earHeight, target.z), forward);
    }
    return (camera.position.toVec3(), forward);
  }

  static AudioAttenuation _createAmbientAttenuation() =>
      AudioAttenuation(minDistance: 12, maxDistance: 95, dopplerFactor: 0);

  static AudioAttenuation _createNoteAttenuation() => AudioAttenuation(
    minDistance: 18,
    maxDistance: 120,
    rolloffFactor: 0.65,
    dopplerFactor: 0,
  );

  @override
  Future<void> prewarm() {
    if (_wavBank != null) {
      return Future<void>.value();
    }
    return _prewarmFuture ??= () async {
      try {
        _wavBank = await Isolate.run(EdoWavBank.synthesizeAll);
      } catch (_) {
        _prewarmFuture = null;
        rethrow;
      }
    }();
  }

  @override
  void setMuted(bool muted) {
    if (_isMuted == muted) return;
    _isMuted = muted;
    _applyVolumes();
  }

  @override
  void setMasterVolume(double volume) {
    final clamped = volume.isNaN || volume < 0.0
        ? 0.0
        : volume > 1.0
        ? 1.0
        : volume;
    if (_masterVolume == clamped) return;
    _masterVolume = clamped;
    _applyVolumes();
  }

  void _applyVolumes() {
    if (!_isNativeAudioActive) return;
    _engine?.masterVolume = _effectiveGain;
    for (final kind in AmbientLoopKind.values) {
      final source = _ambientSources[kind];
      if (source != null) {
        source.volume = _currentLoopGains[kind] ?? 0;
      }
    }
  }

  void _teardownNativeScene() {
    for (final voice in _activeOneShotVoices) {
      voice.stop();
    }
    _activeOneShotVoices.clear();
    _lastOneShotVoice = null;

    for (final source in _ambientSources.values) {
      source.stop();
    }
    _ambientSources.clear();

    final scene = _scene;
    if (scene != null) {
      _ambientNodes.values.forEach(scene.root.remove);
      final listenerNode = _listenerNode;
      if (listenerNode != null) {
        scene.root.remove(listenerNode);
      }
      final engine = _engine;
      if (engine != null) {
        scene.root.removeComponent(engine);
      }
    }
    _ambientNodes.clear();
    _listenerNode = null;

    for (final clip in _instrumentClips.values) {
      clip.dispose();
    }
    _instrumentClips.clear();
    for (final clip in _ambientClips.values) {
      clip.dispose();
    }
    _ambientClips.clear();

    _engine = null;
    _ambientBus = null;
    _instrumentsBus = null;
    _scene = null;
    _isNativeAudioActive = false;
  }

  @override
  Future<void> attach(
    Scene? scene, {
    Map<AmbientLoopKind, Vec3> loopAnchors = const {},
  }) async {
    _teardownNativeScene();
    _lastAttachError = null;
    _loopAnchors.addAll(loopAnchors);
    _scene = scene;

    if (scene == null) {
      return;
    }

    if (_wavBank == null) {
      await prewarm();
    }
    final bank = wavBank;

    try {
      final initFailure = Completer<Never>();
      final engine = SoloudAudioEngine(bufferSize: 1024)
        ..masterVolume = _effectiveGain;
      runZonedGuarded(() => scene.root.addComponent(engine), (error, stack) {
        if (!initFailure.isCompleted) {
          initFailure.completeError(error, stack);
        }
      });
      _engine = engine;
      _ambientBus = engine.createBus('ambient');
      _instrumentsBus = engine.createBus('instruments');

      Future<AudioClip> loadGuarded(String key, Uint8List bytes) =>
          Future.any([engine.loadClipFromBytes(key, bytes), initFailure.future])
              .timeout(const Duration(seconds: 5));

      for (final inst in EdoInstrument.values) {
        final clipBytes = bank.clipForInstrument(inst);
        _instrumentClips[inst] = await loadGuarded(
          'edo_inst_${inst.name}',
          clipBytes,
        );
      }

      for (final kind in AmbientLoopKind.values) {
        final clipBytes = bank.clipForAmbient(kind);
        _ambientClips[kind] = await loadGuarded(
          'edo_ambient_${kind.name}',
          clipBytes,
        );
      }

      final listenerNode = Node(name: 'edo_audio_listener')
        ..addComponent(AudioListener())
        ..addComponent(_ValleyAudioListenerFollower(scene));
      scene.root.add(listenerNode);
      _listenerNode = listenerNode;

      for (final kind in AmbientLoopKind.values) {
        final clip = _ambientClips[kind];
        final anchor = _loopAnchors[kind] ?? Vec3.zero;
        final node = Node(name: 'ambient_${kind.name}')
          ..localTransform = Matrix4.translation(anchor.toVector3());

        final source = ClipAudioSource(
          clip: clip,
          looping: true,
          volume: _currentLoopGains[kind] ?? 0,
          bus: _ambientBus,
          attenuation: _createAmbientAttenuation(),
        );

        node.addComponent(source);
        scene.root.add(node);
        _ambientNodes[kind] = node;
        _ambientSources[kind] = source;
        source.play();
      }

      _isNativeAudioActive = true;
      await Future<void>.delayed(Duration.zero);
    } on Object catch (error, stack) {
      _lastAttachError = '$error';
      debugPrint('EdoAudioDriver.attach failed: $error\n$stack');
      _teardownNativeScene();
    }
  }

  @override
  void syncAtmosphere({
    required TimeOfDayRig rig,
    Map<AmbientLoopKind, Vec3>? loopAnchors,
  }) {
    _currentLoopGains[AmbientLoopKind.riverMurmur] = rig.riverMurmurGain;
    _currentLoopGains[AmbientLoopKind.bambooWind] = rig.bambooWindGain;
    _currentLoopGains[AmbientLoopKind.nightCrickets] = rig.nightCricketGain;

    if (loopAnchors != null) {
      _loopAnchors.addAll(loopAnchors);
      for (final entry in loopAnchors.entries) {
        final node = _ambientNodes[entry.key];
        if (node != null) {
          node.localTransform = Matrix4.translation(entry.value.toVector3());
        }
      }
    }

    _applyVolumes();
  }

  @override
  void playPlacementNote(PlacementNoteEvent event) {
    _recentNotes.add(event);
    if (_recentNotes.length > maxRecentNotes) {
      _recentNotes.removeAt(0);
    }
    _activeOneShotVoices.removeWhere((voice) => !voice.isPlaying);

    if (!_isMuted &&
        _masterVolume > 0 &&
        _isNativeAudioActive &&
        _engine != null) {
      final clip = _instrumentClips[event.instrument];
      if (clip != null && !clip.isDisposed) {
        final pos = event.position.toVector3();
        final attenuation = _createNoteAttenuation();
        final voice = _engine!.createVoice(clip)
          ..volume = event.volume
          ..pitch = event.pitchRatio
          ..setBus(_instrumentsBus)
          ..setPositional(true)
          ..update3d(pos, Vector3.zero(), attenuation)
          ..start()
          ..update3d(pos, Vector3.zero(), attenuation);
        _activeOneShotVoices.add(voice);
        _lastOneShotVoice = voice;
      }
    }
  }

  @override
  void dispose() {
    _prewarmFuture = null;
    _teardownNativeScene();
  }
}
