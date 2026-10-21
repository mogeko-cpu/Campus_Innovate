import 'package:campus_innovate/core/widgets/confirm_dialog.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_task.dart';
import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:campus_innovate/features/listings/ui/views/edit_listing_page.dart';
import 'package:campus_innovate/features/listings/ui/views/listing_detail_page.dart';
import 'package:campus_innovate/features/listings/ui/views/tasks_page.dart';
import 'package:campus_innovate/features/listings/ui/widgets/status_chip.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/in_memory_notification_source.dart';
import '../../../support/in_memory_task_source.dart';
import '../../../support/test_bindings.dart';
import '../../../support/test_session.dart';

const _visitor = TestUser(
  id: 'user_9',
  name: 'Visitante Curioso',
  email: 'visitante@uninorte.edu.co',
);

/// Leonel leads, Mariana works and Carlos mentors.
Listing _project({ListingStatus status = ListingStatus.idea}) => Listing(
      id: '',
      title: 'Observatorio Estudiantil',
      description: 'Medimos la calidad del aire del campus con sensores baratos.',
      category: 'Investigación',
      creatorId: 'user_1',
      creatorName: 'Leonel Triana',
      maxMembers: 5,
      requiredSkills: const [],
      memberIds: const ['user_1', 'user_2', 'user_3'],
      status: status,
      members: const [
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
        ListingMember(
          userId: 'user_3',
          userName: 'Carlos Ruiz',
          role: ListingRole.mentor,
        ),
      ],
    );

class _Detail {
  _Detail(this.source, this.tasks, this.notifications, this.listing);

  final InMemoryListingSource source;
  final InMemoryTaskSource tasks;
  final InMemoryNotificationSource notifications;
  final Listing listing;

  Future<Listing> stored() async => (await source.getListingById(listing.id))!;
}

void main() {
  tearDown(Get.reset);

  Future<_Detail> openDetail(
    WidgetTester tester, {
    TestUser user = TestUsers.leonel,
    ListingStatus status = ListingStatus.idea,
    Future<void> Function(InMemoryTaskSource, String listingId)? withTasks,
  }) async {
    final source = InMemoryListingSource();
    final tasks = InMemoryTaskSource();
    final notifications = InMemoryNotificationSource();
    final listing = await source.createListing(_project(status: status));

    await withTasks?.call(tasks, listing.id);

    await tester.pumpApp(
      route: AppRoutes.detailOf(listing.id),
      bindings: TestBindings(
        source: source,
        taskSource: tasks,
        notificationSource: notifications,
        session: TestSession(user),
      ),
    );

    return _Detail(source, tasks, notifications, listing);
  }

  Finder tileOf(String name) => find.ancestor(
        of: find.text(name),
        matching: find.byType(ListTile),
      );

  Finder subtitleOf(String name, String subtitle) =>
      find.descendant(of: tileOf(name), matching: find.text(subtitle));

  Future<void> chooseFromMenu(
    WidgetTester tester,
    String name,
    String option,
  ) async {
    await tester.tapVisible(find.byTooltip('Opciones de $name'));
    await tester.tap(find.text(option));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byType(ConfirmDialog), matching: find.text(label)),
    );
    await tester.pumpAndSettle();
  }

  group('encabezado y herramientas del líder', () {
    testWidgets('la pastilla de estado aparece junto a la categoría',
        (tester) async {
      await openDetail(tester, status: ListingStatus.inProgress);

      expect(find.byType(StatusChip), findsOneWidget);
      expect(
        find.descendant(of: find.byType(StatusChip), matching: find.text('En curso')),
        findsOneWidget,
      );
    });

    testWidgets('un proyecto nuevo se ve como "Idea"', (tester) async {
      await openDetail(tester);

      expect(
        find.descendant(of: find.byType(StatusChip), matching: find.text('Idea')),
        findsOneWidget,
      );
    });

    testWidgets('el líder ve editar, eliminar y su bandeja', (tester) async {
      await openDetail(tester);

      expect(find.byTooltip('Editar proyecto'), findsOneWidget);
      expect(find.byTooltip('Eliminar proyecto'), findsOneWidget);
      expect(find.text('Solicitudes recibidas'), findsOneWidget);
      expect(find.text('Este es tu proyecto.'), findsOneWidget);
    });

    testWidgets('un integrante no ve las herramientas del líder',
        (tester) async {
      await openDetail(tester, user: TestUsers.mariana);

      expect(find.byTooltip('Editar proyecto'), findsNothing);
      expect(find.byTooltip('Eliminar proyecto'), findsNothing);
      expect(find.text('Solicitudes recibidas'), findsNothing);
      expect(find.text('Ya formas parte de este equipo.'), findsOneWidget);
    });

    testWidgets('"Editar proyecto" abre el formulario de edición',
        (tester) async {
      await openDetail(tester);

      await tester.tap(find.byTooltip('Editar proyecto'));
      await tester.pumpAndSettle();

      expect(find.byType(EditListingPage), findsOneWidget);
    });
  });

  group('equipo', () {
    testWidgets('lista a cada integrante con su rol, y marca quién eres',
        (tester) async {
      await openDetail(tester);

      // Leonel and Mariana: the mentor follows the project without taking one
      // of its seats.
      expect(find.text('2 de 5 integrantes'), findsOneWidget);
      expect(subtitleOf('Mariana Ospina', 'Integrante'), findsOneWidget);
      expect(subtitleOf('Carlos Ruiz', 'Mentor'), findsOneWidget);
      expect(find.text('Líder · tú'), findsOneWidget);
    });

    testWidgets('para otra persona, el "tú" va en su propia fila',
        (tester) async {
      await openDetail(tester, user: TestUsers.mariana);

      expect(subtitleOf('Mariana Ospina', 'Integrante · tú'), findsOneWidget);
      expect(find.text('Líder'), findsOneWidget);
      expect(find.text('Líder · tú'), findsNothing);
    });

    testWidgets('el líder tiene un menú por persona, pero no para sí mismo',
        (tester) async {
      await openDetail(tester);

      expect(find.byTooltip('Opciones de Mariana Ospina'), findsOneWidget);
      expect(find.byTooltip('Opciones de Carlos Ruiz'), findsOneWidget);
      expect(find.byTooltip('Opciones de Leonel Triana'), findsNothing);
    });

    testWidgets('el menú ofrece cambiar el rol, transferir y quitar',
        (tester) async {
      await openDetail(tester);

      await tester.tapVisible(find.byTooltip('Opciones de Mariana Ospina'));

      expect(find.text('Hacer mentor'), findsOneWidget);
      expect(find.text('Transferir liderazgo'), findsOneWidget);
      expect(find.text('Quitar del proyecto'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tapVisible(find.byTooltip('Opciones de Carlos Ruiz'));

      // A mentor goes back to being a member, not to mentor again.
      expect(find.text('Hacer integrante'), findsOneWidget);
      expect(find.text('Hacer mentor'), findsNothing);
    });

    testWidgets('quien no lidera no ve menús en el equipo', (tester) async {
      await openDetail(tester, user: TestUsers.mariana);

      expect(find.byTooltip('Opciones de Carlos Ruiz'), findsNothing);
      expect(find.byTooltip('Opciones de Leonel Triana'), findsNothing);
    });

    testWidgets('"Hacer mentor" cambia el rol y se lo avisa a la persona',
        (tester) async {
      final detail = await openDetail(tester);

      await chooseFromMenu(tester, 'Mariana Ospina', 'Hacer mentor');

      expect(find.text('Rol actualizado'), findsOneWidget);
      expect(find.text('Mariana Ospina ahora es mentor'), findsOneWidget);
      expect(subtitleOf('Mariana Ospina', 'Mentor'), findsOneWidget);
      expect((await detail.stored()).roleOf('user_2'), ListingRole.mentor);
      expect(
        detail.notifications.all.where(
          (n) => n.recipientId == 'user_2' && n.type == NotificationType.roleChanged,
        ),
        hasLength(1),
      );

      await tester.settleSnackbars();
    });

    testWidgets('"Hacer integrante" devuelve al mentor al trabajo',
        (tester) async {
      final detail = await openDetail(tester);

      await chooseFromMenu(tester, 'Carlos Ruiz', 'Hacer integrante');

      expect(find.text('Carlos Ruiz ahora es integrante'), findsOneWidget);
      expect(subtitleOf('Carlos Ruiz', 'Integrante'), findsOneWidget);
      expect((await detail.stored()).roleOf('user_3'), ListingRole.member);

      await tester.settleSnackbars();
    });

    testWidgets('transferir el liderazgo pide confirmación; cancelar no cambia nada',
        (tester) async {
      final detail = await openDetail(tester);

      await chooseFromMenu(tester, 'Mariana Ospina', 'Transferir liderazgo');

      expect(find.text('¿Transferir el liderazgo?'), findsOneWidget);
      expect(
        find.text('Mariana Ospina pasará a dirigir el proyecto y tú quedarás '
            'como integrante.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmDialog), findsNothing);
      expect(find.text('Líder · tú'), findsOneWidget);
      expect((await detail.stored()).leaderId, 'user_1');
    });

    testWidgets(
        'transferir el liderazgo cambia los papeles y quita las herramientas '
        'del líder', (tester) async {
      final detail = await openDetail(tester);

      await chooseFromMenu(tester, 'Mariana Ospina', 'Transferir liderazgo');
      await confirm(tester, 'Transferir');

      expect(find.text('Liderazgo transferido'), findsOneWidget);
      expect(find.text('Mariana Ospina ahora lidera el proyecto'), findsOneWidget);
      expect(subtitleOf('Mariana Ospina', 'Líder'), findsOneWidget);
      expect(find.text('Integrante · tú'), findsOneWidget);
      expect(find.byTooltip('Editar proyecto'), findsNothing);
      expect(find.byTooltip('Opciones de Carlos Ruiz'), findsNothing);
      expect(find.text('Salir del proyecto'), findsOneWidget);

      final stored = await detail.stored();
      expect(stored.leaderId, 'user_2');
      expect(stored.roleOf('user_1'), ListingRole.member);
      expect(
        detail.notifications.all.where(
          (n) => n.recipientId == 'user_2' && n.type == NotificationType.roleChanged,
        ),
        hasLength(1),
      );

      await tester.settleSnackbars();
    });

    testWidgets('quitar a alguien pide confirmación y libera sus tareas',
        (tester) async {
      final detail = await openDetail(
        tester,
        withTasks: (tasks, id) => tasks.createTask(
          ListingTask.draft(
            listingId: id,
            title: 'Comprar sensores',
            createdById: 'user_1',
            assigneeId: 'user_2',
            assigneeName: 'Mariana Ospina',
          ),
        ),
      );

      await chooseFromMenu(tester, 'Mariana Ospina', 'Quitar del proyecto');

      expect(find.text('¿Quitar a Mariana Ospina del equipo?'), findsOneWidget);

      await confirm(tester, 'Quitar');

      expect(find.text('Mariana Ospina ya no está en el equipo'), findsOneWidget);
      expect(tileOf('Mariana Ospina'), findsNothing);
      expect(find.text('1 de 5 integrantes'), findsOneWidget);
      expect((await detail.stored()).memberIds, isNot(contains('user_2')));
      expect(detail.tasks.all.single.assigneeId, isEmpty);
      expect(
        detail.notifications.all.where(
          (n) =>
              n.recipientId == 'user_2' && n.type == NotificationType.memberRemoved,
        ),
        hasLength(1),
      );

      await tester.settleSnackbars();
    });

    testWidgets('cancelar al quitar deja a la persona en el equipo',
        (tester) async {
      final detail = await openDetail(tester);

      await chooseFromMenu(tester, 'Mariana Ospina', 'Quitar del proyecto');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(tileOf('Mariana Ospina'), findsOneWidget);
      expect((await detail.stored()).memberIds, contains('user_2'));
    });
  });

  group('salir del proyecto', () {
    testWidgets('el líder no tiene "Salir del proyecto"', (tester) async {
      await openDetail(tester);

      expect(find.text('Salir del proyecto'), findsNothing);
    });

    testWidgets('quien no es del equipo tampoco', (tester) async {
      await openDetail(tester, user: _visitor);

      expect(find.text('Salir del proyecto'), findsNothing);
    });

    testWidgets('un mentor también puede salir', (tester) async {
      await openDetail(tester, user: _mentor);

      expect(find.text('Salir del proyecto'), findsOneWidget);
    });

    testWidgets('un integrante sale tras confirmar, y queda como visitante',
        (tester) async {
      final detail = await openDetail(
        tester,
        user: TestUsers.mariana,
        withTasks: (tasks, id) => tasks.createTask(
          ListingTask.draft(
            listingId: id,
            title: 'Comprar sensores',
            createdById: 'user_1',
            assigneeId: 'user_2',
            assigneeName: 'Mariana Ospina',
          ),
        ),
      );

      await tester.tapText('Salir del proyecto');

      expect(find.text('¿Salir del proyecto?'), findsOneWidget);

      await confirm(tester, 'Salir');

      expect(find.text('Saliste del proyecto'), findsOneWidget);
      expect(find.text('Salir del proyecto'), findsNothing);
      expect(tileOf('Mariana Ospina'), findsNothing);
      // Off the team, the board is no longer hers to see.
      expect(find.text('Ver tablero'), findsNothing);
      expect(find.text('Solicitar unirme'), findsOneWidget);
      expect((await detail.stored()).memberIds, isNot(contains('user_2')));
      expect(detail.tasks.all.single.assigneeId, isEmpty);

      await tester.settleSnackbars();
    });

    testWidgets('cancelar no saca a nadie', (tester) async {
      final detail = await openDetail(tester, user: TestUsers.mariana);

      await tester.tapText('Salir del proyecto');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Salir del proyecto'), findsOneWidget);
      expect((await detail.stored()).memberIds, contains('user_2'));
    });
  });

  group('tareas', () {
    Future<void> twoTasks(InMemoryTaskSource tasks, String id) async {
      await tasks.createTask(
        ListingTask.draft(listingId: id, title: 'Comprar sensores', createdById: 'user_1'),
      );
      final done = await tasks.createTask(
        ListingTask.draft(listingId: id, title: 'Pedir permiso', createdById: 'user_1'),
      );
      await tasks.updateTask(done.copyWith(column: TaskColumn.done));
    }

    testWidgets('el equipo ve la sección con "Todavía no hay tareas"',
        (tester) async {
      await openDetail(tester);

      expect(find.text('Tareas'), findsOneWidget);
      expect(find.text('Todavía no hay tareas'), findsOneWidget);
      expect(find.text('Ver tablero'), findsOneWidget);
    });

    testWidgets('con tareas muestra el avance', (tester) async {
      await openDetail(tester, user: _mentor, withTasks: twoTasks);

      expect(find.text('1 de 2 tareas hechas'), findsOneWidget);

      final bar = find.descendant(
        of: find.ancestor(
          of: find.text('1 de 2 tareas hechas'),
          matching: find.byType(Column),
        ).first,
        matching: find.byType(LinearProgressIndicator),
      );
      expect(tester.widget<LinearProgressIndicator>(bar).value, 0.5);
    });

    testWidgets('quien no es del equipo no ve las tareas', (tester) async {
      await openDetail(tester, user: _visitor, withTasks: twoTasks);

      expect(find.text('Tareas'), findsNothing);
      expect(find.text('Ver tablero'), findsNothing);
      expect(find.text('1 de 2 tareas hechas'), findsNothing);
    });

    testWidgets('"Ver tablero" abre el tablero y al volver se actualiza el avance',
        (tester) async {
      await openDetail(tester, withTasks: twoTasks);

      await tester.tapText('Ver tablero');

      expect(find.byType(TasksPage), findsOneWidget);

      await tester.tapVisible(
        find.descendant(
          of: find.ancestor(
            of: find.text('Comprar sensores'),
            matching: find.byType(Card),
          ),
          matching: find.byTooltip('Mover a En progreso'),
        ),
      );
      await tester.tapVisible(find.byTooltip('Mover a Hecho').first);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(ListingDetailPage), findsOneWidget);
      expect(find.text('2 de 2 tareas hechas'), findsOneWidget);
    });
  });

  group('estado del proyecto para quien visita', () {
    testWidgets('uno terminado lo dice en lugar del botón para unirse',
        (tester) async {
      await openDetail(tester, user: _visitor, status: ListingStatus.done);

      expect(
        find.text('Este proyecto ya terminó y no recibe solicitudes.'),
        findsOneWidget,
      );
      expect(find.text('Solicitar unirme'), findsNothing);
    });

    testWidgets('uno pausado lo dice en lugar del botón para unirse',
        (tester) async {
      await openDetail(tester, user: _visitor, status: ListingStatus.paused);

      expect(
        find.text('Este proyecto está pausado y no recibe solicitudes por ahora.'),
        findsOneWidget,
      );
      expect(find.text('Solicitar unirme'), findsNothing);
    });

    testWidgets('uno en curso con cupo sigue ofreciendo unirse', (tester) async {
      await openDetail(tester, user: _visitor, status: ListingStatus.inProgress);

      expect(find.text('Solicitar unirme'), findsOneWidget);
    });
  });
}

const _mentor = TestUser(
  id: 'user_3',
  name: 'Carlos Ruiz',
  email: 'carlos@uninorte.edu.co',
);
