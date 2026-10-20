import 'package:campus_innovate/features/listings/domain/models/listing_stats.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty no tiene actividad ni voto propio', () {
    expect(ListingStats.empty.likes, 0);
    expect(ListingStats.empty.score, 0);
    expect(ListingStats.empty.hasActivity, isFalse);
    expect(ListingStats.empty.myReaction, isNull);
  });

  test('el puntaje es likes menos dislikes y puede ser negativo', () {
    expect(const ListingStats(likes: 5, dislikes: 2).score, 3);
    expect(const ListingStats(likes: 1, dislikes: 4).score, -3);
  });

  test('cualquier contador basta para que haya actividad', () {
    expect(const ListingStats(likes: 1).hasActivity, isTrue);
    expect(const ListingStats(dislikes: 1).hasActivity, isTrue);
    expect(const ListingStats(views: 1).hasActivity, isTrue);
    expect(const ListingStats(comments: 1).hasActivity, isTrue);
  });

  test('el voto propio solo no cuenta como actividad', () {
    expect(
      const ListingStats(myReaction: ReactionType.like).hasActivity,
      isFalse,
    );
  });

  group('copyWith', () {
    const stats = ListingStats(
      likes: 3,
      dislikes: 1,
      views: 10,
      comments: 2,
      myReaction: ReactionType.like,
    );

    test('conserva lo que no se cambia', () {
      final copy = stats.copyWith(views: 11);

      expect(copy.views, 11);
      expect(copy.likes, 3);
      expect(copy.dislikes, 1);
      expect(copy.comments, 2);
      expect(copy.myReaction, ReactionType.like);
    });

    test('pasar null no borra el voto: hace falta clearMyReaction', () {
      expect(stats.copyWith(myReaction: null).myReaction, ReactionType.like);
      expect(stats.copyWith(clearMyReaction: true).myReaction, isNull);
    });

    test('clearMyReaction gana aunque también se pase un voto', () {
      final copy = stats.copyWith(
        myReaction: ReactionType.dislike,
        clearMyReaction: true,
      );

      expect(copy.myReaction, isNull);
    });

    test('puede cambiar el voto', () {
      expect(
        stats.copyWith(myReaction: ReactionType.dislike).myReaction,
        ReactionType.dislike,
      );
    });
  });
}
