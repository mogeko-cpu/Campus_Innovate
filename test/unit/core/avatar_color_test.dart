import 'package:campus_innovate/core/app_theme.dart';
import 'package:campus_innovate/core/avatar_color.dart' as core;
import 'package:campus_innovate/core/ui/avatar_color.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const names = [
    'Leonel Triana',
    'Mariana Ospina',
    'Sebastián González',
    'Andrés Betancur',
    'Ana María Pérez',
    'Zoe',
    'Bo',
    'Juan',
  ];

  group('AvatarColor (core)', () {
    test('el mismo nombre siempre da el mismo color', () {
      for (final name in names) {
        expect(core.AvatarColor.of(name), core.AvatarColor.of(name));
      }
    });

    test('depende de las letras y no de su orden', () {
      // The seed is a sum of code units, so an anagram lands on the same color.
      expect(core.AvatarColor.of('ab'), core.AvatarColor.of('ba'));
    });

    test('nombres distintos se reparten en más de un color', () {
      final colors = names.map(core.AvatarColor.of).toSet();
      expect(colors.length, greaterThan(1));
    });

    test('un nombre vacío no falla', () {
      expect(core.AvatarColor.of(''), isA<Color>());
    });

    test('ningún avatar usa los colores de la marca', () {
      final brand = {AppTheme.crimson, AppTheme.navy, AppTheme.gold};

      // 8 consecutive code-unit sums cover every slot of the 8-color palette.
      for (var i = 0; i < 8; i++) {
        final color = core.AvatarColor.of(String.fromCharCode(65 + i));
        expect(brand, isNot(contains(color)));
      }
    });

    group('initialsOf', () {
      test('toma la primera letra del primer y del último nombre', () {
        expect(core.AvatarColor.initialsOf('Ana María Pérez'), 'AP');
        expect(core.AvatarColor.initialsOf('leonel triana'), 'LT');
      });

      test('un solo nombre da una sola letra en mayúscula', () {
        expect(core.AvatarColor.initialsOf('zoe'), 'Z');
      });

      test('ignora espacios de sobra', () {
        expect(core.AvatarColor.initialsOf('  Mariana   Ospina  '), 'MO');
      });

      test('sin nombre muestra un signo de pregunta', () {
        expect(core.AvatarColor.initialsOf(''), '?');
        expect(core.AvatarColor.initialsOf('   '), '?');
      });
    });
  });

  group('AvatarColor (ui)', () {
    test('es determinista para el mismo nombre', () {
      for (final name in names) {
        expect(ui.AvatarColor.of(name), ui.AvatarColor.of(name));
      }
    });

    test('el nombre vacío usa el primer color de la paleta, el carmesí', () {
      expect(ui.AvatarColor.of(''), AppTheme.crimson);
    });

    test('recorre las ocho posiciones de la paleta sin repetir', () {
      final colors = {
        for (var i = 0; i < 8; i++) ui.AvatarColor.of(String.fromCharCode(i + 1)),
      };
      expect(colors, hasLength(8));
    });

    test('las iniciales siempre van en blanco', () {
      expect(ui.AvatarColor.onColor, Colors.white);
    });
  });
}
