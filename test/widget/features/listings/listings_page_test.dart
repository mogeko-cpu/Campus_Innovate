import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:campus_innovate/features/listings/ui/views/create_listing_page.dart';
import 'package:campus_innovate/features/listings/ui/views/listing_detail_page.dart';
import 'package:campus_innovate/features/listings/ui/views/listings_page.dart';
import 'package:campus_innovate/features/listings/ui/widgets/listing_card.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_engagement_source.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/test_bindings.dart';

/// The catalogue is unreachable, as when ROBLE is down.
class _FailingListingSource extends InMemoryListingSource {
  @override
  Future<List<Listing>> getListings() async =>
      throw const ListingException('Sin conexión con el servidor.');
}

void main() {
  tearDown(Get.reset);

  /// By type and not by the hint: the hint disappears once there is text, and
  /// a test that clears the field could no longer find it.
  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  List<String> visibleTitles(WidgetTester tester) => tester
      .widgetList<ListingCard>(find.byType(ListingCard))
      .map((card) => card.listing.title)
      .toList();

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  // Through a chip, since the search field has a horizontal Scrollable too.
  // Some chip is always built, whatever the scroll offset.
  Finder chipBar() => find
      .ancestor(
        of: find.byType(ChoiceChip).first,
        matching: find.byType(Scrollable),
      )
      .first;

  /// The chip bar is a lazy horizontal list: the chips past the edge are not
  /// built, so it is rewound and scrolled until [label] is on screen.
  Future<void> reveal(WidgetTester tester, String label) async {
    await tester.drag(chipBar(), const Offset(3000, 0));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(chip(label), 150, scrollable: chipBar());
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    await reveal(tester, label);
    await tester.tapVisible(chip(label));
  }

  Future<bool> isSelected(WidgetTester tester, String label) async {
    await reveal(tester, label);

    return tester.widget<ChoiceChip>(chip(label)).selected;
  }

  Future<void> openListings(WidgetTester tester, {TestBindings? bindings}) =>
      tester.pumpApp(route: AppRoutes.listings, bindings: bindings);

  testWidgets('lista todos los proyectos con "Todas" seleccionada',
      (tester) async {
    await openListings(tester);

    expect(find.text('Explorar proyectos'), findsOneWidget);
    expect(find.text('Buscar por título o descripción'), findsOneWidget);
    expect(visibleTitles(tester), [
      'Campus App',
      'Huerta Universitaria',
      'Semillero de Robótica',
    ]);
    expect(await isSelected(tester, 'Todas'), isTrue);
  });

  testWidgets('ofrece un chip por cada categoría', (tester) async {
    await openListings(tester);

    for (final category in [
      'Tecnología',
      'Investigación',
      'Sostenibilidad',
      'Emprendimiento',
      'Arte y Cultura',
      'Impacto Social',
    ]) {
      expect(await isSelected(tester, category), isFalse, reason: category);
      expect(chip(category), findsOneWidget);
    }
  });

  testWidgets('la búsqueda filtra por título sin importar mayúsculas',
      (tester) async {
    await openListings(tester);

    await search(tester, 'HUERTA');

    expect(visibleTitles(tester), ['Huerta Universitaria']);
  });

  testWidgets('la búsqueda también encuentra por la descripción',
      (tester) async {
    await openListings(tester);

    // "robot autónomo" is only in the description of the robotics project.
    await search(tester, 'robot autónomo');

    expect(visibleTitles(tester), ['Semillero de Robótica']);
  });

  testWidgets('borrar la búsqueda vuelve a mostrar todo', (tester) async {
    await openListings(tester);

    await search(tester, 'huerta');
    expect(visibleTitles(tester), hasLength(1));

    await search(tester, '');
    expect(visibleTitles(tester), hasLength(3));
  });

  testWidgets('sin coincidencias muestra "Ningún proyecto coincide"',
      (tester) async {
    await openListings(tester);

    await search(tester, 'astronomía cuántica');

    expect(find.byType(ListingCard), findsNothing);
    expect(find.text('Ningún proyecto coincide'), findsOneWidget);
    expect(
      find.text('Prueba con otra categoría o con otro término de búsqueda.'),
      findsOneWidget,
    );
  });

  testWidgets('un chip de categoría filtra y "Todas" quita el filtro',
      (tester) async {
    await openListings(tester);

    await tapChip(tester, 'Sostenibilidad');

    expect(await isSelected(tester, 'Sostenibilidad'), isTrue);
    expect(await isSelected(tester, 'Todas'), isFalse);
    expect(visibleTitles(tester), ['Huerta Universitaria']);

    await tapChip(tester, 'Todas');

    expect(await isSelected(tester, 'Todas'), isTrue);
    expect(visibleTitles(tester), hasLength(3));
  });

  testWidgets('una categoría sin proyectos muestra el estado vacío',
      (tester) async {
    await openListings(tester);

    await tapChip(tester, 'Arte y Cultura');

    expect(find.text('Ningún proyecto coincide'), findsOneWidget);
  });

  testWidgets('la categoría y la búsqueda se combinan', (tester) async {
    await openListings(tester);

    await tapChip(tester, 'Tecnología');
    expect(visibleTitles(tester), ['Campus App']);

    // Matches the robotics project, but that one is "Investigación".
    await search(tester, 'robot');
    expect(find.text('Ningún proyecto coincide'), findsOneWidget);

    await tapChip(tester, 'Investigación');
    expect(visibleTitles(tester), ['Semillero de Robótica']);
  });

  testWidgets('las tarjetas muestran los contadores de cada proyecto',
      (tester) async {
    final engagement = InMemoryEngagementSource();
    await engagement.setReaction(
      listingId: 'listing_3',
      groupId: '',
      userId: 'user_2',
      reaction: ReactionType.dislike,
    );

    await openListings(
      tester,
      bindings: TestBindings(engagementSource: engagement),
    );

    final card = tester.widget<ListingCard>(
      find.widgetWithText(ListingCard, 'Semillero de Robótica'),
    );
    expect(card.stats!.dislikes, 1);
    expect(card.stats!.likes, 0);
  });

  testWidgets('tocar un proyecto abre su detalle', (tester) async {
    await openListings(tester);

    await tester.tapText('Huerta Universitaria');

    expect(find.byType(ListingDetailPage), findsOneWidget);
    expect(find.text('Detalle del proyecto'), findsOneWidget);
    expect(find.text('2 de 6 integrantes'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(ListingsPage), findsOneWidget);
  });

  testWidgets('"Publicar" abre el formulario y al volver recarga la lista',
      (tester) async {
    final source = InMemoryListingSource();
    await openListings(tester, bindings: TestBindings(source: source));

    await tester.tapText('Publicar');
    expect(find.byType(CreateListingPage), findsOneWidget);

    await source.createListing(
      const Listing(
        id: '',
        title: 'Recién publicado',
        description: 'Llegó mientras el formulario estaba abierto.',
        category: 'Emprendimiento',
        creatorId: 'user_9',
        creatorName: 'Otra persona',
        maxMembers: 3,
        requiredSkills: [],
        memberIds: ['user_9'],
      ),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(visibleTitles(tester).first, 'Recién publicado');
  });

  testWidgets('si falla la carga lo dice con el motivo', (tester) async {
    await openListings(
      tester,
      bindings: TestBindings(source: _FailingListingSource()),
    );

    expect(find.text('No se pudieron cargar los proyectos'), findsOneWidget);
    expect(find.text('Sin conexión con el servidor.'), findsOneWidget);
    expect(find.byType(ListingCard), findsNothing);
  });
}
