import 'package:campus_innovate/features/home/ui/viewmodels/home_view_model.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_stats.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:campus_innovate/features/users/domain/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_listing_source.dart';
import '../../../../support/in_memory_user_source.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

class _FailingListingSource extends InMemoryListingSource {
  _FailingListingSource(this.failure);

  final Object failure;

  @override
  Future<List<Listing>> getListings() async => throw failure;
}

class _FailingUserSource extends InMemoryUserSource {
  @override
  Future<void> upsert(AppUser user) async => throw StateError('app_users');
}

Listing _listing(
  String title, {
  int maxMembers = 4,
  List<String> memberIds = const ['user_9'],
}) =>
    Listing(
      id: '',
      title: title,
      description: 'Descripción de $title',
      category: 'Tecnología',
      creatorId: memberIds.first,
      creatorName: 'Alguien',
      maxMembers: maxMembers,
      requiredSkills: const [],
      memberIds: memberIds,
    );

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  HomeViewModel build() => HomeViewModel(
        harness.listings,
        harness.engagement,
        harness.users,
        harness.session,
        harness.mentorships,
      );

  setUp(() => harness = ViewModelHarness());

  test('saluda con el nombre de la sesión', () {
    final viewModel = build();

    expect(viewModel.userName, 'Leonel Triana');
    expect(viewModel.firstName, 'Leonel');
  });

  group('destacados', () {
    test('son los proyectos con cupo del seed', () async {
      final viewModel = await start(build());

      expect(
        viewModel.featuredListings.map((listing) => listing.id),
        ['listing_1', 'listing_2', 'listing_3'],
      );
      expect(viewModel.isLoading.value, isFalse);
      expect(viewModel.error.value, isNull);
    });

    test('excluyen los proyectos llenos y se cortan en 5', () async {
      await harness.listingSource.createListing(
        _listing('Lleno', maxMembers: 2, memberIds: ['user_8', 'user_9']),
      );
      for (var index = 0; index < 4; index++) {
        await harness.listingSource.createListing(_listing('Nuevo $index'));
      }

      final viewModel = await start(build());

      expect(viewModel.featuredListings, hasLength(5));
      expect(
        viewModel.featuredListings.every((listing) => !listing.isFull),
        isTrue,
      );
      expect(
        viewModel.featuredListings.map((listing) => listing.title),
        isNot(contains('Lleno')),
      );
    });
  });

  group('mis proyectos', () {
    test('están vacíos para quien no está en ninguno', () async {
      final viewModel = await start(build());

      expect(viewModel.myListings, isEmpty);
    });

    test('son aquellos en los que la persona es integrante', () async {
      harness.session.signInAs(TestUsers.mariana);

      final viewModel = await start(build());

      expect(viewModel.myListings.map((listing) => listing.id), ['listing_1']);
    });
  });

  group('contadores', () {
    test('se leen por proyecto, y sin actividad son ceros', () async {
      await harness.engagementSource.setReaction(
        listingId: 'listing_1',
        groupId: '',
        userId: 'user_3',
        reaction: ReactionType.like,
      );
      await harness.engagementSource.registerView(
        listingId: 'listing_1',
        groupId: '',
        userId: 'user_3',
      );

      final viewModel = await start(build());

      final campusApp = viewModel.featuredListings.first;
      expect(viewModel.statsOf(campusApp).likes, 1);
      expect(viewModel.statsOf(campusApp).views, 1);
      expect(
        viewModel.statsOf(viewModel.featuredListings[1]),
        same(ListingStats.empty),
      );
    });
  });

  group('errores', () {
    test('un error genérico muestra el mensaje de respaldo', () async {
      harness = ViewModelHarness(
        listingSource: _FailingListingSource(StateError('red')),
      );

      final viewModel = await start(build());

      expect(viewModel.error.value, 'No se pudieron cargar las ideas');
      expect(viewModel.featuredListings, isEmpty);
      expect(viewModel.isLoading.value, isFalse);
    });

    test('un error para el usuario se muestra tal cual', () async {
      harness = ViewModelHarness(
        listingSource: _FailingListingSource(
          const ListingException('Tu sesión expiró.'),
        ),
      );

      final viewModel = await start(build());

      expect(viewModel.error.value, 'Tu sesión expiró.');
    });

    test('recargar después de un error lo limpia', () async {
      final viewModel = await start(build());
      viewModel.error.value = 'anterior';

      await viewModel.load();

      expect(viewModel.error.value, isNull);
    });
  });

  group('directorio de personas', () {
    test('al abrir registra a quien tiene la sesión', () async {
      await start(build());

      final users = await harness.users.getUsers();
      final me = users.where((user) => user.id == 'user_1').toList();

      expect(me, hasLength(1));
      expect(me.single.name, 'Leonel Triana');
      expect(me.single.email, 'leonel@uninorte.edu.co');
    });

    test('si registrarse falla la pantalla carga igual', () async {
      harness = ViewModelHarness(userSource: _FailingUserSource());

      final viewModel = await start(build());

      expect(viewModel.error.value, isNull);
      expect(viewModel.featuredListings, hasLength(3));
    });
  });
}
