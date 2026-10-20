import 'package:campus_innovate/features/listings/data/repositories/listing_repository.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_listing_source.dart';

/// Runs on the in-memory source, seeded with `listing_1` (user_2, 1 of 4),
/// `listing_2` (user_3 with user_4, 2 of 6) and `listing_3` (user_5, 1 of 5).
void main() {
  late InMemoryListingSource source;
  late ListingRepository repository;

  setUp(() {
    source = InMemoryListingSource();
    repository = ListingRepository(source);
  });

  Listing draft(
    String title, {
    String creatorId = 'user_1',
    int maxMembers = 4,
    String groupId = '',
  }) =>
      Listing.draft(
        title: title,
        description: 'd',
        category: 'Tecnología',
        creatorId: creatorId,
        creatorName: 'Leonel',
        maxMembers: maxMembers,
        requiredSkills: const [],
        groupId: groupId,
      );

  JoinRequest requestFrom(String applicantId, {String listingId = 'listing_1'}) =>
      JoinRequest.draft(
        listingId: listingId,
        applicantId: applicantId,
        applicantName: 'Alguien',
        motivation: 'm',
        skills: 's',
        availability: 'a',
      );

  group('destacados', () {
    test('son a lo sumo cinco y ninguno está lleno', () async {
      // A full one at the top, then enough open ones to overflow the limit.
      for (var i = 0; i < 4; i++) {
        await repository.createListing(draft('Abierto $i'));
      }
      await repository.createListing(draft('Lleno', maxMembers: 1));

      final featured = await repository.getFeaturedListings();

      expect(featured, hasLength(5));
      expect(featured.any((l) => l.isFull), isFalse);
      expect(featured.map((l) => l.title), isNot(contains('Lleno')));
    });

    test('con pocos proyectos devuelve los que haya', () async {
      expect(await repository.getFeaturedListings(), hasLength(3));
    });
  });

  test('crear asigna id y lo deja disponible por id', () async {
    final stored = await repository.createListing(draft('Nuevo'));

    expect(stored.isPersisted, isTrue);
    expect((await repository.getListingById(stored.id))?.title, 'Nuevo');
    expect(await repository.getListingById('no-existe'), isNull);
  });

  group('filtros por persona y grupo', () {
    test('mis proyectos son los que creé, no a los que me uní', () async {
      final mine = await repository.createListing(draft('Mío'));

      final result = await repository.getMyListings('user_1');

      expect(result.map((l) => l.id), [mine.id]);
    });

    test('a los que me uní incluye los míos y los ajenos', () async {
      final mine = await repository.createListing(draft('Mío'));

      expect(
        (await repository.getJoinedListings('user_4')).map((l) => l.id),
        ['listing_2'],
      );
      expect(
        (await repository.getJoinedListings('user_1')).map((l) => l.id),
        [mine.id],
      );
    });

    test('por grupo filtra por group_id', () async {
      final a = await repository.createListing(draft('A', groupId: 'group_1'));
      await repository.createListing(draft('B', groupId: 'group_2'));

      expect(
        (await repository.getListingsByGroup('group_1')).map((l) => l.id),
        [a.id],
      );
    });

    test('un grupo vacío no trae los proyectos sin grupo', () async {
      // The seeded ones have no group; asking for "" must not return them.
      expect(await repository.getListingsByGroup(''), isEmpty);
    });
  });

  group('solicitudes', () {
    test('mi solicitud es la de esa persona en ese proyecto', () async {
      await repository.createJoinRequest(requestFrom('user_8'));
      final mine = await repository.createJoinRequest(requestFrom('user_9'));

      final found = await repository.getMyRequestForListing(
        listingId: 'listing_1',
        applicantId: 'user_9',
      );

      expect(found?.id, mine.id);
      expect(
        await repository.getMyRequestForListing(
          listingId: 'listing_2',
          applicantId: 'user_9',
        ),
        isNull,
      );
    });

    test('mis solicitudes cruzan proyectos', () async {
      await repository.createJoinRequest(requestFrom('user_9'));
      await repository.createJoinRequest(
        requestFrom('user_9', listingId: 'listing_3'),
      );
      await repository.createJoinRequest(requestFrom('user_8'));

      final mine = await repository.getMyRequests('user_9');

      expect(mine.map((r) => r.listingId), ['listing_1', 'listing_3']);
    });

    test('aceptar agrega al integrante y marca la solicitud aceptada',
        () async {
      final request = await repository.createJoinRequest(requestFrom('user_9'));

      await repository.acceptJoinRequest(request.id);

      final listing = await repository.getListingById('listing_1');
      final stored = await repository.getMyRequestForListing(
        listingId: 'listing_1',
        applicantId: 'user_9',
      );

      expect(listing?.memberIds, contains('user_9'));
      expect(stored?.status, JoinRequestStatus.accepted);
    });

    test('aceptar dos veces no duplica al integrante', () async {
      final request = await repository.createJoinRequest(requestFrom('user_9'));

      await repository.acceptJoinRequest(request.id);
      await repository.acceptJoinRequest(request.id);

      final listing = await repository.getListingById('listing_1');
      expect(listing?.memberIds.where((id) => id == 'user_9'), hasLength(1));
    });

    test('aceptar en un proyecto lleno deja la solicitud pendiente', () async {
      final full = await repository.createListing(draft('Lleno', maxMembers: 1));
      final request = await repository.createJoinRequest(
        requestFrom('user_9', listingId: full.id),
      );

      await expectLater(
        repository.acceptJoinRequest(request.id),
        throwsA(isA<ListingException>()),
      );

      final stored = await repository.getMyRequestForListing(
        listingId: full.id,
        applicantId: 'user_9',
      );
      // Membership goes first, so a failed accept never reads as accepted.
      expect(stored?.status, JoinRequestStatus.pending);
    });

    test('aceptar una solicitud que no existe falla', () async {
      await expectLater(
        repository.acceptJoinRequest('no-existe'),
        throwsA(isA<StateError>()),
      );
    });

    test('rechazar marca la solicitud y no agrega a nadie', () async {
      final request = await repository.createJoinRequest(requestFrom('user_9'));

      await repository.rejectJoinRequest(request.id);

      final listing = await repository.getListingById('listing_1');
      final stored = (await repository.getRequestsForListing('listing_1')).single;

      expect(listing?.memberIds, isNot(contains('user_9')));
      expect(stored.status, JoinRequestStatus.rejected);
    });
  });

  test('borrar un proyecto se lleva sus solicitudes', () async {
    await repository.createJoinRequest(requestFrom('user_9'));

    await repository.deleteListing('listing_1');

    expect(await repository.getListingById('listing_1'), isNull);
    expect(await repository.getRequestsForListing('listing_1'), isEmpty);
    expect(await repository.getListings(), hasLength(2));
  });
}
