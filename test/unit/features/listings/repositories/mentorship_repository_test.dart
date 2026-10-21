import 'package:campus_innovate/features/listings/data/repositories/listing_repository.dart';
import 'package:campus_innovate/features/listings/data/repositories/mentorship_repository.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/mentorship_request.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_listing_source.dart';
import '../../../../support/in_memory_mentorship_source.dart';

Matcher _refusedWith(String message) => throwsA(
      isA<ListingException>().having((e) => e.message, 'message', message),
    );

void main() {
  // `listing_1` (Campus App) is led by user_2 and has room for 4; the tests add
  // user_1 as a member. prof_1 is outside every team.
  const project = 'listing_1';
  const leader = 'user_2';
  const member = 'user_1';
  const prof = 'prof_1';

  late InMemoryListingSource listings;
  late InMemoryMentorshipSource source;
  late MentorshipRepository repository;

  setUp(() async {
    listings = InMemoryListingSource();
    await listings.addMember(
      listingId: project,
      userId: member,
      userName: 'Leonel Triana',
    );

    source = InMemoryMentorshipSource();
    repository = MentorshipRepository(source, ListingRepository(listings));
  });

  Future<Listing> stored() async => (await listings.getListingById(project))!;

  MentorshipRequest draft({
    String by = member,
    String mentorId = prof,
    String message = '  Revisión de arquitectura  ',
  }) =>
      MentorshipRequest.draft(
        listingId: project,
        listingTitle: '',
        requesterId: by,
        requesterName: 'Leonel Triana',
        mentorId: mentorId,
        mentorName: 'Profesora Díaz',
        message: message,
      );

  group('solicitar', () {
    test('un integrante la pide, con el título copiado y el mensaje recortado',
        () async {
      final request = await repository.request(draft());

      expect(request.isPersisted, isTrue);
      expect(request.listingTitle, 'Campus App');
      expect(request.message, 'Revisión de arquitectura');
      expect(await repository.getPendingFor(project), isNotNull);
      expect(await repository.getMyInvitations(prof), hasLength(1));
    });

    test('alguien de afuera no la puede pedir', () async {
      await expectLater(
        repository.request(draft(by: 'user_3')),
        _refusedWith(
          'Solo el líder y los integrantes pueden solicitar mentoría.',
        ),
      );
    });

    test('un mentor no recluta al siguiente', () async {
      await listings.addMember(
        listingId: project,
        userId: 'mentor_1',
        role: ListingRole.mentor,
      );

      await expectLater(
        repository.request(draft(by: 'mentor_1')),
        _refusedWith(
          'Solo el líder y los integrantes pueden solicitar mentoría.',
        ),
      );
    });

    test('no se le pide a alguien del equipo', () async {
      await expectLater(
        repository.request(draft(mentorId: leader)),
        throwsA(isA<ListingException>()),
      );
    });

    test('sin mensaje no se envía', () async {
      await expectLater(
        repository.request(draft(message: '   ')),
        _refusedWith(
          'Cuéntale a la persona en qué necesita acompañamiento el equipo.',
        ),
      );
    });

    test('mientras una espera, no se pide otra', () async {
      await repository.request(draft());

      await expectLater(
        repository.request(draft(mentorId: 'prof_2')),
        _refusedWith(
          'Ya hay una solicitud de mentoría pendiente para Profesora Díaz.',
        ),
      );
    });

    test('si el proyecto ya tiene mentor, no se pide otro', () async {
      await listings.addMember(
        listingId: project,
        userId: 'mentor_1',
        role: ListingRole.mentor,
      );

      await expectLater(
        repository.request(draft()),
        _refusedWith('Este proyecto ya tiene mentor.'),
      );
    });
  });

  group('responder', () {
    test('al aceptar entra al equipo como mentor y la solicitud desaparece',
        () async {
      final request = await repository.request(draft());

      final answered = await repository.accept(
        requestId: request.id,
        actorId: prof,
      );

      expect(answered.requesterId, member);
      expect(source.all, isEmpty);

      final project0 = await stored();
      expect(project0.roleOf(prof), ListingRole.mentor);
      expect(project0.hasMentor, isTrue);
      expect(project0.mentors.single.userName, 'Profesora Díaz');
    });

    test('un mentor entra aunque el equipo esté completo, sin ocupar cupo',
        () async {
      await listings.addMember(listingId: project, userId: 'user_3');
      await listings.addMember(listingId: project, userId: 'user_4');
      expect((await stored()).isFull, isTrue);

      final request = await repository.request(draft());
      await repository.accept(requestId: request.id, actorId: prof);

      final full = await stored();
      expect(full.roleOf(prof), ListingRole.mentor);
      expect(full.memberCount, 4);
      expect(full.availableSlots, 0);
    });

    test('solo la persona invitada responde', () async {
      final request = await repository.request(draft());

      await expectLater(
        repository.accept(requestId: request.id, actorId: leader),
        _refusedWith(
          'Solo la persona a quien se le pidió la mentoría puede responderla.',
        ),
      );
      await expectLater(
        repository.reject(requestId: request.id, actorId: member),
        throwsA(isA<ListingException>()),
      );
      expect(source.all, hasLength(1));
    });

    test('rechazar borra la solicitud y deja pedírsela a otra persona',
        () async {
      final request = await repository.request(draft());

      await repository.reject(requestId: request.id, actorId: prof);

      expect(source.all, isEmpty);
      expect((await stored()).roleOf(prof), isNull);
      expect(
        (await repository.request(draft(mentorId: 'prof_2'))).isPersisted,
        isTrue,
      );
    });

    test('una solicitud que ya no existe lo dice', () async {
      await expectLater(
        repository.accept(requestId: 'mentorship_fantasma', actorId: prof),
        _refusedWith('Esta solicitud de mentoría ya no existe.'),
      );
    });
  });

  group('cancelar', () {
    test('la cancela quien la envió', () async {
      final request = await repository.request(draft());

      await repository.cancel(requestId: request.id, actorId: member);

      expect(source.all, isEmpty);
    });

    test('o el líder', () async {
      final request = await repository.request(draft());

      await repository.cancel(requestId: request.id, actorId: leader);

      expect(source.all, isEmpty);
    });

    test('nadie más', () async {
      await listings.addMember(listingId: project, userId: 'user_4');
      final request = await repository.request(draft());

      await expectLater(
        repository.cancel(requestId: request.id, actorId: 'user_4'),
        _refusedWith(
          'Solo quien envió la solicitud o el líder del proyecto pueden '
          'cancelarla.',
        ),
      );
    });
  });

  test('purgeListing borra lo que esperaba', () async {
    await repository.request(draft());

    await repository.purgeListing(project);

    expect(source.all, isEmpty);
  });
}
