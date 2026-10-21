import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:campus_innovate/features/listings/ui/views/edit_listing_page.dart';
import 'package:campus_innovate/features/listings/ui/views/listing_detail_page.dart';
import 'package:campus_innovate/features/listings/ui/widgets/status_chip.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/in_memory_notification_source.dart';
import '../../../support/test_bindings.dart';
import '../../../support/test_session.dart';

const _closingWarning = 'Al guardar, las solicitudes pendientes se rechazan y '
    'el proyecto deja de recibir nuevas.';

/// A project Leonel (the signed-in user) leads, with [teamSize] people in it.
Listing _project({
  int teamSize = 1,
  int maxMembers = 4,
  ListingStatus status = ListingStatus.idea,
}) {
  final ids = ['user_1', for (var i = 2; i <= teamSize; i++) 'user_${i + 10}'];

  return Listing(
    id: '',
    title: 'Observatorio Estudiantil',
    description: 'Medimos la calidad del aire del campus con sensores baratos.',
    category: 'Investigación',
    creatorId: 'user_1',
    creatorName: 'Leonel Triana',
    maxMembers: maxMembers,
    requiredSkills: const ['Arduino'],
    memberIds: ids,
    status: status,
    members: [
      for (final id in ids)
        ListingMember(
          userId: id,
          userName: id == 'user_1' ? 'Leonel Triana' : 'Persona $id',
          role: id == 'user_1' ? ListingRole.leader : ListingRole.member,
        ),
    ],
  );
}

void main() {
  tearDown(Get.reset);

  Finder statusOption(String label) => find.widgetWithText(ChoiceChip, label);

  bool isSelected(WidgetTester tester, Finder chip) =>
      tester.widget<ChoiceChip>(chip).selected;

  /// Opens the form straight on its route, over a source holding [listing].
  Future<({InMemoryListingSource source, Listing stored})> openEdit(
    WidgetTester tester, {
    Listing? listing,
    TestBindings Function(InMemoryListingSource)? bindings,
  }) async {
    final source = InMemoryListingSource();
    final stored = await source.createListing(listing ?? _project());

    await tester.pumpApp(
      route: AppRoutes.editOf(stored.id),
      bindings: bindings?.call(source) ?? TestBindings(source: source),
    );

    return (source: source, stored: stored);
  }

  group('carga', () {
    testWidgets('llena el formulario con lo que el proyecto tiene',
        (tester) async {
      await openEdit(tester);

      expect(find.byType(EditListingPage), findsOneWidget);
      expect(find.text('Editar proyecto'), findsOneWidget);
      expect(find.text('Observatorio Estudiantil'), findsOneWidget);
      expect(
        find.text('Medimos la calidad del aire del campus con sensores baratos.'),
        findsOneWidget,
      );
      expect(isSelected(tester, statusOption('Idea')), isTrue);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Investigación'))
            .selected,
        isTrue,
      );
      expect(find.widgetWithText(InputChip, 'Arduino'), findsOneWidget);
      expect(find.text('4 personas'), findsOneWidget);
    });

    testWidgets('ofrece los cuatro estados, cada uno con el ícono de su pastilla',
        (tester) async {
      await openEdit(tester);

      for (final status in ListingStatus.values) {
        final chip = statusOption(status.label);

        expect(chip, findsOneWidget);
        expect(
          find.descendant(
            of: chip,
            matching: find.byIcon(StatusChip.styleOf(status).icon),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('quien no es líder ve que no puede editar', (tester) async {
      final source = InMemoryListingSource();
      final stored = await source.createListing(_project());

      await tester.pumpApp(
        route: AppRoutes.editOf(stored.id),
        bindings: TestBindings(
          source: source,
          session: TestSession(TestUsers.mariana),
        ),
      );

      expect(find.text('No se puede editar'), findsOneWidget);
      expect(find.text('Solo el líder del proyecto puede editarlo.'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsNothing);
    });

    testWidgets('un proyecto que no existe lo dice', (tester) async {
      await tester.pumpApp(route: AppRoutes.editOf('listing_999'));

      expect(find.text('No se puede editar'), findsOneWidget);
      expect(find.text('Proyecto no encontrado'), findsOneWidget);
    });
  });

  group('estado', () {
    testWidgets('elegir "Terminado" avisa que se cierran las solicitudes',
        (tester) async {
      await openEdit(tester);

      expect(find.text(_closingWarning), findsNothing);

      await tester.tapVisible(statusOption('Terminado'));

      expect(isSelected(tester, statusOption('Terminado')), isTrue);
      expect(isSelected(tester, statusOption('Idea')), isFalse);
      expect(find.text(_closingWarning), findsOneWidget);

      // Changing one's mind takes the warning away.
      await tester.tapVisible(statusOption('En curso'));

      expect(find.text(_closingWarning), findsNothing);
    });

    testWidgets('un proyecto que ya estaba terminado no repite el aviso',
        (tester) async {
      await openEdit(tester, listing: _project(status: ListingStatus.done));

      expect(isSelected(tester, statusOption('Terminado')), isTrue);
      expect(find.text(_closingWarning), findsNothing);
    });
  });

  group('tamaño del equipo', () {
    testWidgets('el control no baja del equipo que ya existe', (tester) async {
      await openEdit(tester, listing: _project(teamSize: 3, maxMembers: 5));

      final slider = tester.widget<Slider>(find.byType(Slider));

      expect(slider.min, 3);
      expect(slider.max, 12);
      expect(slider.value, 5);
      expect(
        find.text('El equipo ya tiene 3 personas: no puede ser más pequeño.'),
        findsOneWidget,
      );
    });

    testWidgets('con una sola persona el mínimo sigue siendo dos',
        (tester) async {
      await openEdit(tester);

      expect(tester.widget<Slider>(find.byType(Slider)).min, 2);
      expect(
        find.text('El equipo ya tiene 1 persona: no puede ser más pequeño.'),
        findsOneWidget,
      );
    });

    testWidgets('arrastrar el control cambia el tamaño', (tester) async {
      await openEdit(tester);

      await tester.ensureVisible(find.byType(Slider));
      await tester.drag(find.byType(Slider), const Offset(2000, 0));
      await tester.pumpAndSettle();

      expect(find.text('12 personas'), findsOneWidget);
    });

    testWidgets('con el equipo en el máximo no hay nada que elegir',
        (tester) async {
      await openEdit(tester, listing: _project(teamSize: 12, maxMembers: 12));

      expect(find.byType(Slider), findsNothing);
      expect(find.text('12 personas'), findsOneWidget);
    });
  });

  group('habilidades', () {
    testWidgets('se agregan con el botón y no se repiten', (tester) async {
      await openEdit(tester);

      await tester.enterField('Agregar una habilidad', 'Python');
      await tester.tapVisible(find.byTooltip('Agregar habilidad'));

      expect(find.widgetWithText(InputChip, 'Python'), findsOneWidget);

      await tester.enterField('Agregar una habilidad', 'Arduino');
      await tester.tapVisible(find.byTooltip('Agregar habilidad'));

      expect(find.widgetWithText(InputChip, 'Arduino'), findsOneWidget);
    });

    testWidgets('una habilidad se quita con la x de su chip', (tester) async {
      await openEdit(tester);

      await tester.tapVisible(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Arduino'),
          matching: find.byTooltip('Delete'),
        ),
      );

      expect(find.widgetWithText(InputChip, 'Arduino'), findsNothing);
    });
  });

  group('guardar', () {
    testWidgets('un título corto no se guarda', (tester) async {
      final seeded = await openEdit(tester);

      await tester.enterField('Título del proyecto', 'Obs');
      await tester.tapText('Guardar cambios');

      expect(
        find.text('Escribe un título de al menos 5 caracteres'),
        findsOneWidget,
      );
      expect(find.byType(EditListingPage), findsOneWidget);
      expect(
        (await seeded.source.getListingById(seeded.stored.id))!.title,
        'Observatorio Estudiantil',
      );
    });

    testWidgets('una descripción corta no se guarda', (tester) async {
      await openEdit(tester);

      await tester.enterField('Descripción', 'Muy corta');
      await tester.tapText('Guardar cambios');

      expect(
        find.text('Describe la idea en al menos 20 caracteres'),
        findsOneWidget,
      );
    });

    testWidgets(
        'desde el detalle: guarda, vuelve con "Cambios guardados" y el detalle '
        'ya muestra lo nuevo', (tester) async {
      final source = InMemoryListingSource();
      final stored = await source.createListing(_project());

      await tester.pumpApp(
        route: AppRoutes.detailOf(stored.id),
        bindings: TestBindings(source: source),
      );
      await tester.tap(find.byTooltip('Editar proyecto'));
      await tester.pumpAndSettle();

      expect(find.byType(EditListingPage), findsOneWidget);

      await tester.enterField('Título del proyecto', 'Observatorio del Aire');
      await tester.tapVisible(statusOption('En curso'));
      await tester.tapVisible(find.widgetWithText(ChoiceChip, 'Tecnología'));
      await tester.tapText('Guardar cambios');

      expect(find.byType(EditListingPage), findsNothing);
      expect(find.byType(ListingDetailPage), findsOneWidget);
      expect(find.text('Cambios guardados'), findsOneWidget);
      expect(find.text('"Observatorio del Aire" quedó en curso'), findsOneWidget);
      expect(find.text('Observatorio del Aire'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.text('En curso'),
        ),
        findsOneWidget,
      );

      final saved = (await source.getListingById(stored.id))!;
      expect(saved.title, 'Observatorio del Aire');
      expect(saved.status, ListingStatus.inProgress);
      expect(saved.category, 'Tecnología');

      await tester.settleSnackbars();
    });

    testWidgets('terminar el proyecto rechaza las solicitudes pendientes',
        (tester) async {
      final source = InMemoryListingSource();
      final notifications = InMemoryNotificationSource();
      final stored = await source.createListing(_project());

      await source.createJoinRequest(
        JoinRequest.draft(
          listingId: stored.id,
          applicantId: TestUsers.mariana.id,
          applicantName: TestUsers.mariana.name,
          motivation: 'Me interesa la instrumentación.',
          skills: 'Python',
          availability: 'Martes',
        ),
      );

      await tester.pumpApp(
        route: AppRoutes.detailOf(stored.id),
        bindings: TestBindings(
          source: source,
          notificationSource: notifications,
        ),
      );
      expect(find.text(TestUsers.mariana.name), findsOneWidget);

      await tester.tap(find.byTooltip('Editar proyecto'));
      await tester.pumpAndSettle();
      await tester.tapVisible(statusOption('Terminado'));
      await tester.tapText('Guardar cambios');

      expect(find.text('Cambios guardados'), findsOneWidget);

      final requests = await source.getRequestsForListing(stored.id);
      expect(requests.single.status, JoinRequestStatus.rejected);
      expect(
        notifications.all.where(
          (n) =>
              n.recipientId == TestUsers.mariana.id &&
              n.type == NotificationType.requestRejected,
        ),
        hasLength(1),
      );

      await tester.settleSnackbars();
    });
  });
}
