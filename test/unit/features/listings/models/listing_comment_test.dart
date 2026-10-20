import 'package:campus_innovate/features/listings/domain/models/listing_comment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un borrador no tiene id y queda fechado ahora', () {
    final before = DateTime.now();
    final draft = ListingComment.draft(
      listingId: 'listing_1',
      groupId: 'group_1',
      authorId: 'user_1',
      authorName: 'Leonel',
      body: 'Buena idea',
    );
    final after = DateTime.now();

    expect(draft.id, isEmpty);
    expect(draft.isPersisted, isFalse);
    expect(draft.createdAt.isBefore(before), isFalse);
    expect(draft.createdAt.isAfter(after), isFalse);
  });

  test('un borrador respeta la fecha que se le pasa', () {
    final date = DateTime(2026, 3, 1, 10);
    final draft = ListingComment.draft(
      listingId: 'l',
      groupId: 'g',
      authorId: 'a',
      authorName: 'n',
      body: 'b',
      createdAt: date,
    );

    expect(draft.createdAt, date);
  });

  test('copyWith con id lo guarda y conserva el resto', () {
    final date = DateTime(2026, 3, 1);
    final stored = ListingComment.draft(
      listingId: 'l',
      groupId: 'g',
      authorId: 'a',
      authorName: 'n',
      body: 'b',
      createdAt: date,
    ).copyWith(id: 'comment_1');

    expect(stored.isPersisted, isTrue);
    expect(stored.listingId, 'l');
    expect(stored.groupId, 'g');
    expect(stored.authorId, 'a');
    expect(stored.authorName, 'n');
    expect(stored.body, 'b');
    expect(stored.createdAt, date);
  });

  test('copyWith puede cambiar el texto y la fecha', () {
    final original = ListingComment(
      id: 'c',
      listingId: 'l',
      groupId: 'g',
      authorId: 'a',
      authorName: 'n',
      body: 'viejo',
      createdAt: DateTime(2026),
    );
    final copy = original.copyWith(body: 'nuevo', createdAt: DateTime(2027));

    expect(copy.body, 'nuevo');
    expect(copy.createdAt, DateTime(2027));
    expect(copy.id, 'c');
  });
}
