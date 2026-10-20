import 'package:campus_innovate/main.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/fake_auth_repository.dart';
import '../test/support/in_memory_engagement_source.dart';
import '../test/support/in_memory_group_chat_source.dart';
import '../test/support/in_memory_group_source.dart';
import '../test/support/in_memory_listing_source.dart';
import '../test/support/in_memory_notification_source.dart';
import '../test/support/in_memory_user_source.dart';
import '../test/support/test_bindings.dart';
import '../test/support/test_session.dart';

/// The whole app, started the way a person finds it, over in-memory storage.
///
/// Everything above the data sources is the real thing — routes, bindings,
/// view models, repositories, screens — so a flow that passes here is the flow
/// a student goes through; only ROBLE is replaced, because a test that reached
/// it would need credentials and would leave rows behind for the next run.
class CampusApp {
  CampusApp._(this.tester, this.session, this.auth, this.notifications);

  final WidgetTester tester;
  final TestSession session;
  final FakeAuthRepository auth;

  /// Kept so a flow can assert on who was told what.
  final InMemoryNotificationSource notifications;

  /// Opens the app at login with nobody signed in, or at home already signed
  /// in as [signedInAs].
  static Future<CampusApp> start(
    WidgetTester tester, {
    TestUser? signedInAs,
  }) async {
    final session = TestSession();
    if (signedInAs == null) {
      session.signOut();
    } else {
      session.signInAs(signedInAs);
    }

    final auth = FakeAuthRepository(session: session);
    final notifications = InMemoryNotificationSource();

    final bindings = TestBindings(
      source: InMemoryListingSource(),
      groupSource: InMemoryGroupSource(),
      engagementSource: InMemoryEngagementSource(),
      chatSource: InMemoryGroupChatSource(),
      userSource: InMemoryUserSource(),
      notificationSource: notifications,
      session: session,
      authRepository: auth,
    );

    // A phone held upright, tall enough that the lists build every card: they
    // are lazy, and what a flow counts must not depend on the window the
    // device happened to open.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      CampusInnovateApp(
        initialBinding: bindings,
        initialRoute: signedInAs == null ? AppRoutes.login : AppRoutes.home,
      ),
    );
    await tester.pumpAndSettle();

    return CampusApp._(tester, session, auth, notifications);
  }

  Future<void> logIn(TestUser user) async {
    await enter('Correo institucional', user.email);
    await enter('Contraseña', FakeAuthRepository.password);
    await tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));

    await waitForText('Hola, ${user.name.split(' ').first}');
  }

  /// Signs out from wherever the person is: the root tabs that offer the button
  /// are home and profile, so it goes home first.
  Future<void> logOut() async {
    if (find.byTooltip('Cerrar sesión').evaluate().isEmpty) {
      await goToTab('Inicio');
    }

    await tap(find.byTooltip('Cerrar sesión').first);
    await tap(find.widgetWithText(FilledButton, 'Cerrar sesión'));

    await waitForText('Iniciar sesión');
  }

  /// One of the five destinations of the bar at the bottom.
  Future<void> goToTab(String label) async {
    await tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
  }

  Future<void> tap(Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(String text) => tap(find.text(text));

  /// Types into the field whose label or hint is [label].
  Future<void> enter(String label, String text) async {
    await enterInto(
      find.ancestor(of: find.text(label), matching: find.byType(TextField)),
      text,
    );
  }

  /// Types into [field], for the fields found some other way than by label —
  /// a search box whose hint is gone once something was typed in it.
  Future<void> enterInto(Finder field, String text) async {
    await tester.ensureVisible(field.first);
    await tester.pumpAndSettle();

    // Tapped first: a submit unfocuses the form, and under the device binding
    // typing into a field that lost focus that way reaches the previous input
    // connection instead of this one.
    await tester.tap(field.first);
    await tester.pumpAndSettle();
    await tester.enterText(field.first, text);
    await tester.pumpAndSettle();
  }

  /// Pumps until [finder] matches, for what appears after an async step.
  ///
  /// Under the device binding `pumpAndSettle` can return while the step is still
  /// awaiting — no frame is scheduled during the gap — so a snackbar or the next
  /// screen may not be there yet when it does.
  Future<void> waitFor(
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        throw TestFailure('No apareció a tiempo: $finder');
      }

      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.pumpAndSettle();
  }

  Future<void> waitForText(String text) => waitFor(find.text(text));

  /// Goes back one screen, the way the app bar's arrow does.
  Future<void> back() async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  /// Waits out the snackbars a step left on screen.
  ///
  /// They sit over the bottom of the screen, where the navigation bar is, so a
  /// tap there while one is up would land on the snackbar. On a device the
  /// clock is real and has to be waited for; under the test binding it is
  /// advanced instead.
  Future<void> waitForSnackbars() async {
    if (tester.binding is LiveTestWidgetsFlutterBinding) {
      await Future<void>.delayed(const Duration(seconds: 5));
    } else {
      await tester.pump(const Duration(seconds: 5));
    }

    await tester.pumpAndSettle();
  }
}
