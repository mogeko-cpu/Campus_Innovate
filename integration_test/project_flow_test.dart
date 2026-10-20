import 'package:campus_innovate/features/home/ui/widgets/action_card.dart';
import 'package:campus_innovate/features/listings/ui/widgets/listing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/test_session.dart';
import 'flow_helpers.dart';

/// La vida de un proyecto: se publica, se encuentra, se valora, se comenta,
/// sube en el ranking y su creador lo elimina.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  testWidgets('publicar una idea, valorarla, comentarla, verla primera en el '
      'ranking y eliminarla', (tester) async {
    final app = await CampusApp.start(tester, signedInAs: TestUsers.leonel);

    // Publicar.
    await app.tap(find.widgetWithText(ActionCard, 'Publicar idea'));
    await app.waitForText('Cuéntanos tu idea');

    await app.enter('Título del proyecto', 'Tutorías entre pares');
    await app.enter(
      'Descripción',
      'Red de estudiantes que dictan refuerzos a compañeros de primeros '
          'semestres.',
    );

    // Leonel has exactly one group, so the form already chose it.
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Innovación UN'))
          .selected,
      isTrue,
    );

    await app.tap(find.widgetWithText(ChoiceChip, 'Impacto Social'));
    await app.enter('Ej. Flutter, Diseño UI, Finanzas', 'Pedagogía');
    await app.tap(find.widgetWithIcon(IconButton, Icons.add));

    expect(find.widgetWithText(InputChip, 'Pedagogía'), findsOneWidget);

    await app.tapText('Publicar proyecto');
    await app.waitForText('Proyecto publicado');
    await app.waitForSnackbars();

    // Once under "Ideas destacadas" and once under "Mis proyectos".
    await app.waitFor(find.text('Tutorías entre pares'));
    expect(find.text('Tutorías entre pares'), findsNWidgets(2));

    // Encontrarlo en Explorar.
    await app.goToTab('Explorar');
    await app.waitForText('Explorar proyectos');

    expect(find.byType(ListingCard), findsNWidgets(4));

    final search = find.byType(TextField);

    await app.enterInto(search, 'tutorías');
    expect(find.byType(ListingCard), findsOneWidget);

    await app.enterInto(search, 'no existe nada así');
    expect(find.text('Ningún proyecto coincide'), findsOneWidget);

    await app.enterInto(search, '');
    await app.tap(find.widgetWithText(ChoiceChip, 'Impacto Social'));
    expect(find.byType(ListingCard), findsOneWidget);
    expect(find.text('Tutorías entre pares'), findsOneWidget);

    // Valorarlo y comentarlo.
    await app.tapText('Tutorías entre pares');
    await app.waitForText('Detalle del proyecto');

    expect(find.text('Este es tu proyecto.'), findsOneWidget);
    expect(find.text('No hay solicitudes pendientes'), findsOneWidget);
    expect(find.text('1 vista'), findsOneWidget);

    await app.tap(find.byIcon(Icons.thumb_up_outlined));
    await app.waitFor(find.byIcon(Icons.thumb_up));

    await app.enter('Escribe un comentario', 'Cuenten conmigo para el piloto.');
    await app.tap(find.byIcon(Icons.send));
    await app.waitForText('Comentarios (1)');

    expect(find.text('Cuenten conmigo para el piloto.'), findsOneWidget);
    expect(find.text('1 comentario'), findsOneWidget);

    // Con un me gusta y el resto en cero, encabeza el ranking.
    await app.back();
    await app.waitForText('Explorar proyectos');
    await app.goToTab('Ranking');
    await app.waitForText('Ranking del campus');

    final top = find.byType(ListingCard).first;
    expect(
      find.descendant(of: top, matching: find.text('Tutorías entre pares')),
      findsOneWidget,
    );

    // Eliminarlo desde el ranking.
    await app.tap(
      find.descendant(of: top, matching: find.text('Tutorías entre pares')),
    );
    await app.waitForText('Detalle del proyecto');

    await app.tap(find.byTooltip('Eliminar proyecto'));
    expect(find.text('¿Eliminar el proyecto?'), findsOneWidget);
    await app.tap(find.widgetWithText(FilledButton, 'Eliminar'));

    await app.waitForText('Proyecto eliminado');
    await app.waitForSnackbars();

    expect(find.text('Ranking del campus'), findsOneWidget);
    expect(find.text('Tutorías entre pares'), findsNothing);
    expect(find.byType(ListingCard), findsNWidgets(3));
  });
}
