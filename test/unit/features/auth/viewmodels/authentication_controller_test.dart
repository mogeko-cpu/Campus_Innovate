import 'dart:async';

import 'package:campus_innovate/core/user_facing_exception.dart';
import 'package:campus_innovate/features/auth/domain/models/authentication_user.dart';
import 'package:campus_innovate/features/auth/ui/viewmodels/authentication_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/fake_auth_repository.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

class _Refusal implements UserFacingException {
  const _Refusal(this.message);

  @override
  final String message;
}

/// Holds the login open until the test lets it finish, to look at the state
/// while the request is in flight.
class _SlowAuthRepository extends FakeAuthRepository {
  final gate = Completer<void>();

  @override
  Future<bool> login(AuthenticationUser user) async {
    await gate.future;

    return super.login(user);
  }
}

class _LogOutRepository extends FakeAuthRepository {
  _LogOutRepository({this.result = true, this.failure});

  final bool result;
  final Object? failure;

  @override
  Future<bool> logOut() async {
    await super.logOut();

    if (failure != null) throw failure!;

    return result;
  }
}

class _BrokenRestoreRepository extends FakeAuthRepository {
  @override
  Future<bool> restoreSession() async => throw StateError('almacenamiento');
}

void main() {
  setUpViewModelTests();

  const leonel = TestUsers.leonel;
  const password = FakeAuthRepository.password;

  late FakeAuthRepository repository;
  late AuthenticationController controller;

  setUp(() {
    repository = FakeAuthRepository();
    controller = AuthenticationController(repository);
  });

  group('login', () {
    for (final email in ['leonel', 'a@b', 'leo nel@uninorte.edu.co', '']) {
      test('rechaza el correo "$email" sin llamar al repositorio', () async {
        final result = await controller.login(email, password);

        expect(result, isFalse);
        expect(
          controller.error.value,
          'Escribe tu correo institucional y tu contraseña.',
        );
        expect(repository.logins, 0);
      });
    }

    test('rechaza una contraseña vacía sin llamar al repositorio', () async {
      final result = await controller.login(leonel.email, '');

      expect(result, isFalse);
      expect(
        controller.error.value,
        'Escribe tu correo institucional y tu contraseña.',
      );
      expect(repository.logins, 0);
    });

    test('con credenciales válidas deja la sesión abierta', () async {
      final result = await controller.login(leonel.email, password);

      expect(result, isTrue);
      expect(controller.isLogged, isTrue);
      expect(controller.loggedEmail, leonel.email);
      expect(controller.loggedName, leonel.name);
      expect(controller.error.value, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('limpia el error de un intento anterior al acertar', () async {
      await controller.login(leonel.email, 'Incorrecta1!');
      expect(controller.error.value, isNotEmpty);

      await controller.login(leonel.email, password);

      expect(controller.error.value, isEmpty);
    });

    test('si el repositorio responde false explica que revise sus datos',
        () async {
      final result = await controller.login(leonel.email, 'Incorrecta1!');

      expect(result, isFalse);
      expect(controller.isLogged, isFalse);
      expect(controller.loggedEmail, isEmpty);
      expect(
        controller.error.value,
        'No se pudo iniciar sesión. Revisa tus datos.',
      );
    });

    test('muestra tal cual el mensaje de una excepción para el usuario',
        () async {
      repository.loginFailure = const _Refusal('Espera 40 segundos.');

      final result = await controller.login(leonel.email, password);

      expect(result, isFalse);
      expect(controller.error.value, 'Espera 40 segundos.');
      expect(controller.isLoading, isFalse);
    });

    test('cambia un error genérico por el mensaje de respaldo', () async {
      repository.loginFailure = StateError('Null check operator');

      final result = await controller.login(leonel.email, password);

      expect(result, isFalse);
      expect(
        controller.error.value,
        'No se pudo iniciar sesión. Intenta de nuevo.',
      );
      expect(controller.isLoading, isFalse);
    });

    test('marca isLoading solo mientras la petición está en curso', () async {
      final slow = _SlowAuthRepository();
      final subject = AuthenticationController(slow);

      final pending = subject.login(leonel.email, password);

      expect(subject.isLoading, isTrue);

      slow.gate.complete();
      expect(await pending, isTrue);
      expect(subject.isLoading, isFalse);
    });
  });

  group('signUp', () {
    test('pide el nombre completo si tiene menos de 3 letras', () async {
      final result = await controller.signUp(
        '  Al  ',
        'al@uninorte.edu.co',
        password,
      );

      expect(result, isFalse);
      expect(controller.error.value, 'Escribe tu nombre completo.');
      expect(repository.signUps, 0);
    });

    test('rechaza un correo inválido', () async {
      final result = await controller.signUp('Ana Pérez', 'ana', password);

      expect(result, isFalse);
      expect(controller.error.value, 'Escribe un correo válido.');
      expect(repository.signUps, 0);
    });

    test('aplica la política de contraseñas de ROBLE antes de pedir la cuenta',
        () async {
      final short = await controller.signUp(
        'Ana Pérez',
        'ana@uninorte.edu.co',
        'Ab1!',
      );
      expect(short, isFalse);
      expect(
        controller.error.value,
        'La contraseña debe tener al menos 8 caracteres.',
      );

      await controller.signUp('Ana Pérez', 'ana@uninorte.edu.co', 'campus2026!');
      expect(
        controller.error.value,
        'La contraseña debe incluir una letra mayúscula.',
      );

      expect(repository.signUps, 0);
    });

    test('crea la cuenta cuando todo es válido', () async {
      final result = await controller.signUp(
        'Ana Pérez',
        'ana@uninorte.edu.co',
        password,
      );

      expect(result, isTrue);
      expect(controller.error.value, isEmpty);
      expect(repository.accounts['ana@uninorte.edu.co']?.user.name, 'Ana Pérez');
      expect(controller.isLoading, isFalse);
    });

    test('si el repositorio responde false lo dice', () async {
      // The e-mail is already taken, which the fake answers with false.
      final result = await controller.signUp(
        'Leonel Triana',
        leonel.email,
        password,
      );

      expect(result, isFalse);
      expect(
        controller.error.value,
        'No se pudo crear la cuenta. Intenta de nuevo.',
      );
    });

    test('muestra el mensaje de una excepción para el usuario', () async {
      repository.signUpFailure = const _Refusal('Límite de registros.');

      await controller.signUp('Ana Pérez', 'ana@uninorte.edu.co', password);

      expect(controller.error.value, 'Límite de registros.');
    });

    test('usa el respaldo ante un error genérico', () async {
      repository.signUpFailure = Exception('socket');

      final result = await controller.signUp(
        'Ana Pérez',
        'ana@uninorte.edu.co',
        password,
      );

      expect(result, isFalse);
      expect(
        controller.error.value,
        'No se pudo crear la cuenta. Intenta de nuevo.',
      );
      expect(controller.isLoading, isFalse);
    });
  });

  group('signInWithGoogle', () {
    test('entrega el inicio a Google y no reporta error', () async {
      final result = await controller.signInWithGoogle();

      expect(result, isTrue);
      expect(repository.googleStarts, 1);
      expect(controller.error.value, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('muestra el mensaje de una excepción para el usuario', () async {
      repository.googleFailure = const _Refusal('Google no respondió.');

      final result = await controller.signInWithGoogle();

      expect(result, isFalse);
      expect(controller.error.value, 'Google no respondió.');
    });

    test('usa el respaldo ante un error genérico', () async {
      repository.googleFailure = StateError('plugin');

      final result = await controller.signInWithGoogle();

      expect(result, isFalse);
      expect(
        controller.error.value,
        'No se pudo iniciar sesión con Google. Intenta de nuevo.',
      );
      expect(controller.isLoading, isFalse);
    });
  });

  group('logOut', () {
    test('cierra la sesión que estaba abierta', () async {
      await controller.login(leonel.email, password);

      final result = await controller.logOut();

      expect(result, isTrue);
      expect(controller.isLogged, isFalse);
      expect(controller.loggedEmail, isEmpty);
      expect(controller.loggedName, isEmpty);
      expect(controller.error.value, isEmpty);
    });

    test('si el repositorio responde false avisa pero no deja la sesión local',
        () async {
      final subject = AuthenticationController(_LogOutRepository(result: false));
      await subject.login(leonel.email, password);

      final result = await subject.logOut();

      expect(result, isFalse);
      expect(subject.isLogged, isFalse);
      expect(subject.error.value, 'No se pudo cerrar sesión. Intenta de nuevo.');
    });

    test('si falla la petición tampoco deja la sesión local', () async {
      final subject = AuthenticationController(
        _LogOutRepository(failure: StateError('red')),
      );
      await subject.login(leonel.email, password);

      final result = await subject.logOut();

      expect(result, isFalse);
      expect(subject.isLogged, isFalse);
      expect(subject.loggedEmail, isEmpty);
      expect(subject.error.value, 'No se pudo cerrar sesión. Intenta de nuevo.');
    });
  });

  group('estado inicial', () {
    test('initialError queda como el error visible desde el principio', () {
      final subject = AuthenticationController(
        repository,
        initialError: 'Google rechazó el inicio de sesión.',
      );

      expect(subject.error.value, 'Google rechazó el inicio de sesión.');
    });

    test('sin initialError no hay error', () {
      expect(controller.error.value, isEmpty);
      expect(controller.isLogged, isFalse);
      expect(controller.isLoading, isFalse);
    });

    test('al iniciar restaura una sesión guardada', () async {
      await repository.login(
        AuthenticationUser(
          email: leonel.email,
          name: '',
          password: password,
        ),
      );

      await start(controller);

      expect(controller.isLogged, isTrue);
      expect(controller.loggedEmail, leonel.email);
      expect(controller.loggedName, leonel.name);
    });

    test('al iniciar sin sesión guardada queda fuera', () async {
      await start(controller);

      expect(controller.isLogged, isFalse);
      expect(controller.loggedEmail, isEmpty);
    });

    test('si restaurar falla queda fuera sin romper', () async {
      final subject = await start(
        AuthenticationController(_BrokenRestoreRepository()),
      );

      expect(subject.isLogged, isFalse);
      expect(subject.loggedEmail, isEmpty);
      expect(subject.error.value, isEmpty);
    });
  });
}
