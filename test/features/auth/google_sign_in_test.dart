import 'package:campus_innovate/core/roble/roble_client.dart';
import 'package:campus_innovate/core/roble/roble_session.dart';
import 'package:campus_innovate/core/roble/social/social_login_unsupported.dart';
import 'package:campus_innovate/features/auth/data/datasources/remote/roble_authentication_source.dart';
import 'package:campus_innovate/features/auth/domain/models/authentication_user.dart';
import 'package:campus_innovate/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:campus_innovate/features/auth/ui/viewmodels/authentication_controller.dart';
import 'package:campus_innovate/features/auth/ui/views/login_page.dart';
import 'package:campus_innovate/features/auth/ui/views/signup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/memory_preferences.dart';

/// "Continuar con Google": what the source answers where there is no browser to
/// hand the flow to, and that both screens offer the button.
void main() {
  group('la fuente', () {
    late MemoryPreferences preferences;
    late int requests;
    late RobleAuthenticationSource source;

    setUp(() {
      preferences = MemoryPreferences();
      requests = 0;

      final session = RobleSession(preferences);
      final client = RobleClient(
        session: session,
        httpClient: MockClient((request) async {
          requests++;

          return http.Response('{}', 200);
        }),
        baseUrl: 'https://roble-api.test',
        contractId: 'contrato_test',
      );

      source = RobleAuthenticationSource(client, session);
    });

    // These run on the Dart VM, which is exactly the platform without a browser:
    // the conditional export resolves to the stub and `Uri.base` has no query.
    test('outside the web it says so instead of opening the flow', () async {
      await expectLater(
        source.startGoogleSignIn(),
        throwsA(
          isA<SocialLoginUnsupported>().having(
            (error) => error.message,
            'message',
            contains('web'),
          ),
        ),
      );

      // Refused before the request: otherwise the flow would be open on Google's
      // side with nobody able to finish it.
      expect(requests, 0);
    });

    test('an ordinary launch is not mistaken for a return from Google',
        () async {
      expect(await source.completeGoogleSignIn(), isFalse);

      // The second look would only find a code ROBLE already invalidated.
      expect(await source.completeGoogleSignIn(), isFalse);
      expect(requests, 0);
      expect(preferences.values, isEmpty);
    });
  });

  group('las pantallas', () {
    late _FakeAuthRepository repository;

    setUp(() => repository = _FakeAuthRepository());
    tearDown(Get.reset);

    Future<void> pump(WidgetTester tester, Widget page,
        {String bootError = ''}) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Get.put(
        AuthenticationController(repository, initialError: bootError),
        permanent: true,
      );

      await tester.pumpWidget(GetMaterialApp(home: page));
      await tester.pumpAndSettle();
    }

    /// Drains the 3s auto-dismiss timer of [Get.snackbar].
    Future<void> settleSnackbar(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    }

    testWidgets('entrar y registrarse ofrecen el mismo botón', (tester) async {
      await pump(tester, const LoginPage());
      expect(find.text('Continuar con Google'), findsOneWidget);

      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();
      expect(repository.googleStarts, 1);
      await settleSnackbar(tester);

      Get.reset();
      repository = _FakeAuthRepository();

      await pump(tester, const SignUpPage());
      expect(find.text('Continuar con Google'), findsOneWidget);
    });

    testWidgets('un regreso fallido se cuenta en la pantalla de login',
        (tester) async {
      // The exchange happens while the app boots, so the message is already in
      // the controller when the screen appears: this is the only place it can be
      // shown.
      await pump(
        tester,
        const LoginPage(),
        bootError: 'Google no autorizó el inicio de sesión.',
      );

      expect(find.text('No se pudo entrar con Google'), findsOneWidget);
      expect(
        find.text('Google no autorizó el inicio de sesión.'),
        findsOneWidget,
      );

      await settleSnackbar(tester);
    });

    testWidgets('si no se puede abrir el flujo, se dice y no se navega',
        (tester) async {
      repository.googleFailure = const SocialLoginUnsupported();

      await pump(tester, const LoginPage());
      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo continuar con Google'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);

      await settleSnackbar(tester);
    });
  });
}

/// The repository the screens talk to, without ROBLE.
class _FakeAuthRepository implements IAuthRepository {
  int googleStarts = 0;
  Object? googleFailure;

  @override
  Future<void> startGoogleSignIn() async {
    googleStarts++;

    if (googleFailure != null) throw googleFailure!;
  }

  @override
  Future<bool> completeGoogleSignIn() async => false;

  @override
  Future<bool> restoreSession() async => false;

  @override
  Future<AuthenticationUser?> getLoggedUser() async => null;

  @override
  Future<bool> login(AuthenticationUser user) async => false;

  @override
  Future<bool> signUp(AuthenticationUser user) async => false;

  @override
  Future<bool> logOut() async => true;

  @override
  Future<bool> validate(String email, String validationCode) async => false;

  @override
  Future<bool> validateToken() async => false;

  @override
  Future<void> forgotPassword(String email) async {}
}
