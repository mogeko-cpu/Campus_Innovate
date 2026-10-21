import 'package:campus_innovate/core/day_format.dart';
import 'package:campus_innovate/core/widgets/confirm_dialog.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_task.dart';
import 'package:campus_innovate/features/listings/domain/models/task_column.dart';
import 'package:campus_innovate/features/listings/ui/views/tasks_page.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/main.dart';
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

const _mentor = TestUser(
  id: 'user_3',
  name: 'Carlos Ruiz',
  email: 'carlos@uninorte.edu.co',
);

/// Leonel leads, Mariana works and Carlos, a professor, mentors.
const _project = Listing(
  id: '',
  title: 'Observatorio Estudiantil',
  description: 'Medimos la calidad del aire del campus con sensores baratos.',
  category: 'Investigación',
  creatorId: 'user_1',
  creatorName: 'Leonel Triana',
  maxMembers: 5,
  requiredSkills: [],
  memberIds: ['user_1', 'user_2', 'user_3'],
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
    ListingMember(
      userId: 'user_3',
      userName: 'Carlos Ruiz',
      role: ListingRole.mentor,
    ),
  ],
);

// Wide enough that a card fits its assignee and due date in the test font,
// which is wider than the app's; see the report on the row that holds them.
const _wide = Size(1600, 1200);
const _narrow = Size(480, 900);

class _Board {
  _Board(this.source, this.tasks, this.notifications, this.listing);

  final InMemoryListingSource source;
  final InMemoryTaskSource tasks;
  final InMemoryNotificationSource notifications;
  final Listing listing;

  ListingTask task(String title) => tasks.all.firstWhere((t) => t.title == title);
}

DateTime get _today => ListingTask.dateOnly(DateTime.now());

void main() {
  tearDown(Get.reset);

  /// The project with its board: two cards to do, one in progress, one done,
  /// unless the test asks for an empty one.
  Future<_Board> seed({bool empty = false}) async {
    final source = InMemoryListingSource();
    final tasks = InMemoryTaskSource();
    final listing = await source.createListing(_project);

    if (!empty) {
      await tasks.createTask(
        ListingTask.draft(
          listingId: listing.id,
          title: 'Comprar sensores',
          createdById: 'user_1',
          assigneeId: 'user_2',
          assigneeName: 'Mariana Ospina',
          dueDate: _today.add(const Duration(days: 5)),
        ),
      );
      await tasks.createTask(
        ListingTask.draft(
          listingId: listing.id,
          title: 'Escribir el informe',
          createdById: 'user_2',
          dueDate: _today.subtract(const Duration(days: 2)),
        ),
      );
      final doing = await tasks.createTask(
        ListingTask.draft(
          listingId: listing.id,
          title: 'Soldar la placa',
          createdById: 'user_1',
        ),
      );
      await tasks.updateTask(doing.copyWith(column: TaskColumn.doing));
      final done = await tasks.createTask(
        ListingTask.draft(
          listingId: listing.id,
          title: 'Pedir el permiso',
          createdById: 'user_1',
          dueDate: _today.subtract(const Duration(days: 9)),
        ),
      );
      await tasks.updateTask(done.copyWith(column: TaskColumn.done));
    }

    return _Board(source, tasks, InMemoryNotificationSource(), listing);
  }

  Future<_Board> openBoard(
    WidgetTester tester, {
    TestUser user = TestUsers.leonel,
    Size size = _wide,
    bool empty = false,
  }) async {
    final board = await seed(empty: empty);

    // What `pumpApp` does, but on the board's own surface from the first frame:
    // `pumpApp` lays the screen out at its default size before a test can
    // change it.
    tester.useTallSurface(size: size);
    await tester.pumpWidget(
      CampusInnovateApp(
        initialBinding: TestBindings(
          source: board.source,
          taskSource: board.tasks,
          notificationSource: board.notifications,
          session: TestSession(user),
        ),
        initialRoute: AppRoutes.tasksOf(board.listing.id),
      ),
    );
    await tester.pumpAndSettle();

    return board;
  }

  Finder cardOf(String title) =>
      find.ancestor(of: find.text(title), matching: find.byType(Card));

  Finder inCard(String title, Finder finder) =>
      find.descendant(of: cardOf(title), matching: finder);

  Future<void> openMenu(WidgetTester tester, String title) =>
      tester.tapVisible(inCard(title, find.byTooltip('Opciones de la tarea')));

  group('tablero ancho', () {
    testWidgets('pone las tres columnas lado a lado, sin pestañas',
        (tester) async {
      await openBoard(tester);

      expect(find.byType(TasksPage), findsOneWidget);
      expect(find.text('Tareas · Observatorio Estudiantil'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Por hacer (2)'), findsOneWidget);
      expect(find.text('En progreso (1)'), findsOneWidget);
      expect(find.text('Hecho (1)'), findsOneWidget);

      // Every card at once, each under its own column.
      for (final title in [
        'Comprar sensores',
        'Escribir el informe',
        'Soldar la placa',
        'Pedir el permiso',
      ]) {
        expect(find.text(title), findsOneWidget);
      }

      final todoX = tester.getCenter(find.text('Comprar sensores')).dx;
      final doingX = tester.getCenter(find.text('Soldar la placa')).dx;
      final doneX = tester.getCenter(find.text('Pedir el permiso')).dx;

      expect(todoX, lessThan(doingX));
      expect(doingX, lessThan(doneX));
    });

    testWidgets('el avance cuenta las tareas hechas', (tester) async {
      await openBoard(tester);

      expect(find.text('1 de 4 tareas hechas'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
            .value,
        0.25,
      );
    });

    testWidgets('un tablero vacío lo dice en cada columna', (tester) async {
      await openBoard(tester, empty: true);

      expect(find.text('0 de 0 tareas hechas'), findsOneWidget);
      expect(find.text('Nada en "Por hacer"'), findsOneWidget);
      expect(find.text('Nada en "En progreso"'), findsOneWidget);
      expect(find.text('Nada en "Hecho"'), findsOneWidget);
    });
  });

  group('tablero angosto', () {
    testWidgets('las columnas son pestañas con su cuenta', (tester) async {
      await openBoard(tester, size: _narrow);

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Por hacer (2)'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'En progreso (1)'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Hecho (1)'), findsOneWidget);

      // Only the first tab is on screen.
      expect(find.text('Comprar sensores'), findsOneWidget);
      expect(find.text('Soldar la placa'), findsNothing);
    });

    testWidgets('tocar una pestaña muestra esa columna', (tester) async {
      await openBoard(tester, size: _narrow);

      await tester.tap(find.widgetWithText(Tab, 'En progreso (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Soldar la placa'), findsOneWidget);
      expect(find.text('Comprar sensores'), findsNothing);

      await tester.tap(find.widgetWithText(Tab, 'Hecho (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Pedir el permiso'), findsOneWidget);
    });

    testWidgets('mover una tarjeta actualiza la cuenta de las pestañas',
        (tester) async {
      final board = await openBoard(tester, size: _narrow);

      await tester.tapVisible(
        inCard('Comprar sensores', find.byTooltip('Mover a En progreso')),
      );

      expect(find.widgetWithText(Tab, 'Por hacer (1)'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'En progreso (2)'), findsOneWidget);
      expect(find.text('Comprar sensores'), findsNothing);
      expect(board.task('Comprar sensores').column, TaskColumn.doing);
    });

    testWidgets('volver a ancho pone las columnas lado a lado', (tester) async {
      await openBoard(tester, size: _narrow);

      expect(find.byType(TabBar), findsOneWidget);

      tester.useTallSurface(size: _wide);
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsNothing);
      expect(find.text('Soldar la placa'), findsOneWidget);
    });
  });

  group('tarjetas', () {
    testWidgets('muestran a quién están asignadas o "Sin asignar"',
        (tester) async {
      await openBoard(tester);

      expect(inCard('Comprar sensores', find.text('Mariana Ospina')), findsOneWidget);
      expect(inCard('Escribir el informe', find.text('Sin asignar')), findsOneWidget);
    });

    testWidgets('una fecha futura dice "Vence el" con el color normal',
        (tester) async {
      await openBoard(tester);

      final label = 'Vence el ${shortDay(_today.add(const Duration(days: 5)))}';
      final text = tester.widget<Text>(inCard('Comprar sensores', find.text(label)));
      final error = Theme.of(tester.element(find.byType(TasksPage))).colorScheme.error;

      expect(text.style?.color, isNot(error));
    });

    testWidgets('una fecha pasada dice "Venció el" en color de error',
        (tester) async {
      await openBoard(tester);

      final label =
          'Venció el ${shortDay(_today.subtract(const Duration(days: 2)))}';
      final text = tester.widget<Text>(inCard('Escribir el informe', find.text(label)));
      final error = Theme.of(tester.element(find.byType(TasksPage))).colorScheme.error;

      expect(text.style?.color, error);
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(
        tester
            .widget<Icon>(inCard('Escribir el informe', find.byIcon(Icons.event_outlined)))
            .color,
        error,
      );
    });

    testWidgets('una tarea hecha no está vencida y se ve tachada',
        (tester) async {
      await openBoard(tester);

      final label = 'Vence el ${shortDay(_today.subtract(const Duration(days: 9)))}';

      expect(inCard('Pedir el permiso', find.text(label)), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Pedir el permiso')).style?.decoration,
        TextDecoration.lineThrough,
      );
    });

    testWidgets('cada columna ofrece solo los movimientos posibles',
        (tester) async {
      await openBoard(tester);

      expect(inCard('Comprar sensores', find.byTooltip('Mover a En progreso')), findsOneWidget);
      expect(inCard('Comprar sensores', find.byTooltip('Mover a Por hacer')), findsNothing);
      expect(inCard('Soldar la placa', find.byTooltip('Mover a Por hacer')), findsOneWidget);
      expect(inCard('Soldar la placa', find.byTooltip('Mover a Hecho')), findsOneWidget);
      expect(inCard('Pedir el permiso', find.byTooltip('Mover a En progreso')), findsOneWidget);
      expect(inCard('Pedir el permiso', find.byTooltip('Mover a Hecho')), findsNothing);
    });

    testWidgets('mover a "Hecho" la guarda y sube el avance', (tester) async {
      final board = await openBoard(tester);

      await tester.tapVisible(inCard('Soldar la placa', find.byTooltip('Mover a Hecho')));

      expect(find.text('En progreso (0)'), findsOneWidget);
      expect(find.text('Hecho (2)'), findsOneWidget);
      expect(find.text('2 de 4 tareas hechas'), findsOneWidget);
      expect(board.task('Soldar la placa').column, TaskColumn.done);
    });

    testWidgets('mover hacia atrás también se guarda', (tester) async {
      final board = await openBoard(tester);

      await tester.tapVisible(
        inCard('Soldar la placa', find.byTooltip('Mover a Por hacer')),
      );

      expect(find.text('Por hacer (3)'), findsOneWidget);
      expect(board.task('Soldar la placa').column, TaskColumn.todo);
    });
  });

  group('permisos', () {
    testWidgets('el líder ve "Nueva tarea" y puede eliminar cualquier tarjeta',
        (tester) async {
      await openBoard(tester);

      expect(find.text('Nueva tarea'), findsOneWidget);

      // Written by Mariana, and still the leader's to tidy.
      await openMenu(tester, 'Escribir el informe');

      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('un integrante elimina solo lo que él creó', (tester) async {
      await openBoard(tester, user: TestUsers.mariana);

      expect(find.text('Nueva tarea'), findsOneWidget);

      await openMenu(tester, 'Comprar sensores');

      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsNothing);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await openMenu(tester, 'Escribir el informe');

      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('un mentor sigue el tablero sin poder tocarlo', (tester) async {
      await openBoard(tester, user: _mentor);

      expect(
        find.text('Como mentor puedes seguir el tablero, pero no mover '
            'las tarjetas.'),
        findsOneWidget,
      );
      expect(find.text('Comprar sensores'), findsOneWidget);
      expect(find.text('Nueva tarea'), findsNothing);
      expect(find.byTooltip('Opciones de la tarea'), findsNothing);
      expect(find.byTooltip('Mover a En progreso'), findsNothing);
      expect(find.byTooltip('Mover a Hecho'), findsNothing);
    });

    testWidgets('quien no es del equipo no puede abrir el tablero',
        (tester) async {
      await openBoard(
        tester,
        user: const TestUser(
          id: 'user_9',
          name: 'Visitante',
          email: 'visitante@uninorte.edu.co',
        ),
      );

      expect(find.text('No se pudo abrir el tablero'), findsOneWidget);
      expect(
        find.text('Solo el equipo del proyecto puede ver sus tareas.'),
        findsOneWidget,
      );
      expect(find.text('Comprar sensores'), findsNothing);
      expect(find.text('Nueva tarea'), findsNothing);
    });
  });

  group('formulario', () {
    Future<void> openNew(WidgetTester tester) async {
      await tester.tap(find.text('Nueva tarea'));
      await tester.pumpAndSettle();
    }

    Future<void> chooseAssignee(WidgetTester tester, String name) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }

    testWidgets('"Nueva tarea" abre el formulario vacío', (tester) async {
      await openBoard(tester, empty: true);
      await openNew(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.text('Nueva tarea')),
        findsOneWidget,
      );
      expect(find.text('Título de la tarea'), findsOneWidget);
      expect(find.text('Responsable'), findsOneWidget);
      expect(find.text('Sin fecha límite'), findsOneWidget);
      expect(find.byTooltip('Quitar fecha'), findsNothing);
    });

    testWidgets('el responsable se elige entre quienes trabajan el tablero',
        (tester) async {
      await openBoard(tester, empty: true);
      await openNew(tester);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('Leonel Triana'), findsWidgets);
      expect(find.text('Mariana Ospina'), findsWidgets);
      // The mentor follows the board and is not given cards.
      expect(find.text('Carlos Ruiz'), findsNothing);
    });

    testWidgets('un título muy corto no se guarda', (tester) async {
      final board = await openBoard(tester, empty: true);
      await openNew(tester);

      await tester.enterField('Título de la tarea', 'ab');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Escribe un título de al menos 3 caracteres'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(board.tasks.all, isEmpty);
    });

    testWidgets('"Cancelar" cierra sin crear nada', (tester) async {
      final board = await openBoard(tester, empty: true);
      await openNew(tester);

      await tester.enterField('Título de la tarea', 'Calibrar sensores');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(board.tasks.all, isEmpty);
    });

    testWidgets(
        'crear con responsable la pone en "Por hacer" y le avisa a esa persona',
        (tester) async {
      final board = await openBoard(tester, empty: true);
      await openNew(tester);

      await tester.enterField('Título de la tarea', 'Calibrar sensores');
      await chooseAssignee(tester, 'Mariana Ospina');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Por hacer (1)'), findsOneWidget);
      expect(inCard('Calibrar sensores', find.text('Mariana Ospina')), findsOneWidget);

      final stored = board.task('Calibrar sensores');
      expect(stored.column, TaskColumn.todo);
      expect(stored.assigneeId, 'user_2');
      expect(stored.createdById, 'user_1');
      expect(
        board.notifications.all.where(
          (n) =>
              n.recipientId == 'user_2' &&
              n.type == NotificationType.taskAssigned,
        ),
        hasLength(1),
      );
    });

    testWidgets('elegir y quitar la fecha límite', (tester) async {
      final board = await openBoard(tester, empty: true);
      await openNew(tester);

      await tester.tap(find.text('Elegir fecha'));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      // The picker opens on today; confirming keeps it.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final label = 'Vence el ${shortDay(_today)}';
      expect(find.text(label), findsOneWidget);
      expect(find.byTooltip('Quitar fecha'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar fecha'));
      await tester.pumpAndSettle();

      expect(find.text('Sin fecha límite'), findsOneWidget);

      await tester.tap(find.text('Elegir fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterField('Título de la tarea', 'Entregar avance');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(board.task('Entregar avance').dueDate, _today);
      expect(inCard('Entregar avance', find.text(label)), findsOneWidget);
    });

    testWidgets('"Editar" abre el formulario lleno y guarda los cambios',
        (tester) async {
      final board = await openBoard(tester);

      await openMenu(tester, 'Comprar sensores');
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.text('Editar tarea'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Comprar sensores'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip('Quitar fecha'), findsOneWidget);

      await tester.enterField('Título de la tarea', 'Comprar diez sensores');
      await chooseAssignee(tester, 'Sin asignar');
      await tester.tap(find.byTooltip('Quitar fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(inCard('Comprar diez sensores', find.text('Sin asignar')), findsOneWidget);
      expect(find.text('Comprar sensores'), findsNothing);

      final saved = board.task('Comprar diez sensores');
      expect(saved.assigneeId, isEmpty);
      expect(saved.dueDate, isNull);
    });

    testWidgets('eliminar pide confirmación y "Cancelar" la deja',
        (tester) async {
      final board = await openBoard(tester);

      await openMenu(tester, 'Comprar sensores');
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmDialog), findsOneWidget);
      expect(find.text('¿Eliminar la tarea?'), findsOneWidget);
      expect(find.text('"Comprar sensores" desaparece del tablero.'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Comprar sensores'), findsOneWidget);
      expect(board.tasks.all, hasLength(4));
    });

    testWidgets('confirmar la eliminación quita la tarjeta', (tester) async {
      final board = await openBoard(tester);

      await openMenu(tester, 'Comprar sensores');
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmDialog),
          matching: find.text('Eliminar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Comprar sensores'), findsNothing);
      expect(find.text('Por hacer (1)'), findsOneWidget);
      expect(board.tasks.all, hasLength(3));
    });
  });
}
