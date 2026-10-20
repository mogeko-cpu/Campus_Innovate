import 'package:campus_innovate/features/shell/ui/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  Finder actionButton() => find.byWidgetPredicate(
        (widget) => widget is FilledButton,
      );

  testWidgets('la versión de pantalla centra título, mensaje e ícono',
      (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(
        home: Scaffold(
          body: EmptyState.screen(
            icon: Icons.search_off,
            title: 'Ningún proyecto coincide',
            message: 'Prueba con otra categoría.',
          ),
        ),
      ),
    );

    expect(find.text('Ningún proyecto coincide'), findsOneWidget);
    expect(find.text('Prueba con otra categoría.'), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.search_off)).size, 36);
    expect(
      find.ancestor(
        of: find.text('Ningún proyecto coincide'),
        matching: find.byType(Center),
      ),
      findsWidgets,
    );
  });

  testWidgets('la versión en línea es compacta y ocupa todo el ancho',
      (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const EmptyState.inline(
          icon: Icons.inbox_outlined,
          title: 'No hay solicitudes pendientes',
        ),
      ),
    );

    expect(find.text('No hay solicitudes pendientes'), findsOneWidget);
    expect(tester.widget<Icon>(find.byIcon(Icons.inbox_outlined)).size, 26);

    // 800 px of test surface minus the 16 px padding of each side.
    expect(tester.getSize(find.byType(EmptyState)).width, 800 - 32);
  });

  testWidgets('sin mensaje solo muestra el título', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const EmptyState.inline(icon: Icons.lightbulb_outline, title: 'Vacío'),
      ),
    );

    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('con etiqueta y acción muestra el botón y lo ejecuta',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      wrapWidget(
        EmptyState.inline(
          icon: Icons.groups_outlined,
          title: 'Aún no tienes grupos',
          actionLabel: 'Crear grupo',
          onAction: () => taps++,
        ),
      ),
    );

    expect(actionButton(), findsOneWidget);
    await tester.tap(find.text('Crear grupo'));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('sin acción no hay botón aunque haya etiqueta', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const EmptyState.inline(
          icon: Icons.groups_outlined,
          title: 'Aún no tienes grupos',
          actionLabel: 'Crear grupo',
        ),
      ),
    );

    expect(actionButton(), findsNothing);
    expect(find.text('Crear grupo'), findsNothing);
  });

  testWidgets('sin etiqueta no hay botón aunque haya acción', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        EmptyState.screen(
          icon: Icons.groups_outlined,
          title: 'Aún no tienes grupos',
          onAction: () {},
        ),
      ),
    );

    expect(actionButton(), findsNothing);
  });

  testWidgets('el tinte colorea el ícono; sin él se usa el primario',
      (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );

    await tester.pumpWidget(
      wrapWidget(
        const Column(
          children: [
            EmptyState.inline(icon: Icons.error_outline, title: 'Error', tint: Colors.orange),
            EmptyState.inline(icon: Icons.info_outline, title: 'Normal'),
          ],
        ),
        theme: theme,
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
      Colors.orange,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.info_outline)).color,
      theme.colorScheme.primary,
    );
  });
}
