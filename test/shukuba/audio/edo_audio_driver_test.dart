import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';

void main() {
  group('EdoWavSynth PCM WAV format and audio quality', () {
    const sampleRate = EdoWavSynth.defaultSampleRate;

    test('validates 44-byte RIFF/WAVE header fields on all 7 clips', () {
      final bank = EdoWavBank.synthesizeAll();
      final allClips = <String, Uint8List>{
        'koto': bank.kotoWav,
        'shakuhachi': bank.shakuhachiWav,
        'hyoshigi': bank.hyoshigiWav,
        'bonsho': bank.bonshoWav,
        'riverMurmur': bank.riverMurmurWav,
        'bambooWind': bank.bambooWindWav,
        'nightCrickets': bank.nightCricketsWav,
      };

      for (final entry in allClips.entries) {
        final bytes = entry.value;
        expect(
          bytes.length,
          greaterThanOrEqualTo(44),
          reason: '${entry.key} must be >= 44 bytes',
        );

        final bd = ByteData.sublistView(bytes);
        final riffTag = String.fromCharCodes(bytes.sublist(0, 4));
        expect(riffTag, 'RIFF', reason: '${entry.key} RIFF header');

        final totalFileSizeMinus8 = bd.getUint32(4, Endian.little);
        expect(
          totalFileSizeMinus8,
          bytes.length - 8,
          reason: '${entry.key} chunkSize',
        );

        final waveTag = String.fromCharCodes(bytes.sublist(8, 12));
        expect(waveTag, 'WAVE', reason: '${entry.key} WAVE header');

        final fmtTag = String.fromCharCodes(bytes.sublist(12, 16));
        expect(fmtTag, 'fmt ', reason: '${entry.key} fmt chunk header');

        final subchunk1Size = bd.getUint32(16, Endian.little);
        expect(subchunk1Size, 16, reason: '${entry.key} subchunk1Size');

        final audioFormat = bd.getUint16(20, Endian.little);
        expect(audioFormat, 1, reason: '${entry.key} audioFormat PCM');

        final numChannels = bd.getUint16(22, Endian.little);
        expect(numChannels, 1, reason: '${entry.key} mono channel');

        final clipRate = bd.getUint32(24, Endian.little);
        expect(clipRate, sampleRate, reason: '${entry.key} sampleRate');

        final byteRate = bd.getUint32(28, Endian.little);
        expect(byteRate, sampleRate * 2, reason: '${entry.key} byteRate');

        final blockAlign = bd.getUint16(32, Endian.little);
        expect(blockAlign, 2, reason: '${entry.key} blockAlign');

        final bitsPerSample = bd.getUint16(34, Endian.little);
        expect(bitsPerSample, 16, reason: '${entry.key} bitsPerSample');

        final dataTag = String.fromCharCodes(bytes.sublist(36, 40));
        expect(dataTag, 'data', reason: '${entry.key} data chunk header');

        final dataSize = bd.getUint32(40, Endian.little);
        expect(
          dataSize,
          bytes.length - 44,
          reason: '${entry.key} subchunk2Size matches byte count',
        );
      }
    });

    test('synthesizes exact payload byte counts for 4.0s ambient loops', () {
      final bank = EdoWavBank.synthesizeAll();
      const expectedSampleCount = 4 * sampleRate;
      const expectedDataBytes = expectedSampleCount * 2;
      const expectedTotalBytes = 44 + expectedDataBytes;

      final ambientClips = [
        bank.riverMurmurWav,
        bank.bambooWindWav,
        bank.nightCricketsWav,
      ];

      for (final clip in ambientClips) {
        expect(clip.length, equals(expectedTotalBytes));
      }
    });

    test('produces non-silent RMS and finite unclamped samples on all 7', () {
      final bank = EdoWavBank.synthesizeAll();
      final clips = [
        bank.kotoWav,
        bank.shakuhachiWav,
        bank.hyoshigiWav,
        bank.bonshoWav,
        bank.riverMurmurWav,
        bank.bambooWindWav,
        bank.nightCricketsWav,
      ];

      for (final clip in clips) {
        final floats = EdoWavSynth.decodeWav16MonoToFloat(clip);
        expect(floats.isNotEmpty, isTrue);

        var sumSq = 0.0;
        var maxAbs = 0.0;
        for (final s in floats) {
          expect(s.isFinite, isTrue);
          expect(s, inInclusiveRange(-1, 1));
          final abs = s.abs();
          if (abs > maxAbs) {
            maxAbs = abs;
          }
          sumSq += s * s;
        }

        final rms = math.sqrt(sumSq / floats.length);
        expect(rms, greaterThan(0.04));
        expect(maxAbs, greaterThan(0.20));
        expect(maxAbs, lessThanOrEqualTo(0.95));
      }
    });

    test('seamless loop wrap continuity has zero click discontinuity', () {
      final bank = EdoWavBank.synthesizeAll();
      final ambientLoops = [
        bank.riverMurmurWav,
        bank.bambooWindWav,
        bank.nightCricketsWav,
      ];

      for (final clip in ambientLoops) {
        final floats = EdoWavSynth.decodeWav16MonoToFloat(clip);
        final firstSample = floats.first;
        final lastSample = floats.last;
        final delta = (firstSample - lastSample).abs();

        expect(
          delta,
          lessThan(0.015),
          reason: 'Loop wrap jump must be under 0.015 full-scale',
        );
      }
    });

    test('one-shot instruments have click-free envelopes at start/end', () {
      final bank = EdoWavBank.synthesizeAll();
      final instruments = [
        bank.kotoWav,
        bank.shakuhachiWav,
        bank.hyoshigiWav,
        bank.bonshoWav,
      ];

      for (final clip in instruments) {
        final floats = EdoWavSynth.decodeWav16MonoToFloat(clip);
        expect(floats.first.abs(), lessThan(0.01));
        expect(floats.last.abs(), lessThan(0.01));
      }
    });

    test('verifies concert D4 tuning on koto via spectral energy', () {
      final kotoWav = EdoWavSynth.synthesizeKoto();
      final floats = EdoWavSynth.decodeWav16MonoToFloat(kotoWav);

      final energyD4 = _computeDftEnergy(
        floats,
        PentatonicScale.rootD4Hz,
        sampleRate,
        startSample: 3000,
        sampleCount: 22050,
      );
      final energyLow = _computeDftEnergy(
        floats,
        220,
        sampleRate,
        startSample: 3000,
        sampleCount: 22050,
      );
      final energyHigh = _computeDftEnergy(
        floats,
        370,
        sampleRate,
        startSample: 3000,
        sampleCount: 22050,
      );

      expect(energyD4, greaterThan(energyLow * 5));
      expect(energyD4, greaterThan(energyHigh * 5));
    });

    test('verifies concert D4 tuning on shakuhachi via spectral energy', () {
      final shakuhachiWav = EdoWavSynth.synthesizeShakuhachi();
      final floats = EdoWavSynth.decodeWav16MonoToFloat(shakuhachiWav);

      final energyD4 = _computeDftEnergy(
        floats,
        PentatonicScale.rootD4Hz,
        sampleRate,
        startSample: 6000,
        sampleCount: 22050,
      );
      final energyLow = _computeDftEnergy(
        floats,
        220,
        sampleRate,
        startSample: 6000,
        sampleCount: 22050,
      );
      final energyHigh = _computeDftEnergy(
        floats,
        370,
        sampleRate,
        startSample: 6000,
        sampleCount: 22050,
      );

      expect(energyD4, greaterThan(energyLow * 8));
      expect(energyD4, greaterThan(energyHigh * 8));
    });
  });

  group('EdoAudioDriver lifecycle, atmosphere sync, and note placement', () {
    test('initializes and exposes immutable inspector state', () {
      final driver = EdoAudioDriver();
      expect(driver.wavBank, isNotNull);
      expect(driver.recentNotes, isEmpty);
      expect(
        driver.currentLoopGains[AmbientLoopKind.riverMurmur],
        equals(0.15),
      );
      expect(driver.currentLoopGains[AmbientLoopKind.bambooWind], equals(0.18));
      expect(driver.currentLoopGains[AmbientLoopKind.nightCrickets], equals(0));
      expect(EdoAudioDriver.defaultMusicGain, equals(0.24));
      expect(driver.isMusicPlaying, isFalse);
      expect(driver.isNativeAudioActive, isFalse);
    });

    test('prewarm synthesizes wavBank asynchronously and deduplicates '
        'in-flight calls', () async {
      final driver = EdoAudioDriver();
      expect(driver.isWavBankLoaded, isFalse);

      final f1 = driver.prewarm();
      final f2 = driver.prewarm();
      expect(identical(f1, f2), isTrue);

      await f1;
      expect(driver.isWavBankLoaded, isTrue);
      expect(driver.wavBank, isNotNull);

      await driver.prewarm();
      expect(driver.isWavBankLoaded, isTrue);
    });

    test(
      'attaches cleanly with loop anchors and falls back without throwing',
      () async {
        final scene = _tryScene();
        final driver = EdoAudioDriver();

        const anchors = {
          AmbientLoopKind.riverMurmur: Vec3(-10, 0, 8),
          AmbientLoopKind.bambooWind: Vec3(12, 1, -15),
          AmbientLoopKind.nightCrickets: Vec3.zero,
        };

        await driver.attach(scene, loopAnchors: anchors);

        expect(driver.loopAnchors, equals(anchors));
        expect(driver.isNativeAudioActive, isA<bool>());
      },
    );

    test('syncAtmosphere tracks Golden Dusk vs Blue Hour Night curves', () {
      final driver = EdoAudioDriver()
        ..syncAtmosphere(rig: TimeOfDayRig.goldenDusk);
      final duskGains = driver.currentLoopGains;
      expect(
        duskGains[AmbientLoopKind.riverMurmur],
        closeTo(TimeOfDayRig.goldenDusk.riverMurmurGain, 1e-4),
      );
      expect(
        duskGains[AmbientLoopKind.bambooWind],
        closeTo(TimeOfDayRig.goldenDusk.bambooWindGain, 1e-4),
      );
      expect(
        duskGains[AmbientLoopKind.nightCrickets],
        closeTo(TimeOfDayRig.goldenDusk.nightCricketGain, 1e-4),
      );
      expect(duskGains[AmbientLoopKind.nightCrickets], equals(0));

      driver.syncAtmosphere(rig: TimeOfDayRig.blueHourNight);
      final nightGains = driver.currentLoopGains;
      expect(
        nightGains[AmbientLoopKind.riverMurmur],
        closeTo(TimeOfDayRig.blueHourNight.riverMurmurGain, 1e-4),
      );
      expect(
        nightGains[AmbientLoopKind.bambooWind],
        closeTo(TimeOfDayRig.blueHourNight.bambooWindGain, 1e-4),
      );
      expect(
        nightGains[AmbientLoopKind.nightCrickets],
        closeTo(TimeOfDayRig.blueHourNight.nightCricketGain, 1e-4),
      );
      expect(nightGains[AmbientLoopKind.nightCrickets], greaterThan(0.08));
      expect(
        nightGains[AmbientLoopKind.nightCrickets],
        lessThanOrEqualTo(0.14),
      );
      expect(
        nightGains[AmbientLoopKind.riverMurmur],
        lessThan(duskGains[AmbientLoopKind.riverMurmur]!),
      );
      expect(
        nightGains[AmbientLoopKind.bambooWind],
        lessThan(duskGains[AmbientLoopKind.bambooWind]!),
      );
    });

    test('playPlacementNote emits Yo below 0.55 and In-sen at/above 0.55', () {
      final driver = EdoAudioDriver();

      const snapDusk = SnappedPlacement(
        position: Vec3(3, 0, 6),
        yawRadians: 0,
        scaleDegree: 0,
      );
      final noteDusk = PlacementNoteEvent.fromSnap(
        instrument: EdoInstrument.koto,
        rig: TimeOfDayRig.goldenDusk,
        snapped: snapDusk,
      );
      expect(noteDusk.scale, PentatonicScale.yo);
      expect(noteDusk.pitchRatio, closeTo(1, 1e-6));
      expect(noteDusk.frequencyHz, closeTo(293.6648, 1e-3));

      driver.playPlacementNote(noteDusk);
      expect(driver.recentNotes, hasLength(1));
      expect(driver.recentNotes.last, equals(noteDusk));

      const snapBoundaryYo = SnappedPlacement(
        position: Vec3(1, 0, 1),
        yawRadians: 0,
        scaleDegree: 3,
      );
      final noteBoundaryYo = PlacementNoteEvent.fromSnap(
        instrument: EdoInstrument.hyoshigi,
        rig: const TimeOfDayRig(0.549),
        snapped: snapBoundaryYo,
      );
      expect(noteBoundaryYo.scale, PentatonicScale.yo);
      expect(noteBoundaryYo.frequencyHz, closeTo(440, 1e-3));
      driver.playPlacementNote(noteBoundaryYo);
      expect(driver.recentNotes, hasLength(2));

      const snapBoundaryInSen = SnappedPlacement(
        position: Vec3(4, 0, -2),
        yawRadians: 0,
        scaleDegree: 1,
      );
      final noteBoundaryInSen = PlacementNoteEvent.fromSnap(
        instrument: EdoInstrument.shakuhachi,
        rig: const TimeOfDayRig(0.55),
        snapped: snapBoundaryInSen,
      );
      expect(noteBoundaryInSen.scale, PentatonicScale.inSen);
      expect(noteBoundaryInSen.frequencyHz, closeTo(311.127, 1e-3));
      driver.playPlacementNote(noteBoundaryInSen);
      expect(driver.recentNotes, hasLength(3));

      const snapNight = SnappedPlacement(
        position: Vec3(7, 2, -5),
        yawRadians: 0,
        scaleDegree: 4,
      );
      final noteNight = PlacementNoteEvent.fromSnap(
        instrument: EdoInstrument.bonsho,
        rig: TimeOfDayRig.blueHourNight,
        snapped: snapNight,
      );
      expect(noteNight.scale, PentatonicScale.inSen);
      expect(noteNight.frequencyHz, closeTo(523.251, 1e-3));
      driver.playPlacementNote(noteNight);
      expect(driver.recentNotes, hasLength(4));
    });

    test('bounds recentNotes history without unbounded memory growth', () {
      final driver = EdoAudioDriver(maxRecentNotes: 8);
      const snap = SnappedPlacement(
        position: Vec3.zero,
        yawRadians: 0,
        scaleDegree: 0,
      );

      for (var i = 0; i < 20; i++) {
        final note = PlacementNoteEvent.fromSnap(
          instrument: EdoInstrument.koto,
          rig: TimeOfDayRig.goldenDusk,
          snapped: snap,
        );
        driver.playPlacementNote(note);
      }

      expect(driver.recentNotes.length, equals(8));
    });

    test('disposes cleanly without throwing', () async {
      final scene = _tryScene();
      final driver = EdoAudioDriver();
      await driver.attach(scene);
      driver.dispose();
      expect(driver.isNativeAudioActive, isFalse);
    });

    test('computes valley-focal listener pose across camera zoom levels', () {
      final (nullPos, nullFwd) = EdoAudioDriver.computeListenerPose(null);
      expect(nullPos, equals(const Vec3(0, 10.5, 0)));
      expect(nullFwd, equals(Vec3.forward));

      final closeCam = PerspectiveCamera(
        position:
            CameraPreset.duskOverview.target.toVector3() +
            (CameraPreset.duskOverview.eye - CameraPreset.duskOverview.target)
                    .normalized()
                    .toVector3() *
                12,
        target: CameraPreset.duskOverview.target.toVector3(),
      );
      final (closePos, closeFwd) = EdoAudioDriver.computeListenerPose(closeCam);
      expect(
        closePos.y,
        closeTo(CameraPreset.duskOverview.target.y + 3.5, 1e-4),
      );
      expect(closePos.x, closeTo(CameraPreset.duskOverview.target.x, 1e-4));
      expect(closePos.z, closeTo(CameraPreset.duskOverview.target.z, 1e-4));
      expect(closeFwd.y, equals(0));
      expect(closeFwd.length, closeTo(1, 1e-5));

      final duskCam = CameraPreset.duskOverview.toPerspectiveCamera();
      final duskDist = (duskCam.position - duskCam.target).length;
      final expectedDuskHeight =
          3.5 + 0.18 * (duskDist - 12.0).clamp(0.0, 95.0);
      final (duskPos, duskFwd) = EdoAudioDriver.computeListenerPose(duskCam);
      expect(
        duskPos.y,
        closeTo(CameraPreset.duskOverview.target.y + expectedDuskHeight, 1e-4),
      );
      expect(duskFwd.x, closeTo(duskCam.horizontalForward.x, 1e-5));
      expect(duskFwd.z, closeTo(duskCam.horizontalForward.z, 1e-5));

      final vistaCam = CameraPreset.countrysideVista.toPerspectiveCamera();
      final (vistaPos, _) = EdoAudioDriver.computeListenerPose(vistaCam);
      expect(
        vistaPos.y,
        closeTo(CameraPreset.countrysideVista.target.y + 20.6, 1e-4),
      );
    });

    test('exposes diagnostics and preserves wavBank across dispose', () async {
      final driver = EdoAudioDriver();
      expect(driver.loadedClipCount, equals(0));
      expect(driver.playingAmbientSourceCount, equals(0));
      expect(driver.listenerWorldPosition, isNull);
      expect(driver.lastOneShotVoicePlaying, isFalse);
      expect(driver.lastAttachError, isNull);

      driver
        ..setMuted(true)
        ..setMasterVolume(double.nan);
      expect(driver.isMuted, isTrue);
      expect(driver.masterVolume, equals(0));

      driver
        ..setMasterVolume(-0.4)
        ..setMasterVolume(2.5);
      expect(driver.masterVolume, equals(1));
      driver.setMuted(false);

      await driver.prewarm();
      expect(driver.isWavBankLoaded, isTrue);

      await driver.attach(null);
      driver.dispose();
      await driver.attach(null);
      expect(driver.isWavBankLoaded, isTrue);
      await driver.prewarm();
      expect(driver.isWavBankLoaded, isTrue);
    });

    test(
      'startMenuMusic and transition to attach/dispose complete cleanly',
      () async {
        final driver = EdoAudioDriver();
        await driver.startMenuMusic();
        expect(driver.isMusicPlaying, isA<bool>());
        expect(driver.isNativeAudioActive, isA<bool>());

        final scene = _tryScene();
        await driver.attach(scene);
        expect(driver.isNativeAudioActive, isA<bool>());

        driver.dispose();
        expect(driver.isMusicPlaying, isFalse);
        expect(driver.isNativeAudioActive, isFalse);
      },
    );
  });
}

Scene? _tryScene() {
  try {
    return Scene();
  } on Object catch (_) {
    return null;
  }
}

double _computeDftEnergy(
  Float64List samples,
  double freqHz,
  int sampleRate, {
  required int startSample,
  required int sampleCount,
}) {
  var real = 0.0;
  var imag = 0.0;
  final w = 2.0 * math.pi * freqHz / sampleRate;
  for (var i = 0; i < sampleCount; i++) {
    final s = samples[startSample + i];
    final angle = w * i;
    real += s * math.cos(angle);
    imag -= s * math.sin(angle);
  }
  return real * real + imag * imag;
}
