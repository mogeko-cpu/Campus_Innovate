import 'package:campus_innovate/core/theme_controller.dart';
import 'package:campus_innovate/features/auth/ui/views/login_page.dart';
import 'package:campus_innovate/features/groups/ui/views/group_detail_page.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:campus_innovate/features/profile/ui/views/profile_page.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_engagement_source.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/test_bindings.dart';
import '../../../support/test_session.dart';

/// The number above [label] in the stats row.
String _stat(WidgetTester tester, String label) {
  final stat = find
      .ancestor(
        of: find.descendant(of: find.byType(Wrap), matching: find.text(label)),
        matching: find.byType(Column),
      )
      .first;

  return tester
      .widgetList<Text>(find.descendant(of: stat, matching: find.byType(Text)))
      .first
      .data!;
}

/// Somebody with nothing in the app yet, so every section is empty.
const _newcomer = FakeSessionService(
  currentUserId: 'user_9',
  currentUserName: 'Ana Pérez',
  currentUserEmail: 'ana@uninorte.edu.co',
);

void main() {
  tearDown(Get.reset);

  testWidgets('muestra el nombre, las iniciales y el correo', (tester) async {
    await tester.pumpApp(route: AppRoutes.profile);

    expect(find.text('Leonel Triana'), findsOneWidget);
    expect(find.text('LT'), findsOneWidget);
    expect(find.text('leonel@uninorte.edu.co'), findsOneWidget);
  });

  testWidgets('quien no tiene nada ve todas las secciones vacías y ceros',
      (tester) async {
    await tester.pumpApp(
      route: AppRoutes.profile,
      bindings: TestBindings(session: _newcomer),
    );

    expect(find.text('AP'), findsOneWidget);
    for (final label in [
      'Grupos',
      'Publicados',
      'Participaciones',
      'Me gusta recibidos',
      'Vistas',
    ]) {
      expect(_stat(tester, label), '0', reason: label);
    }

    expect(find.text('Todavía no haces parte de un grupo'), findsOneWidget);
    expect(find.text('Aún no has publicado proyectos'), findsOneWidget);
    expect(
      find.text('Todavía no te unes a proyectos de otras personas'),
      findsOneWidget,
    );
    expect(find.text('No has enviado solicitudes'), findsOneWidget);
  });

  testWidgets('cuenta grupos, proyectos, participaciones, me gusta y vistas',
      (tester) async {
    final listings = InMemoryListingSource();
    final engagement = InMemoryEngagementSource();

    final mine = await listings.createListing(
      const Listing(
        id: '',
        title: 'Tutorías entre pares',
        description: 'Refuerzos para primeros semestres.',
        category: 'Impacto Social',
        creatorId: 'user_1',
        creatorName: 'Leonel Triana',
        maxMembers: 4,
        requiredSkills: [],
        memberIds: ['user_1'],
        groupId: 'group_1',
        groupName: 'Innovación UN',
      ),
    );
    await listings.addMember(listingId: 'listing_3', userId: 'user_1');
    await listings.createJoinRequest(
      const JoinRequest.draft(
        listingId: 'listing_1',
        applicantId: 'user_1',
        applicantName: 'Leonel Triana',
        motivation: 'Quiero aportar en el diseño',
        skills: 'Figma',
        availability: 'Tardes',
      ),
    );
    for (final user in ['user_2', 'user_3']) {
      await engagement.setReaction(
        listingId: mine.id,
        groupId: 'group_1',
        userId: user,
        reaction: ReactionType.like,
      );
      await engagement.registerView(
        listingId: mine.id,
        groupId: 'group_1',
        userId: user,
      );
    }
    await engagement.registerView(
      listingId: mine.id,
      groupId: 'group_1',
      userId: 'user_4',
    );
    // Activity on somebody else's project is not Leonel's.
    await engagement.setReaction(
      listingId: 'listing_1',
      groupId: '',
      userId: 'user_4',
      reaction: ReactionType.like,
    );

    await tester.pumpApp(
      route: AppRoutes.profile,
      bindings: TestBindings(source: listings, engagementSource: engagement),
    );

    expect(_stat(tester, 'Grupos'), '1');
    expect(_stat(tester, 'Publicados'), '1');
    expect(_stat(tester, 'Participaciones'), '1');
    expect(_stat(tester, 'Me gusta recibidos'), '2');
    expect(_stat(tester, 'Vistas'), '3');

    expect(find.text('Innovación UN'), findsOneWidget);
    expect(find.text('Creador · 1 integrantes'), findsOneWidget);
    expect(find.text('Tutorías entre pares'), findsOneWidget);
    expect(find.text('1 de 4 integrantes · Impacto Social'), findsOneWidget);
    expect(find.text('Semillero de Robótica'), findsOneWidget);
    expect(find.text('Creado por Andrés Betancur'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Quiero aportar en el diseño'), findsOneWidget);
  });

  testWidgets('tocar un grupo propio abre su detalle', (tester) async {
    await tester.pumpApp(route: AppRoutes.profile);

    await tester.tapText('Innovación UN');

    expect(find.byType(GroupDetailPage), findsOneWidget);
  });

  testWidgets('el selector de apariencia cambia el modo del tema',
      (tester) async {
    await tester.pumpApp(route: AppRoutes.profile);

    final theme = Get.find<ThemeController>();
    expect(theme.themeMode.value, ThemeMode.system);

    await tester.tapText('Oscuro');
    expect(theme.themeMode.value, ThemeMode.dark);
    expect(Theme.of(tester.element(find.byType(ProfilePage))).brightness,
        Brightness.dark);

    await tester.tapText('Claro');
    expect(theme.themeMode.value, ThemeMode.light);

    final selector = tester.widget<SegmentedButton<ThemeMode>>(
      find.byType(SegmentedButton<ThemeMode>),
    );
    expect(selector.selected, {ThemeMode.light});
  });

  testWidgets('cancelar el cierre de sesión deja todo como estaba',
      (tester) async {
    final auth = FakeAuthRepository();

    await tester.pumpApp(
      route: AppRoutes.profile,
      bindings: TestBindings(authRepository: auth),
    );

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tapText('Cancelar');

    expect(find.byType(ProfilePage), findsOneWidget);
    expect(auth.logOuts, 0);
  });

  testWidgets('confirmar el cierre de sesión lleva al login', (tester) async {
    final session = TestSession(TestUsers.leonel);
    final auth = FakeAuthRepository(session: session);

    await tester.pumpApp(
      route: AppRoutes.profile,
      bindings: TestBindings(session: session, authRepository: auth),
    );

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    await tester.tapVisible(
      find.widgetWithText(FilledButton, 'Cerrar sesión'),
    );

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(ProfilePage), findsNothing);
    expect(Get.currentRoute, AppRoutes.login);
    expect(auth.logOuts, 1);
    expect(session.isSignedIn, isFalse);
  });
}
