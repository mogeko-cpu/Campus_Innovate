import 'package:campus_innovate/features/home/ui/widgets/action_card.dart';
import 'package:campus_innovate/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const CampusInnovateApp());
    await tester.pumpAndSettle();
  }

  /// Drains the 3s auto-dismiss timer of [Get.snackbar] so the test does not
  /// end with a pending timer.
  Future<void> settleSnackbar(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('home shows the greeting and featured listings', (tester) async {
    await pumpApp(tester);

    expect(find.text('Hola, Leonel'), findsOneWidget);
    expect(find.text('Campus App'), findsOneWidget);
    expect(find.text('Huerta Universitaria'), findsOneWidget);

    await tester.ensureVisible(find.text('Mis proyectos'));
    await tester.pumpAndSettle();
    expect(find.text('Aún no participas en ningún proyecto.'), findsOneWidget);
  });

  testWidgets('publishing a project lists it under my projects',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(ActionCard, 'Publicar idea'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Título del proyecto'),
      'Tutorías entre pares',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Descripción'),
      'Red de estudiantes que dictan refuerzos a compañeros de primeros semestres.',
    );
    await tapText(tester, 'Impacto Social');
    await tapText(tester, 'Publicar proyecto');

    await tester.ensureVisible(find.text('Mis proyectos'));
    await tester.pumpAndSettle();

    // Once under "Ideas destacadas" and once under "Mis proyectos".
    expect(find.text('Tutorías entre pares'), findsNWidgets(2));

    await settleSnackbar(tester);
  });

  testWidgets('a student can request to join an open project', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(ActionCard, 'Explorar'));
    await tester.pumpAndSettle();

    await tapText(tester, 'Huerta Universitaria');

    expect(find.text('2 de 6 integrantes'), findsOneWidget);

    await tapText(tester, 'Solicitar unirme');

    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Por qué quieres participar?'),
      'Quiero aplicar lo que aprendí en el curso de sostenibilidad.',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '¿Qué habilidades aportas?'),
      'Biología, trabajo de campo',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Disponibilidad semanal'),
      '8 horas, lunes y miércoles',
    );

    await tapText(tester, 'Enviar solicitud');

    expect(
      find.text('Solicitud enviada — estado: Pendiente.'),
      findsOneWidget,
    );
    expect(find.text('Solicitar unirme'), findsNothing);

    await settleSnackbar(tester);
  });
}
