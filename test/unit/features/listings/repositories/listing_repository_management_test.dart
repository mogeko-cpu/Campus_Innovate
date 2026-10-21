import 'package:campus_innovate/features/listings/data/repositories/listing_repository.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_listing_source.dart';

/// The rules that came with managing a project: editing it, its status, the
/// team's roles and who leads. The repository is where they are enforced — a
/// hidden button is only a hint — so every refusal is checked to leave the
/// stored project as it was.
void main() {
  late InMemoryListingSource source;
  late ListingRepository repository;

  setUp(() {
    source = InMemoryListingSource();
    repository = ListingRepository(source);
  });

  const leader = 'user_1';
  const description = 'Una app para organizar la vida en el campus.';

  /// A project led by `user_1`, with [others] already in as plain members.
  Future<Listing> project({
    int maxMembers = 4,
    List<String> others = const [],
  }) async {
    final created = await repository.createListing(
      Listing.draft(
        title: 'Campus App',
        description: description,
        category: 'Tecnología',
        creatorId: leader,
        creatorName: 'Leonel',
        maxMembers: maxMembers,
        requiredSkills: const ['Flutter'],
      ),
    );

    for (final id in others) {
      await source.addMember(
        listingId: created.id,
        userId: id,
        userName: 'Nombre de $id',
      );
    }

    return (await source.getListingById(created.id))!;
  }

  Future<Listing> stored(String id) async => (await source.getListingById(id))!;

  Matcher refusal(String message) => throwsA(
        isA<ListingException>().having(
          (error) => error.message,
          'message',
          contains(message),
        ),
      );

  JoinRequest requestFrom(String applicantId, String listingId) =>
      JoinRequest.draft(
        listingId: listingId,
        applicantId: applicantId,
        applicantName: 'Persona $applicantId',
        motivation: 'Quiero aprender',
        skills: 'Dart',
        availability: '6 horas',
      );

  group('updateListing', () {
    test('el líder edita lo que el formulario ofrece, ya recortado', () async {
      final original = await project();

      final updated = await repository.updateListing(
        original.copyWith(
          title: '  Campus App 2.0  ',
          description: '  Ahora con mapas, horarios y avisos.  ',
          category: 'Impacto Social',
          maxMembers: 6,
          requiredSkills: const ['Flutter', 'Figma'],
          status: ListingStatus.inProgress,
        ),
        actorId: leader,
      );

      expect(updated.title, 'Campus App 2.0');
      expect(updated.description, 'Ahora con mapas, horarios y avisos.');
      expect(updated.category, 'Impacto Social');
      expect(updated.maxMembers, 6);
      expect(updated.requiredSkills, ['Flutter', 'Figma']);
      expect(updated.status, ListingStatus.inProgress);

      final reread = await stored(original.id);
      expect(reread.title, 'Campus App 2.0');
      expect(reread.status, ListingStatus.inProgress);
    });

    test('el equipo y el liderazgo salen de la fila guardada, no del formulario',
        () async {
      final original = await project(others: ['user_3']);

      // A stale screen that still shows somebody else in and leading.
      final stale = original.copyWith(
        title: 'Campus App editada',
        memberIds: const ['user_1', 'user_9'],
        creatorId: 'user_9',
      );

      final updated = await repository.updateListing(stale, actorId: leader);

      expect(updated.memberIds, ['user_1', 'user_3']);
      expect(updated.creatorId, leader);
      expect(updated.leaderId, leader);
    });

    test('un integrante que no lidera no puede editar', () async {
      final original = await project(others: ['user_3']);

      await expectLater(
        repository.updateListing(
          original.copyWith(title: 'Tomado por otro'),
          actorId: 'user_3',
        ),
        refusal('Solo el líder del proyecto puede editar el proyecto.'),
      );

      expect((await stored(original.id)).title, 'Campus App');
    });

    test('alguien de fuera tampoco', () async {
      final original = await project();

      await expectLater(
        repository.updateListing(original, actorId: 'user_9'),
        refusal('Solo el líder'),
      );
    });

    test('un proyecto que ya no existe se informa', () async {
      final original = await project();

      await expectLater(
        repository.updateListing(
          original.copyWith(id: 'listing_999'),
          actorId: leader,
        ),
        refusal('El proyecto listing_999 ya no existe.'),
      );
    });

    test('el título necesita al menos 5 caracteres sin contar espacios',
        () async {
      final original = await project();

      await expectLater(
        repository.updateListing(
          original.copyWith(title: '   Abcd    '),
          actorId: leader,
        ),
        refusal('al menos 5 caracteres'),
      );

      final updated = await repository.updateListing(
        original.copyWith(title: ' Abcde '),
        actorId: leader,
      );
      expect(updated.title, 'Abcde');
    });

    test('la descripción necesita al menos 20 caracteres', () async {
      final original = await project();

      await expectLater(
        repository.updateListing(
          original.copyWith(description: '  ${'x' * 19}  '),
          actorId: leader,
        ),
        refusal('La descripción debe tener al menos 20 caracteres.'),
      );

      expect((await stored(original.id)).description, description);
    });

    test('el tamaño del equipo va de 2 a 12', () async {
      final original = await project();

      for (final size in [1, 13]) {
        await expectLater(
          repository.updateListing(
            original.copyWith(maxMembers: size),
            actorId: leader,
          ),
          refusal('El equipo debe ser de 2 a 12 personas.'),
        );
      }

      for (final size in [2, 12]) {
        final updated = await repository.updateListing(
          original.copyWith(maxMembers: size),
          actorId: leader,
        );
        expect(updated.maxMembers, size);
      }
    });

    test('no se puede achicar por debajo de los que ya están', () async {
      final original = await project(maxMembers: 5, others: ['user_3', 'user_4']);

      await expectLater(
        repository.updateListing(
          original.copyWith(maxMembers: 2),
          actorId: leader,
        ),
        refusal('El equipo ya tiene 3 personas'),
      );
      expect((await stored(original.id)).maxMembers, 5);

      // Exactly the people already in is allowed: it only closes the slots.
      final updated = await repository.updateListing(
        original.copyWith(maxMembers: 3),
        actorId: leader,
      );
      expect(updated.isFull, isTrue);
    });

    test('un proyecto anterior a los roles lo edita su creador', () async {
      // `listing_1` was seeded with no role rows: user_2 leads because they
      // created it.
      final old = await stored('listing_1');

      final updated = await repository.updateListing(
        old.copyWith(status: ListingStatus.paused),
        actorId: 'user_2',
      );

      expect(updated.status, ListingStatus.paused);
    });

    test('tras transferir el liderazgo el creador ya no puede editar',
        () async {
      final original = await project(others: ['user_3']);
      await repository.transferLeadership(
        listingId: original.id,
        newLeaderId: 'user_3',
        actorId: leader,
      );

      await expectLater(
        repository.updateListing(original, actorId: leader),
        refusal('Solo el líder'),
      );

      final byNewLeader = await repository.updateListing(
        original.copyWith(title: 'Campus App de Carlos'),
        actorId: 'user_3',
      );
      expect(byNewLeader.title, 'Campus App de Carlos');
    });
  });

  group('closePendingRequests', () {
    test('rechaza solo las pendientes y las devuelve', () async {
      final original = await project();
      final waiting =
          await repository.createJoinRequest(requestFrom('user_3', original.id));
      final accepted =
          await repository.createJoinRequest(requestFrom('user_4', original.id));
      final rejected =
          await repository.createJoinRequest(requestFrom('user_5', original.id));
      await repository.acceptJoinRequest(accepted.id);
      await repository.rejectJoinRequest(rejected.id);

      final closed = await repository.closePendingRequests(original.id);

      expect(closed.map((r) => r.id), [waiting.id]);

      final statuses = {
        for (final request in await repository.getRequestsForListing(original.id))
          request.applicantId: request.status,
      };
      expect(statuses, {
        'user_3': JoinRequestStatus.rejected,
        'user_4': JoinRequestStatus.accepted,
        'user_5': JoinRequestStatus.rejected,
      });
    });

    test('sin pendientes no hace nada y devuelve una lista vacía', () async {
      final original = await project();

      expect(await repository.closePendingRequests(original.id), isEmpty);
    });
  });

  group('removeMember', () {
    test('el líder quita a un integrante del equipo', () async {
      final original = await project(others: ['user_3', 'user_4']);

      await repository.removeMember(
        listingId: original.id,
        userId: 'user_3',
        actorId: leader,
      );

      final after = await stored(original.id);
      expect(after.memberIds, ['user_1', 'user_4']);
      expect(after.roleOf('user_3'), isNull);
    });

    test('solo el líder puede quitar integrantes', () async {
      final original = await project(others: ['user_3', 'user_4']);

      await expectLater(
        repository.removeMember(
          listingId: original.id,
          userId: 'user_4',
          actorId: 'user_3',
        ),
        refusal('Solo el líder del proyecto puede quitar integrantes.'),
      );

      expect((await stored(original.id)).memberIds, contains('user_4'));
    });

    test('al líder no se le puede quitar, ni siquiera él mismo', () async {
      final original = await project(others: ['user_3']);

      await expectLater(
        repository.removeMember(
          listingId: original.id,
          userId: leader,
          actorId: leader,
        ),
        refusal('No se puede quitar al líder'),
      );

      expect((await stored(original.id)).memberIds, contains(leader));
    });

    test('quien ya no está en el equipo se informa', () async {
      final original = await project();

      await expectLater(
        repository.removeMember(
          listingId: original.id,
          userId: 'user_9',
          actorId: leader,
        ),
        refusal('Esa persona ya no está en el equipo.'),
      );
    });

    test('un proyecto que ya no existe se informa', () async {
      await expectLater(
        repository.removeMember(
          listingId: 'listing_999',
          userId: 'user_3',
          actorId: leader,
        ),
        refusal('ya no existe'),
      );
    });
  });

  group('leaveListing', () {
    test('un integrante puede salir por su cuenta', () async {
      final original = await project(others: ['user_3']);

      await repository.leaveListing(listingId: original.id, userId: 'user_3');

      expect((await stored(original.id)).memberIds, ['user_1']);
    });

    test('salir de un proyecto en el que no se está no hace nada', () async {
      final original = await project(others: ['user_3']);

      await repository.leaveListing(listingId: original.id, userId: 'user_9');

      expect((await stored(original.id)).memberIds, ['user_1', 'user_3']);
    });

    test('el líder no puede salir sin transferir el liderazgo', () async {
      final original = await project(others: ['user_3']);

      await expectLater(
        repository.leaveListing(listingId: original.id, userId: leader),
        refusal('transfiere el liderazgo antes de salir'),
      );

      expect((await stored(original.id)).memberIds, contains(leader));
    });

    test('tras transferir el liderazgo el antiguo líder sí puede salir',
        () async {
      final original = await project(others: ['user_3']);
      await repository.transferLeadership(
        listingId: original.id,
        newLeaderId: 'user_3',
        actorId: leader,
      );

      await repository.leaveListing(listingId: original.id, userId: leader);

      final after = await stored(original.id);
      expect(after.memberIds, ['user_3']);
      expect(after.leaderId, 'user_3');
    });

    test('salir de un proyecto que ya no existe se informa', () async {
      await expectLater(
        repository.leaveListing(listingId: 'listing_999', userId: 'user_3'),
        refusal('ya no existe'),
      );
    });
  });

  group('setMemberRole', () {
    test('el líder convierte a un integrante en mentor y de vuelta', () async {
      final original = await project(others: ['user_3']);

      await repository.setMemberRole(
        listingId: original.id,
        userId: 'user_3',
        role: ListingRole.mentor,
        actorId: leader,
      );
      expect((await stored(original.id)).roleOf('user_3'), ListingRole.mentor);

      await repository.setMemberRole(
        listingId: original.id,
        userId: 'user_3',
        role: ListingRole.member,
        actorId: leader,
      );
      expect((await stored(original.id)).roleOf('user_3'), ListingRole.member);
    });

    test('el liderazgo no se asigna por aquí, antes de mirar nada', () async {
      // Refused even for a project that does not exist: the rule is about the
      // operation, not about the data.
      await expectLater(
        repository.setMemberRole(
          listingId: 'listing_999',
          userId: 'user_3',
          role: ListingRole.leader,
          actorId: leader,
        ),
        refusal('El liderazgo se transfiere, no se asigna'),
      );
    });

    test('el liderazgo tampoco, sobre un proyecto real', () async {
      final original = await project(others: ['user_3']);

      await expectLater(
        repository.setMemberRole(
          listingId: original.id,
          userId: 'user_3',
          role: ListingRole.leader,
          actorId: leader,
        ),
        refusal('El liderazgo se transfiere'),
      );

      expect((await stored(original.id)).leaderId, leader);
      expect((await stored(original.id)).isLeader('user_3'), isFalse);
    });

    test('solo el líder cambia roles', () async {
      final original = await project(others: ['user_3', 'user_4']);

      await expectLater(
        repository.setMemberRole(
          listingId: original.id,
          userId: 'user_4',
          role: ListingRole.mentor,
          actorId: 'user_3',
        ),
        refusal('Solo el líder del proyecto puede cambiar roles.'),
      );

      expect((await stored(original.id)).roleOf('user_4'), ListingRole.member);
    });

    test('el líder no puede cambiarse su propio rol', () async {
      final original = await project(others: ['user_3']);

      await expectLater(
        repository.setMemberRole(
          listingId: original.id,
          userId: leader,
          role: ListingRole.mentor,
          actorId: leader,
        ),
        refusal('El líder no puede cambiar su propio rol'),
      );

      expect((await stored(original.id)).isLeader(leader), isTrue);
    });

    test('a quien no está en el equipo no se le cambia el rol', () async {
      final original = await project();

      await expectLater(
        repository.setMemberRole(
          listingId: original.id,
          userId: 'user_9',
          role: ListingRole.mentor,
          actorId: leader,
        ),
        refusal('Esa persona ya no está en el equipo.'),
      );
    });
  });

  group('transferLeadership', () {
    test('el nuevo líder lidera y el anterior queda como integrante',
        () async {
      final original = await project(others: ['user_3']);

      await repository.transferLeadership(
        listingId: original.id,
        newLeaderId: 'user_3',
        actorId: leader,
      );

      final after = await stored(original.id);
      expect(after.leaderId, 'user_3');
      expect(after.isLeader('user_3'), isTrue);
      expect(after.roleOf(leader), ListingRole.member);
      expect(after.team.where((m) => m.role == ListingRole.leader), hasLength(1));
    });

    test('un mentor también puede recibir el liderazgo', () async {
      final original = await project(others: ['user_3']);
      await repository.setMemberRole(
        listingId: original.id,
        userId: 'user_3',
        role: ListingRole.mentor,
        actorId: leader,
      );

      await repository.transferLeadership(
        listingId: original.id,
        newLeaderId: 'user_3',
        actorId: leader,
      );

      expect((await stored(original.id)).leaderId, 'user_3');
    });

    test('promueve primero y degrada después', () async {
      final recording = _RecordingListingSource();
      final repo = ListingRepository(recording);
      final created = await repo.createListing(
        Listing.draft(
          title: 'Campus App',
          description: description,
          category: 'Tecnología',
          creatorId: leader,
          creatorName: 'Leonel',
          maxMembers: 4,
          requiredSkills: const [],
        ),
      );
      await recording.addMember(listingId: created.id, userId: 'user_3');

      await repo.transferLeadership(
        listingId: created.id,
        newLeaderId: 'user_3',
        actorId: leader,
      );

      expect(recording.roleWrites, [
        'user_3:leader',
        'user_1:member',
      ]);
    });

    test('si la segunda escritura falla quedan dos líderes, nunca ninguno',
        () async {
      final failing = _RecordingListingSource(failOnWrite: 2);
      final repo = ListingRepository(failing);
      final created = await repo.createListing(
        Listing.draft(
          title: 'Campus App',
          description: description,
          category: 'Tecnología',
          creatorId: leader,
          creatorName: 'Leonel',
          maxMembers: 4,
          requiredSkills: const [],
        ),
      );
      await failing.addMember(listingId: created.id, userId: 'user_3');

      await expectLater(
        repo.transferLeadership(
          listingId: created.id,
          newLeaderId: 'user_3',
          actorId: leader,
        ),
        throwsA(isA<ListingException>()),
      );

      final after = (await failing.getListingById(created.id))!;
      expect(after.isLeader('user_3'), isTrue);
      // The old leader can still run the project and finish stepping down.
      expect(after.isLeader(leader), isTrue);
    });

    test('transfiere también en un proyecto anterior a los roles', () async {
      // `listing_1`: user_2 created it and leads with no role row at all.
      await source.addMember(
        listingId: 'listing_1',
        userId: 'user_6',
        userName: 'Valentina',
      );

      await repository.transferLeadership(
        listingId: 'listing_1',
        newLeaderId: 'user_6',
        actorId: 'user_2',
      );

      final after = await stored('listing_1');
      expect(after.leaderId, 'user_6');
      expect(after.roleOf('user_2'), ListingRole.member);
      expect(after.memberIds, ['user_2', 'user_6']);
    });

    test('solo el líder puede transferir', () async {
      final original = await project(others: ['user_3', 'user_4']);

      await expectLater(
        repository.transferLeadership(
          listingId: original.id,
          newLeaderId: 'user_4',
          actorId: 'user_3',
        ),
        refusal('Solo el líder del proyecto puede transferir el liderazgo.'),
      );

      expect((await stored(original.id)).leaderId, leader);
    });

    test('transferirse a sí mismo no escribe nada', () async {
      final recording = _RecordingListingSource();
      final repo = ListingRepository(recording);

      await repo.transferLeadership(
        listingId: 'listing_1',
        newLeaderId: 'user_2',
        actorId: 'user_2',
      );

      expect(recording.roleWrites, isEmpty);
      expect((await recording.getListingById('listing_1'))!.leaderId, 'user_2');
    });

    test('a quien no está en el equipo no se le transfiere', () async {
      final original = await project();

      await expectLater(
        repository.transferLeadership(
          listingId: original.id,
          newLeaderId: 'user_9',
          actorId: leader,
        ),
        refusal('Esa persona ya no está en el equipo.'),
      );

      expect((await stored(original.id)).leaderId, leader);
    });
  });

  group('solicitudes según el estado', () {
    Future<Listing> withStatus(ListingStatus status) async {
      final original = await project();

      return repository.updateListing(
        original.copyWith(status: status),
        actorId: leader,
      );
    }

    test('una idea o un proyecto en curso reciben solicitudes', () async {
      for (final status in [ListingStatus.idea, ListingStatus.inProgress]) {
        final open = await withStatus(status);

        final request =
            await repository.createJoinRequest(requestFrom('user_3', open.id));

        expect(request.isPersisted, isTrue);
      }
    });

    test('uno pausado rechaza la solicitud y no la guarda', () async {
      final paused = await withStatus(ListingStatus.paused);

      await expectLater(
        repository.createJoinRequest(requestFrom('user_3', paused.id)),
        refusal('Este proyecto está pausado y ya no recibe solicitudes.'),
      );

      expect(await repository.getRequestsForListing(paused.id), isEmpty);
    });

    test('uno terminado también', () async {
      final done = await withStatus(ListingStatus.done);

      await expectLater(
        repository.createJoinRequest(requestFrom('user_3', done.id)),
        refusal('está terminado'),
      );
    });

    test('una solicitud pendiente no se acepta si el proyecto se pausó',
        () async {
      final original = await project();
      final request =
          await repository.createJoinRequest(requestFrom('user_3', original.id));
      await repository.updateListing(
        original.copyWith(status: ListingStatus.paused),
        actorId: leader,
      );

      await expectLater(
        repository.acceptJoinRequest(request.id),
        refusal('Este proyecto está pausado: ya no se aceptan integrantes'),
      );

      expect((await stored(original.id)).memberIds, isNot(contains('user_3')));
      final mine = await repository.getMyRequestForListing(
        listingId: original.id,
        applicantId: 'user_3',
      );
      expect(mine?.status, JoinRequestStatus.pending);
    });

    test('en un proyecto en curso la aceptación sí entra al equipo', () async {
      final open = await withStatus(ListingStatus.inProgress);
      final request =
          await repository.createJoinRequest(requestFrom('user_3', open.id));

      await repository.acceptJoinRequest(request.id);

      final after = await stored(open.id);
      expect(after.memberIds, contains('user_3'));
      expect(after.roleOf('user_3'), ListingRole.member);
    });
  });

  group('destacados según el estado', () {
    test('un proyecto pausado o terminado no se destaca aunque tenga cupo',
        () async {
      final paused = await project();
      await repository.updateListing(
        paused.copyWith(title: 'Proyecto pausado', status: ListingStatus.paused),
        actorId: leader,
      );
      final done = await project();
      await repository.updateListing(
        done.copyWith(title: 'Proyecto terminado', status: ListingStatus.done),
        actorId: leader,
      );
      final running = await project();
      await repository.updateListing(
        running.copyWith(
          title: 'Proyecto en curso',
          status: ListingStatus.inProgress,
        ),
        actorId: leader,
      );

      final featured = await repository.getFeaturedListings();
      final titles = featured.map((listing) => listing.title);

      expect(titles, contains('Proyecto en curso'));
      expect(titles, isNot(contains('Proyecto pausado')));
      expect(titles, isNot(contains('Proyecto terminado')));
      expect(featured.every((listing) => listing.isRecruiting), isTrue);
    });
  });
}

/// Records every role write, and fails the [failOnWrite]-th one — the second of
/// a transfer is the step whose loss the ordering is designed around.
class _RecordingListingSource extends InMemoryListingSource {
  _RecordingListingSource({this.failOnWrite});

  final int? failOnWrite;
  final List<String> roleWrites = [];

  @override
  Future<void> setMemberRole({
    required String listingId,
    required String userId,
    required ListingRole role,
  }) async {
    if (roleWrites.length + 1 == failOnWrite) {
      throw const ListingException('ROBLE no responde');
    }

    roleWrites.add('$userId:${role.name}');

    return super.setMemberRole(
      listingId: listingId,
      userId: userId,
      role: role,
    );
  }
}
