import 'package:campus_innovate/core/i_local_preferences.dart';

/// [ILocalPreferences] backed by a map, so tests can look at what was stored
/// without a plugin or a device.
class MemoryPreferences implements ILocalPreferences {
  final Map<String, Object> values = {};

  T? _read<T>(String key) {
    final value = values[key];

    return value is T ? value : null;
  }

  @override
  Future<String?> getString(String key) async => _read<String>(key);

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<int?> getInt(String key) async => _read<int>(key);

  @override
  Future<void> setInt(String key, int value) async => values[key] = value;

  @override
  Future<double?> getDouble(String key) async => _read<double>(key);

  @override
  Future<void> setDouble(String key, double value) async => values[key] = value;

  @override
  Future<bool?> getBool(String key) async => _read<bool>(key);

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<List<String>?> getStringList(String key) async =>
      _read<List<String>>(key);

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  Future<void> clear() async => values.clear();
}
