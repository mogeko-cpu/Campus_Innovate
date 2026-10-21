import 'package:campus_innovate/features/home/ui/viewmodels/home_view_model.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_task.dart';
import 'package:campus_innovate/features/listings/domain/models/project_file.dart';
import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/files_view_model.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/listing_detail_view_model.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/tasks_view_model.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/users/domain/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/fake_file_picker.dart';
import '../../../../support/in_memory_file_storage.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

/// Outside every team, in the directory: the one asked to mentor.
const _prof = TestUser(
  id: 'user_9',
  name: 'Profesora Díaz',
  email: 'diaz@uninorte.edu.co',
);

const _outsider = TestUser(id: 'user_7', name: 'Ajeno', email: 'a@u.co');

/// The team's own corner of a project: its files, its mentor, and the board's
/// cancelled column — what was added on top of the project management.
void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;
  late Listing project;

  setUp(() async {
    harness = ViewModelHarness();

    await harness.userSource.upsert(
      AppUser(id: _prof.id, name: _prof.name, email: _prof.email),
    );

    // Leonel leads and Mariana works.
    project = await harness.listingSource.createListing(
      const Listing(
        id: '',
        title: 'Tutorías entre pares',
        description: 'Refuerzos para estudiantes de primer semestre.',
        category: 'Impacto Social',
        creatorId: 'user_1',
        creatorName: 'Leonel Triana',
        maxMembers: 4,
        requiredSkills: [],
        memberIds: ['user_1', 'user_2'],
        members: [
          ListingMember(
            userId: 'user_1',
            userName: 'Leonel Triana',
            role: ListingRole.leader,
          ),
          ListingMember(
            userId: 'user_2',
            userName: 'Mariana Ospina',
            role: ListingRole.member,
          ),
        ],
      ),
    );
  });

  /// Opens a screen as [user]. `Get.put` keeps a live instance instead of
  /// replacing it, so the previous one is let go first, the way leaving the
  /// screen would.
  Future<T> openAs<T extends GetxController>(
    T Function() build, {
    TestUser user = TestUsers.leonel,
  }) async {
    await Get.delete<T>(force: true);
    harness.session.signInAs(user);

    return start(build(), routeId: project.id);
  }

  ListingDetailViewModel detail() => ListingDetailViewModel(
        harness.listings,
        harness.engagement,
        harness.groups,
        harness.publisher,
        harness.session,
        harness.tasks,
        harness.files,
        harness.mentorships,
        harness.users,
      );

  FilesViewModel files() => FilesViewModel(
        harness.files,
        harness.listings,
        harness.session,
        harness.picker,
        harness.links,
      );

  List<(String, NotificationType?)> sent() => harness.notificationSource.all
      .map((n) => (n.recipientId, n.type))
      .toList();

  const profUser = AppUser(
    id: 'user_9',
    name: 'Profesora Díaz',
    email: 'diaz@uninorte.edu.co',
  );

  group('archivos', () {
    test('el equipo ve la carpeta; alguien de afuera, no', () async {
      final team = await openAs(files);
      expect(team.error.value, isNull);
      expect(team.listing.value?.title, 'Tutorías entre pares');

      final outsider = await openAs(files, user: _outsider);
      expect(
        outsider.error.value,
        'Solo el equipo del proyecto puede ver sus archivos.',
      );
    });

    test('cerrar el selector sin elegir no es éxito ni error', () async {
      final viewModel = await openAs(files);

      expect(await viewModel.upload(), isNull);
      expect(harness.picker.calls, 1);
      expect(viewModel.lastActionError, isNull);
    });

    test('subir un archivo lo pone arriba y abrirlo pide un enlace firmado',
        () async {
      final viewModel = await openAs(files);
      harness.picker.next = FakeFilePicker.textFile('acta.txt');

      expect(await viewModel.upload(), isTrue);
      expect(viewModel.uploading.value, isNull);

      final file = viewModel.files.single;
      expect(file.name, 'acta.txt');
      expect(file.uploaderName, 'Leonel Triana');
      expect(viewModel.uploadCount, 1);

      expect(await viewModel.open(file), isTrue);
      expect(harness.links.opened, [InMemoryFileStorage.linkOf(file.storageId)]);
    });

    test('un enlace se guarda tal cual y un dispositivo que no lo abre lo dice',
        () async {
      final viewModel = await openAs(files);

      await viewModel.addLink(name: 'Repo', url: 'github.com/equipo/tutorias');
      final link = viewModel.files.single;

      expect(link.url, 'https://github.com/equipo/tutorias');
      expect(viewModel.linkCount, 1);

      harness.links.canOpen = false;
      expect(await viewModel.open(link), isFalse);
      expect(viewModel.lastActionError, 'Este dispositivo no pudo abrir "Repo".');
    });

    test('solo quien lo compartió lo elimina', () async {
      final leonel = await openAs(files);
      await leonel.addLink(name: 'Drive', url: 'https://drive.google.com/x');

      final mariana = await openAs(files, user: TestUsers.mariana);
      final shared = mariana.files.single;
      expect(mariana.canDelete(shared), isFalse);
      expect(await mariana.delete(shared), isFalse);
      expect(
        mariana.lastActionError,
        'Solo quien compartió el archivo puede eliminarlo.',
      );

      final again = await openAs(files);
      expect(await again.delete(again.files.single), isTrue);
      expect(again.files, isEmpty);
    });
  });

  group('espacio del equipo en el detalle', () {
    test('cuenta los archivos del equipo', () async {
      await harness.fileSource.createFile(
        ProjectFile.link(
          listingId: project.id,
          name: 'Drive',
          url: 'https://drive.google.com/x',
          uploaderId: 'user_2',
          uploaderName: 'Mariana Ospina',
        ),
      );

      expect((await openAs(detail)).fileCount.value, 1);
    });

    test('quien no es del equipo no lee los archivos', () async {
      expect((await openAs(detail, user: _outsider)).fileCount.value, isNull);
    });

    test('el progreso deja fuera las canceladas', () async {
      for (final column in [
        TaskColumn.done,
        TaskColumn.todo,
        TaskColumn.cancelled,
      ]) {
        final task = await harness.taskSource.createTask(
          ListingTask.draft(
            listingId: project.id,
            title: 'Tarea ${column.name}',
            createdById: 'user_1',
          ),
        );
        await harness.taskSource.updateTask(task.copyWith(column: column));
      }

      final viewModel = await openAs(detail);

      expect(viewModel.progress.value?.percent, 50);
      expect(viewModel.progress.value?.label, '1 de 2 tareas hechas');
    });
  });

  group('mentoría', () {
    test('los candidatos son las personas del directorio fuera del equipo',
        () async {
      final viewModel = await openAs(detail);

      final names = (await viewModel.mentorCandidates()).map((u) => u.name);

      expect(names, contains('Profesora Díaz'));
      expect(names, isNot(contains('Mariana Ospina')));
    });

    test('un integrante la solicita y se le avisa a esa persona', () async {
      final viewModel = await openAs(detail, user: TestUsers.mariana);
      expect(viewModel.canRequestMentorship, isTrue);

      expect(
        await viewModel.requestMentorship(profUser, 'Revisión del plan'),
        isTrue,
      );

      expect(viewModel.mentorshipRequest.value?.mentorName, 'Profesora Díaz');
      expect(viewModel.canRequestMentorship, isFalse);
      expect(viewModel.canCancelMentorship, isTrue);
      expect(sent(), [(_prof.id, NotificationType.mentorshipRequested)]);
    });

    Future<void> ask() async {
      final team = await openAs(detail, user: TestUsers.mariana);
      await team.requestMentorship(profUser, 'Revisión del plan');
    }

    test('la persona invitada la ve, y al aceptar entra al equipo', () async {
      await ask();

      final viewModel = await openAs(detail, user: _prof);
      expect(viewModel.isInvitedMentor, isTrue);
      expect(viewModel.myRole, isNull);

      expect(await viewModel.acceptMentorship(), isTrue);

      expect(viewModel.isInvitedMentor, isFalse);
      expect(viewModel.myRole, ListingRole.mentor);
      expect(viewModel.listing.value?.hasMentor, isTrue);
      expect(viewModel.mentorshipRequest.value, isNull);
      // On the team now, the board is readable.
      expect(viewModel.progress.value, isNotNull);

      final accepted = harness.notificationSource.all
          .where((n) => n.type == NotificationType.mentorshipAccepted)
          .map((n) => n.recipientId);
      expect(accepted, unorderedEquals(['user_1', 'user_2']));
    });

    test('al rechazar solo se le avisa a quien la pidió', () async {
      await ask();

      final viewModel = await openAs(detail, user: _prof);
      expect(await viewModel.rejectMentorship(), isTrue);

      expect(viewModel.mentorshipRequest.value, isNull);
      expect(viewModel.myRole, isNull);

      final rejected = harness.notificationSource.all
          .where((n) => n.type == NotificationType.mentorshipRejected)
          .map((n) => n.recipientId);
      expect(rejected, ['user_2']);
    });

    test('el líder puede cancelar una solicitud ajena', () async {
      await ask();

      final leader = await openAs(detail);
      expect(leader.canCancelMentorship, isTrue);
      expect(await leader.cancelMentorshipRequest(), isTrue);

      expect(leader.mentorshipRequest.value, isNull);
      expect(harness.mentorshipSource.all, isEmpty);
    });

    test('con mentor en el equipo ya no se ofrece pedir otro', () async {
      await ask();
      await (await openAs(detail, user: _prof)).acceptMentorship();

      expect((await openAs(detail)).canRequestMentorship, isFalse);
    });

    test('eliminar el proyecto se lleva sus archivos y su solicitud', () async {
      await ask();
      await harness.fileSource.createFile(
        ProjectFile.link(
          listingId: project.id,
          name: 'Drive',
          url: 'https://drive.google.com/x',
          uploaderId: 'user_1',
          uploaderName: 'Leonel Triana',
        ),
      );

      expect(await (await openAs(detail)).deleteListing(), isTrue);

      expect(harness.fileSource.all, isEmpty);
      expect(harness.mentorshipSource.all, isEmpty);
    });

    test('Home muestra a quién le piden ser mentor', () async {
      await ask();

      harness.session.signInAs(_prof);
      final home = HomeViewModel(
        harness.listings,
        harness.engagement,
        harness.users,
        harness.session,
        harness.mentorships,
      );
      await start(home);

      expect(home.mentorshipRequests.single.listingTitle, 'Tutorías entre pares');
    });
  });

  group('tablero', () {
    TasksViewModel board() => TasksViewModel(
          harness.tasks,
          harness.listings,
          harness.publisher,
          harness.session,
        );

    test('cancelar saca la tarea de la cuenta y reabrirla la devuelve al '
        'principio', () async {
      await harness.taskSource.createTask(
        ListingTask.draft(
          listingId: project.id,
          title: 'Pedir patrocinio',
          createdById: 'user_1',
        ),
      );
      final viewModel = await openAs(board);
      final task = viewModel.tasks.single;

      expect(await viewModel.cancel(task), isTrue);
      expect(viewModel.tasksIn(TaskColumn.cancelled), hasLength(1));
      expect(viewModel.progress.counted, 0);

      expect(await viewModel.reopen(viewModel.tasks.single), isTrue);
      expect(viewModel.tasks.single.column, TaskColumn.todo);
      expect(viewModel.progress.counted, 1);
    });
  });
}
