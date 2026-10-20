import 'package:campus_innovate/core/roble/roble_session.dart';
import 'package:campus_innovate/core/roble/roble_session_service.dart';
import 'package:campus_innovate/core/roble/roble_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/memory_preferences.dart';

void main() {
  late RobleSession session;
  late RobleSessionService service;

  setUp(() {
    session = RobleSession(MemoryPreferences());
    service = RobleSessionService(session);
  });

  test('expone la identidad del usuario de la sesión', () async {
    await session.save(
      accessToken: 'a',
      refreshToken: null,
      user: const RobleUser(
        id: 'uuid-1',
        email: 'leonel@uninorte.edu.co',
        name: 'Leonel Triana',
      ),
    );

    expect(service.currentUserId, 'uuid-1');
    expect(service.currentUserName, 'Leonel Triana');
    expect(service.currentUserEmail, 'leonel@uninorte.edu.co');
  });

  test('sigue a la sesión cuando cambia de usuario', () async {
    await session.save(
      accessToken: 'a',
      refreshToken: null,
      user: const RobleUser(id: 'u1', email: '', name: 'Uno'),
    );
    expect(service.currentUserId, 'u1');

    await session.save(
      accessToken: 'b',
      refreshToken: null,
      user: const RobleUser(id: 'u2', email: '', name: 'Dos'),
    );
    expect(service.currentUserId, 'u2');
  });

  test('sin sesión falla con un StateError en vez de devolver un id vacío',
      () async {
    expect(() => service.currentUserId, throwsStateError);
    expect(() => service.currentUserName, throwsStateError);
    expect(() => service.currentUserEmail, throwsStateError);
  });

  test('después de cerrar sesión vuelve a fallar', () async {
    await session.save(
      accessToken: 'a',
      refreshToken: null,
      user: const RobleUser(id: 'u1', email: '', name: 'Uno'),
    );
    await session.clear();

    expect(() => service.currentUserId, throwsStateError);
  });
}
