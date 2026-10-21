import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:campus_innovate/features/listings/ui/widgets/listing_card.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/test_bindings.dart';

Listing _project(String title, ListingStatus status, {String? category}) =>
    Listing(
      id: '',
      title: title,
      description: 'Un proyecto de prueba para el filtro por estado.',
      category: category ?? 'Tecnología',
      creatorId: 'user_7',
      creatorName: 'Camila Rojas',
      maxMembers: 4,
      requiredSkills: const [],
      memberIds: const ['user_7'],
      status: status,
    );

/// The three seeded projects are ideas; these add one of every other state.
Future<InMemoryListingSource> _seeded() async {
  final source = InMemoryListingSource();

  await source.createListing(
    _project('Radar de Buses', ListingStatus.inProgress),
  );
  await source.createListing(
    _project('Mural Colectivo', ListingStatus.paused, category: 'Arte y Cultura'),
  );
  await source.createListing(
    _project('Feria de Reciclaje', ListingStatus.done, category: 'Sostenibilidad'),
  );

  return source;
}

const _ideas = ['Campus App', 'Huerta Universitaria', 'Semillero de Robótica'];

void main() {
  tearDown(Get.reset);

  Finder statusFilter(String label) => find.widgetWithText(FilterChip, label);

  Finder categoryFilter(String label) => find.widgetWithText(ChoiceChip, label);

  Future<void> open(WidgetTester tester) async {
    await tester.pumpApp(
      route: AppRoutes.listings,
      bindings: TestBindings(source: await _seeded()),
    );
    // Room for all six cards, so the list builds every one of them.
    tester.useTallSurface(size: const Size(1000, 4000));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, Finder chip) async {
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  bool isSelected(WidgetTester tester, String label) =>
      tester.widget<FilterChip>(statusFilter(label)).selected;

  void expectTitles(List<String> shown) {
    expect(find.byType(ListingCard), findsNWidgets(shown.length));

    for (final title in shown) {
      expect(find.text(title), findsOneWidget);
    }
  }

  testWidgets('ofrece "Cualquier estado" y los cuatro estados, sin filtrar',
      (tester) async {
    await open(tester);

    for (final label in ['Cualquier estado', 'Idea', 'En curso', 'Pausado', 'Terminado']) {
      expect(statusFilter(label), findsOneWidget);
    }

    expect(isSelected(tester, 'Cualquier estado'), isTrue);
    expectTitles([
      ..._ideas,
      'Radar de Buses',
      'Mural Colectivo',
      'Feria de Reciclaje',
    ]);
  });

  testWidgets('"Idea" deja solo las ideas', (tester) async {
    await open(tester);
    await pick(tester, statusFilter('Idea'));

    expect(isSelected(tester, 'Idea'), isTrue);
    expect(isSelected(tester, 'Cualquier estado'), isFalse);
    expectTitles(_ideas);
  });

  testWidgets('cada estado deja solo sus proyectos', (tester) async {
    await open(tester);

    final expected = {
      'En curso': 'Radar de Buses',
      'Pausado': 'Mural Colectivo',
      'Terminado': 'Feria de Reciclaje',
    };

    for (final entry in expected.entries) {
      await pick(tester, statusFilter(entry.key));

      expect(isSelected(tester, entry.key), isTrue);
      expectTitles([entry.value]);
    }
  });

  testWidgets('"Cualquier estado" vuelve a mostrar todo', (tester) async {
    await open(tester);
    await pick(tester, statusFilter('Pausado'));
    await pick(tester, statusFilter('Cualquier estado'));

    expect(isSelected(tester, 'Cualquier estado'), isTrue);
    expect(find.byType(ListingCard), findsNWidgets(6));
  });

  testWidgets('se combina con la categoría', (tester) async {
    await open(tester);
    await pick(tester, categoryFilter('Sostenibilidad'));

    expectTitles(['Huerta Universitaria', 'Feria de Reciclaje']);

    await pick(tester, statusFilter('Terminado'));

    expectTitles(['Feria de Reciclaje']);

    await pick(tester, statusFilter('En curso'));

    expect(find.byType(ListingCard), findsNothing);
    expect(find.text('Ningún proyecto coincide'), findsOneWidget);
  });

  testWidgets('se combina con la búsqueda', (tester) async {
    await open(tester);
    await tester.enterField('Buscar por título o descripción', 'mural');
    await pick(tester, statusFilter('Pausado'));

    expectTitles(['Mural Colectivo']);

    await pick(tester, statusFilter('Idea'));

    expect(find.text('Ningún proyecto coincide'), findsOneWidget);
  });
}
