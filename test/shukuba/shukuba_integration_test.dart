import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';
import 'package:kage_no_machi/shukuba/look/look.dart';
import 'package:kage_no_machi/shukuba/model/shukuba_types.dart';
import 'package:kage_no_machi/shukuba/view/shukuba_controller.dart';
import 'package:kage_no_machi/shukuba/world/world.dart';

void main() {
  group('Slice 2 end-to-end city-builder controller + world + audio', () {
    test('placing lane, terrace, courtyard wall, machiya, chaya, kura, torii, '
        'demolishing, and undoing snaps to roads/terrain, strings <= 6.5m '
        'catenary lanterns, and emits finite PCM WAV notes', () {
      final look = EdoLookDriver(allowHeadlessFallback: true);
      final world = EdoWorldDriver()..initSimulation();
      final audio = EdoAudioDriver();
      final controller = ShukubaController(
        look: look,
        world: world,
        audio: audio,
      );

      final initialSpans = controller.graph.lanternSpans.length;
      expect(initialSpans, greaterThanOrEqualTo(5));

      controller
        ..setTimeOfDay(0.20)
        ..selectTool(const DrawLaneTool())
        ..beginStrokeAt(const Vec3(-28, 0, -18))
        ..extendStrokeTo(const Vec3(-14, 0, -18));
      expect(controller.finishDragStroke(), isTrue);

      controller
        ..selectTool(const BuildTerraceTool())
        ..beginStrokeAt(const Vec3(-28, 0, -25))
        ..extendStrokeTo(const Vec3(-14, 0, -25));
      expect(controller.finishDragStroke(), isTrue);

      controller
        ..selectTool(const BuildWallTool())
        ..beginStrokeAt(const Vec3(-28, 0, -28))
        ..extendStrokeTo(const Vec3(-18, 0, -28));
      expect(controller.finishDragStroke(), isTrue);
      final wallCountAfterBuild = controller.graph.walls.length;

      controller
        ..selectTool(const StampStructureTool(kind: StructureKind.machiya))
        ..handlePrimaryPlotTap(const Vec3(-20, 0, -20));
      final duskNote = audio.recentNotes.last;
      expect(duskNote.scale, PentatonicScale.yo);
      expect(duskNote.instrument, EdoInstrument.koto);

      controller
        ..setTimeOfDay(0.55)
        ..selectTool(const StampStructureTool(kind: StructureKind.marketStall))
        ..handlePrimaryPlotTap(const Vec3(-20, 0, -15.5));
      final thresholdNote = audio.recentNotes.last;
      expect(thresholdNote.scale, PentatonicScale.inSen);
      expect(thresholdNote.instrument, EdoInstrument.hyoshigi);

      controller
        ..setTimeOfDay(0.90)
        ..selectTool(const StampStructureTool(kind: StructureKind.chaya))
        ..handlePrimaryPlotTap(const Vec3(-16, 0, -15));
      expect(audio.recentNotes.last.scale, PentatonicScale.inSen);

      controller
        ..selectTool(const StampStructureTool(kind: StructureKind.kura))
        ..handlePrimaryPlotTap(const Vec3(-26, 0, -22));
      expect(audio.recentNotes.last.instrument, EdoInstrument.bonsho);

      controller
        ..selectTool(const StampStructureTool(kind: StructureKind.toriiGate))
        ..handlePrimaryPlotTap(const Vec3(-24, 0, -18.2));
      expect(audio.recentNotes.last.instrument, EdoInstrument.koto);

      controller
        ..selectTool(const StampStructureTool(kind: StructureKind.bambooGrove))
        ..handlePrimaryPlotTap(const Vec3(-30, 0, -24));
      expect(audio.recentNotes.last.instrument, EdoInstrument.shakuhachi);

      expect(controller.graph.lanternSpans.length, greaterThan(initialSpans));
      for (final span in controller.graph.lanternSpans) {
        expect(span.lengthMeters, lessThanOrEqualTo(LanternSpan.maxSpanMeters));
      }

      // Demolish wall then undo
      controller
        ..selectTool(const DemolishTool())
        ..handlePrimaryPlotTap(const Vec3(-23, 0, -28));
      expect(controller.graph.walls.length, wallCountAfterBuild - 1);
      expect(controller.undo(), isTrue);
      expect(controller.graph.walls.length, wallCountAfterBuild);

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
