import 'package:campus_innovate/core/local_preferences_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences.setMockInitialValues` only reaches the legacy API, and
/// this class is built on [SharedPreferencesAsync], so the store is a double
/// handed in through the constructor.
void main() {
  late _FakeAsyncPrefs store;
  late LocalPreferencesShared preferences;

  setUp(() {
    store = _FakeAsyncPrefs();
    preferences = LocalPreferencesShared(prefs: store);
  });

  test('guarda y lee cada tipo', () async {
    await preferences.setString('s', 'hola');
    await preferences.setInt('i', 42);
    await preferences.setDouble('d', 1.5);
    await preferences.setBool('b', true);
    await preferences.setStringList('l', ['a', 'b']);

    expect(await preferences.getString('s'), 'hola');
    expect(await preferences.getInt('i'), 42);
    expect(await preferences.getDouble('d'), 1.5);
    expect(await preferences.getBool('b'), isTrue);
    expect(await preferences.getStringList('l'), ['a', 'b']);
  });

  test('una clave que no existe se lee como null', () async {
    expect(await preferences.getString('nada'), isNull);
    expect(await preferences.getInt('nada'), isNull);
  });

  test('remove borra una sola clave y clear todas', () async {
    await preferences.setString('a', '1');
    await preferences.setString('b', '2');

    await preferences.remove('a');
    expect(await preferences.getString('a'), isNull);
    expect(await preferences.getString('b'), '2');

    await preferences.clear();
    expect(store.values, isEmpty);
  });

  test('un error al leer se registra y devuelve null en vez de fallar',
      () async {
    await preferences.setString('token', 'abc');
    store.failing = true;

    expect(await preferences.getString('token'), isNull);
    expect(await preferences.getBool('token'), isNull);
    expect(await preferences.getStringList('token'), isNull);
  });

  test('un error al escribir, borrar o limpiar se propaga', () async {
    store.failing = true;

    await expectLater(preferences.setString('k', 'v'), throwsStateError);
    await expectLater(preferences.setInt('k', 1), throwsStateError);
    await expectLater(preferences.remove('k'), throwsStateError);
    await expectLater(preferences.clear(), throwsStateError);
  });
}

class _FakeAsyncPrefs implements SharedPreferencesAsync {
  final Map<String, Object> values = {};

  /// Breaks every call, the way a dead plugin channel would. A holder rather
  /// than a plain field because [SharedPreferencesAsync] is `@immutable`.
  final channel = _Channel();

  bool get failing => channel.broken;

  set failing(bool value) => channel.broken = value;

  Future<T?> _get<T>(String key) async {
    if (failing) throw StateError('canal roto');
    final value = values[key];
    return value is T ? value : null;
  }

  Future<void> _set(String key, Object value) async {
    if (failing) throw StateError('canal roto');
    values[key] = value;
  }

  @override
  Future<String?> getString(String key) => _get<String>(key);

  @override
  Future<int?> getInt(String key) => _get<int>(key);

  @override
  Future<double?> getDouble(String key) => _get<double>(key);

  @override
  Future<bool?> getBool(String key) => _get<bool>(key);

  @override
  Future<List<String>?> getStringList(String key) => _get<List<String>>(key);

  @override
  Future<void> setString(String key, String value) => _set(key, value);

  @override
  Future<void> setInt(String key, int value) => _set(key, value);

  @override
  Future<void> setDouble(String key, double value) => _set(key, value);

  @override
  Future<void> setBool(String key, bool value) => _set(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _set(key, value);

  @override
  Future<void> remove(String key) async {
    if (failing) throw StateError('canal roto');
    values.remove(key);
  }

  @override
  Future<void> clear({Set<String>? allowList}) async {
    if (failing) throw StateError('canal roto');
    values.clear();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Channel {
  bool broken = false;
}
