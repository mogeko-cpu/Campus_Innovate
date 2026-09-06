import 'package:loggy/loggy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i_local_preferences.dart';

/// SharedPreferences implementation used by the web application.
class LocalPreferencesShared with UiLoggy implements ILocalPreferences {
  LocalPreferencesShared({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> getString(String key) =>
      _read(() => _prefs.getString(key), key, 'String');

  @override
  Future<void> setString(String key, String value) =>
      _write(() => _prefs.setString(key, value), key, 'String');

  @override
  Future<int?> getInt(String key) =>
      _read(() => _prefs.getInt(key), key, 'int');

  @override
  Future<void> setInt(String key, int value) =>
      _write(() => _prefs.setInt(key, value), key, 'int');

  @override
  Future<double?> getDouble(String key) =>
      _read(() => _prefs.getDouble(key), key, 'double');

  @override
  Future<void> setDouble(String key, double value) =>
      _write(() => _prefs.setDouble(key, value), key, 'double');

  @override
  Future<bool?> getBool(String key) =>
      _read(() => _prefs.getBool(key), key, 'bool');

  @override
  Future<void> setBool(String key, bool value) =>
      _write(() => _prefs.setBool(key, value), key, 'bool');

  @override
  Future<List<String>?> getStringList(String key) =>
      _read(() => _prefs.getStringList(key), key, 'List<String>');

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _write(() => _prefs.setStringList(key, value), key, 'List<String>');

  @override
  Future<void> remove(String key) async {
    try {
      await _prefs.remove(key);
    } catch (exception, stackTrace) {
      loggy.error(
        'Error removing key "$key": $exception',
        exception,
        stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _prefs.clear();
    } catch (exception, stackTrace) {
      loggy.error(
        'Error clearing local preferences: $exception',
        exception,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<T?> _read<T>(
    Future<T?> Function() read,
    String key,
    String type,
  ) async {
    try {
      return await read();
    } catch (exception, stackTrace) {
      loggy.error(
        'Error getting $type for key "$key": $exception',
        exception,
        stackTrace,
      );
      return null;
    }
  }

  Future<void> _write(
    Future<void> Function() write,
    String key,
    String type,
  ) async {
    try {
      await write();
    } catch (exception, stackTrace) {
      loggy.error(
        'Error setting $type for key "$key": $exception',
        exception,
        stackTrace,
      );
      rethrow;
    }
  }
}
