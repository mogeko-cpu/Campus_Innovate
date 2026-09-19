import 'package:campus_innovate/core/roble/roble_client.dart';
import 'package:campus_innovate/core/roble/roble_session.dart';
import 'package:campus_innovate/core/roble/roble_user.dart';
import 'package:campus_innovate/features/listings/data/datasources/remote/roble_listing_source.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_roble_api.dart';
import '../../support/memory_preferences.dart';

/// What the source has to do that ROBLE will not: group members across two
/// tables, order rows, undo a half-written project, and turn a `UNIQUE`
/// violation into either a friendly message or a success.
void main() {
  const contract = 'contrato_test';

  late FakeRobleApi api;
  late RobleListingSource source;

  Future<RobleListingSource> sourceOn(http.Client client) async {
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

    return RobleListingSource(
      RobleClient(
        session: session,
        httpClient: client,
        baseUrl: 'https://roble-api.test',
        contractId: contract,
      ),
    );
  }

  setUp(() async {
    api = FakeRobleApi(contractId: contract);
    source = await sourceOn(api.client);
  });

  /// A listing row as the console would show it, with its members.
  String seedListing({
    required String title,
    required String createdAt,
    String creatorId = 'user-2',
    int maxMembers = 4,
    List<String> members = const [],
  }) {
    final row = api.seed('listings', {
      'title': title,
      'description': 'Descripción de $title',
      'category': 'Tecnología',
      'creator_id': creatorId,
      'creator_name': 'Sebastián González',
      'max_members': maxMembers,
      'required_skills': ['Flutter', 'Diseño UI'],
      'created_at': createdAt,
    });

    final id = row['_id'] as String;

    for (final member in members) {
      api.seed('listing_members', {
        'listing_id': id,
        'user_id': member,
        'joined_at': createdAt,
      });
    }

    return id;
  }

  test('listings come back newest first with their members attached', () async {
    seedListing(
      title: 'Campus App',
      createdAt: '2026-09-01T10:00:00Z',
      members: ['user-2'],
    );
    seedListing(
      title: 'Huerta Universitaria',
      createdAt: '2026-09-15T10:00:00Z',
      members: ['user-3', 'user-4'],
    );

    final listings = await source.getListings();

    expect(
      listings.map((listing) => listing.title),
      ['Huerta Universitaria', 'Campus App'],
    );
    expect(listings.first.memberIds, ['user-3', 'user-4']);
    expect(listings.last.memberIds, ['user-2']);
    // `jsonb` arrives as a real list, so the skills survive the round trip.
    expect(listings.first.requiredSkills, ['Flutter', 'Diseño UI']);
  });

  test('a row without created_at sorts last instead of breaking the list',
      () async {
    seedListing(title: 'Sin fecha', createdAt: '');
    seedListing(title: 'Con fecha', createdAt: '2026-09-15T10:00:00Z');

    final listings = await source.getListings();

    expect(listings.map((listing) => listing.title), ['Con fecha', 'Sin fecha']);
  });

  test('publishing stores the project and its creator as first member',
      () async {
    final created = await source.createListing(
      Listing.draft(
        title: 'Tutorías entre pares',
        description: 'Refuerzos para primeros semestres.',
        category: 'Impacto Social',
        creatorId: 'user-1',
        creatorName: 'Ana Pérez',
        maxMembers: 5,
        requiredSkills: const ['Pedagogía'],
      ),
    );

    expect(created.isPersisted, isTrue);
    expect(created.memberIds, ['user-1']);

    expect(api.rowsOf('listings'), hasLength(1));
    expect(api.rowsOf('listings').single['title'], 'Tutorías entre pares');
    expect(api.rowsOf('listings').single['created_at'], isNotEmpty);
    expect(api.rowsOf('listing_members'), hasLength(1));
    expect(api.rowsOf('listing_members').single['listing_id'], created.id);
  });

  test('a project whose membership cannot be written is not left behind',
      () async {
    // The listing insert succeeds and the membership one fails: without the
    // compensating delete the project would exist with nobody in it, and no
    // screen can fix that.
    final client = MockClient((request) async {
      if (request.url.pathSegments.last == 'insert-one' &&
          request.body.contains('listing_members')) {
        return http.Response('{"message":"la base de datos no responde"}', 500);
      }

      return api.handle(request);
    });

    final guarded = await sourceOn(client);

    await expectLater(
      guarded.createListing(
        Listing.draft(
          title: 'Tutorías entre pares',
          description: 'Refuerzos para primeros semestres.',
          category: 'Impacto Social',
          creatorId: 'user-1',
          creatorName: 'Ana Pérez',
          maxMembers: 5,
          requiredSkills: const [],
        ),
      ),
      throwsA(isA<Exception>()),
    );

    expect(api.rowsOf('listings'), isEmpty);
    expect(api.calls, contains('delete'));
  });

  test('joining twice adds one row and does not fail', () async {
    final id = seedListing(
      title: 'Huerta Universitaria',
      createdAt: '2026-09-15T10:00:00Z',
      maxMembers: 6,
      members: ['user-2'],
    );

    await source.addMember(listingId: id, userId: 'user-1');
    // The second call finds them already in and writes nothing.
    await source.addMember(listingId: id, userId: 'user-1');

    expect(api.rowsOf('listing_members'), hasLength(2));
  });

  test('the UNIQUE catching a race counts as already joined', () async {
    final id = seedListing(
      title: 'Huerta Universitaria',
      createdAt: '2026-09-15T10:00:00Z',
      maxMembers: 6,
    );
    api.seed('listing_members', {
      'listing_id': id,
      'user_id': 'user-1',
      'joined_at': '2026-09-15T10:00:00Z',
    });

    // The membership exists but the read does not see it — the state the other
    // device leaves behind between our read and our insert. The insert then hits
    // the constraint, and being a member is what the caller wanted anyway.
    final stale = MockClient((request) async {
      if (request.url.pathSegments.last == 'read' &&
          request.url.queryParameters['tableName'] == 'listing_members') {
        return http.Response('[]', 200);
      }

      return api.handle(request);
    });

    final racing = await sourceOn(stale);

    await racing.addMember(listingId: id, userId: 'user-1');

    expect(api.rowsOf('listing_members'), hasLength(1));
  });

  test('a full project refuses a new member', () async {
    final id = seedListing(
      title: 'Campus App',
      createdAt: '2026-09-15T10:00:00Z',
      maxMembers: 2,
      members: ['user-2', 'user-3'],
    );

    await expectLater(
      source.addMember(listingId: id, userId: 'user-1'),
      throwsA(
        isA<ListingException>().having(
          (error) => error.message,
          'message',
          contains('máximo de integrantes'),
        ),
      ),
    );

    expect(api.rowsOf('listing_members'), hasLength(2));
  });

  test('a listing that no longer exists is reported, not ignored', () async {
    await expectLater(
      source.addMember(
        listingId: '00000000-0000-4000-8000-000000009999',
        userId: 'user-1',
      ),
      throwsA(isA<ListingException>()),
    );
  });

  test('an id that is not a UUID reads as absent without a request', () async {
    expect(await source.getListingById('listing_1'), isNull);
    expect(await source.getRequestsForListing('listing_1'), isEmpty);
    expect(await source.getRequestById('7'), isNull);
    expect(api.calls, isEmpty);
  });

  test('a second application to the same project is explained', () async {
    final id = seedListing(
      title: 'Huerta Universitaria',
      createdAt: '2026-09-15T10:00:00Z',
    );

    final draft = JoinRequest.draft(
      listingId: id,
      applicantId: 'user-1',
      applicantName: 'Ana Pérez',
      motivation: 'Quiero aprender.',
      skills: 'Biología',
      availability: '8 horas',
    );

    final stored = await source.createJoinRequest(draft);
    expect(stored.isPersisted, isTrue);
    expect(stored.status, JoinRequestStatus.pending);

    await expectLater(
      source.createJoinRequest(draft),
      throwsA(
        isA<ListingException>().having(
          (error) => error.message,
          'message',
          'Ya enviaste una solicitud a este proyecto.',
        ),
      ),
    );
  });

  test('requests are listed oldest first and keep their status', () async {
    final id = seedListing(
      title: 'Huerta Universitaria',
      createdAt: '2026-09-15T10:00:00Z',
    );

    api.seed('join_requests', {
      'listing_id': id,
      'applicant_id': 'user-4',
      'applicant_name': 'Segundo',
      'motivation': '',
      'skills': '',
      'availability': '',
      'status': 'accepted',
      'created_at': '2026-09-17T10:00:00Z',
    });
    api.seed('join_requests', {
      'listing_id': id,
      'applicant_id': 'user-3',
      'applicant_name': 'Primero',
      'motivation': '',
      'skills': '',
      'availability': '',
      'status': 'pending',
      'created_at': '2026-09-16T10:00:00Z',
    });

    final requests = await source.getRequestsForListing(id);

    expect(requests.map((request) => request.applicantName), [
      'Primero',
      'Segundo',
    ]);
    expect(requests.last.status, JoinRequestStatus.accepted);

    await source.updateRequestStatus(requests.first.id, JoinRequestStatus.rejected);

    final updated = await source.getRequestById(requests.first.id);
    expect(updated?.status, JoinRequestStatus.rejected);
  });
}
