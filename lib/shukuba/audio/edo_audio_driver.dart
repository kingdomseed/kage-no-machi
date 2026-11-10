import 'package:flutter_scene/audio.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_scene_soloud/flutter_scene_soloud.dart';
import 'package:kage_no_machi/shukuba/audio/edo_wav_synth.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:vector_math/vector_math.dart';

/// Shukuba audio driver backed by synthesized 16-bit PCM WAV clips and
/// spatial 3D audio via [SoloudAudioEngine].
class EdoAudioDriver implements ShukubaAudioDriver {
  new({EdoWavBank? wavBank, this.maxRecentNotes = 64})
    : _wavBank = wavBank ?? EdoWavBank.synthesizeAll();

  final EdoWavBank _wavBank;
  final int maxRecentNotes;

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

  /// Synthesized PCM WAV clips bank.
  EdoWavBank get wavBank => _wavBank;

  /// Whether the native SoLoud audio backend is active.
  bool get isNativeAudioActive => _isNativeAudioActive;

  /// Bounded history of recent placement note events.
  List<PlacementNoteEvent> get recentNotes =>
      List<PlacementNoteEvent>.unmodifiable(_recentNotes);

  /// Current ambient loop gains keyed by kind.
  Map<AmbientLoopKind, double> get currentLoopGains =>
      Map<AmbientLoopKind, double>.unmodifiable(_currentLoopGains);

  /// Current 3D spatial anchor positions for ambient beds.
  Map<AmbientLoopKind, Vec3> get loopAnchors =>
      Map<AmbientLoopKind, Vec3>.unmodifiable(_loopAnchors);

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

    try {
      final engine = SoloudAudioEngine();
      scene.root.addComponent(engine);
      if (!engine.isLoaded) {
        await engine.onLoad();
      }

      _ambientBus = engine.createBus('ambient');
      _instrumentsBus = engine.createBus('instruments');

      for (final inst in EdoInstrument.values) {
        final clipBytes = _wavBank.clipForInstrument(inst);
        _instrumentClips[inst] = await engine.loadClipFromBytes(
          'edo_inst_${inst.name}',
          clipBytes,
        );
      }

      for (final kind in AmbientLoopKind.values) {
        final clipBytes = _wavBank.clipForAmbient(kind);
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
          volume: _currentLoopGains[kind] ?? 0,
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
          source.volume = _currentLoopGains[kind] ?? 0;
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

    if (_isNativeAudioActive && _engine != null) {
      final clip = _instrumentClips[event.instrument];
      if (clip != null) {
        _engine!.playOneShot(
          clip,
          position: event.position.toVector3(),
          volume: event.volume,
          pitch: event.pitchRatio,
          bus: _instrumentsBus,
          attenuation: AudioAttenuation(minDistance: 6, maxDistance: 60),
        );
      }
    }
  }

  @override
  void dispose() {
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
