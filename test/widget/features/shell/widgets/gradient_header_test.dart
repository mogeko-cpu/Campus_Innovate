import 'package:campus_innovate/features/shell/ui/widgets/gradient_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
  );

  BoxDecoration decorationOf(WidgetTester tester) => tester
      .widget<Container>(
        find.descendant(
          of: find.byType(GradientHeader),
          matching: find.byType(Container),
        ).first,
      )
      .decoration! as BoxDecoration;

  testWidgets('muestra el ícono, el título y el subtítulo', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const GradientHeader(
          icon: Icons.leaderboard_outlined,
          title: 'Ranking del campus',
          subtitle: 'Ordenado por valoración',
        ),
      ),
    );

    expect(find.text('Ranking del campus'), findsOneWidget);
    expect(find.text('Ordenado por valoración'), findsOneWidget);
    expect(find.byIcon(Icons.leaderboard_outlined), findsOneWidget);
  });

  testWidgets('el fondo es un degradado del primario al secundario',
      (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const GradientHeader(icon: Icons.groups, title: 'Grupos', subtitle: 'x'),
        theme: theme,
      ),
    );

    final gradient = decorationOf(tester).gradient! as LinearGradient;
    expect(gradient.colors, [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
    ]);
  });

  testWidgets('sin estadísticas no dibuja chips', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const GradientHeader(icon: Icons.groups, title: 'Grupos', subtitle: 'x'),
      ),
    );

    // Title and subtitle only.
    expect(
      find.descendant(
        of: find.byType(GradientHeader),
        matching: find.byType(Text),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('cada estadística muestra su valor sobre su etiqueta, en orden',
      (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const GradientHeader(
          icon: Icons.leaderboard_outlined,
          title: 'Ranking del campus',
          subtitle: 'x',
          stats: [('3', 'proyectos'), ('12', 'me gusta en total')],
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('proyectos'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('me gusta en total'), findsOneWidget);

    expect(
      tester.getTopLeft(find.text('3')).dy,
      lessThan(tester.getTopLeft(find.text('proyectos')).dy),
    );
    expect(
      tester.getTopLeft(find.text('3')).dx,
      lessThan(tester.getTopLeft(find.text('12')).dx),
    );
  });
}
