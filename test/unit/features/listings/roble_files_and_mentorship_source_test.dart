import 'package:campus_innovate/core/roble/roble_client.dart';
import 'package:campus_innovate/core/roble/roble_session.dart';
import 'package:campus_innovate/core/roble/roble_user.dart';
import 'package:campus_innovate/features/listings/data/datasources/remote/roble_mentorship_source.dart';
import 'package:campus_innovate/features/listings/data/datasources/remote/roble_project_file_source.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/mentorship_request.dart';
import 'package:campus_innovate/features/listings/domain/models/project_file.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_roble_api.dart';
import '../../../support/memory_preferences.dart';

/// What the two sources do that ROBLE will not: order the rows, read the size
/// back as a number, and turn the `UNIQUE (listing_id)` of the mentorships into
/// a message a person can read.
void main() {
  const contract = 'contrato_test';
  const project = '00000000-0000-4000-8000-00000000aaaa';
  const otherProject = '00000000-0000-4000-8000-00000000bbbb';

  late FakeRobleApi api;
  late RobleProjectFileSource files;
  late RobleMentorshipSource mentorships;

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

    final client = RobleClient(
      session: session,
      httpClient: api.client,
      baseUrl: 'https://roble-api.test',
      contractId: contract,
    );

    files = RobleProjectFileSource(client);
    mentorships = RobleMentorshipSource(client);
  });

  MentorshipRequest request({String listingId = project, String mentor = 'p1'}) =>
      MentorshipRequest.draft(
        listingId: listingId,
        listingTitle: 'Campus App',
        requesterId: 'user-1',
        requesterName: 'Ana Pérez',
        mentorId: mentor,
        mentorName: 'Profesora Díaz',
        message: 'Revisión de arquitectura',
      );

  group('archivos', () {
    test('lo más reciente primero, y el tamaño leído como número', () async {
      api.seed('project_files', {
        'listing_id': project,
        'name': 'viejo.pdf',
        'kind': 'file',
        'storage_id': 'obj-1',
        'size_bytes': '2048',
        'created_at': '2026-10-01T10:00:00Z',
      });
      api.seed('project_files', {
        'listing_id': project,
        'name': 'Drive',
        'kind': 'link',
        'url': 'https://drive.google.com/x',
        'created_at': '2026-10-03T10:00:00Z',
      });
      api.seed('project_files', {
        'listing_id': otherProject,
        'name': 'Ajeno',
        'kind': 'link',
        'created_at': '2026-10-04T10:00:00Z',
      });

      final found = await files.getFiles(project);

      expect(found.map((file) => file.name), ['Drive', 'viejo.pdf']);
      expect(found.first.isLink, isTrue);
      expect(found.last.sizeBytes, 2048);
      expect(found.last.storageId, 'obj-1');
    });

    test('createFile guarda cada columna y deleteFilesOf borra solo las del '
        'proyecto', () async {
      final stored = await files.createFile(
        ProjectFile.link(
          listingId: project,
          name: 'Repositorio',
          url: 'https://github.com/equipo/app',
          uploaderId: 'user-1',
          uploaderName: 'Ana Pérez',
        ),
      );
      await files.createFile(
        ProjectFile.link(
          listingId: otherProject,
          name: 'Otro',
          url: 'https://github.com/otro',
          uploaderId: 'user-1',
          uploaderName: 'Ana Pérez',
        ),
      );

      expect(stored.id, isNotEmpty);
      expect(api.rowsOf('project_files').first['kind'], 'link');
      expect(api.rowsOf('project_files').first['size_bytes'], 0);
      expect((await files.getFileById(stored.id))!.name, 'Repositorio');

      await files.deleteFilesOf(project);

      expect(api.rowsOf('project_files').single['name'], 'Otro');
    });

    test('un id que no es UUID no llega a ROBLE', () async {
      expect(await files.getFiles('listing_1'), isEmpty);
      expect(await files.getFileById('file_1'), isNull);
      expect(api.calls, isEmpty);
    });
  });

  group('mentoría', () {
    test('una segunda solicitud para el mismo proyecto se rechaza con un '
        'mensaje', () async {
      await mentorships.create(request());

      await expectLater(
        mentorships.create(request(mentor: 'p2')),
        throwsA(
          isA<ListingException>().having(
            (e) => e.message,
            'message',
            'Este proyecto ya tiene una solicitud de mentoría pendiente.',
          ),
        ),
      );
      expect(api.rowsOf('mentorship_requests'), hasLength(1));
    });

    test('se encuentra por proyecto, por mentor y por id', () async {
      final stored = await mentorships.create(request());
      await mentorships.create(request(listingId: otherProject));

      expect((await mentorships.getForListing(project))!.id, stored.id);
      expect(await mentorships.getForMentor('p1'), hasLength(2));
      expect(await mentorships.getForMentor('nadie'), isEmpty);
      expect((await mentorships.getById(stored.id))!.mentorName,
          'Profesora Díaz');
    });

    test('borrar libera el proyecto, y deleteFor borra solo las suyas',
        () async {
      final stored = await mentorships.create(request());
      await mentorships.create(request(listingId: otherProject));

      await mentorships.delete(stored.id);
      expect(await mentorships.getForListing(project), isNull);

      await mentorships.create(request(mentor: 'p2'));
      await mentorships.deleteFor(project);

      expect(
        api.rowsOf('mentorship_requests').single['listing_id'],
        otherProject,
      );
    });
  });
}
