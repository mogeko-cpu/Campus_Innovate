import 'dart:async';

import 'package:campus_innovate/features/auth/ui/views/login_page.dart';
import 'package:campus_innovate/features/home/ui/views/home_page.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:campus_innovate/features/listings/ui/views/create_listing_page.dart';
import 'package:campus_innovate/features/listings/ui/views/listing_detail_page.dart';
import 'package:campus_innovate/features/listings/ui/widgets/listing_card.dart';
import 'package:campus_innovate/main.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/fake_auth_repository.dart';
import '../../../support/in_memory_engagement_source.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/in_memory_user_source.dart';
import '../../../support/test_bindings.dart';

/// The catalogue is unreachable, as when ROBLE is down.
class _FailingListingSource extends InMemoryListingSource {
  @override
  Future<List<Listing>> getListings() async =>
      throw const ListingException('Sin conexión con el servidor.');
}

/// A campus where nobody has published anything yet.
class _EmptyListingSource extends InMemoryListingSource {
  @override
  Future<List<Listing>> getListings() async => const [];
}

/// Holds the first read until the test releases it, to see the spinner.
class _SlowListingSource extends InMemoryListingSource {
  final gate = Completer<void>();

  @override
  Future<List<Listing>> getListings() async {
    await gate.future;
    return super.getListings();
  }
}

Listing _open(String title, {String creatorId = 'user_8', int max = 4}) =>
    Listing(
      id: '',
      title: title,
      description: 'Descripción suficientemente larga de $title.',
      category: 'Tecnología',
      creatorId: creatorId,
      creatorName: 'Persona $creatorId',
      maxMembers: max,
      requiredSkills: const [],
      memberIds: [creatorId],
    );

void main() {
  tearDown(Get.reset);

  /// The titles of the cards under one section, in order.
  List<String> cardTitles(WidgetTester tester) => tester
      .widgetList<ListingCard>(find.byType(ListingCard))
      .map((card) => card.listing.title)
      .toList();

  testWidgets('saluda por el primer nombre de quien inició sesión',
      (tester) async {
    await tester.pumpApp(
      bindings: TestBindings(
        session: const FakeSessionService(
          currentUserId: 'user_2',
          currentUserName: 'Mariana Ospina',
          currentUserEmail: 'mariana@uninorte.edu.co',
        ),
      ),
    );

    expect(find.text('Hola, Mariana'), findsOneWidget);
    expect(find.text('Hola, Mariana Ospina'), findsNothing);
    expect(find.text('CAMPUS INNOVATE'), findsOneWidget);
  });

  testWidgets('al abrir se registra en el directorio de usuarios',
      (tester) async {
    final users = InMemoryUserSource();

    await tester.pumpApp(bindings: TestBindings(userSource: users));

    final directory = await users.getUsers();
    expect(directory.map((user) => user.id), contains('user_1'));
    expect(
      directory.firstWhere((user) => user.id == 'user_1').email,
      'leonel@uninorte.edu.co',
    );
  });

  testWidgets('mientras carga muestra un indicador y luego las ideas',
      (tester) async {
    final source = _SlowListingSource();

    tester.useTallSurface();
    await tester.pumpWidget(
      CampusInnovateApp(
        initialBinding: TestBindings(source: source),
        initialRoute: AppRoutes.home,
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ListingCard), findsNothing);

    source.gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Campus App'), findsOneWidget);
  });

  testWidgets('las destacadas omiten los equipos llenos y son a lo sumo cinco',
      (tester) async {
    final source = InMemoryListingSource();
    await source.createListing(
      _open('Equipo lleno', max: 2).copyWith(memberIds: ['user_8', 'user_9']),
    );
    for (var i = 1; i <= 4; i++) {
      await source.createListing(_open('Idea abierta $i'));
    }

    await tester.pumpApp(bindings: TestBindings(source: source));

    final featured = cardTitles(tester);
    expect(featured, hasLength(5));
    expect(featured, isNot(contains('Equipo lleno')));
    // The newest are stored first, and the seeded three come after them.
    expect(featured.take(4), [
      'Idea abierta 4',
      'Idea abierta 3',
      'Idea abierta 2',
      'Idea abierta 1',
    ]);
  });

  testWidgets('las tarjetas muestran los contadores de cada proyecto',
      (tester) async {
    final engagement = InMemoryEngagementSource();
    await engagement.setReaction(
      listingId: 'listing_2',
      groupId: '',
      userId: 'user_7',
      reaction: ReactionType.like,
    );
    await engagement.setReaction(
      listingId: 'listing_2',
      groupId: '',
      userId: 'user_8',
      reaction: ReactionType.like,
    );

    await tester.pumpApp(
      bindings: TestBindings(engagementSource: engagement),
    );

    final huerta = find.widgetWithText(ListingCard, 'Huerta Universitaria');
    expect(
      tester.widget<ListingCard>(huerta).stats!.likes,
      2,
    );
    expect(find.descendant(of: huerta, matching: find.text('2')), findsOneWidget);
  });

  testWidgets('sin ideas con cupo muestra el estado vacío', (tester) async {
    await tester.pumpApp(
      bindings: TestBindings(source: _EmptyListingSource()),
    );

    expect(
      find.text('Todavía no hay ideas con cupos disponibles'),
      findsOneWidget,
    );
    expect(find.text('Aún no participas en ningún proyecto'), findsOneWidget);
    expect(find.byType(ListingCard), findsNothing);
  });

  testWidgets('si falla la carga lo dice con el motivo', (tester) async {
    await tester.pumpApp(
      bindings: TestBindings(source: _FailingListingSource()),
    );

    expect(find.text('No se pudieron cargar las ideas'), findsOneWidget);
    expect(find.text('Sin conexión con el servidor.'), findsOneWidget);
    expect(find.byType(ListingCard), findsNothing);
  });

  testWidgets('"Mis proyectos" lista aquellos de los que soy integrante',
      (tester) async {
    final source = InMemoryListingSource();
    await source.createListing(_open('Mi propio proyecto', creatorId: 'user_1'));

    await tester.pumpApp(bindings: TestBindings(source: source));

    expect(find.text('Aún no participas en ningún proyecto'), findsNothing);
    // Once among the featured ones and once under "Mis proyectos".
    expect(find.text('Mi propio proyecto'), findsNWidgets(2));
    expect(cardTitles(tester).last, 'Mi propio proyecto');
  });

  testWidgets('"Publicar idea" abre el formulario de publicación',
      (tester) async {
    await tester.pumpApp();

    await tester.tapText('Publicar idea');

    expect(find.byType(CreateListingPage), findsOneWidget);
  });

  testWidgets('tocar una idea abre su detalle y al volver se recarga',
      (tester) async {
    final source = InMemoryListingSource();
    await tester.pumpApp(bindings: TestBindings(source: source));

    await tester.tapText('Huerta Universitaria');
    expect(find.byType(ListingDetailPage), findsOneWidget);
    expect(find.text('2 de 6 integrantes'), findsOneWidget);

    // Something changes while the detail is open...
    await source.createListing(_open('Publicada mientras tanto'));

    await tester.pageBack();
    await tester.pumpAndSettle();

    // ...and home shows it after coming back.
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Publicada mientras tanto'), findsOneWidget);
  });

  testWidgets('cancelar el cierre de sesión deja todo como estaba',
      (tester) async {
    final auth = FakeAuthRepository();
    await tester.pumpApp(bindings: TestBindings(authRepository: auth));

    await tester.tapVisible(find.byTooltip('Cerrar sesión'));

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(
      find.text(
        'Tendrás que volver a escribir tu correo y contraseña para entrar.',
      ),
      findsOneWidget,
    );

    await tester.tapText('Cancelar');

    expect(find.text('¿Cerrar sesión?'), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(auth.logOuts, 0);
  });

  testWidgets('confirmar el cierre de sesión lleva al login sin vuelta atrás',
      (tester) async {
    final auth = FakeAuthRepository();
    await tester.pumpApp(bindings: TestBindings(authRepository: auth));

    await tester.tapVisible(find.byTooltip('Cerrar sesión'));
    await tester.tapVisible(find.widgetWithText(FilledButton, 'Cerrar sesión'));

    expect(auth.logOuts, 1);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(
      Navigator.of(tester.element(find.byType(LoginPage))).canPop(),
      isFalse,
    );
  });
}
