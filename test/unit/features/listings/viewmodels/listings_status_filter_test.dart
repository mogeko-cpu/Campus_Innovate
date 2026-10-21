import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/listings_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../view_model_harness.dart';

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;
  late ListingsViewModel viewModel;

  List<String> titles() =>
      viewModel.listings.map((listing) => listing.title).toList();

  Future<void> seed(String title, String category, ListingStatus status) =>
      harness.listingSource.createListing(
        Listing(
          id: '',
          title: title,
          description: 'Proyecto de prueba del campus.',
          category: category,
          creatorId: 'user_3',
          creatorName: 'Carlos Ruiz',
          maxMembers: 4,
          requiredSkills: const [],
          memberIds: const ['user_3'],
          status: status,
        ),
      );

  setUp(() async {
    harness = ViewModelHarness();
    // The three seeded projects are ideas; these add one of every other state.
    await seed('Robot en curso', 'Investigación', ListingStatus.inProgress);
    await seed('Huerta pausada', 'Sostenibilidad', ListingStatus.paused);
    await seed('App terminada', 'Tecnología', ListingStatus.done);
    await seed('Sensores en curso', 'Tecnología', ListingStatus.inProgress);

    viewModel = await start(
      ListingsViewModel(harness.listings, harness.engagement, harness.session),
    );
  });

  test('sin estado elegido muestra todos los estados', () {
    expect(viewModel.selectedStatus.value, isNull);
    expect(viewModel.listings, hasLength(7));
  });

  test('filtra por el estado elegido', () {
    viewModel.filterByStatus(ListingStatus.inProgress);
    expect(titles(), ['Sensores en curso', 'Robot en curso']);

    viewModel.filterByStatus(ListingStatus.done);
    expect(titles(), ['App terminada']);

    viewModel.filterByStatus(ListingStatus.idea);
    expect(
      titles(),
      ['Campus App', 'Huerta Universitaria', 'Semillero de Robótica'],
    );
  });

  test('null vuelve a mostrar todos', () {
    viewModel.filterByStatus(ListingStatus.paused);
    viewModel.filterByStatus(null);

    expect(viewModel.listings, hasLength(7));
  });

  test('se combina con la categoría', () {
    viewModel.filterByCategory('Tecnología');
    viewModel.filterByStatus(ListingStatus.inProgress);

    expect(titles(), ['Sensores en curso']);

    viewModel.filterByStatus(ListingStatus.idea);
    expect(titles(), ['Campus App']);
  });

  test('se combina con la búsqueda', () {
    viewModel.search('robot');
    expect(titles(), ['Robot en curso', 'Semillero de Robótica']);

    viewModel.filterByStatus(ListingStatus.inProgress);
    expect(titles(), ['Robot en curso']);
  });

  test('los tres filtros juntos pueden dejar la lista vacía', () {
    viewModel.filterByCategory('Sostenibilidad');
    viewModel.filterByStatus(ListingStatus.paused);
    viewModel.search('huerta');
    expect(titles(), ['Huerta pausada']);

    viewModel.filterByStatus(ListingStatus.done);
    expect(viewModel.listings, isEmpty);
  });
}
