import 'package:campus_innovate/core/roble/roble_client.dart';
import 'package:campus_innovate/core/roble/roble_session.dart';
import 'package:campus_innovate/core/roble/roble_user.dart';
import 'package:campus_innovate/features/listings/data/datasources/remote/roble_listing_source.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_roble_api.dart';
import '../../../support/memory_preferences.dart';

/// The columns project management added — `status` on `listings`, `role` and
/// `user_name` on `listing_members` — and the rows written before them, which
/// have to keep reading as they did.
void main() {
  const contract = 'contrato_test';
  const missingId = '00000000-0000-4000-8000-000000009999';

  late FakeRobleApi api;
  late RobleListingSource source;

  setUp(() async {
    api = FakeRobleApi(contractId: contract);

    final session = RobleSession(MemoryPreferences());
    await session.save(
      accessToken: 'access-1',
      refreshToken: null,
      user: const RobleUser(
        id: 'user-1',
        email: 'ana@uninorte.edu.co',
        name: 'Ana Pérez',
      ),
    );

    source = RobleListingSource(
      RobleClient(
        session: session,
        httpClient: api.client,
        baseUrl: 'https://roble-api.test',
        contractId: contract,
      ),
    );
  });

  /// A listing row; [status] omitted means a row from before the column.
  String seedListing({
    String? status,
    String creatorId = 'user-2',
    int maxMembers = 4,
  }) {
    final row = api.seed('listings', {
      'title': 'Huerta Universitaria',
      'description': 'Cultivar alimentos en las zonas verdes del campus.',
      'category': 'Sostenibilidad',
      'creator_id': creatorId,
      'creator_name': 'Mariana Ospina',
      'max_members': maxMembers,
      'required_skills': ['Biología'],
      'group_id': 'group-1',
      'group_name': 'Innovación UN',
      'created_at': '2026-09-15T10:00:00Z',
      'status': ?status,
    });

    return row['_id'] as String;
  }

  /// A member row; without [role] and [name] it is a row from before roles.
  void seedMember(String listingId, String userId, {String? role, String? name}) {
    api.seed('listing_members', {
      'listing_id': listingId,
      'user_id': userId,
      'joined_at': '2026-09-15T10:00:00Z',
      'role': ?role,
      'user_name': ?name,
    });
  }

  Map<String, dynamic> memberRow(String listingId, String userId) =>
      api.rowsOf('listing_members').singleWhere(
            (row) => row['listing_id'] == listingId && row['user_id'] == userId,
          );

  group('estado del proyecto', () {
    test('se lee de la columna status', () async {
      final id = seedListing(status: 'paused');

      final listing = await source.getListingById(id);

      expect(listing?.status, ListingStatus.paused);
    });

    test('una fila sin estado o con uno desconocido es una idea', () async {
      seedListing();
      seedListing(status: 'archived');

      final listings = await source.getListings();

      expect(listings.map((l) => l.status), [
        ListingStatus.idea,
        ListingStatus.idea,
      ]);
    });

    test('publicar guarda el estado por su nombre', () async {
      await source.createListing(
        Listing.draft(
          title: 'Tutorías entre pares',
          description: 'Refuerzos para primeros semestres.',
          category: 'Impacto Social',
          creatorId: 'user-1',
          creatorName: 'Ana Pérez',
          maxMembers: 5,
          requiredSkills: const [],
        ).copyWith(status: ListingStatus.inProgress),
      );

      expect(api.rowsOf('listings').single['status'], 'inProgress');
    });
  });

  group('filas de integrantes', () {
    test('con rol y nombre describen al equipo', () async {
      final id = seedListing();
      seedMember(id, 'user-2', role: 'leader', name: 'Mariana Ospina');
      seedMember(id, 'user-3', role: 'mentor', name: 'Profe Ruiz');

      final listing = (await source.getListingById(id))!;

      expect(listing.memberIds, ['user-2', 'user-3']);
      expect(listing.members.map((m) => m.userName), [
        'Mariana Ospina',
        'Profe Ruiz',
      ]);
      expect(listing.roleOf('user-3'), ListingRole.mentor);
      expect(listing.leaderId, 'user-2');
    });

    test('las anteriores a los roles siguen dando creador líder', () async {
      final id = seedListing();
      seedMember(id, 'user-2');
      seedMember(id, 'user-3');

      final listing = (await source.getListingById(id))!;

      // Rows without a role add no entry; `Listing.team` fills them in.
      expect(listing.memberIds, ['user-2', 'user-3']);
      expect(listing.members, isEmpty);
      expect(listing.leaderId, 'user-2');
      expect(listing.roleOf('user-3'), ListingRole.member);
      expect(listing.team.first.userName, 'Mariana Ospina');
    });

    test('un creador con rol pero sin nombre toma el del proyecto', () async {
      final id = seedListing();
      seedMember(id, 'user-2', role: 'leader');
      seedMember(id, 'user-3', role: 'member');

      final listing = (await source.getListingById(id))!;

      expect(listing.members.first.userName, 'Mariana Ospina');
      // Nobody else has a name to borrow.
      expect(listing.members.last.userName, isEmpty);
    });

    test('un rol desconocido se trata como fila sin rol', () async {
      final id = seedListing();
      seedMember(id, 'user-2', role: 'owner', name: 'Mariana Ospina');

      final listing = (await source.getListingById(id))!;

      expect(listing.members, isEmpty);
      expect(listing.isLeader('user-2'), isTrue);
    });

    test('la lista completa agrupa los roles por proyecto', () async {
      final first = seedListing();
      final second = seedListing(creatorId: 'user-5');
      seedMember(first, 'user-2', role: 'leader', name: 'Mariana');
      seedMember(second, 'user-5', role: 'member', name: 'Andrés');
      seedMember(second, 'user-6', role: 'leader', name: 'Valentina');

      final byId = {for (final l in await source.getListings()) l.id: l};

      expect(byId[first]!.leaderId, 'user-2');
      expect(byId[second]!.leaderId, 'user-6');
      expect(byId[second]!.roleOf('user-5'), ListingRole.member);
    });

    test('publicar escribe al creador como líder con su nombre', () async {
      final created = await source.createListing(
        Listing.draft(
          title: 'Tutorías entre pares',
          description: 'Refuerzos para primeros semestres.',
          category: 'Impacto Social',
          creatorId: 'user-1',
          creatorName: 'Ana Pérez',
          maxMembers: 5,
          requiredSkills: const [],
        ),
      );

      final row = memberRow(created.id, 'user-1');
      expect(row['role'], 'leader');
      expect(row['user_name'], 'Ana Pérez');
      expect(created.members.single.role, ListingRole.leader);
    });

    test('quien entra lo hace como integrante con su nombre', () async {
      final id = seedListing();
      seedMember(id, 'user-2', role: 'leader', name: 'Mariana Ospina');

      await source.addMember(listingId: id, userId: 'user-1', userName: 'Ana');

      final row = memberRow(id, 'user-1');
      expect(row['role'], 'member');
      expect(row['user_name'], 'Ana');
    });
  });

  group('updateListing', () {
    test('escribe solo lo editable y devuelve lo que quedó guardado', () async {
      final id = seedListing(status: 'idea');
      seedMember(id, 'user-2', role: 'leader', name: 'Mariana Ospina');
      final current = (await source.getListingById(id))!;

      final updated = await source.updateListing(
        current.copyWith(
          title: 'Huerta 2.0',
          description: 'Ahora con compostaje y riego por goteo.',
          category: 'Investigación',
          maxMembers: 8,
          requiredSkills: const ['Biología', 'Química'],
          status: ListingStatus.inProgress,
          // Not editable here: must not reach the row.
          creatorId: 'user-9',
          groupId: 'group-9',
        ),
      );

      final row = api.rowsOf('listings').single;
      expect(row['title'], 'Huerta 2.0');
      expect(row['description'], 'Ahora con compostaje y riego por goteo.');
      expect(row['category'], 'Investigación');
      expect(row['max_members'], 8);
      expect(row['required_skills'], ['Biología', 'Química']);
      expect(row['status'], 'inProgress');
      expect(row['creator_id'], 'user-2');
      expect(row['group_id'], 'group-1');

      // Read back, members included: the update itself answers nothing.
      expect(updated.title, 'Huerta 2.0');
      expect(updated.status, ListingStatus.inProgress);
      expect(updated.creatorId, 'user-2');
      expect(updated.leaderId, 'user-2');
      expect(api.calls, containsAllInOrder(['update', 'read']));
    });

    test('un id que no es UUID se informa sin ir a ROBLE', () async {
      final draft = Listing.draft(
        title: 'Sin guardar',
        description: 'Un proyecto que nunca se publicó.',
        category: 'Tecnología',
        creatorId: 'user-1',
        creatorName: 'Ana',
        maxMembers: 3,
        requiredSkills: const [],
      ).copyWith(id: 'listing_1');

      await expectLater(
        source.updateListing(draft),
        throwsA(isA<ListingException>()),
      );
      expect(api.calls, isEmpty);
    });

    test('un proyecto borrado entretanto se informa', () async {
      final id = seedListing();
      final current = (await source.getListingById(id))!;
      api.rowsOf('listings').clear();

      await expectLater(
        source.updateListing(current.copyWith(title: 'Huerta 2.0')),
        throwsA(
          isA<ListingException>().having(
            (error) => error.message,
            'message',
            contains('ya no existe'),
          ),
        ),
      );
      expect(api.rowsOf('listings'), isEmpty);
    });
  });

  group('removeMember', () {
    test('borra solo la fila de esa persona en ese proyecto', () async {
      final id = seedListing();
      final other = seedListing();
      seedMember(id, 'user-2', role: 'leader');
      seedMember(id, 'user-3', role: 'member');
      seedMember(other, 'user-3', role: 'member');

      await source.removeMember(listingId: id, userId: 'user-3');

      expect((await source.getListingById(id))!.memberIds, ['user-2']);
      expect((await source.getListingById(other))!.memberIds, ['user-3']);
    });

    test('quitar a quien no está no borra nada', () async {
      final id = seedListing();
      seedMember(id, 'user-2');

      await source.removeMember(listingId: id, userId: 'user-9');

      expect(api.rowsOf('listing_members'), hasLength(1));
      expect(api.calls, isNot(contains('delete')));
    });

    test('un id que no es UUID no hace ninguna petición', () async {
      await source.removeMember(listingId: 'listing_1', userId: 'user-3');

      expect(api.calls, isEmpty);
    });
  });

  group('setMemberRole', () {
    test('cambia el rol en la fila de esa persona', () async {
      final id = seedListing();
      seedMember(id, 'user-2', role: 'leader', name: 'Mariana Ospina');
      seedMember(id, 'user-3', role: 'member', name: 'Carlos');

      await source.setMemberRole(
        listingId: id,
        userId: 'user-3',
        role: ListingRole.mentor,
      );

      expect(memberRow(id, 'user-3')['role'], 'mentor');
      expect(memberRow(id, 'user-3')['user_name'], 'Carlos');
      expect(memberRow(id, 'user-2')['role'], 'leader');
      expect((await source.getListingById(id))!.roleOf('user-3'),
          ListingRole.mentor);
    });

    test('a una fila anterior a los roles le pone uno', () async {
      final id = seedListing();
      seedMember(id, 'user-2');
      seedMember(id, 'user-3');

      // A transfer on an old project: the new leader gets the first role row,
      // and from then on the creator no longer leads by default.
      await source.setMemberRole(
        listingId: id,
        userId: 'user-3',
        role: ListingRole.leader,
      );

      final listing = (await source.getListingById(id))!;
      expect(listing.leaderId, 'user-3');
      expect(listing.roleOf('user-2'), ListingRole.member);
    });

    test('a quien no está en el equipo se le informa', () async {
      final id = seedListing();
      seedMember(id, 'user-2');

      await expectLater(
        source.setMemberRole(
          listingId: id,
          userId: 'user-9',
          role: ListingRole.mentor,
        ),
        throwsA(
          isA<ListingException>().having(
            (error) => error.message,
            'message',
            'Esa persona ya no está en el equipo.',
          ),
        ),
      );
      expect(api.calls, isNot(contains('update')));
    });

    test('un id que no es UUID se informa sin ir a ROBLE', () async {
      await expectLater(
        source.setMemberRole(
          listingId: 'listing_1',
          userId: 'user-2',
          role: ListingRole.mentor,
        ),
        throwsA(isA<ListingException>()),
      );
      expect(api.calls, isEmpty);
    });

    test('un proyecto sin filas de integrantes se informa', () async {
      await expectLater(
        source.setMemberRole(
          listingId: missingId,
          userId: 'user-2',
          role: ListingRole.mentor,
        ),
        throwsA(isA<ListingException>()),
      );
    });
  });
}
