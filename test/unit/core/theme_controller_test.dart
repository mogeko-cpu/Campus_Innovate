import 'package:campus_innovate/core/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/memory_preferences.dart';

void main() {
  late MemoryPreferences preferences;

  setUp(() => preferences = MemoryPreferences());

  tearDown(Get.reset);

  group('readInitial', () {
    test('sin nada guardado sigue al sistema', () async {
      expect(await ThemeController.readInitial(preferences), ThemeMode.system);
    });

    test('lee claro y oscuro', () async {
      preferences.values['theme_mode'] = 'light';
      expect(await ThemeController.readInitial(preferences), ThemeMode.light);

      preferences.values['theme_mode'] = 'dark';
      expect(await ThemeController.readInitial(preferences), ThemeMode.dark);
    });

    test('un valor desconocido cae a seguir al sistema', () async {
      preferences.values['theme_mode'] = 'sepia';
      expect(await ThemeController.readInitial(preferences), ThemeMode.system);
    });
  });

  group('setMode', () {
    test('cambia el modo, lo aplica a GetX y lo persiste', () async {
      final controller = ThemeController(
        preferences,
        initialMode: ThemeMode.system,
      );

      await controller.setMode(ThemeMode.dark);

      expect(controller.themeMode.value, ThemeMode.dark);
      expect(Get.rootController.themeMode, ThemeMode.dark);
      expect(preferences.values['theme_mode'], 'dark');
    });

    test('lo que guarda se vuelve a leer igual al reiniciar', () async {
      final controller = ThemeController(
        preferences,
        initialMode: ThemeMode.dark,
      );

      for (final mode in ThemeMode.values) {
        if (mode == controller.themeMode.value) continue;

        await controller.setMode(mode);
        expect(await ThemeController.readInitial(preferences), mode);
      }
    });

    test('elegir el modo actual no escribe nada', () async {
      final controller = ThemeController(
        preferences,
        initialMode: ThemeMode.light,
      );

      await controller.setMode(ThemeMode.light);

      expect(preferences.values, isEmpty);
      expect(controller.themeMode.value, ThemeMode.light);
    });
  });
}
