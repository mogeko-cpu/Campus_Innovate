import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:loggy/loggy.dart';

import 'i_local_preferences.dart';
import 'local_preferences_shared.dart';

/// Encrypted local-preferences implementation used by native applications.
class LocalPreferencesSecured with UiLoggy implements ILocalPreferences {
  LocalPreferencesSecured({
    FlutterSecureStorage? storage,
    ILocalPreferences? fallback,
  }) : _fallback = fallback ?? LocalPreferencesShared(),
       _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.unlocked,
             ),
           );

  final FlutterSecureStorage _storage;
  final ILocalPreferences _fallback;
  var _useFallback = false;

  @override
  Future<String?> getString(String key) => _secureOrFallback(
    () => _storage.read(key: key),
    () => _fallback.getString(key),
  );

  @override
  Future<void> setString(String key, String value) => _secureOrFallback(
    () => _storage.write(key: key, value: value),
    () => _fallback.setString(key, value),
  );

  @override
  Future<int?> getInt(String key) async {
    final value = await _storage.read(key: key);
    return value == null ? null : int.tryParse(value);
  }

  @override
  Future<void> setInt(String key, int value) => _secureOrFallback(
    () => _storage.write(key: key, value: value.toString()),
    () => _fallback.setInt(key, value),
  );

  @override
  Future<double?> getDouble(String key) async {
    final value = await _storage.read(key: key);
    return value == null ? null : double.tryParse(value);
  }

  @override
  Future<void> setDouble(String key, double value) => _secureOrFallback(
    () => _storage.write(key: key, value: value.toString()),
    () => _fallback.setDouble(key, value),
  );

  @override
  Future<bool?> getBool(String key) async {
    final value = await _storage.read(key: key);
    if (value == null) return null;
    if (value.toLowerCase() == 'true') return true;
    if (value.toLowerCase() == 'false') return false;
    return null;
  }

  @override
  Future<void> setBool(String key, bool value) => _secureOrFallback(
    () => _storage.write(key: key, value: value.toString()),
    () => _fallback.setBool(key, value),
  );

  @override
  Future<List<String>?> getStringList(String key) async {
    if (_useFallback) return _fallback.getStringList(key);

    String? value;
    try {
      value = await _storage.read(key: key);
    } on MissingPluginException {
      _useFallback = true;
      loggy.warning(
        'flutter_secure_storage is unavailable; using SharedPreferences fallback. '
        'Fully restart the app after adding the plugin to enable encrypted storage.',
      );
      return _fallback.getStringList(key);
    }
    if (value == null) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return null;
      return decoded.cast<String>();
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _secureOrFallback(
        () => _storage.write(key: key, value: jsonEncode(value)),
        () => _fallback.setStringList(key, value),
      );

  @override
  Future<void> remove(String key) => _secureOrFallback(
    () => _storage.delete(key: key),
    () => _fallback.remove(key),
  );

  @override
  Future<void> clear() =>
      _secureOrFallback(_storage.deleteAll, _fallback.clear);

  Future<T> _secureOrFallback<T>(
    Future<T> Function() secure,
    Future<T> Function() fallback,
  ) async {
    if (_useFallback) return fallback();

    try {
      return await secure();
    } on MissingPluginException {
      _useFallback = true;
      loggy.warning(
        'flutter_secure_storage is unavailable; using SharedPreferences fallback. '
        'Fully restart the app after adding the plugin to enable encrypted storage.',
      );
      return fallback();
    }
  }
}
