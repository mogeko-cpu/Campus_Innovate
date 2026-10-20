import 'package:campus_innovate/core/user_facing_exception.dart';
import 'package:campus_innovate/features/auth/ui/views/login_page.dart';
import 'package:campus_innovate/features/auth/ui/views/signup_page.dart';
import 'package:campus_innovate/features/home/ui/views/home_page.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/test_bindings.dart';
import '../../../support/test_session.dart';

/// A refusal written for the user, the way ROBLE's errors are.
class _Refused implements UserFacingException {
  const _Refused(this.message);

  @override
  final String message;
}

void main() {
  tearDown(Get.reset);

  late FakeAuthRepository auth;

  Future<void> openLogin(WidgetTester tester) async {
    auth = FakeAuthRepository();
    await tester.pumpApp(
      route: AppRoutes.login,
      bindings: TestBindings(authRepository: auth),
    );
  }

  Future<void> submit(WidgetTester tester) =>
      tester.tapVisible(find.widgetWithText(FilledButton, 'Iniciar sesión'));

  testWidgets('arranca con el formulario vacío y sin credenciales precargadas',
      (tester) async {
    await openLogin(tester);

    expect(find.text('Campus Innovate'), findsOneWidget);
    expect(find.text('Correo institucional'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller!.text, isEmpty);
    }

    // The password field hides what is typed.
    final password = tester.widget<TextField>(
      find.ancestor(of: find.text('Contraseña'), matching: find.byType(TextField)),
    );
    expect(password.obscureText, isTrue);
  });

  testWidgets('enviar vacío muestra los dos mensajes y no intenta entrar',
      (tester) async {
    await openLogin(tester);

    await submit(tester);

    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);
    expect(auth.logins, 0);
  });

  testWidgets('un correo sin arroba se rechaza en el formulario',
      (tester) async {
    await openLogin(tester);

    await tester.enterField('Correo institucional', 'leonel.uninorte.edu.co');
    await tester.enterField('Contraseña', FakeAuthRepository.password);
    await submit(tester);

    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(auth.logins, 0);
  });

  testWidgets('un correo que el formulario deja pasar pero no es válido '
      'se explica en un aviso sin llegar al servidor', (tester) async {
    await openLogin(tester);

    await tester.enterField('Correo institucional', 'a@b');
    await tester.enterField('Contraseña', 'cualquiera');
    await submit(tester);

    expect(find.text('No se pudo entrar'), findsOneWidget);
    expect(
      find.text('Escribe tu correo institucional y tu contraseña.'),
      findsOneWidget,
    );
    expect(auth.logins, 0);

    await tester.settleSnackbars();
  });

  testWidgets('con las credenciales correctas entra al inicio y no se puede '
      'volver al login', (tester) async {
    await openLogin(tester);

    await tester.enterField('Correo institucional', TestUsers.leonel.email);
    await tester.enterField('Contraseña', FakeAuthRepository.password);
    await submit(tester);

    expect(auth.logins, 1);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.text('Hola, Leonel'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(HomePage))).canPop(),
      isFalse,
    );
  });

  testWidgets('el correo se acepta con espacios alrededor', (tester) async {
    await openLogin(tester);

    await tester.enterField(
      'Correo institucional',
      '  ${TestUsers.mariana.email}  ',
    );
    await tester.enterField('Contraseña', FakeAuthRepository.password);
    await submit(tester);

    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('una contraseña equivocada muestra el aviso y se queda en login',
      (tester) async {
    await openLogin(tester);

    await tester.enterField('Correo institucional', TestUsers.leonel.email);
    await tester.enterField('Contraseña', 'NoEsLaClave1!');
    await submit(tester);

    expect(auth.logins, 1);
    expect(find.text('No se pudo entrar'), findsOneWidget);
    expect(
      find.text('No se pudo iniciar sesión. Revisa tus datos.'),
      findsOneWidget,
    );
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);

    await tester.settleSnackbars();
  });

  testWidgets('el error del servidor se muestra con sus propias palabras',
      (tester) async {
    await openLogin(tester);
    auth.loginFailure = const _Refused(
      'Demasiados intentos. Espera 40 segundos.',
    );

    await tester.enterField('Correo institucional', TestUsers.leonel.email);
    await tester.enterField('Contraseña', FakeAuthRepository.password);
    await submit(tester);

    expect(find.text('No se pudo entrar'), findsOneWidget);
    expect(find.text('Demasiados intentos. Espera 40 segundos.'), findsOneWidget);
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.settleSnackbars();
  });

  testWidgets('un fallo técnico se reemplaza por un mensaje genérico',
      (tester) async {
    await openLogin(tester);
    auth.loginFailure = StateError('Bad state: socket closed');

    await tester.enterField('Correo institucional', TestUsers.leonel.email);
    await tester.enterField('Contraseña', FakeAuthRepository.password);
    await submit(tester);

    expect(
      find.text('No se pudo iniciar sesión. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('socket'), findsNothing);

    await tester.settleSnackbars();
  });

  testWidgets('"Crear una cuenta" abre el registro y se puede volver',
      (tester) async {
    await openLogin(tester);

    await tester.tapText('Crear una cuenta');

    expect(find.byType(SignUpPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('ofrece entrar con Google', (tester) async {
    await openLogin(tester);

    await tester.tapText('Continuar con Google');

    expect(auth.googleStarts, 1);
  });
}
