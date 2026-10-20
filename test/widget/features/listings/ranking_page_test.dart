import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_comment.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:campus_innovate/features/listings/ui/views/listing_detail_page.dart';
import 'package:campus_innovate/features/listings/ui/views/ranking_page.dart';
import 'package:campus_innovate/features/listings/ui/widgets/listing_card.dart';
import 'package:campus_innovate/features/shell/ui/widgets/gradient_header.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_engagement_source.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/test_bindings.dart';

/// A campus where nobody has published anything yet.
class _EmptyListingSource extends InMemoryListingSource {
  @override
  Future<List<Listing>> getListings() async => const [];
}

/// The catalogue is unreachable, as when ROBLE is down.
class _FailingListingSource extends InMemoryListingSource {
  @override
  Future<List<Listing>> getListings() async =>
      throw const ListingException('Sin conexión con el servidor.');
}

void main() {
  tearDown(Get.reset);

  /// The titles in the order the ranking shows them.
  List<String> order(WidgetTester tester) => tester
      .widgetList<ListingCard>(find.byType(ListingCard))
      .map((card) => card.listing.title)
      .toList();

  /// The position badge of the card titled [title]: the text of its leading
  /// widget.
  String positionOf(WidgetTester tester, String title) {
    final card = tester.widget<ListingCard>(
      find.widgetWithText(ListingCard, title),
    );

    return tester
        .widget<Text>(
          find.descendant(
            of: find.byWidget(card.leading!),
            matching: find.byType(Text),
          ),
        )
        .data!;
  }

  Future<void> vote(
    InMemoryEngagementSource engagement,
    String listingId,
    String userId,
    ReactionType reaction,
  ) =>
      engagement.setReaction(
        listingId: listingId,
        groupId: '',
        userId: userId,
        reaction: reaction,
      );

  Finder headerText(String text) => find.descendant(
        of: find.byType(GradientHeader),
        matching: find.text(text),
      );

  testWidgets('sin actividad el orden es alfabético y numerado desde 1',
      (tester) async {
    await tester.pumpApp(route: AppRoutes.ranking);

    expect(order(tester), [
      'Campus App',
      'Huerta Universitaria',
      'Semillero de Robótica',
    ]);
    expect(positionOf(tester, 'Campus App'), '1');
    expect(positionOf(tester, 'Huerta Universitaria'), '2');
    expect(positionOf(tester, 'Semillero de Robótica'), '3');
  });

  testWidgets('el encabezado cuenta proyectos y me gusta totales',
      (tester) async {
    final engagement = InMemoryEngagementSource();
    await vote(engagement, 'listing_3', 'user_2', ReactionType.like);
    await vote(engagement, 'listing_3', 'user_3', ReactionType.like);
    // A dislike does not count as a like.
    await vote(engagement, 'listing_2', 'user_2', ReactionType.dislike);

    await tester.pumpApp(
      route: AppRoutes.ranking,
      bindings: TestBindings(engagementSource: engagement),
    );

    expect(headerText('Ranking del campus'), findsOneWidget);
    expect(headerText('3'), findsOneWidget);
    expect(headerText('proyectos'), findsOneWidget);
    expect(headerText('2'), findsOneWidget);
    expect(headerText('me gusta en total'), findsOneWidget);
    // Projects first, then likes.
    expect(
      tester.getTopLeft(headerText('3')).dx,
      lessThan(tester.getTopLeft(headerText('2')).dx),
    );
  });

  testWidgets('con un solo proyecto el encabezado dice "proyecto"',
      (tester) async {
    await tester.pumpApp(
      route: AppRoutes.ranking,
      bindings: TestBindings(source: _SingleListingSource()),
    );

    expect(headerText('1'), findsOneWidget);
    expect(headerText('proyecto'), findsOneWidget);
  });

  testWidgets('ordena por me gusta menos no me gusta', (tester) async {
    final engagement = InMemoryEngagementSource();
    // Robótica +2, Huerta 0 (one each), Campus App -1.
    await vote(engagement, 'listing_3', 'user_2', ReactionType.like);
    await vote(engagement, 'listing_3', 'user_3', ReactionType.like);
    await vote(engagement, 'listing_2', 'user_2', ReactionType.like);
    await vote(engagement, 'listing_2', 'user_5', ReactionType.dislike);
    await vote(engagement, 'listing_1', 'user_3', ReactionType.dislike);

    await tester.pumpApp(
      route: AppRoutes.ranking,
      bindings: TestBindings(engagementSource: engagement),
    );

    expect(order(tester), [
      'Semillero de Robótica',
      'Huerta Universitaria',
      'Campus App',
    ]);
    expect(positionOf(tester, 'Semillero de Robótica'), '1');
    expect(positionOf(tester, 'Campus App'), '3');
    expect(headerText('3'), findsNWidgets(2)); // projects and total likes
  });

  testWidgets('a igual puntaje desempatan los comentarios y luego las vistas',
      (tester) async {
    final engagement = InMemoryEngagementSource();
    await engagement.registerView(
      listingId: 'listing_2',
      groupId: '',
      userId: 'user_9',
    );
    await engagement.addComment(
      ListingComment(
        id: '',
        listingId: 'listing_3',
        groupId: '',
        authorId: 'user_9',
        authorName: 'Alguien',
        body: 'Me encanta.',
        createdAt: DateTime(2026, 3, 1),
      ),
    );

    await tester.pumpApp(
      route: AppRoutes.ranking,
      bindings: TestBindings(engagementSource: engagement),
    );

    expect(order(tester), [
      'Semillero de Robótica', // a comment
      'Huerta Universitaria', // a view
      'Campus App', // nothing
    ]);
  });

  testWidgets('votar en el detalle reordena el ranking al volver',
      (tester) async {
    await tester.pumpApp(route: AppRoutes.ranking);
    expect(order(tester).last, 'Semillero de Robótica');

    await tester.tapText('Semillero de Robótica');
    expect(find.byType(ListingDetailPage), findsOneWidget);

    await tester.tapVisible(
      find.ancestor(
        of: find.byIcon(Icons.thumb_up_outlined),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.byType(RankingPage), findsOneWidget);
    expect(order(tester).first, 'Semillero de Robótica');
    expect(positionOf(tester, 'Semillero de Robótica'), '1');
    expect(positionOf(tester, 'Campus App'), '2');
    expect(headerText('1'), findsOneWidget); // total likes
  });

  testWidgets('sin proyectos muestra el estado vacío', (tester) async {
    await tester.pumpApp(
      route: AppRoutes.ranking,
      bindings: TestBindings(source: _EmptyListingSource()),
    );

    expect(find.text('Todavía no hay proyectos publicados'), findsOneWidget);
    expect(find.byType(GradientHeader), findsNothing);
    expect(find.byType(ListingCard), findsNothing);
  });

  testWidgets('si falla la carga lo dice con el motivo', (tester) async {
    await tester.pumpApp(
      route: AppRoutes.ranking,
      bindings: TestBindings(source: _FailingListingSource()),
    );

    expect(find.text('No se pudo cargar el ranking'), findsOneWidget);
    expect(find.text('Sin conexión con el servidor.'), findsOneWidget);
  });
}

/// Only the first seeded project, for the singular wording.
class _SingleListingSource extends InMemoryListingSource {
  @override
  Future<List<Listing>> getListings() async =>
      (await super.getListings()).take(1).toList();
}
