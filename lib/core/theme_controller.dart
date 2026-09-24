import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'i_local_preferences.dart';

/// Remembers whether the person picked light, dark, or "follow the system",
/// and keeps [GetMaterialApp] in sync with that choice.
///
/// The value is written to [ILocalPreferences] — the same storage the session
/// uses — so it survives a restart. [AppBindings.boot] reads it before
/// `runApp`, the same way it reads the session, so the very first frame opens
/// in the right theme instead of flashing light and then switching.
class ThemeController extends GetxController {
  static const _key = 'theme_mode';

  final ILocalPreferences _preferences;

  ThemeController(this._preferences, {required ThemeMode initialMode})
      : themeMode = initialMode.obs;

  final Rx<ThemeMode> themeMode;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == themeMode.value) return;

    themeMode.value = mode;
    Get.changeThemeMode(mode);

    await _preferences.setString(_key, _nameOf(mode));
  }

  /// Reads the stored choice before the widget tree exists, so [main] can pass
  /// it as `GetMaterialApp`'s first `themeMode` and skip the flash. Falls back
  /// to following the system when nothing has been chosen yet, or when the
  /// stored value is something this version of the app does not recognize.
  static Future<ThemeMode> readInitial(ILocalPreferences preferences) async {
    final stored = await preferences.getString(_key);

    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String _nameOf(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
