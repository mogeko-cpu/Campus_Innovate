import 'package:campus_innovate/core/roble/roble_session.dart';
import 'package:campus_innovate/core/roble/roble_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/memory_preferences.dart';

void main() {
  const leonel = RobleUser(
    id: 'uuid-1',
    email: 'leonel@uninorte.edu.co',
    name: 'Leonel Triana',
  );

  late MemoryPreferences preferences;
  late RobleSession session;

  setUp(() {
    preferences = MemoryPreferences();
    session = RobleSession(preferences);
  });

  test('una sesión nueva no está activa', () {
    expect(session.isActive, isFalse);
    expect(session.accessToken, isNull);
    expect(session.user, isNull);
  });

  group('save', () {
    test('deja la sesión activa y la persiste', () async {
      await session.save(
        accessToken: 'access',
        refreshToken: 'refresh',
        user: leonel,
      );

      expect(session.isActive, isTrue);
      expect(preferences.values['roble_access_token'], 'access');
      expect(preferences.values['roble_refresh_token'], 'refresh');
      expect(preferences.values['roble_user'], leonel.toCache());
    });

    test('sin refresh token no escribe esa clave', () async {
      await session.save(accessToken: 'a', refreshToken: null, user: leonel);

      expect(preferences.values.containsKey('roble_refresh_token'), isFalse);
      expect(session.refreshToken, isNull);
    });
  });

  group('restore', () {
    test('recupera lo que otra instancia guardó', () async {
      await session.save(
        accessToken: 'access',
        refreshToken: 'refresh',
        user: leonel,
      );

      final reopened = RobleSession(preferences);
      await reopened.restore();

      expect(reopened.isActive, isTrue);
      expect(reopened.accessToken, 'access');
      expect(reopened.refreshToken, 'refresh');
      expect(reopened.user?.id, 'uuid-1');
      expect(reopened.user?.name, 'Leonel Triana');
    });

    test('borra las claves heredadas que guardaban contraseñas', () async {
      preferences.values.addAll({
        'auth_users': '[{"email":"a","password":"secreta"}]',
        'auth_is_logged_in': 'true',
        'auth_session_email': 'a',
        'otra_clave': 'se queda',
      });

      await session.restore();

      expect(preferences.values.keys, ['otra_clave']);
    });

    test('un usuario en caché ilegible limpia la sesión entera', () async {
      preferences.values.addAll({
        'roble_access_token': 'access',
        'roble_refresh_token': 'refresh',
        'roble_user': '{no es json',
      });

      await session.restore();

      expect(session.isActive, isFalse);
      expect(session.accessToken, isNull);
      expect(preferences.values, isEmpty);
    });

    test('un usuario en caché sin id también limpia la sesión', () async {
      preferences.values.addAll({
        'roble_access_token': 'access',
        'roble_user': '{"email":"a@b.co"}',
      });

      await session.restore();

      expect(session.isActive, isFalse);
      expect(preferences.values, isEmpty);
    });

    test('un token sin usuario no cuenta como sesión activa', () async {
      preferences.values['roble_access_token'] = 'access';

      await session.restore();

      expect(session.accessToken, 'access');
      expect(session.isActive, isFalse);
    });
  });

  group('renew', () {
    setUp(() => session.save(
          accessToken: 'viejo',
          refreshToken: 'refresh-viejo',
          user: leonel,
        ));

    test('reemplaza solo el access token cuando no rota el refresh', () async {
      await session.renew('nuevo');

      expect(session.accessToken, 'nuevo');
      expect(session.refreshToken, 'refresh-viejo');
      expect(preferences.values['roble_access_token'], 'nuevo');
      expect(preferences.values['roble_refresh_token'], 'refresh-viejo');
    });

    test('guarda el refresh token nuevo cuando ROBLE lo rota', () async {
      await session.renew('nuevo', refreshToken: 'refresh-nuevo');

      expect(session.refreshToken, 'refresh-nuevo');
      expect(preferences.values['roble_refresh_token'], 'refresh-nuevo');
    });
  });

  test('clear borra la memoria y el almacenamiento', () async {
    await session.save(accessToken: 'a', refreshToken: 'r', user: leonel);
    preferences.values['theme_mode'] = 'dark';

    await session.clear();

    expect(session.isActive, isFalse);
    expect(session.refreshToken, isNull);
    expect(session.user, isNull);
    // Only the session's own keys: the theme choice survives a logout.
    expect(preferences.values, {'theme_mode': 'dark'});
  });
}
