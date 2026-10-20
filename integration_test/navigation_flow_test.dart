import 'package:campus_innovate/features/listings/ui/widgets/listing_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/test_session.dart';
import 'flow_helpers.dart';

/// Recorrer las cinco pestañas, las notificaciones y el tema, como alguien que
/// abre la app por primera vez.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  Brightness brightnessOf(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(NavigationBar))).brightness;

  testWidgets('las cinco pestañas, la campana y el cambio de tema',
      (tester) async {
    final app = await CampusApp.start(tester, signedInAs: TestUsers.leonel);

    expect(find.text('Hola, Leonel'), findsOneWidget);

    await app.goToTab('Explorar');
    await app.waitForText('Explorar proyectos');
    expect(find.byType(ListingCard), findsNWidgets(3));

    await app.goToTab('Ranking');
    await app.waitForText('Ranking del campus');
    expect(find.text('proyectos'), findsOneWidget);

    await app.goToTab('Grupos');
    await app.waitForText('Mis grupos');
    expect(find.text('Innovación UN'), findsOneWidget);
    expect(find.text('Creador'), findsOneWidget);

    await app.goToTab('Perfil');
    await app.waitForText('Leonel Triana');
    expect(find.text('leonel@uninorte.edu.co'), findsOneWidget);

    // Sin nada pendiente, la lista de notificaciones lo dice.
    await app.tap(find.byTooltip('Notificaciones'));
    await app.waitForText('Todavía no tienes notificaciones');
    await app.back();

    // El tema cambia en toda la app en el momento.
    await app.tapText('Oscuro');
    expect(brightnessOf(tester), Brightness.dark);

    await app.goToTab('Inicio');
    await app.waitForText('Hola, Leonel');
    expect(brightnessOf(tester), Brightness.dark);

    await app.goToTab('Perfil');
    await app.waitForText('Leonel Triana');
    await app.tapText('Claro');
    expect(brightnessOf(tester), Brightness.light);
  });
}
