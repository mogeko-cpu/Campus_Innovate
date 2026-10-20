import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_stats.dart';
import 'package:campus_innovate/features/listings/domain/models/ranked_listing.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Entry = ({Listing listing, ListingStats stats});

void main() {
  Entry entry(
    String title, {
    int likes = 0,
    int dislikes = 0,
    int views = 0,
    int comments = 0,
  }) =>
      (
        listing: Listing(
          id: title,
          title: title,
          description: '',
          category: 'Tecnología',
          creatorId: 'u',
          creatorName: 'n',
          maxMembers: 3,
          requiredSkills: const [],
          memberIds: const ['u'],
        ),
        stats: ListingStats(
          likes: likes,
          dislikes: dislikes,
          views: views,
          comments: comments,
        ),
      );

  List<String> rank(List<Entry> entries) =>
      ([...entries]..sort(RankedListing.compare))
          .map((e) => e.listing.title)
          .toList();

  test('el puntaje más alto va primero', () {
    expect(
      rank([
        entry('B', likes: 1),
        entry('A', likes: 5, dislikes: 1),
        entry('C', likes: 2, dislikes: 5),
      ]),
      ['A', 'B', 'C'],
    );
  });

  test('a igual puntaje gana el que tiene más comentarios', () {
    expect(
      rank([
        entry('Visto', likes: 2, views: 100),
        entry('Comentado', likes: 2, comments: 1),
      ]),
      ['Comentado', 'Visto'],
    );
  });

  test('a igual puntaje y comentarios gana el más visto', () {
    expect(
      rank([
        entry('Poco', likes: 1, comments: 2, views: 3),
        entry('Mucho', likes: 1, comments: 2, views: 9),
      ]),
      ['Mucho', 'Poco'],
    );
  });

  test('sin actividad desempata el título, sin importar mayúsculas', () {
    expect(
      rank([entry('zeta'), entry('Beta'), entry('alfa')]),
      ['alfa', 'Beta', 'zeta'],
    );
  });

  test('el orden es estable entre recargas', () {
    final entries = [entry('c'), entry('a', views: 1), entry('b')];

    expect(rank(entries), rank(entries.reversed.toList()));
  });

  test('un dislike pesa lo mismo que un like en contra', () {
    // Score is likes minus dislikes, so 3-3 ties with 0-0 and falls to views.
    expect(
      rank([entry('Polémico', likes: 3, dislikes: 3), entry('Visto', views: 1)]),
      ['Visto', 'Polémico'],
    );
  });

  test('conserva posición, proyecto y estadísticas', () {
    final e = entry('A', likes: 2);
    final ranked = RankedListing(position: 1, listing: e.listing, stats: e.stats);

    expect(ranked.position, 1);
    expect(ranked.listing.title, 'A');
    expect(ranked.stats.score, 2);
  });
}
