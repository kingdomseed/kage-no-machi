import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';

abstract final class EdoWavSynth {
  static const int defaultSampleRate = 44100;
  static const double defaultLoopDurationSeconds = 4;
  static const double rootD4Hz = PentatonicScale.rootD4Hz;

  static Uint8List synthesizeInstrument(
    EdoInstrument instrument, {
    int sampleRate = defaultSampleRate,
  }) => switch (instrument) {
    EdoInstrument.koto => synthesizeKoto(sampleRate: sampleRate),
    EdoInstrument.shakuhachi => synthesizeShakuhachi(sampleRate: sampleRate),
    EdoInstrument.hyoshigi => synthesizeHyoshigi(sampleRate: sampleRate),
    EdoInstrument.bonsho => synthesizeBonsho(sampleRate: sampleRate),
  };

  static Uint8List synthesizeAmbient(
    AmbientLoopKind kind, {
    int sampleRate = defaultSampleRate,
    double durationSeconds = defaultLoopDurationSeconds,
  }) => switch (kind) {
    AmbientLoopKind.riverMurmur => synthesizeRiverMurmur(
      sampleRate: sampleRate,
      durationSeconds: durationSeconds,
    ),
    AmbientLoopKind.bambooWind => synthesizeBambooWind(
      sampleRate: sampleRate,
      durationSeconds: durationSeconds,
    ),
    AmbientLoopKind.nightCrickets => synthesizeNightCrickets(
      sampleRate: sampleRate,
      durationSeconds: durationSeconds,
    ),
  };

  static Uint8List synthesizeKoto({int sampleRate = defaultSampleRate}) {
    const duration = 2.2;
    final totalSamples = (duration * sampleRate).round();
    final samples = Float64List(totalSamples);

    final exactPeriod = sampleRate / rootD4Hz;
    final exactDelay = exactPeriod - 0.5;
    final intDelay = exactDelay.floor();
    final frac = exactDelay - intDelay;

    final bufferSize = intDelay + 16;
    final ring = Float64List(bufferSize);

    final rng = _FastRng(0x5A170);
    for (var i = 0; i < intDelay; i++) {
      final p = i / intDelay;
      final tri = p < 0.22 ? (p / 0.22) : ((1 - p) / 0.78);
      final noise = (rng.nextDouble() * 2 - 1) * 0.35;
      ring[i] = tri + noise;
    }

    final bp195 = _BiquadBandpass(195, 3.5, sampleRate);
    final bp420 = _BiquadBandpass(420, 4, sampleRate);

    var writePos = 0;
    var prevVal = 0.0;
    const decay = 0.9942;

    for (var n = 0; n < totalSamples; n++) {
      var idx0 = writePos - intDelay;
      while (idx0 < 0) {
        idx0 += bufferSize;
      }
      var idx1 = idx0 - 1;
      while (idx1 < 0) {
        idx1 += bufferSize;
      }

      final interpolated = (1 - frac) * ring[idx0] + frac * ring[idx1];
      final filtered = 0.5 * (interpolated + prevVal) * decay;
      prevVal = interpolated;
      ring[writePos] = filtered;
      writePos = (writePos + 1) % bufferSize;

      final body1 = bp195.process(filtered);
      final body2 = bp420.process(filtered);
      samples[n] = 0.62 * filtered + 0.22 * body1 + 0.16 * body2;
    }

    _applyFadeOut(samples, (0.06 * sampleRate).round());
    return encodeWav16Mono(samples, sampleRate: sampleRate);
  }

  static Uint8List synthesizeShakuhachi({int sampleRate = defaultSampleRate}) {
    const duration = 2.2;
    final totalSamples = (duration * sampleRate).round();
    final samples = Float64List(totalSamples);

    final bpBreath = _BiquadBandpass(1900, 1.8, sampleRate);
    final rng = _FastRng(0x58A3);

    var phase = 0.0;
    final dt = 1.0 / sampleRate;

    for (var n = 0; n < totalSamples; n++) {
      final t = n * dt;

      var vibratoDepth = 0.0;
      if (t > 0.35) {
        final progress = (t - 0.35) / 0.50;
        vibratoDepth = progress >= 1 ? 0.012 : progress * 0.012;
      }
      final vibrato = math.sin(2 * math.pi * 4.8 * t) * vibratoDepth;
      final fInst = rootD4Hz * (1 + vibrato);

      phase += 2 * math.pi * fInst * dt;
      if (phase >= 2 * math.pi) {
        phase -= 2 * math.pi;
      }

      final h1 = math.sin(phase);
      final h2 = math.sin(2 * phase) * 0.28;
      final h3 = math.sin(3 * phase) * 0.11;
      final h4 = math.sin(4 * phase) * 0.035;
      final tone = h1 + h2 + h3 + h4;

      final rawNoise = rng.nextDouble() * 2 - 1;
      final filteredNoise = bpBreath.process(rawNoise);

      final chiffEnv = t < 0.03 ? (t / 0.03) : math.exp(-(t - 0.03) / 0.07);
      final breathAmount = 0.05 + 0.40 * chiffEnv;

      double amp;
      if (t < 0.09) {
        amp = t / 0.09;
      } else if (t < 1.80) {
        amp = 1;
      } else {
        final rel = (t - 1.80) / 0.40;
        amp = 0.5 * (1 + math.cos(math.pi * rel));
      }

      samples[n] = amp * (tone * 0.85 + filteredNoise * breathAmount);
    }

    _applyFadeOut(samples, (0.04 * sampleRate).round());
    return encodeWav16Mono(samples, sampleRate: sampleRate);
  }

  static Uint8List synthesizeHyoshigi({int sampleRate = defaultSampleRate}) {
    const duration = 0.65;
    final totalSamples = (duration * sampleRate).round();
    final samples = Float64List(totalSamples);

    const d5Hz = rootD4Hz * 2;
    final rng = _FastRng(0x48A0);
    final dt = 1.0 / sampleRate;

    for (var n = 0; n < totalSamples; n++) {
      final t = n * dt;

      final mD5 =
          math.sin(2 * math.pi * d5Hz * t) * math.exp(-t / 0.075) * 0.85;
      final mD4 =
          math.sin(2 * math.pi * rootD4Hz * t) * math.exp(-t / 0.110) * 0.50;
      final mHigh1 =
          math.sin(2 * math.pi * (d5Hz * 2.756) * t) *
          math.exp(-t / 0.035) *
          0.38;
      final mHigh2 =
          math.sin(2 * math.pi * (d5Hz * 5.404) * t) *
          math.exp(-t / 0.020) *
          0.22;
      final mHigh3 =
          math.sin(2 * math.pi * (d5Hz * 8.930) * t) *
          math.exp(-t / 0.012) *
          0.14;

      final crackNoise = rng.nextDouble() * 2 - 1;
      final crack = crackNoise * math.exp(-t / 0.0028) * 1.6;

      samples[n] = mD5 + mD4 + mHigh1 + mHigh2 + mHigh3 + crack;
    }

    _applyFadeOut(samples, (0.04 * sampleRate).round());
    return encodeWav16Mono(samples, sampleRate: sampleRate);
  }

  static Uint8List synthesizeBonsho({int sampleRate = defaultSampleRate}) {
    const duration = 3.6;
    final totalSamples = (duration * sampleRate).round();
    final samples = Float64List(totalSamples);
    final dt = 1.0 / sampleRate;

    const fHum = 0.5 * rootD4Hz;
    const fPrime = rootD4Hz;
    const fTierce = 1.19 * rootD4Hz;
    const fNominal = 2 * rootD4Hz;
    const fSuperFifth = 2.76 * rootD4Hz;

    for (var n = 0; n < totalSamples; n++) {
      final t = n * dt;

      final hum =
          (math.sin(2 * math.pi * fHum * t) +
              0.5 * math.sin(2 * math.pi * (fHum + 0.72) * t)) *
          math.exp(-t / 3.2) *
          0.65;

      final prime =
          (math.sin(2 * math.pi * fPrime * t) +
              0.55 * math.sin(2 * math.pi * (fPrime + 1.35) * t)) *
          math.exp(-t / 2.8) *
          0.90;

      final tierce =
          (math.sin(2 * math.pi * fTierce * t) +
              0.45 * math.sin(2 * math.pi * (fTierce + 1.62) * t)) *
          math.exp(-t / 2.4) *
          0.60;

      final nominal =
          (math.sin(2 * math.pi * fNominal * t) +
              0.35 * math.sin(2 * math.pi * (fNominal + 1.95) * t)) *
          math.exp(-t / 1.8) *
          0.40;

      final decima =
          math.sin(2 * math.pi * fSuperFifth * t) * math.exp(-t / 1.4) * 0.30;

      final p6 =
          math.sin(2 * math.pi * (4.07 * rootD4Hz) * t) *
          math.exp(-t / 0.9) *
          0.16;
      final p7 =
          math.sin(2 * math.pi * (5.43 * rootD4Hz) * t) *
          math.exp(-t / 0.6) *
          0.10;

      final malletThump =
          math.sin(2 * math.pi * 78 * t) * math.exp(-t / 0.022) * 0.75;

      samples[n] =
          hum + prime + tierce + nominal + decima + p6 + p7 + malletThump;
    }

    _applyFadeOut(samples, (0.08 * sampleRate).round());
    return encodeWav16Mono(samples, sampleRate: sampleRate);
  }

  static Uint8List synthesizeRiverMurmur({
    int sampleRate = defaultSampleRate,
    double durationSeconds = defaultLoopDurationSeconds,
  }) {
    final loopSamples = (durationSeconds * sampleRate).round();
    final crossfadeSamples = (0.12 * sampleRate).round();
    final totalGen = loopSamples + crossfadeSamples;
    final raw = Float64List(totalGen);

    final bpLow = _BiquadBandpass(240, 1.5, sampleRate);
    final bpMid = _BiquadBandpass(780, 2, sampleRate);
    final bpHig = _BiquadBandpass(3100, 1.8, sampleRate);
    final rng = _FastRng(0x1337);
    final dt = 1.0 / sampleRate;

    final bubbleOffsets = [0.45, 1.15, 1.85, 2.55, 3.25, 3.85];
    final bubbleFreqs = [980.0, 1280.0, 1050.0, 1390.0, 1140.0, 1220.0];

    for (var n = 0; n < totalGen; n++) {
      final t = n * dt;
      final white = rng.nextDouble() * 2 - 1;

      final lowRush = bpLow.process(white) * 0.55;

      final midMod =
          0.70 +
          0.20 * math.sin(2 * math.pi * 0.75 * t) +
          0.10 * math.sin(2 * math.pi * 1.25 * t);
      final midRush = bpMid.process(white) * midMod * 0.40;

      final higSpray = bpHig.process(white) * 0.18;

      var bubbles = 0.0;
      for (var b = 0; b < bubbleOffsets.length; b++) {
        final relT = (t - bubbleOffsets[b]) % durationSeconds;
        if (relT >= 0 && relT < 0.035) {
          final fChirp = bubbleFreqs[b] * (1 + relT * 4);
          final env = math.sin(math.pi * (relT / 0.035));
          bubbles += math.sin(2 * math.pi * fChirp * relT) * env * 0.22;
        }
      }

      raw[n] = lowRush + midRush + higSpray + bubbles;
    }

    final seamless = _wrapCircularCrossfade(raw, loopSamples, crossfadeSamples);
    return encodeWav16Mono(seamless, sampleRate: sampleRate, isLoop: true);
  }

  static Uint8List synthesizeBambooWind({
    int sampleRate = defaultSampleRate,
    double durationSeconds = defaultLoopDurationSeconds,
  }) {
    final loopSamples = (durationSeconds * sampleRate).round();
    final crossfadeSamples = (0.14 * sampleRate).round();
    final totalGen = loopSamples + crossfadeSamples;
    final raw = Float64List(totalGen);

    final bpCulm1 = _BiquadBandpass(480, 4, sampleRate);
    final bpCulm2 = _BiquadBandpass(720, 4.5, sampleRate);
    final bpCulm3 = _BiquadBandpass(1150, 5, sampleRate);
    final bpWind = _BiquadBandpass(380, 2, sampleRate);

    final rng = _FastRng(0x8A41);
    final dt = 1.0 / sampleRate;

    for (var n = 0; n < totalGen; n++) {
      final t = n * dt;
      final white = rng.nextDouble() * 2 - 1;

      final windGain =
          0.65 +
          0.25 * math.sin(2 * math.pi * (1 / durationSeconds) * t) +
          0.10 * math.sin(2 * math.pi * (2 / durationSeconds) * t);
      final wind = bpWind.process(white) * windGain * 0.55;

      final gust1 = math.max<double>(
        0,
        math.sin(2 * math.pi * (1 / durationSeconds) * t),
      );
      final gust2 = math.max<double>(
        0,
        math.sin(2 * math.pi * (3 / durationSeconds) * t + 0.8),
      );

      final c1 = bpCulm1.process(white) * gust1 * 0.25;
      final c2 = bpCulm2.process(white) * gust2 * 0.18;
      final c3 = bpCulm3.process(white) * gust1 * gust2 * 0.12;

      raw[n] = wind + c1 + c2 + c3;
    }

    final seamless = _wrapCircularCrossfade(raw, loopSamples, crossfadeSamples);
    return encodeWav16Mono(seamless, sampleRate: sampleRate, isLoop: true);
  }

  static Uint8List synthesizeNightCrickets({
    int sampleRate = defaultSampleRate,
    double durationSeconds = defaultLoopDurationSeconds,
  }) {
    final loopSamples = (durationSeconds * sampleRate).round();
    final samples = Float64List(loopSamples);
    final dt = 1.0 / sampleRate;

    const f1 = 4300;
    const f2 = 4375;

    for (var n = 0; n < loopSamples; n++) {
      final t = n * dt;

      var pulse = 0.0;

      if (t >= 0.28 && t <= 1.25) {
        final phraseT = t - 0.28;
        final chirpIdx = (phraseT * 28).floor();
        final chirpFrac = (phraseT * 28) - chirpIdx;
        if (chirpFrac < 0.65) {
          final env = math.sin(math.pi * (chirpFrac / 0.65));
          final carrier =
              math.sin(2 * math.pi * f1 * t) +
              0.16 * math.sin(2 * math.pi * (f1 * 2) * t);
          pulse += carrier * env * 0.70;
        }
      }

      if (t >= 1.75 && t <= 2.65) {
        final phraseT = t - 1.75;
        final chirpIdx = (phraseT * 30).floor();
        final chirpFrac = (phraseT * 30) - chirpIdx;
        if (chirpFrac < 0.60) {
          final env = math.sin(math.pi * (chirpFrac / 0.60));
          final carrier =
              math.sin(2 * math.pi * f2 * t) +
              0.12 * math.sin(2 * math.pi * (f2 * 2) * t);
          pulse += carrier * env * 0.42;
        }
      }

      if (t >= 3.05 && t <= 3.65) {
        final phraseT = t - 3.05;
        final chirpIdx = (phraseT * 26).floor();
        final chirpFrac = (phraseT * 26) - chirpIdx;
        if (chirpFrac < 0.65) {
          final env = math.sin(math.pi * (chirpFrac / 0.65));
          final carrier =
              math.sin(2 * math.pi * f1 * t) +
              0.15 * math.sin(2 * math.pi * (f1 * 2) * t);
          pulse += carrier * env * 0.62;
        }
      }

      samples[n] = pulse;
    }

    return encodeWav16Mono(samples, sampleRate: sampleRate, isLoop: true);
  }

  static Uint8List encodeWav16Mono(
    List<double> rawSamples, {
    required int sampleRate,
    bool isLoop = false,
  }) {
    final count = rawSamples.length;
    final processed = Float64List(count);

    var sum = 0.0;
    for (var i = 0; i < count; i++) {
      final s = rawSamples[i];
      final finite = s.isFinite ? s : 0.0;
      processed[i] = finite;
      sum += finite;
    }
    final dcBias = count > 0 ? sum / count : 0.0;

    var maxAbs = 0.0;
    for (var i = 0; i < count; i++) {
      final uncorrected = processed[i] - dcBias;
      processed[i] = uncorrected;
      final abs = uncorrected.abs();
      if (abs > maxAbs) {
        maxAbs = abs;
      }
    }

    final scaleFactor = maxAbs > 1e-9 ? (0.90 / maxAbs) : 1;
    final clampedInt16 = Int16List(count);

    if (!isLoop) {
      final fadeLen = math.min(128, count ~/ 4);
      for (var i = 0; i < fadeLen; i++) {
        final w = 0.5 * (1 - math.cos(math.pi * i / fadeLen));
        processed[i] *= w;
        final endIdx = count - 1 - i;
        processed[endIdx] *= w;
      }
    }

    for (var i = 0; i < count; i++) {
      final scaled = processed[i] * scaleFactor * 32767.0;
      final rounded = scaled.round();
      clampedInt16[i] = rounded > 32767
          ? 32767
          : (rounded < -32767 ? -32767 : rounded);
    }

    final byteDataSize = 44 + count * 2;
    final wavBytes = Uint8List(byteDataSize);
    final bd = ByteData.sublistView(wavBytes)
      ..setUint8(0, 0x52)
      ..setUint8(1, 0x49)
      ..setUint8(2, 0x46)
      ..setUint8(3, 0x46)
      ..setUint32(4, 36 + count * 2, Endian.little)
      ..setUint8(8, 0x57)
      ..setUint8(9, 0x41)
      ..setUint8(10, 0x56)
      ..setUint8(11, 0x45)
      ..setUint8(12, 0x66)
      ..setUint8(13, 0x6D)
      ..setUint8(14, 0x74)
      ..setUint8(15, 0x20)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, sampleRate, Endian.little)
      ..setUint32(28, sampleRate * 2, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint8(36, 0x64)
      ..setUint8(37, 0x61)
      ..setUint8(38, 0x74)
      ..setUint8(39, 0x61)
      ..setUint32(40, count * 2, Endian.little);

    var offset = 44;
    for (var i = 0; i < count; i++) {
      bd.setInt16(offset, clampedInt16[i], Endian.little);
      offset += 2;
    }

    return wavBytes;
  }

  static Float64List decodeWav16MonoToFloat(Uint8List wavBytes) {
    if (wavBytes.length < 44) {
      throw ArgumentError('Invalid WAV: byte length < 44.');
    }
    final bd = ByteData.sublistView(wavBytes);
    final dataSize = bd.getUint32(40, Endian.little);
    final sampleCount = dataSize ~/ 2;
    final floats = Float64List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      final s = bd.getInt16(44 + i * 2, Endian.little);
      floats[i] = s / 32767.0;
    }
    return floats;
  }

  static void _applyFadeOut(Float64List samples, int fadeSamples) {
    final len = samples.length;
    final fade = math.min(fadeSamples, len);
    for (var i = 0; i < fade; i++) {
      final target = len - fade + i;
      final w = 0.5 * (1 + math.cos(math.pi * i / fade));
      samples[target] *= w;
    }
  }

  static Float64List _wrapCircularCrossfade(
    Float64List raw,
    int loopSamples,
    int crossfadeSamples,
  ) {
    final result = Float64List(loopSamples);
    for (var i = 0; i < loopSamples; i++) {
      result[i] = raw[i];
    }
    for (var i = 0; i < crossfadeSamples; i++) {
      final w = 0.5 * (1 - math.cos(math.pi * i / crossfadeSamples));
      final extraSample = raw[loopSamples + i];
      result[i] = (1 - w) * extraSample + w * result[i];
    }

    final delta = result.first - result.last;
    final blendCount = math.min(128, loopSamples ~/ 8);
    for (var i = 0; i < blendCount; i++) {
      final progress = (i + 1) / blendCount;
      final smooth = progress * progress * (3 - 2 * progress);
      final idx = loopSamples - blendCount + i;
      result[idx] += delta * smooth;
    }

    return result;
  }
}

@immutable
class EdoWavBank {
  const new({
    required this.kotoWav,
    required this.shakuhachiWav,
    required this.hyoshigiWav,
    required this.bonshoWav,
    required this.riverMurmurWav,
    required this.bambooWindWav,
    required this.nightCricketsWav,
    this.sampleRate = EdoWavSynth.defaultSampleRate,
  });

  factory synthesizeAll({int sampleRate = EdoWavSynth.defaultSampleRate}) =>
      EdoWavBank(
        kotoWav: EdoWavSynth.synthesizeInstrument(
          EdoInstrument.koto,
          sampleRate: sampleRate,
        ),
        shakuhachiWav: EdoWavSynth.synthesizeInstrument(
          EdoInstrument.shakuhachi,
          sampleRate: sampleRate,
        ),
        hyoshigiWav: EdoWavSynth.synthesizeInstrument(
          EdoInstrument.hyoshigi,
          sampleRate: sampleRate,
        ),
        bonshoWav: EdoWavSynth.synthesizeInstrument(
          EdoInstrument.bonsho,
          sampleRate: sampleRate,
        ),
        riverMurmurWav: EdoWavSynth.synthesizeAmbient(
          AmbientLoopKind.riverMurmur,
          sampleRate: sampleRate,
        ),
        bambooWindWav: EdoWavSynth.synthesizeAmbient(
          AmbientLoopKind.bambooWind,
          sampleRate: sampleRate,
        ),
        nightCricketsWav: EdoWavSynth.synthesizeAmbient(
          AmbientLoopKind.nightCrickets,
          sampleRate: sampleRate,
        ),
        sampleRate: sampleRate,
      );

  final Uint8List kotoWav;
  final Uint8List shakuhachiWav;
  final Uint8List hyoshigiWav;
  final Uint8List bonshoWav;
  final Uint8List riverMurmurWav;
  final Uint8List bambooWindWav;
  final Uint8List nightCricketsWav;
  final int sampleRate;

  Uint8List clipForInstrument(EdoInstrument instrument) => switch (instrument) {
    EdoInstrument.koto => kotoWav,
    EdoInstrument.shakuhachi => shakuhachiWav,
    EdoInstrument.hyoshigi => hyoshigiWav,
    EdoInstrument.bonsho => bonshoWav,
  };

  Uint8List clipForAmbient(AmbientLoopKind kind) => switch (kind) {
    AmbientLoopKind.riverMurmur => riverMurmurWav,
    AmbientLoopKind.bambooWind => bambooWindWav,
    AmbientLoopKind.nightCrickets => nightCricketsWav,
  };
}

class _FastRng {
  new([int seed = 0x12345678]) : _state = seed & 0x7FFFFFFF;

  int _state;

  double nextDouble() {
    _state = (_state * 1103515245 + 12345) & 0x7FFFFFFF;
    return _state / 0x7FFFFFFF;
  }
}

class _BiquadBandpass {
  new(double frequencyHz, double q, int sampleRate) {
    final w0 = 2 * math.pi * frequencyHz / sampleRate;
    final alpha = math.sin(w0) / (2 * q);
    final a0 = 1 + alpha;
    b0 = alpha / a0;
    b1 = 0.0;
    b2 = -alpha / a0;
    a1 = (-2 * math.cos(w0)) / a0;
    a2 = (1 - alpha) / a0;
  }

  late final double b0;
  late final double b1;
  late final double b2;
  late final double a1;
  late final double a2;

  double _x1 = 0;
  double _x2 = 0;
  double _y1 = 0;
  double _y2 = 0;

  double process(double input) {
    final y = b0 * input + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
    _x2 = _x1;
    _x1 = input;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}
