import 'package:campus_innovate/core/widgets/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  /// A button that asks, and keeps every answer where the test can read it.
  Future<List<bool>> pumpAsker(WidgetTester tester) async {
    final answers = <bool>[];

    await tester.pumpWidget(
      wrapWidget(
        FilledButton(
          onPressed: () async => answers.add(
            await confirmAction(
              title: '¿Eliminar el proyecto?',
              message: 'Esta acción no se puede deshacer.',
              confirmLabel: 'Eliminar',
            ),
          ),
          child: const Text('Preguntar'),
        ),
      ),
    );

    return answers;
  }

  Future<void> ask(WidgetTester tester) async {
    await tester.tap(find.text('Preguntar'));
    await tester.pumpAndSettle();
  }

  testWidgets('muestra título, mensaje, "Cancelar" y la acción', (tester) async {
    await pumpAsker(tester);
    await ask(tester);

    expect(find.byType(ConfirmDialog), findsOneWidget);
    expect(find.text('¿Eliminar el proyecto?'), findsOneWidget);
    expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Eliminar'), findsOneWidget);
  });

  testWidgets('confirmar cierra el diálogo y devuelve true', (tester) async {
    final answers = await pumpAsker(tester);
    await ask(tester);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmDialog), findsNothing);
    expect(answers, [true]);
  });

  testWidgets('"Cancelar" cierra el diálogo y devuelve false', (tester) async {
    final answers = await pumpAsker(tester);
    await ask(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmDialog), findsNothing);
    expect(answers, [false]);
  });

  testWidgets('tocar fuera del diálogo cuenta como no confirmar',
      (tester) async {
    final answers = await pumpAsker(tester);
    await ask(tester);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmDialog), findsNothing);
    expect(answers, [false]);
  });

  testWidgets('"Cancelar" cierra el diálogo aunque haya un snackbar a la vista',
      (tester) async {
    final answers = await pumpAsker(tester);

    // The case `Get.back()` got wrong: it closed the toast and left the dialog.
    Get.snackbar('Listo', 'Algo pasó', snackPosition: SnackPosition.BOTTOM);
    await tester.pump(const Duration(milliseconds: 500));

    await ask(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(ConfirmDialog), findsNothing);
    expect(answers, [false]);

    await tester.settleSnackbars();
  });
}
