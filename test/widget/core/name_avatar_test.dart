import 'package:campus_innovate/core/avatar_color.dart';
import 'package:campus_innovate/core/widgets/name_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('dos palabras o más muestran la inicial del primero y del último',
      (tester) async {
    await tester.pumpWidget(wrapWidget(const NameAvatar(name: 'Ana María Pérez')));

    expect(find.text('AP'), findsOneWidget);
  });

  testWidgets('un nombre de una sola palabra muestra una letra en mayúscula',
      (tester) async {
    await tester.pumpWidget(wrapWidget(const NameAvatar(name: 'mariana')));

    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('un nombre vacío o de espacios muestra un signo de pregunta',
      (tester) async {
    await tester.pumpWidget(wrapWidget(const NameAvatar(name: '   ')));

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('usa el radio por defecto y escala la letra con él',
      (tester) async {
    await tester.pumpWidget(wrapWidget(const NameAvatar(name: 'Leonel Triana')));

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final initials = tester.widget<Text>(find.text('LT'));

    expect(avatar.radius, 15);
    expect(initials.style?.fontSize, closeTo(15 * 0.62, 0.001));
  });

  testWidgets('respeta el radio pedido', (tester) async {
    await tester.pumpWidget(
      wrapWidget(const NameAvatar(name: 'Leonel Triana', radius: 30)),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final initials = tester.widget<Text>(find.text('LT'));

    expect(avatar.radius, 30);
    expect(initials.style?.fontSize, closeTo(30 * 0.62, 0.001));
    expect(tester.getSize(find.byType(CircleAvatar)), const Size(60, 60));
  });

  testWidgets('el color sale del nombre, igual en cada aparición',
      (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const Column(
          children: [
            NameAvatar(name: 'Leonel Triana'),
            NameAvatar(name: 'Leonel Triana'),
          ],
        ),
      ),
    );

    final expected = AvatarColor.of('Leonel Triana');
    final texts = tester.widgetList<Text>(find.text('LT')).toList();

    expect(texts, hasLength(2));
    for (final text in texts) {
      expect(text.style?.color, expected);
    }
  });
}
