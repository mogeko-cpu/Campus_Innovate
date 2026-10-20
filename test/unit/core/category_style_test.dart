import 'package:campus_innovate/core/category_style.dart' as core;
import 'package:campus_innovate/core/ui/category_style.dart' as ui;
import 'package:campus_innovate/features/listings/domain/models/listing_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Both lookups need a [BuildContext] for the fallback color, so each test
/// pumps a themed app and reads the context from it.
void main() {
  const primary = Color(0xFF123456);

  Future<BuildContext> contextWithPrimary(WidgetTester tester) async {
    late BuildContext captured;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(
            primary: primary,
          ),
        ),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );

    return captured;
  }

  group('CategoryStyle (core)', () {
    testWidgets('cada categoría conocida tiene su propio color e ícono',
        (tester) async {
      final context = await contextWithPrimary(tester);

      final styles =
          listingCategories.map((c) => core.CategoryStyle.of(context, c));

      expect(styles.map((s) => s.color).toSet(), hasLength(6));
      expect(styles.map((s) => s.icon).toSet(), hasLength(6));
      expect(styles.map((s) => s.color), isNot(contains(primary)));
    });

    testWidgets('asigna los íconos esperados', (tester) async {
      final context = await contextWithPrimary(tester);

      expect(
        core.CategoryStyle.of(context, 'Tecnología').icon,
        Icons.memory_outlined,
      );
      expect(
        core.CategoryStyle.of(context, 'Sostenibilidad').icon,
        Icons.eco_outlined,
      );
    });

    testWidgets(
        'una categoría desconocida usa el primario del tema y un ícono genérico',
        (tester) async {
      final context = await contextWithPrimary(tester);

      final style = core.CategoryStyle.of(context, 'Gastronomía');

      expect(style.color, primary);
      expect(style.icon, Icons.lightbulb_outline);
    });

    testWidgets('distingue mayúsculas y tildes', (tester) async {
      final context = await contextWithPrimary(tester);

      // The lookup is exact: a hand-typed variant gets the fallback, not a crash.
      expect(core.CategoryStyle.of(context, 'tecnologia').color, primary);
    });
  });

  group('CategoryStyle (ui)', () {
    testWidgets('cada categoría conocida tiene su propio color e ícono',
        (tester) async {
      final context = await contextWithPrimary(tester);

      final styles =
          listingCategories.map((c) => ui.CategoryStyle.of(context, c));

      expect(styles.map((s) => s.color).toSet(), hasLength(6));
      expect(styles.map((s) => s.icon).toSet(), hasLength(6));
    });

    testWidgets('una categoría desconocida usa el primario y una carpeta',
        (tester) async {
      final context = await contextWithPrimary(tester);

      final style = ui.CategoryStyle.of(context, '');

      expect(style.color, primary);
      expect(style.icon, Icons.folder_outlined);
    });
  });
}
