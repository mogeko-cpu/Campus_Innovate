import 'package:campus_innovate/core/day_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 20);

  test('un día del año en curso se muestra sin año', () {
    expect(shortDay(DateTime(2026, 11, 15), now: now), '15 nov');
  });

  test('un día de otro año lleva el año, hacia adelante o hacia atrás', () {
    expect(shortDay(DateTime(2027, 1, 3), now: now), '3 ene 2027');
    expect(shortDay(DateTime(2025, 12, 31), now: now), '31 dic 2025');
  });

  test('el día no se rellena con cero', () {
    expect(shortDay(DateTime(2026, 3, 1), now: now), '1 mar');
  });

  test('los doce meses usan su abreviatura en español', () {
    final labels = [
      for (var month = 1; month <= 12; month++)
        shortDay(DateTime(2026, month, 10), now: now),
    ];

    expect(labels, [
      '10 ene', '10 feb', '10 mar', '10 abr', '10 may', '10 jun', //
      '10 jul', '10 ago', '10 sep', '10 oct', '10 nov', '10 dic',
    ]);
  });

  test('la hora del día no cambia la etiqueta', () {
    expect(shortDay(DateTime(2026, 11, 15, 23, 59), now: now), '15 nov');
  });

  test('sin now compara con el año actual del reloj', () {
    final today = DateTime.now();

    expect(shortDay(DateTime(today.year, 6, 5)), '5 jun');
    expect(
      shortDay(DateTime(today.year + 1, 6, 5)),
      '5 jun ${today.year + 1}',
    );
  });
}
