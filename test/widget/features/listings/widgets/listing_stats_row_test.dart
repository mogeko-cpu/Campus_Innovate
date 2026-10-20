import 'package:campus_innovate/features/listings/domain/models/listing_stats.dart';
import 'package:campus_innovate/features/listings/ui/widgets/listing_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  /// The number shown next to [icon].
  String counterNextTo(WidgetTester tester, IconData icon) {
    final row = find.ancestor(
      of: find.byIcon(icon),
      matching: find.byType(Row),
    ).first;

    return tester
        .widget<Text>(find.descendant(of: row, matching: find.byType(Text)))
        .data!;
  }

  testWidgets('cada contador va junto a su ícono', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        const ListingStatsRow(
          stats: ListingStats(likes: 5, dislikes: 2, views: 40, comments: 9),
        ),
      ),
    );

    expect(counterNextTo(tester, Icons.thumb_up_outlined), '5');
    expect(counterNextTo(tester, Icons.thumb_down_outlined), '2');
    expect(counterNextTo(tester, Icons.visibility_outlined), '40');
    expect(counterNextTo(tester, Icons.mode_comment_outlined), '9');
  });

  testWidgets('los ceros se muestran en vez de ocultarse', (tester) async {
    await tester.pumpWidget(
      wrapWidget(const ListingStatsRow(stats: ListingStats.empty)),
    );

    expect(find.text('0'), findsNWidgets(4));
    expect(find.byType(Icon), findsNWidgets(4));
  });

  testWidgets('los me gusta van en el color primario y el resto en el neutro',
      (tester) async {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    );

    await tester.pumpWidget(
      wrapWidget(
        const ListingStatsRow(stats: ListingStats(likes: 1)),
        theme: theme,
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.thumb_up_outlined)).color,
      theme.colorScheme.primary,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.thumb_down_outlined)).color,
      theme.colorScheme.outline,
    );
  });
}
