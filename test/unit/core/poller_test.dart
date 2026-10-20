import 'dart:async';

import 'package:campus_innovate/core/poller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Timing runs inside `testWidgets`, whose fake clock lets `tester.pump`
/// advance a `Timer.periodic` without waiting for real seconds.
void main() {
  const interval = Duration(seconds: 10);

  late bool previouslyEnabled;

  setUp(() {
    previouslyEnabled = Poller.enabled;
    Poller.enabled = true;
  });

  tearDown(() => Poller.enabled = previouslyEnabled);

  testWidgets('ejecuta la acción en cada intervalo una vez iniciado',
      (tester) async {
    var runs = 0;
    final poller = Poller(interval: interval, action: () async => runs++);

    poller.start();
    expect(poller.isActive, isTrue);

    // Nothing runs at start: the screen already loaded once by itself.
    await tester.pump(const Duration(seconds: 9));
    expect(runs, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(runs, 1);

    await tester.pump(interval * 2);
    expect(runs, 3);

    poller.stop();
  });

  testWidgets('iniciar dos veces no crea un segundo temporizador',
      (tester) async {
    var runs = 0;
    final poller = Poller(interval: interval, action: () async => runs++);

    poller
      ..start()
      ..start();

    await tester.pump(interval);
    expect(runs, 1);

    poller.stop();
  });

  testWidgets('detenido deja de ejecutar y queda inactivo', (tester) async {
    var runs = 0;
    final poller = Poller(interval: interval, action: () async => runs++);

    poller.start();
    await tester.pump(interval);
    poller.stop();

    expect(poller.isActive, isFalse);

    await tester.pump(interval * 3);
    expect(runs, 1);
  });

  testWidgets('en pausa se salta los ticks y al reanudar vuelve a ejecutar',
      (tester) async {
    var runs = 0;
    final poller = Poller(interval: interval, action: () async => runs++);

    poller
      ..start()
      ..pause();

    await tester.pump(interval * 3);
    expect(runs, 0);
    // Paused is not stopped: the timer is still there for resume.
    expect(poller.isActive, isTrue);

    poller.resume();
    await tester.pump(interval);
    expect(runs, 1);

    poller.stop();
  });

  testWidgets('no solapa una ejecución que sigue en vuelo', (tester) async {
    var runs = 0;
    final pending = Completer<void>();
    final poller = Poller(
      interval: interval,
      action: () {
        runs++;
        return pending.future;
      },
    );

    poller.start();
    await tester.pump(interval);
    expect(runs, 1);

    // The first run has not finished, so these ticks must not start another.
    await tester.pump(interval * 3);
    expect(runs, 1);

    pending.complete();
    await tester.pump();

    await tester.pump(interval);
    expect(runs, 2);

    poller.stop();
  });

  testWidgets('un fallo se traga y el siguiente tick vuelve a intentar',
      (tester) async {
    var runs = 0;
    final poller = Poller(
      interval: interval,
      action: () async {
        runs++;
        if (runs == 1) throw StateError('sin conexión');
      },
    );

    poller.start();
    await tester.pump(interval);
    await tester.pump(interval);

    expect(runs, 2);
    expect(tester.takeException(), isNull);

    poller.stop();
  });

  testWidgets('deshabilitado globalmente, start no hace nada', (tester) async {
    Poller.enabled = false;

    var runs = 0;
    final poller = Poller(interval: interval, action: () async => runs++);

    poller.start();
    expect(poller.isActive, isFalse);

    await tester.pump(interval * 2);
    expect(runs, 0);
  });
}
