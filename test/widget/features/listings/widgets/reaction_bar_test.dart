import 'package:campus_innovate/features/listings/domain/models/listing_stats.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:campus_innovate/features/listings/ui/widgets/reaction_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  /// The like or dislike button, whichever of its two icons it is showing.
  /// Matched by [ButtonStyleButton] because the selected one is a
  /// `FilledButton.tonalIcon`, a private subclass `find.byType` would miss.
  Finder vote(IconData icon) => find.ancestor(
        of: find.byIcon(icon),
        matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
      );

  Future<void> pump(
    WidgetTester tester,
    ListingStats stats, {
    ValueChanged<ReactionType>? onReact,
    bool isBusy = false,
  }) async {
    await tester.pumpWidget(
      wrapWidget(
        ReactionBar(
          stats: stats,
          isBusy: isBusy,
          onReact: onReact ?? (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra los contadores de votos, vistas y comentarios',
      (tester) async {
    await pump(
      tester,
      const ListingStats(likes: 4, dislikes: 1, views: 10, comments: 3),
    );

    expect(
      find.descendant(of: vote(Icons.thumb_up_outlined), matching: find.text('4')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: vote(Icons.thumb_down_outlined),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text('10 vistas'), findsOneWidget);
    expect(find.text('3 comentarios'), findsOneWidget);
  });

  testWidgets('una vista y un comentario van en singular', (tester) async {
    await pump(tester, const ListingStats(views: 1, comments: 1));

    expect(find.text('1 vista'), findsOneWidget);
    expect(find.text('1 comentario'), findsOneWidget);
  });

  testWidgets('cada botón avisa su reacción', (tester) async {
    final received = <ReactionType>[];

    await pump(tester, ListingStats.empty, onReact: received.add);

    await tester.tap(vote(Icons.thumb_up_outlined));
    await tester.tap(vote(Icons.thumb_down_outlined));

    expect(received, [ReactionType.like, ReactionType.dislike]);
  });

  testWidgets('el voto propio se rellena y el otro queda delineado',
      (tester) async {
    await pump(
      tester,
      const ListingStats(likes: 1, myReaction: ReactionType.like),
    );

    expect(find.byIcon(Icons.thumb_up), findsOneWidget);
    expect(find.byIcon(Icons.thumb_up_outlined), findsNothing);
    expect(tester.widget(vote(Icons.thumb_up)), isA<FilledButton>());
    expect(
      tester.widget(vote(Icons.thumb_down_outlined)),
      isA<OutlinedButton>(),
    );
  });

  testWidgets('ya votado, ambos botones siguen habilitados para deshacer',
      (tester) async {
    final received = <ReactionType>[];

    await pump(
      tester,
      const ListingStats(dislikes: 1, myReaction: ReactionType.dislike),
      onReact: received.add,
    );

    await tester.tap(vote(Icons.thumb_down));
    expect(received, [ReactionType.dislike]);
    expect(
      tester.widget<ButtonStyleButton>(vote(Icons.thumb_up_outlined)).enabled,
      isTrue,
    );
  });

  testWidgets('mientras se escribe un voto, los botones se deshabilitan',
      (tester) async {
    final received = <ReactionType>[];

    await pump(
      tester,
      const ListingStats(likes: 2),
      isBusy: true,
      onReact: received.add,
    );

    expect(
      tester.widget<ButtonStyleButton>(vote(Icons.thumb_up_outlined)).enabled,
      isFalse,
    );
    expect(
      tester.widget<ButtonStyleButton>(vote(Icons.thumb_down_outlined)).enabled,
      isFalse,
    );

    await tester.tap(vote(Icons.thumb_up_outlined), warnIfMissed: false);
    expect(received, isEmpty);
  });

  testWidgets('al cambiar el contador, el número nuevo reemplaza al viejo',
      (tester) async {
    await pump(tester, const ListingStats(likes: 2));

    await pump(
      tester,
      const ListingStats(likes: 3, myReaction: ReactionType.like),
    );

    expect(
      find.descendant(of: vote(Icons.thumb_up), matching: find.text('3')),
      findsOneWidget,
    );
    expect(find.text('2'), findsNothing);
  });

  testWidgets('el botón rebota al quedar seleccionado y vuelve a su tamaño',
      (tester) async {
    await pump(tester, const ListingStats(likes: 0));

    await tester.pumpWidget(
      wrapWidget(
        ReactionBar(
          stats: const ListingStats(likes: 1, myReaction: ReactionType.like),
          onReact: (_) {},
        ),
      ),
    );

    ScaleTransition scaleOf() => tester.widget<ScaleTransition>(
          find.ancestor(
            of: vote(Icons.thumb_up),
            matching: find.byType(ScaleTransition),
          ).first,
        );

    // Halfway through the 260 ms bounce the button is bigger than at rest.
    await tester.pump(const Duration(milliseconds: 110));
    expect(scaleOf().scale.value, greaterThan(1.0));

    await tester.pumpAndSettle();
    expect(scaleOf().scale.value, 1.0);
  });
}
