import 'dart:isolate';

import 'package:flutter_scene/audio.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_scene_soloud/flutter_scene_soloud.dart';
import 'package:kage_no_machi/shukuba/audio/edo_wav_synth.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart';

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

  Scene? _scene;
  SoloudAudioEngine? _engine;
  AudioBus? _ambientBus;
  AudioBus? _instrumentsBus;
  bool _isNativeAudioActive = false;

  double get _effectiveGain => _isMuted ? 0.0 : _masterVolume;

  @override
  bool get isMuted => _isMuted;

  @override
  double get masterVolume => _masterVolume;

  bool get isWavBankLoaded => _wavBank != null;

  EdoWavBank get wavBank => _wavBank ??= EdoWavBank.synthesizeAll();

  bool get isNativeAudioActive => _isNativeAudioActive;

  List<PlacementNoteEvent> get recentNotes =>
      List<PlacementNoteEvent>.unmodifiable(_recentNotes);

  Map<AmbientLoopKind, double> get currentLoopGains =>
      Map<AmbientLoopKind, double>.unmodifiable(_currentLoopGains);

  Map<AmbientLoopKind, Vec3> get loopAnchors =>
      Map<AmbientLoopKind, Vec3>.unmodifiable(_loopAnchors);

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
    _applyAmbientVolumes();
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
    _applyAmbientVolumes();
  }

  void _applyAmbientVolumes() {
    if (!_isNativeAudioActive) return;
    for (final kind in AmbientLoopKind.values) {
      final source = _ambientSources[kind];
      if (source != null) {
        source.volume = (_currentLoopGains[kind] ?? 0) * _effectiveGain;
      }
    }
  }

  @override
  Future<void> attach(
    Scene? scene, {
    Map<AmbientLoopKind, Vec3> loopAnchors = const {},
  }) async {
    _scene = scene;
    _loopAnchors.addAll(loopAnchors);

    if (scene == null) {
      _isNativeAudioActive = false;
      return;
    }

    if (_wavBank == null) {
      await prewarm();
    }
    final bank = wavBank;

    try {
      final engine = SoloudAudioEngine();
      scene.root.addComponent(engine);
      if (!engine.isLoaded) {
        await engine.onLoad();
      }

      _ambientBus = engine.createBus('ambient');
      _instrumentsBus = engine.createBus('instruments');

      for (final inst in EdoInstrument.values) {
        final clipBytes = bank.clipForInstrument(inst);
        _instrumentClips[inst] = await engine.loadClipFromBytes(
          'edo_inst_${inst.name}',
          clipBytes,
        );
      }

      for (final kind in AmbientLoopKind.values) {
        final clipBytes = bank.clipForAmbient(kind);
        _ambientClips[kind] = await engine.loadClipFromBytes(
          'edo_ambient_${kind.name}',
          clipBytes,
        );
      }

      for (final kind in AmbientLoopKind.values) {
        final clip = _ambientClips[kind];
        final anchor = _loopAnchors[kind] ?? Vec3.zero;
        final node = Node(name: 'ambient_${kind.name}')
          ..localTransform = Matrix4.translation(anchor.toVector3());

        final source = ClipAudioSource(
          clip: clip,
          looping: true,
          volume: (_currentLoopGains[kind] ?? 0) * _effectiveGain,
          bus: _ambientBus,
          attenuation: AudioAttenuation(minDistance: 5, maxDistance: 55),
        );

        node.addComponent(source);
        scene.root.add(node);
        _ambientNodes[kind] = node;
        _ambientSources[kind] = source;
        source.play();
      }

      _engine = engine;
      _isNativeAudioActive = true;
    } on Object catch (_) {
      _isNativeAudioActive = false;
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

    if (_isNativeAudioActive) {
      for (final kind in AmbientLoopKind.values) {
        final source = _ambientSources[kind];
        if (source != null) {
          source.volume = (_currentLoopGains[kind] ?? 0) * _effectiveGain;
        }
      }
    }
  }

  @override
  void playPlacementNote(PlacementNoteEvent event) {
    _recentNotes.add(event);
    if (_recentNotes.length > maxRecentNotes) {
      _recentNotes.removeAt(0);
    }

    if (!_isMuted &&
        _masterVolume > 0 &&
        _isNativeAudioActive &&
        _engine != null) {
      final clip = _instrumentClips[event.instrument];
      if (clip != null) {
        _engine!.playOneShot(
          clip,
          position: event.position.toVector3(),
          volume: event.volume * _masterVolume,
          pitch: event.pitchRatio,
          bus: _instrumentsBus,
          attenuation: AudioAttenuation(minDistance: 6, maxDistance: 60),
        );
      }
    }
  }

  @override
  void dispose() {
    _prewarmFuture = null;
    for (final source in _ambientSources.values) {
      source.stop();
    }
    for (final clip in _instrumentClips.values) {
      clip.dispose();
    }
    _instrumentClips.clear();
    for (final clip in _ambientClips.values) {
      clip.dispose();
    }
    _ambientClips.clear();

    final scene = _scene;
    if (scene != null) {
      _ambientNodes.values.forEach(scene.root.remove);
      final engine = _engine;
      if (engine != null) {
        scene.root.removeComponent(engine);
      }
    }

    _ambientNodes.clear();
    _ambientSources.clear();
    _engine = null;
    _scene = null;
    _isNativeAudioActive = false;
  }
}
