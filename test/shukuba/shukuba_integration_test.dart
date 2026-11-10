import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/look/look.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';

void main() {
  group('Slice 1 end-to-end controller + world + audio integration', () {
    test('placing lane, terrace, machiya, stall, yagura, and trees snaps to '
        'roads/terrain, strings <= 6.5m catenary lanterns, and emits finite '
        'PCM WAV notes on Yo (< 0.55) and In-sen (>= 0.55)', () {
      final look = EdoLookDriver(allowHeadlessFallback: true);
      final world = EdoWorldDriver()..initSimulation();
      final audio = EdoAudioDriver();
      final controller = ShukubaController(
        look: look,
        world: world,
        audio: audio,
      );

      final initialSpans = controller.graph.lanternSpans.length;
      expect(initialSpans, greaterThanOrEqualTo(6));

      controller
        ..setTimeOfDay(0.20)
        ..selectTool(const DrawLaneTool())
        ..handlePrimaryPlotTap(const Vec3(-26, 0, -14))
        ..handlePrimaryPlotTap(const Vec3(-14, 0, -14));
      expect(controller.commitActiveStroke(), isTrue);

      controller
        ..selectTool(const BuildTerraceTool())
        ..handlePrimaryPlotTap(const Vec3(-26, 0, -21))
        ..handlePrimaryPlotTap(const Vec3(-14, 0, -21));
      expect(controller.commitActiveStroke(), isTrue);

      controller
        ..selectTool(const StampStructureTool(kind: StructureKind.machiya))
        ..handlePrimaryPlotTap(const Vec3(-20, 0, -16));
      final duskNote = audio.recentNotes.last;
      expect(duskNote.scale, PentatonicScale.yo);
      expect(duskNote.instrument, EdoInstrument.koto);

      controller
        ..setTimeOfDay(0.55)
        ..selectTool(const StampStructureTool(kind: StructureKind.marketStall))
        ..handlePrimaryPlotTap(const Vec3(-20, 0, -11.5));
      final thresholdNote = audio.recentNotes.last;
      expect(thresholdNote.scale, PentatonicScale.inSen);
      expect(thresholdNote.instrument, EdoInstrument.hyoshigi);

      controller
        ..setTimeOfDay(0.90)
        ..selectTool(const StampStructureTool(kind: StructureKind.machiya))
        ..handlePrimaryPlotTap(const Vec3(-16, 0, -11.5));
      expect(audio.recentNotes.last.scale, PentatonicScale.inSen);

      controller
        ..selectTool(const StampStructureTool(kind: StructureKind.yaguraTower))
        ..handlePrimaryPlotTap(const Vec3(-25, 0, -17));
      expect(audio.recentNotes.last.instrument, EdoInstrument.bonsho);

      controller
        ..selectTool(const StampStructureTool(kind: StructureKind.bambooGrove))
        ..handlePrimaryPlotTap(const Vec3(-28, 0, -20));
      expect(audio.recentNotes.last.instrument, EdoInstrument.shakuhachi);

      expect(controller.graph.lanternSpans.length, greaterThan(initialSpans));
      for (final span in controller.graph.lanternSpans) {
        expect(span.lengthMeters, lessThanOrEqualTo(LanternSpan.maxSpanMeters));
      }

      for (final event in audio.recentNotes) {
        expect(event.frequencyHz.isFinite, isTrue);
        expect(event.pitchRatio, greaterThan(0));
        final wav = audio.wavBank.clipForInstrument(event.instrument);
        expect(wav.length, greaterThan(44));
        final view = ByteData.sublistView(wav, 44);
        var nonZeroSamples = 0;
        for (var i = 0; i + 1 < view.lengthInBytes; i += 2) {
          if (view.getInt16(i, Endian.little) != 0) {
            nonZeroSamples++;
          }
        }
        expect(nonZeroSamples, greaterThan(100));
      }

      controller.dispose();
    });
  });
}
