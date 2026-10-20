import 'package:campus_innovate/core/local_preferences_secured.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/memory_preferences.dart';

void main() {
  late Map<String, String> secure;
  late MemoryPreferences fallback;
  late LocalPreferencesSecured preferences;

  setUp(() {
    // The plugin's own in-memory platform; the map is the encrypted store.
    secure = {};
    FlutterSecureStorage.setMockInitialValues(secure);
    fallback = MemoryPreferences();
    preferences = LocalPreferencesSecured(
      storage: const FlutterSecureStorage(),
      fallback: fallback,
    );
  });

  group('con el plugin disponible', () {
    test('todo se escribe como texto en el almacenamiento cifrado', () async {
      await preferences.setString('s', 'hola');
      await preferences.setInt('i', 7);
      await preferences.setDouble('d', 2.5);
      await preferences.setBool('b', false);
      await preferences.setStringList('l', ['x', 'y']);

      expect(secure, {
        's': 'hola',
        'i': '7',
        'd': '2.5',
        'b': 'false',
        'l': '["x","y"]',
      });
      expect(fallback.values, isEmpty);
    });

    test('lee cada tipo de vuelta', () async {
      await preferences.setString('s', 'hola');
      await preferences.setInt('i', 7);
      await preferences.setDouble('d', 2.5);
      await preferences.setBool('b', true);
      await preferences.setStringList('l', ['x', 'y']);

      expect(await preferences.getString('s'), 'hola');
      expect(await preferences.getInt('i'), 7);
      expect(await preferences.getDouble('d'), 2.5);
      expect(await preferences.getBool('b'), isTrue);
      expect(await preferences.getStringList('l'), ['x', 'y']);
    });

    test('una clave ausente se lee como null', () async {
      expect(await preferences.getString('nada'), isNull);
      expect(await preferences.getInt('nada'), isNull);
      expect(await preferences.getDouble('nada'), isNull);
      expect(await preferences.getBool('nada'), isNull);
      expect(await preferences.getStringList('nada'), isNull);
    });

    test('un valor que no se puede convertir se lee como null', () async {
      secure['i'] = 'siete';
      secure['d'] = 'dos';
      secure['b'] = 'quizás';
      secure['l'] = 'no es json';
      secure['m'] = '{"a": 1}';

      expect(await preferences.getInt('i'), isNull);
      expect(await preferences.getDouble('d'), isNull);
      expect(await preferences.getBool('b'), isNull);
      expect(await preferences.getStringList('l'), isNull);
      // Valid JSON, but not a list.
      expect(await preferences.getStringList('m'), isNull);
    });

    test('el booleano no distingue mayúsculas', () async {
      secure['b'] = 'TRUE';
      expect(await preferences.getBool('b'), isTrue);

      secure['b'] = 'False';
      expect(await preferences.getBool('b'), isFalse);
    });

    test('remove borra una clave y clear todas', () async {
      await preferences.setString('a', '1');
      await preferences.setString('b', '2');

      await preferences.remove('a');
      expect(secure.keys, ['b']);

      await preferences.clear();
      expect(secure, isEmpty);
    });
  });

  group('sin el plugin', () {
    late LocalPreferencesSecured withoutPlugin;

    setUp(() {
      withoutPlugin = LocalPreferencesSecured(
        storage: _MissingPluginStorage(),
        fallback: fallback,
      );
    });

    test('la primera escritura cae al respaldo en vez de fallar', () async {
      await withoutPlugin.setString('token', 'abc');

      expect(fallback.values['token'], 'abc');
      expect(await withoutPlugin.getString('token'), 'abc');
    });

    test('una lectura sin plugin también usa el respaldo', () async {
      fallback.values['token'] = 'previo';

      expect(await withoutPlugin.getString('token'), 'previo');
    });

    test('las listas, remove y clear siguen al respaldo', () async {
      await withoutPlugin.setStringList('l', ['a']);
      expect(await withoutPlugin.getStringList('l'), ['a']);

      await withoutPlugin.setString('x', '1');
      await withoutPlugin.remove('x');
      expect(fallback.values.containsKey('x'), isFalse);

      await withoutPlugin.clear();
      expect(fallback.values, isEmpty);
    });

    test('los números y booleanos se escriben en el respaldo', () async {
      await withoutPlugin.setInt('i', 3);
      await withoutPlugin.setDouble('d', 0.5);
      await withoutPlugin.setBool('b', true);

      expect(fallback.values, {'i': 3, 'd': 0.5, 'b': true});
    });
  });
}

/// What `flutter_secure_storage` looks like before a full restart picked up the
/// native side: every call fails with [MissingPluginException].
class _MissingPluginStorage implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(MissingPluginException('sin plugin'));
}
