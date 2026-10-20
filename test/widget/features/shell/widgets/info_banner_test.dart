import 'package:campus_innovate/features/shell/ui/widgets/info_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  final theme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  );

  testWidgets('muestra el ícono y el texto en una fila', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const InfoBanner(
          icon: Icons.verified_outlined,
          text: 'Este es tu proyecto.',
        ),
      ),
    );

    expect(find.text('Este es tu proyecto.'), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(Icons.verified_outlined)).dx,
      lessThan(tester.getTopLeft(find.text('Este es tu proyecto.')).dx),
    );
  });

  testWidgets('sin tinte el ícono usa el color primario', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const InfoBanner(icon: Icons.schedule, text: 'Pendiente'),
        theme: theme,
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.schedule)).color,
      theme.colorScheme.primary,
    );
  });

  testWidgets('con tinte el ícono toma ese color', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        InfoBanner(
          icon: Icons.error_outline,
          text: 'No se pudieron cargar las solicitudes',
          tint: theme.colorScheme.error,
        ),
        theme: theme,
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.error_outline)).color,
      theme.colorScheme.error,
    );
  });

  testWidgets('un texto largo se ajusta sin desbordar', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        SizedBox(
          width: 220,
          child: InfoBanner(
            icon: Icons.info_outline,
            text: 'Solicitud enviada — estado: Pendiente. ' * 4,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(InfoBanner)).height, greaterThan(60));
  });
}
