import 'package:campus_innovate/core/app_theme.dart';
import 'package:campus_innovate/features/shell/ui/widgets/panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/app_tester.dart';

void main() {
  testWidgets('muestra el título con su ícono, lo de la derecha y el contenido',
      (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const Panel(
          title: 'Equipo',
          icon: Icons.groups_outlined,
          trailing: Text('3'),
          child: Text('Contenido'),
        ),
      ),
    );

    expect(find.text('Equipo'), findsOneWidget);
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Contenido'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Equipo')).dy,
      lessThan(tester.getTopLeft(find.text('Contenido')).dy),
    );
  });

  testWidgets('sin título es solo la superficie con su contenido',
      (tester) async {
    await tester.pumpWidget(wrapWidget(const Panel(child: Text('Solo esto'))));

    expect(find.text('Solo esto'), findsOneWidget);
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('la superficie es más clara que la página y lleva sombra',
      (tester) async {
    final theme = AppTheme.light;

    await tester.pumpWidget(
      wrapWidget(const Panel(child: Text('x')), theme: theme),
    );

    final decoration = tester
        .widget<Container>(
          find.descendant(
            of: find.byType(Panel),
            matching: find.byType(Container),
          ).first,
        )
        .decoration! as BoxDecoration;

    expect(decoration.color, theme.colorScheme.surfaceContainerLowest);
    expect(decoration.color, isNot(theme.scaffoldBackgroundColor));
    expect(decoration.boxShadow, isNotEmpty);
  });

  testWidgets('un texto largo a la derecha cede en vez de desbordar',
      (tester) async {
    tester.view.physicalSize = const Size(300, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrapWidget(
        const Panel(
          title: 'Carpeta del equipo',
          icon: Icons.folder_outlined,
          trailing: Text('12 archivos y 30 enlaces compartidos'),
          child: SizedBox(),
        ),
      ),
    );

    // An overflow would have failed the test while laying out.
    expect(find.byType(Panel), findsOneWidget);
  });
}
