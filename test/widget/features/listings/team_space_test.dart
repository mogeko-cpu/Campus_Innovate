import 'package:campus_innovate/core/widgets/confirm_dialog.dart';
import 'package:campus_innovate/features/home/ui/views/home_page.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_task.dart';
import 'package:campus_innovate/features/listings/domain/models/mentorship_request.dart';
import 'package:campus_innovate/features/listings/domain/models/project_file.dart';
import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:campus_innovate/features/listings/ui/views/files_page.dart';
import 'package:campus_innovate/features/listings/ui/views/listing_detail_page.dart';
import 'package:campus_innovate/features/listings/ui/views/tasks_page.dart';
import 'package:campus_innovate/features/users/domain/models/app_user.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/fake_file_picker.dart';
import '../../../support/fake_link_opener.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/in_memory_mentorship_source.dart';
import '../../../support/in_memory_project_file_source.dart';
import '../../../support/in_memory_task_source.dart';
import '../../../support/in_memory_user_source.dart';
import '../../../support/test_bindings.dart';
import '../../../support/test_session.dart';

const _prof = TestUser(
  id: 'user_9',
  name: 'Profesora Díaz',
  email: 'diaz@uninorte.edu.co',
);

const _outsider = TestUser(id: 'user_7', name: 'Ajeno', email: 'a@u.co');

/// Leonel leads and Mariana works; nobody mentors it yet.
const _project = Listing(
  id: '',
  title: 'Tutorías entre pares',
  description: 'Refuerzos para estudiantes de primer semestre del campus.',
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
);

/// The project, its doubles, and what each test needs to look into.
class _World {
  final listings = InMemoryListingSource();
  final tasks = InMemoryTaskSource();
  final files = InMemoryProjectFileSource();
  final mentorships = InMemoryMentorshipSource();
  final users = InMemoryUserSource();
  final picker = FakeFilePicker();
  final links = FakeLinkOpener();
  late final String id;

  Future<void> seed() async {
    await users.upsert(
      AppUser(id: _prof.id, name: _prof.name, email: _prof.email),
    );
    id = (await listings.createListing(_project)).id;
  }

  Future<void> task(String title, TaskColumn column) async {
    final stored = await tasks.createTask(
      ListingTask.draft(listingId: id, title: title, createdById: 'user_1'),
    );
    await tasks.updateTask(stored.copyWith(column: column));
  }

  Future<MentorshipRequest> askProf() => mentorships.create(
        MentorshipRequest.draft(
          listingId: id,
          listingTitle: _project.title,
          requesterId: 'user_2',
          requesterName: 'Mariana Ospina',
          mentorId: _prof.id,
          mentorName: _prof.name,
          message: 'Revisión del plan de tutorías',
        ),
      );

  TestBindings bindings(TestUser user) => TestBindings(
        source: listings,
        taskSource: tasks,
        fileSource: files,
        mentorshipSource: mentorships,
        userSource: users,
        filePicker: picker,
        linkOpener: links,
        session: TestSession(user),
      );
}

void main() {
  late _World world;

  setUp(() async {
    world = _World();
    await world.seed();
  });

  tearDown(Get.reset);

  Future<void> open(
    WidgetTester tester,
    String route, {
    TestUser user = TestUsers.leonel,
  }) =>
      tester.pumpApp(route: route, bindings: world.bindings(user));

  group('espacio del equipo en el detalle', () {
    testWidgets('el equipo ve tareas con su %, archivos y mentoría',
        (tester) async {
      await world.task('Hecha', TaskColumn.done);
      await world.task('Pendiente', TaskColumn.todo);
      await world.task('Descartada', TaskColumn.cancelled);
      await world.files.createFile(
        ProjectFile.link(
          listingId: world.id,
          name: 'Drive',
          url: 'https://drive.google.com/x',
          uploaderId: 'user_2',
          uploaderName: 'Mariana Ospina',
        ),
      );

      await open(tester, AppRoutes.detailOf(world.id));

      expect(find.text('Espacio del equipo'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('1 de 2 tareas hechas'), findsOneWidget);
      expect(find.text('1 cancelada, fuera de la cuenta'), findsOneWidget);
      expect(find.text('1 archivo o enlace compartido.'), findsOneWidget);
      expect(find.text('Solicitar mentoría'), findsOneWidget);
    });

    testWidgets('en un teléfono de 360 dp el detalle completo cabe',
        (tester) async {
      await world.task('Hecha', TaskColumn.done);
      await world.task('Descartada', TaskColumn.cancelled);
      await world.askProf();
      await open(tester, AppRoutes.detailOf(world.id));
      // As narrow as a small phone and tall enough that every panel is laid
      // out at once: an overflow anywhere fails the test.
      tester.view.physicalSize = const Size(360, 4000);
      await tester.pumpAndSettle();

      expect(find.textContaining('Comentarios ('), findsOneWidget);

      expect(find.byType(ListingDetailPage), findsOneWidget);
    });

    testWidgets('quien no es del equipo no lo ve', (tester) async {
      await open(tester, AppRoutes.detailOf(world.id), user: _outsider);

      expect(find.text('Espacio del equipo'), findsNothing);
      expect(find.text('Ver archivos'), findsNothing);
    });

    testWidgets('"Ver archivos" abre la carpeta del equipo', (tester) async {
      await open(tester, AppRoutes.detailOf(world.id));

      await tester.tapText('Ver archivos');

      expect(find.byType(FilesPage), findsOneWidget);
    });

    testWidgets('pedir mentoría: elegir a alguien, escribir y queda esperando',
        (tester) async {
      await open(tester, AppRoutes.detailOf(world.id), user: TestUsers.mariana);

      await tester.tapText('Solicitar mentoría');

      // Only people outside the team are offered.
      expect(find.text('Leonel Triana'), findsWidgets);
      await tester.tap(find.text('Profesora Díaz'));
      await tester.pumpAndSettle();
      await tester.enterField('Mensaje', 'Revisión del plan de tutorías');
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();

      expect(find.text('Solicitud enviada'), findsOneWidget);
      await tester.settleSnackbars();

      expect(
        find.text('Esperando la respuesta de Profesora Díaz.'),
        findsOneWidget,
      );
      expect(find.text('Solicitar mentoría'), findsNothing);
      expect(world.mentorships.all.single.mentorId, _prof.id);
    });

    testWidgets('el líder puede cancelar la solicitud pendiente',
        (tester) async {
      await world.askProf();
      await open(tester, AppRoutes.detailOf(world.id));

      await tester.tapText('Cancelar solicitud');
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmDialog),
          matching: find.text('Cancelar solicitud'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Solicitud cancelada'), findsOneWidget);
      await tester.settleSnackbars();
      expect(world.mentorships.all, isEmpty);
      expect(find.text('Solicitar mentoría'), findsOneWidget);
    });

    testWidgets('la persona invitada responde desde la publicación y entra',
        (tester) async {
      await world.askProf();
      await open(tester, AppRoutes.detailOf(world.id), user: _prof);

      expect(
        find.text('Mariana Ospina te pidió ser mentor de este proyecto'),
        findsOneWidget,
      );
      expect(find.text('Solicitar unirme'), findsNothing);

      await tester.tapVisible(find.widgetWithText(FilledButton, 'Aceptar'));

      expect(find.text('Ahora eres mentor'), findsOneWidget);
      await tester.settleSnackbars();

      expect(find.text('Espacio del equipo'), findsOneWidget);
      expect(find.text('Acompaña al equipo'), findsOneWidget);
      expect(
        (await world.listings.getListingById(world.id))!.roleOf(_prof.id),
        ListingRole.mentor,
      );
      // A mentor takes no seat.
      expect(find.text('2 de 4 integrantes'), findsOneWidget);
    });

    testWidgets('al rechazar, la publicación vuelve a ser la de un visitante',
        (tester) async {
      await world.askProf();
      await open(tester, AppRoutes.detailOf(world.id), user: _prof);

      await tester.tapVisible(find.widgetWithText(TextButton, 'Rechazar'));

      expect(find.text('Solicitud rechazada'), findsOneWidget);
      await tester.settleSnackbars();
      expect(find.text('Solicitar unirme'), findsOneWidget);
      expect(world.mentorships.all, isEmpty);
    });
  });

  group('archivos', () {
    testWidgets('subir un archivo lo muestra con su tamaño y quién lo subió',
        (tester) async {
      world.picker.next = FakeFilePicker.textFile('acta.txt', 'hola');
      await open(tester, AppRoutes.filesOf(world.id));

      expect(find.text('Todavía no hay archivos'), findsOneWidget);

      await tester.tapText('Subir archivo');

      expect(find.text('Archivo subido'), findsOneWidget);
      await tester.settleSnackbars();
      expect(find.text('acta.txt'), findsOneWidget);
      expect(find.textContaining('4 B · Leonel Triana'), findsOneWidget);
      expect(find.text('1 archivo · 0 enlaces'), findsOneWidget);
    });

    testWidgets('cerrar el selector sin elegir no dice nada', (tester) async {
      await open(tester, AppRoutes.filesOf(world.id));

      await tester.tapText('Subir archivo');

      expect(world.picker.calls, 1);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Todavía no hay archivos'), findsOneWidget);
    });

    testWidgets('un enlace se agrega y al tocarlo se abre', (tester) async {
      await open(tester, AppRoutes.filesOf(world.id));

      await tester.tapText('Agregar enlace');
      await tester.enterField('Nombre del enlace', 'Carpeta del informe');
      await tester.enterField('Enlace', 'drive.google.com/drive/abc');
      await tester.tap(find.text('Guardar enlace'));
      await tester.pumpAndSettle();
      await tester.settleSnackbars();

      await tester.tap(find.text('Carpeta del informe'));
      await tester.pumpAndSettle();

      expect(world.links.opened, ['https://drive.google.com/drive/abc']);
    });

    testWidgets('solo quien lo compartió ve la papelera, y borrar pide '
        'confirmación', (tester) async {
      await world.files.createFile(
        ProjectFile.link(
          listingId: world.id,
          name: 'De Mariana',
          url: 'https://drive.google.com/m',
          uploaderId: 'user_2',
          uploaderName: 'Mariana Ospina',
        ),
      );
      await world.files.createFile(
        ProjectFile.link(
          listingId: world.id,
          name: 'Mío',
          url: 'https://drive.google.com/l',
          uploaderId: 'user_1',
          uploaderName: 'Leonel Triana',
        ),
      );

      await open(tester, AppRoutes.filesOf(world.id));

      expect(find.byTooltip('Eliminar archivo'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar archivo'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmDialog),
          matching: find.text('Eliminar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mío'), findsNothing);
      expect(world.files.all.single.name, 'De Mariana');
    });

    testWidgets('alguien de afuera no entra', (tester) async {
      await open(tester, AppRoutes.filesOf(world.id), user: _outsider);

      expect(find.text('No se pudieron abrir los archivos'), findsOneWidget);
      expect(
        find.text('Solo el equipo del proyecto puede ver sus archivos.'),
        findsOneWidget,
      );
    });

    testWidgets('en un teléfono de 360 dp nada se desborda', (tester) async {
      world.picker.next = FakeFilePicker.textFile(
        'Informe de avance del primer corte con todos sus anexos.pdf',
      );
      await open(tester, AppRoutes.filesOf(world.id));
      tester.view.physicalSize = const Size(360, 740);
      await tester.pumpAndSettle();

      await tester.tapText('Subir archivo');
      await tester.settleSnackbars();

      expect(find.byType(FilesPage), findsOneWidget);
    });
  });

  group('tablero', () {
    Finder cardOf(String title) =>
        find.ancestor(of: find.text(title), matching: find.byType(Card));

    testWidgets('cancelar una tarea pide confirmación y la manda a Cancelado',
        (tester) async {
      await world.task('Pedir patrocinio', TaskColumn.todo);
      await world.task('Armar horario', TaskColumn.done);
      await open(tester, AppRoutes.tasksOf(world.id));

      expect(find.text('100%'), findsNothing);
      expect(find.text('50%'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: cardOf('Pedir patrocinio'),
          matching: find.byTooltip('Opciones de la tarea'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar tarea'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cancelar la tarea?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmDialog),
          matching: find.text('Cancelar tarea'),
        ),
      );
      await tester.pumpAndSettle();

      // Out of the count, what is left is done.
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('1 de 1 tarea hecha'), findsOneWidget);
      expect(find.text('Cancelado (1)'), findsOneWidget);
      expect(
        world.tasks.all.firstWhere((t) => t.title == 'Pedir patrocinio').column,
        TaskColumn.cancelled,
      );
    });

    testWidgets('una tarea cancelada se reabre en "Por hacer"', (tester) async {
      await world.task('Pedir patrocinio', TaskColumn.cancelled);
      await open(tester, AppRoutes.tasksOf(world.id));

      await tester.tap(find.text('Cancelado (1)'));
      await tester.pumpAndSettle();

      // Cancelled is not a step: no arrows on its cards.
      expect(find.byTooltip('Mover a Hecho'), findsNothing);

      await tester.tap(find.byTooltip('Opciones de la tarea'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reabrir tarea'));
      await tester.pumpAndSettle();

      expect(find.text('Por hacer (1)'), findsOneWidget);
      expect(find.text('Cancelado (0)'), findsOneWidget);
    });

    testWidgets('el tablero abre desde el detalle con el mismo avance',
        (tester) async {
      await world.task('Hecha', TaskColumn.done);
      await open(tester, AppRoutes.detailOf(world.id));

      await tester.tapText('Ver tablero');

      expect(find.byType(TasksPage), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });
  });

  testWidgets('Home muestra a quién le piden ser mentor y lleva al proyecto',
      (tester) async {
    await world.askProf();
    await open(tester, AppRoutes.home, user: _prof);

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Te piden ser mentor'), findsOneWidget);

    await tester.tapText('Mariana Ospina te pidió acompañar al equipo');

    expect(find.byType(ListingDetailPage), findsOneWidget);
    expect(
      find.text('Mariana Ospina te pidió ser mentor de este proyecto'),
      findsOneWidget,
    );
  });
}
