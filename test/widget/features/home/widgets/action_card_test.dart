import 'package:campus_innovate/features/home/ui/widgets/action_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  ThemeData theme() => ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.red));

  Material surfaceOf(WidgetTester tester) => tester.widget<Material>(
        find
            .descendant(
              of: find.byType(ActionCard),
              matching: find.byType(Material),
            )
            .first,
      );

  testWidgets('muestra el ícono, el título y el subtítulo', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        ActionCard(
          icon: Icons.add_circle_outline,
          title: 'Publicar idea',
          subtitle: 'Arma tu equipo',
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Publicar idea'), findsOneWidget);
    expect(find.text('Arma tu equipo'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('tocar la tarjeta ejecuta onTap una vez por toque',
      (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      wrapWidget(
        ActionCard(
          icon: Icons.explore,
          title: 'Explorar',
          subtitle: 'Ver proyectos',
          onTap: () => taps++,
        ),
      ),
    );

    await tester.tap(find.byType(ActionCard));
    await tester.pump();
    expect(taps, 1);

    // The subtitle is inside the same InkWell, so it counts as the card too.
    await tester.tap(find.text('Ver proyectos'));
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('la versión rellena usa el color primario y el texto sobre él',
      (tester) async {
    final appTheme = theme();

    await tester.pumpWidget(
      wrapWidget(
        ActionCard(
          icon: Icons.add,
          title: 'Rellena',
          subtitle: 'Primaria',
          filled: true,
          onTap: () {},
        ),
        theme: appTheme,
      ),
    );

    expect(surfaceOf(tester).color, appTheme.colorScheme.primary);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.add)).color,
      appTheme.colorScheme.onPrimary,
    );
  });

  testWidgets('la versión sin rellenar usa la superficie y un borde',
      (tester) async {
    final appTheme = theme();

    await tester.pumpWidget(
      wrapWidget(
        ActionCard(
          icon: Icons.add,
          title: 'Plana',
          subtitle: 'Superficie',
          onTap: () {},
        ),
        theme: appTheme,
      ),
    );

    expect(surfaceOf(tester).color, appTheme.colorScheme.surfaceContainerLow);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.add)).color,
      appTheme.colorScheme.onSurface,
    );

    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(InkWell),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
  });
}
