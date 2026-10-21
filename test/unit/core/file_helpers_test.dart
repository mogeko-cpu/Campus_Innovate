import 'dart:typed_data';

import 'package:campus_innovate/core/i_file_picker.dart';
import 'package:campus_innovate/core/time_ago.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mimeTypeOf', () {
    test('reconoce los formatos que comparte un equipo', () {
      expect(mimeTypeOf('informe.pdf'), 'application/pdf');
      expect(mimeTypeOf('FOTO.JPG'), 'image/jpeg');
      expect(
        mimeTypeOf('presupuesto.xlsx'),
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(mimeTypeOf('notas.md'), 'text/markdown');
    });

    test('sin extensión, o una que no conoce, no adivina', () {
      expect(mimeTypeOf('Makefile'), isNull);
      expect(mimeTypeOf('raro.xyz'), isNull);
      expect(mimeTypeOf('termina.'), isNull);
    });
  });

  group('PickedFile', () {
    test('lo que diga la plataforma gana sobre la extensión', () {
      final file = PickedFile(
        name: 'datos.csv',
        bytes: Uint8List(3),
        mimeType: 'application/vnd.ms-excel',
      );

      expect(file.sizeBytes, 3);
      expect(file.resolvedMimeType, 'application/vnd.ms-excel');
    });

    test('sin tipo de la plataforma, lo saca del nombre', () {
      final file = PickedFile(name: 'plano.png', bytes: Uint8List(1));

      expect(file.resolvedMimeType, 'image/png');
    });
  });

  group('timeAgo', () {
    final now = DateTime(2026, 10, 20, 12);

    test('usa la unidad más corta que sigue siendo cierta', () {
      expect(timeAgo(now, now: now), 'ahora');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
          'hace 5 min');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now),
          'hace 3 h');
      expect(timeAgo(now.subtract(const Duration(days: 2)), now: now),
          'hace 2 d');
    });
  });
}
