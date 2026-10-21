import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_comment.dart';
import 'package:campus_innovate/features/listings/ui/views/join_request_page.dart';
import 'package:campus_innovate/features/listings/ui/views/listing_detail_page.dart';
import 'package:campus_innovate/features/listings/ui/views/listings_page.dart';
import 'package:campus_innovate/features/listings/ui/widgets/listing_card.dart';
import 'package:campus_innovate/features/listings/ui/widgets/reaction_bar.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_engagement_source.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/in_memory_notification_source.dart';
import '../../../support/test_bindings.dart';
import '../../../support/test_session.dart';

/// A project Leonel (the signed-in user) published under his group.
Listing _mine({int maxMembers = 3, List<String> memberIds = const ['user_1']}) =>
    Listing(
      id: '',
      title: 'Observatorio Estudiantil',
      description: 'Medimos la calidad del aire del campus con sensores baratos.',
      category: 'Investigación',
      creatorId: 'user_1',
      creatorName: 'Leonel Triana',
      maxMembers: maxMembers,
      requiredSkills: const ['Arduino'],
      memberIds: memberIds,
      groupId: 'group_1',
      groupName: 'Innovación UN',
    );

JoinRequest _fromMariana(String listingId) => JoinRequest.draft(
      listingId: listingId,
      applicantId: TestUsers.mariana.id,
      applicantName: TestUsers.mariana.name,
      motivation: 'Me interesa la instrumentación ambiental.',
      skills: 'Python, soldadura',
      availability: 'Martes en la tarde',
    );

void main() {
  tearDown(Get.reset);

  /// The like or dislike button, whichever of its icons it shows. By
  /// [ButtonStyleButton] because the selected one is a private subclass of
  /// [FilledButton].
  Finder vote(IconData icon) => find.ancestor(
        of: find.byIcon(icon),
        matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      );

  Finder commentField() => find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Escribe un comentario',
      );

  Future<void> writeComment(WidgetTester tester, String body) async {
    await tester.enterText(commentField(), body);
    await tester.tapVisible(find.widgetWithIcon(IconButton, Icons.send));
  }

  Future<void> openDetail(
    WidgetTester tester,
    String id, {
    TestBindings? bindings,
  }) =>
      tester.pumpApp(route: AppRoutes.detailOf(id), bindings: bindings);

  group('como visitante', () {
    testWidgets('muestra el proyecto: categoría, creador, habilidades y equipo',
        (tester) async {
      await openDetail(tester, 'listing_2');

      expect(find.text('Detalle del proyecto'), findsOneWidget);
      expect(find.text('Huerta Universitaria'), findsOneWidget);
      expect(find.text('Sostenibilidad'), findsOneWidget);
      // Once under the title and once on the team list, where she leads.
      expect(find.text('Mariana Ospina'), findsNWidgets(2));
      expect(find.text('Creador del proyecto'), findsOneWidget);
      expect(find.text('Líder'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Biología'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Gestión de proyectos'), findsOneWidget);
      expect(find.text('2 de 6 integrantes'), findsOneWidget);
      // The seeded projects predate groups.
      expect(find.text('Publicado sin grupo'), findsOneWidget);
    });

    testWidgets('un proyecto de un grupo dice qué grupo lo publicó',
        (tester) async {
      final source = InMemoryListingSource();
      final stored = await source.createListing(
        _mine().copyWith(creatorId: 'user_3', creatorName: 'Mariana Ospina'),
      );

      await openDetail(tester, stored.id, bindings: TestBindings(source: source));

      expect(find.text('Publicado por Innovación UN'), findsOneWidget);
    });

    testWidgets('ofrece "Solicitar unirme" y no las herramientas del creador',
        (tester) async {
      await openDetail(tester, 'listing_2');

      expect(find.text('Solicitar unirme'), findsOneWidget);
      expect(find.byTooltip('Eliminar proyecto'), findsNothing);
      expect(find.text('Solicitudes recibidas'), findsNothing);
      expect(find.text('Este es tu proyecto.'), findsNothing);
    });

    testWidgets('"Solicitar unirme" abre el formulario de postulación',
        (tester) async {
      await openDetail(tester, 'listing_2');

      await tester.tapText('Solicitar unirme');

      expect(find.byType(JoinRequestPage), findsOneWidget);
    });

    testWidgets('abrirlo cuenta una vista, y volver del formulario no la '
        'repite', (tester) async {
      await openDetail(tester, 'listing_2');

      expect(find.text('1 vista'), findsOneWidget);

      await tester.tapText('Solicitar unirme');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(ListingDetailPage), findsOneWidget);
      expect(find.text('1 vista'), findsOneWidget);
    });

    testWidgets('con el equipo completo lo dice y no ofrece unirse',
        (tester) async {
      final source = InMemoryListingSource();
      final full = await source.createListing(
        _mine(maxMembers: 2, memberIds: ['user_3', 'user_4']).copyWith(
          creatorId: 'user_3',
          creatorName: 'Mariana Ospina',
        ),
      );

      await openDetail(tester, full.id, bindings: TestBindings(source: source));

      expect(find.text('El equipo ya está completo.'), findsOneWidget);
      expect(find.text('2 de 2 integrantes'), findsOneWidget);
      expect(find.text('Solicitar unirme'), findsNothing);
    });

    testWidgets('si ya soy integrante lo dice en vez de ofrecer unirme',
        (tester) async {
      final source = InMemoryListingSource();
      final joined = await source.createListing(
        _mine(memberIds: ['user_3', 'user_1']).copyWith(
          creatorId: 'user_3',
          creatorName: 'Mariana Ospina',
        ),
      );

      await openDetail(tester, joined.id, bindings: TestBindings(source: source));

      expect(find.text('Ya formas parte de este equipo.'), findsOneWidget);
      expect(find.text('Solicitar unirme'), findsNothing);
    });

    testWidgets('si ya me postulé muestra el estado de mi solicitud',
        (tester) async {
      final source = InMemoryListingSource();
      final request = await source.createJoinRequest(
        JoinRequest.draft(
          listingId: 'listing_2',
          applicantId: 'user_1',
          applicantName: 'Leonel Triana',
          motivation: 'Quiero aprender de agricultura urbana.',
          skills: 'Logística',
          availability: 'Fines de semana',
        ),
      );
      await source.updateRequestStatus(request.id, JoinRequestStatus.rejected);

      await openDetail(tester, 'listing_2', bindings: TestBindings(source: source));

      expect(find.text('Solicitud enviada — estado: Rechazada.'), findsOneWidget);
      expect(find.text('Solicitar unirme'), findsNothing);
    });

    testWidgets('un proyecto que no existe muestra "Proyecto no encontrado"',
        (tester) async {
      await openDetail(tester, 'listing_que_no_existe');

      expect(find.text('Proyecto no encontrado'), findsOneWidget);
      expect(find.byType(ReactionBar), findsNothing);
      expect(find.byTooltip('Eliminar proyecto'), findsNothing);
    });
  });

  group('valoración', () {
    testWidgets('me gusta suma uno y rellena el botón; repetirlo lo retira',
        (tester) async {
      await openDetail(tester, 'listing_2');

      await tester.tapVisible(vote(Icons.thumb_up_outlined));

      expect(tester.widget(vote(Icons.thumb_up)), isA<FilledButton>());
      expect(
        find.descendant(of: vote(Icons.thumb_up), matching: find.text('1')),
        findsOneWidget,
      );

      await tester.tapVisible(vote(Icons.thumb_up));

      expect(find.byIcon(Icons.thumb_up), findsNothing);
      expect(
        find.descendant(
          of: vote(Icons.thumb_up_outlined),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('cambiar a no me gusta mueve el voto de un contador al otro',
        (tester) async {
      final engagement = InMemoryEngagementSource();
      await openDetail(
        tester,
        'listing_2',
        bindings: TestBindings(engagementSource: engagement),
      );

      await tester.tapVisible(vote(Icons.thumb_up_outlined));
      await tester.tapVisible(vote(Icons.thumb_down_outlined));

      expect(
        find.descendant(
          of: vote(Icons.thumb_up_outlined),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: vote(Icons.thumb_down), matching: find.text('1')),
        findsOneWidget,
      );

      // One person, one vote: what the database holds agrees with the screen.
      final stats = await engagement.getStatsFor(
        listingId: 'listing_2',
        userId: 'user_1',
      );
      expect(stats.likes, 0);
      expect(stats.dislikes, 1);
    });
  });

  group('comentarios', () {
    testWidgets('sin comentarios lo dice', (tester) async {
      await openDetail(tester, 'listing_2');

      expect(find.text('Comentarios (0)'), findsOneWidget);
      expect(find.text('Todavía no hay comentarios'), findsOneWidget);
    });

    testWidgets('publicar un comentario lo muestra, vacía el campo y avisa '
        'al creador', (tester) async {
      final notifications = InMemoryNotificationSource();
      await openDetail(
        tester,
        'listing_2',
        bindings: TestBindings(notificationSource: notifications),
      );

      await writeComment(tester, '¿Necesitan ayuda con el riego?');

      expect(find.text('¿Necesitan ayuda con el riego?'), findsOneWidget);
      expect(find.text('Leonel Triana'), findsOneWidget);
      expect(find.text('Comentarios (1)'), findsOneWidget);
      expect(find.text('1 comentario'), findsOneWidget);
      expect(find.text('Todavía no hay comentarios'), findsNothing);
      expect(tester.widget<TextField>(commentField()).controller!.text, isEmpty);

      expect(
        notifications.all.where(
          (n) => n.recipientId == 'user_3' && n.type == NotificationType.comment,
        ),
        hasLength(1),
      );
    });

    testWidgets('un comentario en blanco no se envía', (tester) async {
      final engagement = InMemoryEngagementSource();
      await openDetail(
        tester,
        'listing_2',
        bindings: TestBindings(engagementSource: engagement),
      );

      await writeComment(tester, '    ');

      expect(find.text('Comentarios (0)'), findsOneWidget);
      expect(await engagement.getComments('listing_2'), isEmpty);
    });

    testWidgets('el más reciente va primero y solo el mío se puede borrar',
        (tester) async {
      final engagement = InMemoryEngagementSource();
      await engagement.addComment(
        ListingComment(
          id: '',
          listingId: 'listing_2',
          groupId: '',
          authorId: 'user_3',
          authorName: 'Mariana Ospina',
          body: 'Bienvenidos todos.',
          createdAt: DateTime(2026, 1, 1),
        ),
      );

      await openDetail(
        tester,
        'listing_2',
        bindings: TestBindings(engagementSource: engagement),
      );

      expect(find.text('Comentarios (1)'), findsOneWidget);
      expect(find.byTooltip('Eliminar comentario'), findsNothing);

      await writeComment(tester, 'Cuenten conmigo.');

      expect(find.text('Comentarios (2)'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Cuenten conmigo.')).dy,
        lessThan(tester.getTopLeft(find.text('Bienvenidos todos.')).dy),
      );
      expect(find.byTooltip('Eliminar comentario'), findsOneWidget);
    });

    testWidgets('borrar mi comentario lo quita y descuenta', (tester) async {
      final engagement = InMemoryEngagementSource();
      await openDetail(
        tester,
        'listing_2',
        bindings: TestBindings(engagementSource: engagement),
      );

      await writeComment(tester, 'Me retracto de esto.');
      await tester.tapVisible(find.byTooltip('Eliminar comentario'));

      expect(find.text('Me retracto de esto.'), findsNothing);
      expect(find.text('Comentarios (0)'), findsOneWidget);
      expect(find.text('Todavía no hay comentarios'), findsOneWidget);
      expect(await engagement.getComments('listing_2'), isEmpty);
    });
  });

  group('como creador', () {
    testWidgets('ve que es su proyecto, el botón de borrar y la bandeja vacía',
        (tester) async {
      final source = InMemoryListingSource();
      final stored = await source.createListing(_mine());

      await openDetail(tester, stored.id, bindings: TestBindings(source: source));

      expect(find.text('Este es tu proyecto.'), findsOneWidget);
      expect(find.byTooltip('Eliminar proyecto'), findsOneWidget);
      expect(find.text('Solicitudes recibidas'), findsOneWidget);
      expect(find.text('No hay solicitudes pendientes'), findsOneWidget);
      expect(find.text('Solicitar unirme'), findsNothing);
    });

    testWidgets('la bandeja muestra quién se postuló y con qué datos',
        (tester) async {
      final source = InMemoryListingSource();
      final stored = await source.createListing(_mine());
      await source.createJoinRequest(_fromMariana(stored.id));

      await openDetail(tester, stored.id, bindings: TestBindings(source: source));

      expect(find.text('Mariana Ospina'), findsOneWidget);
      expect(
        find.textContaining(
          'Me interesa la instrumentación ambiental.',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Python, soldadura', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('Martes en la tarde', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Aceptar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);
    });

    testWidgets('aceptar suma a la persona al equipo y la saca de la bandeja',
        (tester) async {
      final source = InMemoryListingSource();
      final notifications = InMemoryNotificationSource();
      final stored = await source.createListing(_mine());
      final request = await source.createJoinRequest(_fromMariana(stored.id));

      await openDetail(
        tester,
        stored.id,
        bindings: TestBindings(source: source, notificationSource: notifications),
      );
      expect(find.text('1 de 3 integrantes'), findsOneWidget);

      await tester.tapText('Aceptar');

      expect(find.text('Solicitud aceptada'), findsOneWidget);
      expect(find.text('Mariana Ospina ya hace parte del equipo'), findsOneWidget);
      expect(find.text('2 de 3 integrantes'), findsOneWidget);
      expect(find.text('No hay solicitudes pendientes'), findsOneWidget);

      expect(
        (await source.getRequestById(request.id))!.status,
        JoinRequestStatus.accepted,
      );
      expect(
        (await source.getListingById(stored.id))!.memberIds,
        contains('user_2'),
      );
      expect(
        notifications.all.where(
          (n) =>
              n.recipientId == 'user_2' &&
              n.type == NotificationType.requestAccepted,
        ),
        hasLength(1),
      );

      await tester.settleSnackbars();
    });

    testWidgets('rechazar la saca de la bandeja sin sumar a nadie',
        (tester) async {
      final source = InMemoryListingSource();
      final stored = await source.createListing(_mine());
      final request = await source.createJoinRequest(_fromMariana(stored.id));

      await openDetail(tester, stored.id, bindings: TestBindings(source: source));

      await tester.tapText('Rechazar');

      expect(find.text('Solicitud rechazada'), findsOneWidget);
      expect(find.text('La persona verá el estado en su perfil'), findsOneWidget);
      expect(find.text('1 de 3 integrantes'), findsOneWidget);
      expect(find.text('No hay solicitudes pendientes'), findsOneWidget);
      expect(
        (await source.getRequestById(request.id))!.status,
        JoinRequestStatus.rejected,
      );

      await tester.settleSnackbars();
    });

    testWidgets('aceptar con el equipo lleno avisa el error y deja la '
        'solicitud pendiente', (tester) async {
      final source = InMemoryListingSource();
      final stored = await source.createListing(
        _mine(maxMembers: 2, memberIds: ['user_1', 'user_4']),
      );
      final request = await source.createJoinRequest(_fromMariana(stored.id));

      await openDetail(tester, stored.id, bindings: TestBindings(source: source));

      await tester.tapText('Aceptar');

      expect(find.text('Error'), findsOneWidget);
      // Once in the snackbar and once in the inbox, which shows the failure in
      // place of the cards.
      expect(
        find.text('El proyecto ya alcanzó su número máximo de integrantes.'),
        findsNWidgets(2),
      );
      expect(find.text('2 de 2 integrantes'), findsOneWidget);
      expect(
        (await source.getRequestById(request.id))!.status,
        JoinRequestStatus.pending,
      );

      await tester.settleSnackbars();
    });

    testWidgets('eliminar pide confirmación; cancelar no borra nada',
        (tester) async {
      final source = InMemoryListingSource();
      final stored = await source.createListing(_mine());

      await openDetail(tester, stored.id, bindings: TestBindings(source: source));

      await tester.tapVisible(find.byTooltip('Eliminar proyecto'));

      expect(find.text('¿Eliminar el proyecto?'), findsOneWidget);

      await tester.tapText('Cancelar');

      expect(find.text('¿Eliminar el proyecto?'), findsNothing);
      expect(find.byType(ListingDetailPage), findsOneWidget);
      expect(await source.getListingById(stored.id), isNotNull);
    });

    testWidgets('confirmar el borrado elimina el proyecto con su actividad y '
        'vuelve a la lista', (tester) async {
      final source = InMemoryListingSource();
      final engagement = InMemoryEngagementSource();
      final stored = await source.createListing(_mine());

      // Opened from the catalogue, so there is a list to go back to.
      await tester.pumpApp(
        route: AppRoutes.listings,
        bindings: TestBindings(source: source, engagementSource: engagement),
      );
      await tester.tapText('Observatorio Estudiantil');
      await writeComment(tester, 'Nota para el equipo.');

      await tester.tapVisible(find.byTooltip('Eliminar proyecto'));
      await tester.tapVisible(find.widgetWithText(FilledButton, 'Eliminar'));

      expect(find.byType(ListingsPage), findsOneWidget);
      expect(find.widgetWithText(ListingCard, 'Observatorio Estudiantil'),
          findsNothing);
      expect(find.text('Proyecto eliminado'), findsOneWidget);
      expect(find.text('Ya no aparece en el campus'), findsOneWidget);

      expect(await source.getListingById(stored.id), isNull);
      expect(await engagement.getComments(stored.id), isEmpty);

      await tester.settleSnackbars();
    });
  });
}
