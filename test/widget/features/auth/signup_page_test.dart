import 'package:campus_innovate/core/user_facing_exception.dart';
import 'package:campus_innovate/features/auth/ui/views/login_page.dart';
import 'package:campus_innovate/features/auth/ui/views/signup_page.dart';
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

  Future<void> openSignUp(WidgetTester tester) async {
    auth = FakeAuthRepository();
    await tester.pumpApp(
      route: AppRoutes.signup,
      bindings: TestBindings(authRepository: auth),
    );
  }

  // "Crear cuenta" is also the title of the app bar.
  Future<void> submit(WidgetTester tester) =>
      tester.tapVisible(find.widgetWithText(FilledButton, 'Crear cuenta'));

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Valentina Herrera',
    String email = 'valentina@uninorte.edu.co',
    String password = FakeAuthRepository.password,
  }) async {
    await tester.enterField('Nombre completo', name);
    await tester.enterField('Correo institucional', email);
    await tester.enterField('Contraseña', password);
  }

  testWidgets('explica la política de contraseñas antes de escribir',
      (tester) async {
    await openSignUp(tester);

    expect(find.text('Tus datos'), findsOneWidget);
    expect(
      find.text(
        'Mínimo 8 caracteres, con mayúscula, minúscula, número y un símbolo '
        r'(!@#$_-.)',
      ),
      findsOneWidget,
    );
  });

  testWidgets('enviar vacío muestra un mensaje por campo y no registra',
      (tester) async {
    await openSignUp(tester);

    await submit(tester);

    expect(find.text('Escribe tu nombre completo'), findsOneWidget);
    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(
      find.text('La contraseña debe tener al menos 8 caracteres.'),
      findsOneWidget,
    );
    expect(auth.signUps, 0);
  });

  testWidgets('un nombre de menos de tres letras y un correo sin arroba '
      'se rechazan', (tester) async {
    await openSignUp(tester);

    await fill(tester, name: ' Al ', email: 'valentina');
    await submit(tester);

    expect(find.text('Escribe tu nombre completo'), findsOneWidget);
    expect(find.text('Escribe un correo válido'), findsOneWidget);
    expect(auth.signUps, 0);
  });

  testWidgets('la contraseña se valida regla por regla, en orden',
      (tester) async {
    await openSignUp(tester);
    await tester.enterField('Nombre completo', 'Valentina Herrera');
    await tester.enterField('Correo institucional', 'valentina@uninorte.edu.co');

    final cases = {
      'corta1!': 'La contraseña debe tener al menos 8 caracteres.',
      'sinmayuscula1!': 'La contraseña debe incluir una letra mayúscula.',
      'SINMINUSCULA1!': 'La contraseña debe incluir una letra minúscula.',
      'SinNumero!!': 'La contraseña debe incluir un número.',
      'SinSimbolo12': r'La contraseña debe incluir uno de estos símbolos: !@#$_-.',
      // `%` looks strong, but ROBLE does not accept it.
      'ConPorcentaje1%': r'La contraseña debe incluir uno de estos símbolos: !@#$_-.',
    };

    for (final MapEntry(key: password, value: message) in cases.entries) {
      await tester.enterField('Contraseña', password);
      await submit(tester);

      expect(find.text(message), findsOneWidget, reason: password);
    }

    expect(auth.signUps, 0);
  });

  testWidgets('crear la cuenta lleva al login, sin registro detrás, y con '
      'ella se puede entrar de inmediato', (tester) async {
    await openSignUp(tester);

    await fill(tester);
    await submit(tester);

    expect(auth.signUps, 1);
    expect(
      auth.accounts['valentina@uninorte.edu.co']!.user.name,
      'Valentina Herrera',
    );
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(SignUpPage), findsNothing);

    // The stack was replaced: there is no sign-up screen behind the login.
    expect(
      Navigator.of(tester.element(find.byType(LoginPage))).canPop(),
      isFalse,
    );

    // On the login screen, where the person will use the new account.
    expect(find.text('Cuenta creada'), findsOneWidget);
    await tester.settleSnackbars();

    await tester.enterField('Correo institucional', 'valentina@uninorte.edu.co');
    await tester.enterField('Contraseña', FakeAuthRepository.password);
    await tester.tapVisible(find.widgetWithText(FilledButton, 'Iniciar sesión'));

    expect(auth.logins, 1);
    expect(find.byType(LoginPage), findsNothing);

    await tester.settleSnackbars();
  });

  testWidgets('un correo ya registrado muestra el aviso y se queda en el '
      'registro', (tester) async {
    await openSignUp(tester);

    await fill(tester, email: TestUsers.mariana.email);
    await submit(tester);

    expect(auth.signUps, 1);
    expect(find.text('No se pudo registrar'), findsOneWidget);
    expect(
      find.text('No se pudo crear la cuenta. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.byType(SignUpPage), findsOneWidget);

    await tester.settleSnackbars();
  });

  testWidgets('el rechazo del servidor se muestra con sus propias palabras',
      (tester) async {
    await openSignUp(tester);
    auth.signUpFailure = const _Refused(
      'Se alcanzó el límite de registros. Intenta en una hora.',
    );

    await fill(tester);
    await submit(tester);

    expect(find.text('No se pudo registrar'), findsOneWidget);
    expect(
      find.text('Se alcanzó el límite de registros. Intenta en una hora.'),
      findsOneWidget,
    );
    expect(find.text('Cuenta creada'), findsNothing);

    await tester.settleSnackbars();
  });

  testWidgets('también ofrece continuar con Google', (tester) async {
    await openSignUp(tester);

    expect(find.text('Continuar con Google'), findsOneWidget);
  });
}
