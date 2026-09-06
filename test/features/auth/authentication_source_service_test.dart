import 'package:f_clean_template/core/i_local_preferences.dart';
import 'package:f_clean_template/features/auth/data/datasources/remote/authentication_source_service.dart';
import 'package:f_clean_template/features/auth/domain/models/authentication_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthenticationSourceService', () {
    late AuthenticationSourceService source;

    setUp(() {
      source = AuthenticationSourceService(_MemoryPreferences());
    });

    test(
      'stores multiple users and restores the matching login session',
      () async {
        await source.signUp(_user('alice@example.com', 'Password1!'));
        await source.signUp(_user('bob@example.com', 'Password2!'));

        expect(
          await source.login(_user('ALICE@example.com', 'Password1!')),
          isTrue,
        );
        expect(await source.restoreSession(), isTrue);
        expect((await source.getLoggedUser())?.email, 'alice@example.com');

        await source.logOut();
        expect(await source.restoreSession(), isFalse);
        expect(await source.getLoggedUser(), isNull);
      },
    );

    test('rejects duplicate accounts and invalid credentials', () async {
      await source.signUp(_user('alice@example.com', 'Password1!'));

      await expectLater(
        source.signUp(_user('ALICE@example.com', 'Password2!')),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        source.login(_user('alice@example.com', 'incorrect')),
        throwsA(isA<StateError>()),
      );
    });
  });
}

AuthenticationUser _user(String email, String password) =>
    AuthenticationUser(email: email, name: email, password: password);

class _MemoryPreferences implements ILocalPreferences {
  final Map<String, Object> _values = <String, Object>{};

  @override
  Future<void> clear() async => _values.clear();

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<List<String>?> getStringList(String key) async =>
      (_values[key] as List<String>?)?.toList();

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<void> setDouble(String key, double value) async =>
      _values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = value.toList();
}
