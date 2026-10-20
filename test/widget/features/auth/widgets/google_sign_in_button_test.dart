import 'dart:async';

import 'package:campus_innovate/core/user_facing_exception.dart';
import 'package:campus_innovate/features/auth/ui/viewmodels/authentication_controller.dart';
import 'package:campus_innovate/features/auth/ui/widgets/google_sign_in_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';
import '../../../../support/fake_auth_repository.dart';

/// A refusal written for the user, the way ROBLE's errors are.
class _Refused implements UserFacingException {
  const _Refused(this.message);

  @override
  final String message;
}

/// Keeps the hand-off to Google open until the test lets it finish, to look at
/// the button while the request is in flight.
class _PendingGoogle extends FakeAuthRepository {
  final pending = Completer<void>();

  @override
  Future<void> startGoogleSignIn() async {
    googleStarts++;
    await pending.future;
  }
}

void main() {
  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester, FakeAuthRepository repository) async {
    Get.put(AuthenticationController(repository), permanent: true);

    await tester.pumpWidget(wrapWidget(const GoogleSignInButton()));
    await tester.pumpAndSettle();
  }

  ButtonStyleButton button(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Continuar con Google'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );

  testWidgets('muestra el separador "o", la marca G y el botón',
      (tester) async {
    await pump(tester, FakeAuthRepository());

    expect(find.text('o'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
    expect(find.text('G'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(button(tester).enabled, isTrue);
  });

  testWidgets('tocarlo inicia el flujo de Google y, si arranca, no avisa nada',
      (tester) async {
    final repository = FakeAuthRepository();
    await pump(tester, repository);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(repository.googleStarts, 1);
    expect(find.text('No se pudo continuar con Google'), findsNothing);
  });

  testWidgets('mientras el flujo está en curso el botón se deshabilita',
      (tester) async {
    final repository = _PendingGoogle();
    await pump(tester, repository);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();

    expect(button(tester).enabled, isFalse);

    // A second tap while disabled must not open a second flow.
    await tester.tap(find.text('Continuar con Google'), warnIfMissed: false);
    expect(repository.googleStarts, 1);

    repository.pending.complete();
    await tester.pumpAndSettle();

    expect(button(tester).enabled, isTrue);
  });

  testWidgets('un rechazo legible se muestra tal cual en el aviso',
      (tester) async {
    final repository = FakeAuthRepository()
      ..googleFailure = const _Refused('Demasiados intentos, espera 40 segundos.');
    await pump(tester, repository);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo continuar con Google'), findsOneWidget);
    expect(find.text('Demasiados intentos, espera 40 segundos.'), findsOneWidget);

    await tester.settleSnackbars();
  });

  testWidgets('un error técnico se reemplaza por un mensaje genérico',
      (tester) async {
    final repository = FakeAuthRepository()
      ..googleFailure = StateError('Null check operator used on a null value');
    await pump(tester, repository);

    await tester.tap(find.text('Continuar con Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo iniciar sesión con Google. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('Null check'), findsNothing);

    await tester.settleSnackbars();
  });
}
