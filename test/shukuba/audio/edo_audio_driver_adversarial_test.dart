import 'dart:async';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kage_no_machi/shukuba/audio/audio.dart';

Scene? _tryScene() {
  try {
    return Scene();
  } on Object {
    return null;
  }
}

void main() {
  group('Adversarial Stress Test: High Concurrency (50–100 callers)', () {
    test(
      '100 simultaneous prewarm() calls in same tick deduplicate to identical '
      'Future',
      () async {
        final driver = EdoAudioDriver();
        expect(driver.isWavBankLoaded, isFalse);

        const callerCount = 100;
        final futures = List.generate(callerCount, (_) => driver.prewarm());

        final firstFuture = futures.first;
        for (var i = 1; i < callerCount; i++) {
          expect(
            identical(futures[i], firstFuture),
            isTrue,
            reason: 'Future #$i must be identical to the first future',
          );
        }

        final results = await Future.wait(futures);
        expect(results.length, equals(callerCount));
        expect(driver.isWavBankLoaded, isTrue);
        expect(driver.wavBank, isNotNull);

        final postFuture = driver.prewarm();
        expect(driver.isWavBankLoaded, isTrue);
        await postFuture;
      },
    );

    test('100 staggered concurrent prewarm() callers across multiple async '
        'tasks and timers', () async {
      final driver = EdoAudioDriver();
      expect(driver.isWavBankLoaded, isFalse);

      final completedResults = <int>[];
      final futures = <Future<void>>[];

      for (var i = 0; i < 20; i++) {
        final id = i;
        futures.add(driver.prewarm().then((_) => completedResults.add(id)));
      }

      for (var i = 20; i < 40; i++) {
        final id = i;
        final comp = Completer<void>();
        scheduleMicrotask(() async {
          try {
            await driver.prewarm();
            completedResults.add(id);
            comp.complete();
          } catch (e, st) {
            comp.completeError(e, st);
          }
        });
        futures.add(comp.future);
      }

      for (var i = 40; i < 60; i++) {
        final id = i;
        final comp = Completer<void>();
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 5), () async {
            try {
              await driver.prewarm();
              completedResults.add(id);
              comp.complete();
            } catch (e, st) {
              comp.completeError(e, st);
            }
          }),
        );
        futures.add(comp.future);
      }

      for (var i = 60; i < 80; i++) {
        final id = i;
        final comp = Completer<void>();
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 10), () async {
            try {
              await driver.prewarm();
              completedResults.add(id);
              comp.complete();
            } catch (e, st) {
              comp.completeError(e, st);
            }
          }),
        );
        futures.add(comp.future);
      }

      for (var i = 80; i < 100; i++) {
        final id = i;
        final comp = Completer<void>();
        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 15), () async {
            try {
              await driver.prewarm();
              completedResults.add(id);
              comp.complete();
            } catch (e, st) {
              comp.completeError(e, st);
            }
          }),
        );
        futures.add(comp.future);
      }

      await Future.wait(futures);

      expect(completedResults.length, equals(100));
      expect(driver.isWavBankLoaded, isTrue);
      expect(driver.wavBank.kotoWav.length, greaterThan(44));
    });

    test('10 distinct EdoAudioDriver instances prewarming concurrently in '
        'parallel isolates', () async {
      final drivers = List.generate(10, (_) => EdoAudioDriver());
      for (final d in drivers) {
        expect(d.isWavBankLoaded, isFalse);
      }

      await Future.wait(drivers.map((d) => d.prewarm()));

      for (final d in drivers) {
        expect(d.isWavBankLoaded, isTrue);
        expect(d.wavBank.bonshoWav.isNotEmpty, isTrue);
      }
    });
  });

  group('Adversarial Stress Test: Idempotency and Lifecycle Transitions', () {
    test('prewarm() called before attach() and then after attach()', () async {
      final driver = EdoAudioDriver();
      expect(driver.isWavBankLoaded, isFalse);

      await driver.prewarm();
      expect(driver.isWavBankLoaded, isTrue);

      final scene = _tryScene();
      await driver.attach(scene);

      await driver.prewarm();
      expect(driver.isWavBankLoaded, isTrue);
    });

    test('prewarm() called concurrently with attach()', () async {
      final driver = EdoAudioDriver();
      final scene = _tryScene();

      final fPrewarm = driver.prewarm();
      final fAttach = driver.attach(scene);

      await Future.wait([fPrewarm, fAttach]);
      expect(driver.isWavBankLoaded, isTrue);
    });

    test(
      'attach() called without prior prewarm(), followed by prewarm()',
      () async {
        final driver = EdoAudioDriver();
        expect(driver.isWavBankLoaded, isFalse);

        final scene = _tryScene();
        await driver.attach(scene);

        await driver.prewarm();
        expect(driver.isWavBankLoaded, isTrue);
      },
    );

    test(
      'prewarm() after dispose() does not throw and completes cleanly',
      () async {
        final driver = EdoAudioDriver();
        final scene = _tryScene();
        await driver.attach(scene);
        driver.dispose();

        await expectLater(driver.prewarm(), completes);
        expect(driver.isWavBankLoaded, isTrue);
      },
    );

    test(
      'prewarm() on fresh driver disposed immediately before prewarm',
      () async {
        final driver = EdoAudioDriver()..dispose();

        await expectLater(driver.prewarm(), completes);
        expect(driver.isWavBankLoaded, isTrue);
      },
    );

    test('dispose() called while prewarm() is actively in flight', () async {
      final driver = EdoAudioDriver();
      final fPrewarm = driver.prewarm();

      driver.dispose();

      await expectLater(fPrewarm, completes);
      expect(driver.isWavBankLoaded, isTrue);
    });

    test(
      'repeated rapid cycles of prewarm() -> dispose() -> prewarm()',
      () async {
        final driver = EdoAudioDriver();
        for (var i = 0; i < 5; i++) {
          await driver.prewarm();
          expect(driver.isWavBankLoaded, isTrue);
          driver.dispose();
        }
        expect(driver.isWavBankLoaded, isTrue);
      },
    );

    test('subsequent prewarm() calls on already prewarmed driver return '
        'immediately', () async {
      final driver = EdoAudioDriver();
      await driver.prewarm();
      expect(driver.isWavBankLoaded, isTrue);

      final sw = Stopwatch()..start();
      await driver.prewarm();
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(5));
      expect(driver.isWavBankLoaded, isTrue);
    });

    test(
      'accessing wavBank getter while prewarm() is in-flight completes safely',
      () async {
        final driver = EdoAudioDriver();
        final fPrewarm = driver.prewarm();

        final synchronousBank = driver.wavBank;
        expect(synchronousBank, isNotNull);
        expect(driver.isWavBankLoaded, isTrue);

        await fPrewarm;
        expect(driver.isWavBankLoaded, isTrue);
        expect(driver.wavBank, isNotNull);
      },
    );
  });

  group('Adversarial Stress Test: Background Thread Offloading & Event Loop '
      'Liveness', () {
    test('prewarm() does not starve caller event loop timers compared to '
        'synchronous synthesis', () async {
      final syncTicks = <int>[];
      final syncStopwatch = Stopwatch()..start();
      final syncTimer = Timer.periodic(const Duration(milliseconds: 2), (_) {
        syncTicks.add(syncStopwatch.elapsedMicroseconds);
      });

      final syncBank = EdoWavBank.synthesizeAll();
      syncTimer.cancel();

      final driver = EdoAudioDriver();
      final asyncTicks = <int>[];
      final asyncStopwatch = Stopwatch()..start();
      var maxAsyncIntervalUs = 0;
      var lastTickUs = 0;

      final asyncTimer = Timer.periodic(const Duration(milliseconds: 2), (_) {
        final currentUs = asyncStopwatch.elapsedMicroseconds;
        asyncTicks.add(currentUs);
        if (lastTickUs > 0) {
          final interval = currentUs - lastTickUs;
          if (interval > maxAsyncIntervalUs) {
            maxAsyncIntervalUs = interval;
          }
        }
        lastTickUs = currentUs;
      });

      await driver.prewarm();
      asyncTimer.cancel();

      final maxAsyncHitchMs = maxAsyncIntervalUs / 1000.0;

      expect(
        asyncTicks.length,
        greaterThan(5),
        reason:
            'Event loop must have pumped periodic timer ticks while '
            'isolate ran',
      );

      expect(
        asyncTicks.length,
        greaterThan(syncTicks.length),
        reason:
            'Async isolate must yield significantly more event loop ticks '
            'than synchronous execution',
      );

      expect(
        maxAsyncHitchMs,
        lessThan(50.0),
        reason: 'Event loop hitch during prewarm must remain below 50ms',
      );

      expect(driver.isWavBankLoaded, isTrue);
      expect(syncBank.kotoWav.length, equals(driver.wavBank.kotoWav.length));
    });

    test(
      'continuous cooperative event-loop task processing during prewarm() is '
      'uninterrupted',
      () async {
        final driver = EdoAudioDriver();
        var eventCounter = 0;
        var inFlight = true;

        void pumpNext() {
          if (!inFlight) return;
          eventCounter++;
          unawaited(Future<void>.delayed(Duration.zero, pumpNext));
        }

        pumpNext();

        await driver.prewarm();
        inFlight = false;

        expect(
          eventCounter,
          greaterThan(10),
          reason:
              'Caller event loop must be continuously serviced during '
              'Isolate.run',
        );
        expect(driver.isWavBankLoaded, isTrue);
      },
    );
  });
}
