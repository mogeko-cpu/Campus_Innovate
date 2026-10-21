import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:campus_innovate/features/listings/ui/widgets/status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester, ListingStatus status) =>
      tester.pumpWidget(wrapWidget(StatusChip(status: status)));

  for (final status in ListingStatus.values) {
    testWidgets('"${status.label}" muestra su nombre, su ícono y su color',
        (tester) async {
      await pump(tester, status);

      final style = StatusChip.styleOf(status);

      expect(find.text(status.label), findsOneWidget);
      expect(find.byIcon(style.icon), findsOneWidget);
      expect(tester.widget<Icon>(find.byIcon(style.icon)).color, style.color);
      expect(
        tester.widget<Text>(find.text(status.label)).style?.color,
        style.color,
      );
    });
  }

  test('cada estado tiene un color y un ícono distintos', () {
    final styles = ListingStatus.values.map(StatusChip.styleOf).toList();

    expect(styles.map((s) => s.color).toSet(), hasLength(styles.length));
    expect(styles.map((s) => s.icon).toSet(), hasLength(styles.length));
  });

  testWidgets('el fondo es el color del estado, atenuado', (tester) async {
    await pump(tester, ListingStatus.done);

    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text('Terminado'), matching: find.byType(Container))
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(
      decoration.color,
      StatusChip.styleOf(ListingStatus.done).color.withValues(alpha: 0.14),
    );
  });
}
