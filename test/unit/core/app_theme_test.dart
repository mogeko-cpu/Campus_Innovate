import 'dart:async';

import 'package:campus_innovate/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  late ThemeData light;
  late ThemeData dark;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // The fonts are not bundled and the network is off limits, so every font
    // load fails. The failure surfaces asynchronously, after the theme is
    // already built, and would be pinned on whichever test was running; the
    // themes are therefore built once here, in a zone that absorbs it.
    GoogleFonts.config.allowRuntimeFetching = false;

    final built = Completer<void>();
    runZonedGuarded(() async {
      light = AppTheme.light;
      dark = AppTheme.dark;
      try {
        await GoogleFonts.pendingFonts();
      } catch (_) {}
      built.complete();
    }, (_, _) {});
    await built.future;
  });

  test('el tema claro usa el carmesí, el azul marino y el dorado', () {
    final scheme = light.colorScheme;

    expect(scheme.brightness, Brightness.light);
    expect(scheme.primary, AppTheme.crimson);
    expect(scheme.secondary, AppTheme.navy);
    expect(scheme.tertiary, AppTheme.gold);
  });

  test('el tema oscuro es oscuro y no reutiliza el primario claro', () {
    final scheme = dark.colorScheme;

    expect(scheme.brightness, Brightness.dark);
    expect(scheme.primary, isNot(AppTheme.crimson));
  });

  test('los títulos van en Sora y el cuerpo en Inter', () {
    for (final theme in [light, dark]) {
      final text = theme.textTheme;

      expect(text.displayLarge?.fontFamily, contains('Sora'));
      expect(text.headlineSmall?.fontFamily, contains('Sora'));
      expect(text.titleMedium?.fontFamily, contains('Sora'));
      expect(text.titleSmall?.fontFamily, contains('Inter'));
      expect(text.bodyMedium?.fontFamily, contains('Inter'));
      expect(text.labelLarge?.fontFamily, contains('Inter'));
    }
  });

  test('el título de la barra superior es Sora en negrita', () {
    final style = light.appBarTheme.titleTextStyle;

    expect(style?.fontFamily, contains('Sora'));
    expect(style?.fontWeight, FontWeight.w700);
  });
}
