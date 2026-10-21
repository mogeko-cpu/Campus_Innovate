import 'package:campus_innovate/core/category_style.dart';
import 'package:campus_innovate/features/listings/ui/widgets/category_choice_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  Future<void> pump(
    WidgetTester tester, {
    String category = 'Sostenibilidad',
    bool selected = false,
    VoidCallback? onSelected,
  }) =>
      tester.pumpWidget(
        wrapWidget(
          CategoryChoiceChip(
            category: category,
            selected: selected,
            onSelected: onSelected ?? () {},
          ),
        ),
      );

  ChoiceChip chip(WidgetTester tester) =>
      tester.widget<ChoiceChip>(find.byType(ChoiceChip));

  testWidgets('sin elegir muestra la categoría con el ícono en su color',
      (tester) async {
    await pump(tester);

    expect(find.text('Sostenibilidad'), findsOneWidget);
    expect(chip(tester).selected, isFalse);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.eco_outlined)).color,
      const Color(0xFF1E9E6B),
    );
  });

  testWidgets('elegida se pinta del color de la categoría con ícono blanco',
      (tester) async {
    await pump(tester, selected: true);

    expect(chip(tester).selected, isTrue);
    expect(chip(tester).selectedColor, const Color(0xFF1E9E6B));
    expect(chip(tester).labelStyle?.fontWeight, FontWeight.w700);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.eco_outlined)).color,
      Colors.white,
    );
  });

  testWidgets('tocarla avisa, esté o no elegida', (tester) async {
    var taps = 0;

    await pump(tester, onSelected: () => taps++);
    await tester.tap(find.text('Sostenibilidad'));
    await tester.pump();

    await pump(tester, selected: true, onSelected: () => taps++);
    await tester.tap(find.text('Sostenibilidad'));
    await tester.pump();

    expect(taps, 2);
  });

  testWidgets('una categoría desconocida usa el color primario del tema',
      (tester) async {
    await pump(tester, category: 'Deportes');

    final context = tester.element(find.byType(CategoryChoiceChip));
    final icon = tester.widget<Icon>(find.byIcon(Icons.lightbulb_outline));

    expect(find.text('Deportes'), findsOneWidget);
    expect(icon.color, CategoryStyle.of(context, 'Deportes').color);
    expect(icon.color, Theme.of(context).colorScheme.primary);
  });
}
