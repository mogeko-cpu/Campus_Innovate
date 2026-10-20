import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el like vale 1 y el dislike -1, para que el puntaje sea una suma', () {
    expect(ReactionType.like.value, 1);
    expect(ReactionType.dislike.value, -1);
  });

  test('fromValue convierte la columna value de vuelta', () {
    expect(ReactionType.fromValue(1), ReactionType.like);
    expect(ReactionType.fromValue(-1), ReactionType.dislike);
  });

  test('cualquier otro valor, o ninguno, no es una reacción', () {
    expect(ReactionType.fromValue(null), isNull);
    expect(ReactionType.fromValue(0), isNull);
    expect(ReactionType.fromValue(2), isNull);
    expect(ReactionType.fromValue(-2), isNull);
  });

  test('ida y vuelta para cada reacción', () {
    for (final reaction in ReactionType.values) {
      expect(ReactionType.fromValue(reaction.value), reaction);
    }
  });
}
