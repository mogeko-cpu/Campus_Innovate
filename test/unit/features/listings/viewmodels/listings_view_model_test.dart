import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_stats.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/listings_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_listing_source.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

class _FailingListingSource extends InMemoryListingSource {
  @override
  Future<List<Listing>> getListings() async => throw StateError('listings');
}

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;
  late ListingsViewModel viewModel;

  List<String> ids() => viewModel.listings.map((listing) => listing.id).toList();

  setUp(() async {
    harness = ViewModelHarness();
    viewModel = await start(
      ListingsViewModel(harness.listings, harness.engagement, harness.session),
    );
  });

  test('sin filtros muestra todos los proyectos', () {
    expect(ids(), ['listing_1', 'listing_2', 'listing_3']);
    expect(viewModel.isLoading.value, isFalse);
    expect(viewModel.error.value, isNull);
  });

  group('categoría', () {
    test('filtra por la categoría elegida', () {
      viewModel.filterByCategory('Sostenibilidad');

      expect(ids(), ['listing_2']);
    });

    test('null vuelve a mostrar todas', () {
      viewModel.filterByCategory('Investigación');
      viewModel.filterByCategory(null);

      expect(ids(), hasLength(3));
    });

    test('una categoría sin proyectos deja la lista vacía', () {
      viewModel.filterByCategory('Arte y Cultura');

      expect(viewModel.listings, isEmpty);
    });
  });

  group('búsqueda', () {
    test('encuentra por título', () {
      viewModel.search('huerta');

      expect(ids(), ['listing_2']);
    });

    test('encuentra por descripción', () {
      viewModel.search('robot autónomo');

      expect(ids(), ['listing_3']);
    });

    test('no distingue mayúsculas', () {
      // "Campus App" by title, and the gardens project says "del campus".
      viewModel.search('CAMPUS');

      expect(ids(), ['listing_1', 'listing_2']);
    });

    test('ignora los espacios alrededor y un texto en blanco no filtra', () {
      viewModel.search('  huerta  ');
      expect(ids(), ['listing_2']);

      viewModel.search('   ');
      expect(ids(), hasLength(3));
    });

    test('sin coincidencias deja la lista vacía', () {
      viewModel.search('blockchain');

      expect(viewModel.listings, isEmpty);
    });
  });

  test('categoría y búsqueda se combinan', () {
    viewModel.search('campus');
    viewModel.filterByCategory('Sostenibilidad');

    expect(ids(), ['listing_2']);

    viewModel.filterByCategory('Investigación');

    expect(viewModel.listings, isEmpty);
  });

  test('isMember dice si la persona está en el equipo', () async {
    harness.session.signInAs(TestUsers.mariana);

    expect(viewModel.isMember(viewModel.listings.first), isTrue);
    expect(viewModel.isMember(viewModel.listings[1]), isFalse);
  });

  test('los contadores se leen por proyecto', () async {
    await harness.engagementSource.setReaction(
      listingId: 'listing_3',
      groupId: '',
      userId: 'user_2',
      reaction: ReactionType.like,
    );

    await viewModel.load();

    final robotics = viewModel.listings.last;
    expect(viewModel.statsOf(robotics).likes, 1);
    expect(viewModel.statsOf(viewModel.listings.first), same(ListingStats.empty));
  });

  test('un fallo al cargar muestra el mensaje de respaldo', () async {
    final failing = ViewModelHarness(listingSource: _FailingListingSource());

    final broken = ListingsViewModel(
      failing.listings,
      failing.engagement,
      failing.session,
    );
    await broken.load();

    expect(broken.error.value, 'No se pudieron cargar los proyectos');
    expect(broken.listings, isEmpty);
    expect(broken.isLoading.value, isFalse);
  });
}
