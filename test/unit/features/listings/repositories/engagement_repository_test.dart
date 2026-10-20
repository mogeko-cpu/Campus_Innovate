import 'package:campus_innovate/features/listings/data/repositories/engagement_repository.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_comment.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_engagement_source.dart';

void main() {
  late InMemoryEngagementSource source;
  late EngagementRepository repository;

  setUp(() {
    source = InMemoryEngagementSource();
    repository = EngagementRepository(source);
  });

  Future<void> react(
    String userId,
    ReactionType reaction, {
    String listingId = 'listing_1',
  }) async {
    final current =
        (await repository.getStatsFor(listingId: listingId, userId: userId))
            .myReaction;

    await repository.toggleReaction(
      listingId: listingId,
      groupId: 'group_1',
      userId: userId,
      reaction: reaction,
      current: current,
    );
  }

  ListingComment comment(String body, {DateTime? at}) => ListingComment.draft(
        listingId: 'listing_1',
        groupId: 'group_1',
        authorId: 'user_1',
        authorName: 'Leonel',
        body: body,
        createdAt: at,
      );

  group('reacciones', () {
    test('un primer toque vota', () async {
      await react('user_1', ReactionType.like);

      final stats =
          await repository.getStatsFor(listingId: 'listing_1', userId: 'user_1');

      expect(stats.likes, 1);
      expect(stats.myReaction, ReactionType.like);
    });

    test('tocar el mismo botón otra vez deshace el voto', () async {
      await react('user_1', ReactionType.like);
      await react('user_1', ReactionType.like);

      final stats =
          await repository.getStatsFor(listingId: 'listing_1', userId: 'user_1');

      expect(stats.likes, 0);
      expect(stats.myReaction, isNull);
    });

    test('tocar el otro botón cambia el voto en vez de sumar dos', () async {
      await react('user_1', ReactionType.like);
      await react('user_1', ReactionType.dislike);

      final stats =
          await repository.getStatsFor(listingId: 'listing_1', userId: 'user_1');

      expect(stats.likes, 0);
      expect(stats.dislikes, 1);
      expect(stats.score, -1);
      expect(stats.myReaction, ReactionType.dislike);
    });

    test('el voto de cada persona cuenta por separado', () async {
      await react('user_1', ReactionType.like);
      await react('user_2', ReactionType.like);
      await react('user_3', ReactionType.dislike);

      final seenBy2 =
          await repository.getStatsFor(listingId: 'listing_1', userId: 'user_2');
      final seenBy4 =
          await repository.getStatsFor(listingId: 'listing_1', userId: 'user_4');

      expect(seenBy2.score, 1);
      expect(seenBy2.myReaction, ReactionType.like);
      expect(seenBy4.myReaction, isNull);
    });
  });

  test('la misma persona abriendo dos veces cuenta una visita', () async {
    for (var i = 0; i < 2; i++) {
      await repository.registerView(
        listingId: 'listing_1',
        groupId: 'group_1',
        userId: 'user_1',
      );
    }
    await repository.registerView(
      listingId: 'listing_1',
      groupId: 'group_1',
      userId: 'user_2',
    );

    final stats =
        await repository.getStatsFor(listingId: 'listing_1', userId: 'user_1');

    expect(stats.views, 2);
  });

  test('getStats trae los contadores de todos los proyectos a la vez', () async {
    await react('user_1', ReactionType.like);
    await react('user_1', ReactionType.dislike, listingId: 'listing_2');

    final all = await repository.getStats(userId: 'user_1');

    expect(all.keys, unorderedEquals(['listing_1', 'listing_2']));
    expect(all['listing_1']?.likes, 1);
    expect(all['listing_2']?.dislikes, 1);
  });

  group('comentarios', () {
    test('un comentario vacío o de solo espacios se rechaza', () {
      expect(
        () => repository.addComment(comment('')),
        throwsA(isA<ListingException>()),
      );
      expect(
        () => repository.addComment(comment('   \n ')),
        throwsA(isA<ListingException>()),
      );
    });

    test('un comentario válido se guarda con id y suma al contador', () async {
      final stored = await repository.addComment(comment('Buena idea'));

      expect(stored.isPersisted, isTrue);

      final stats =
          await repository.getStatsFor(listingId: 'listing_1', userId: 'user_1');
      expect(stats.comments, 1);
    });

    test('se listan del más nuevo al más viejo', () async {
      await repository.addComment(comment('viejo', at: DateTime(2026, 1, 1)));
      await repository.addComment(comment('nuevo', at: DateTime(2026, 2, 1)));

      final comments = await repository.getComments('listing_1');

      expect(comments.map((c) => c.body), ['nuevo', 'viejo']);
    });

    test('borrar un comentario lo quita de la lista', () async {
      final stored = await repository.addComment(comment('borrame'));

      await repository.deleteComment(stored.id);

      expect(await repository.getComments('listing_1'), isEmpty);
    });
  });

  test('purgar un proyecto borra votos, visitas y comentarios solo de él',
      () async {
    await react('user_1', ReactionType.like);
    await react('user_1', ReactionType.like, listingId: 'listing_2');
    await repository.registerView(
      listingId: 'listing_1',
      groupId: 'group_1',
      userId: 'user_1',
    );
    await repository.addComment(comment('hola'));

    await repository.purgeListing('listing_1');

    final purged =
        await repository.getStatsFor(listingId: 'listing_1', userId: 'user_1');
    final other =
        await repository.getStatsFor(listingId: 'listing_2', userId: 'user_1');

    expect(purged.hasActivity, isFalse);
    expect(other.likes, 1);
  });
}
