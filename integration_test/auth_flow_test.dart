import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/fake_auth_repository.dart';
import '../test/support/test_session.dart';
import 'flow_helpers.dart';

/// Entrar, registrarse y salir: la puerta de la app, de punta a punta.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  testWidgets('entrar con una cuenta existente lleva al inicio y salir vuelve '
      'al login', (tester) async {
    final app = await CampusApp.start(tester);

    expect(find.text('Campus Innovate'), findsOneWidget);

    await app.logIn(TestUsers.leonel);

    expect(app.session.currentUserId, TestUsers.leonel.id);
    expect(find.text('Ideas destacadas'), findsOneWidget);

    await app.logOut();

    expect(app.session.isSignedIn, isFalse);
    expect(app.auth.logOuts, 1);
  });

  testWidgets('el formulario frena los datos inválidos antes de llamar a '
      'ROBLE', (tester) async {
    final app = await CampusApp.start(tester);

    await app.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));

    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Escribe tu contraseña'), findsOneWidget);

    await app.enter('Correo institucional', 'sin-arroba');
    await app.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));

    expect(find.text('Escribe un correo válido'), findsOneWidget);

    // Nothing reached the repository: a rejected login spends one of the ten
    // ROBLE allows per network every 15 minutes.
    expect(app.auth.logins, 0);
  });

  testWidgets('una contraseña equivocada se informa y no deja entrar',
      (tester) async {
    final app = await CampusApp.start(tester);

    await app.enter('Correo institucional', TestUsers.leonel.email);
    await app.enter('Contraseña', 'no-es-esta');
    await app.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await app.waitForText('No se pudo entrar');

    expect(
      find.text('No se pudo iniciar sesión. Revisa tus datos.'),
      findsOneWidget,
    );
    expect(find.text('Ideas destacadas'), findsNothing);
    expect(app.session.isSignedIn, isFalse);

    await app.waitForSnackbars();
  });

  testWidgets('registrarse y luego entrar con la cuenta nueva', (tester) async {
    final app = await CampusApp.start(tester);

    await app.tapText('Crear una cuenta');

    expect(find.text('Tus datos'), findsOneWidget);

    await app.enter('Nombre completo', 'Valentina Rojas');
    await app.enter('Correo institucional', 'valentina@uninorte.edu.co');

    // A password that breaks ROBLE's policy never becomes a request.
    await app.enter('Contraseña', 'corta');
    await app.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));

    expect(app.auth.signUps, 0);

    await app.enter('Contraseña', FakeAuthRepository.password);
    await app.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));

    await app.waitForText('Cuenta creada');
    expect(app.auth.signUps, 1);

    await app.waitForSnackbars();

    await app.logIn(
      const TestUser(
        id: 'signup_1',
        name: 'Valentina Rojas',
        email: 'valentina@uninorte.edu.co',
      ),
    );

    expect(app.session.currentUserName, 'Valentina Rojas');
  });
}
