import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_comment.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_stats.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/ranking_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_listing_source.dart';
import '../../view_model_harness.dart';

class _FailingListingSource extends InMemoryListingSource {
  @override
  Future<List<Listing>> getListings() async => throw StateError('listings');
}

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  Future<RankingViewModel> open() => start(
        RankingViewModel(harness.listings, harness.engagement, harness.session),
      );

  List<String> order(RankingViewModel viewModel) =>
      viewModel.ranking.map((entry) => entry.listing.id).toList();

  Future<void> react(String listingId, String userId, ReactionType reaction) =>
      harness.engagementSource.setReaction(
        listingId: listingId,
        groupId: '',
        userId: userId,
        reaction: reaction,
      );

  setUp(() => harness = ViewModelHarness());

  test('ordena por puntaje, likes menos dislikes', () async {
    await react('listing_3', 'user_6', ReactionType.like);
    await react('listing_3', 'user_7', ReactionType.like);
    await react('listing_1', 'user_6', ReactionType.dislike);
    await react('listing_2', 'user_6', ReactionType.like);
    await react('listing_2', 'user_7', ReactionType.dislike);

    final viewModel = await open();

    expect(order(viewModel), ['listing_3', 'listing_2', 'listing_1']);
    expect(viewModel.ranking.map((entry) => entry.position), [1, 2, 3]);
    expect(viewModel.ranking.first.stats.score, 2);
    expect(viewModel.isLoading.value, isFalse);
  });

  test('a igual puntaje gana el más comentado y luego el más visto', () async {
    await harness.engagementSource.addComment(
      ListingComment.draft(
        listingId: 'listing_3',
        groupId: '',
        authorId: 'user_6',
        authorName: 'Alguien',
        body: 'Comentario',
      ),
    );
    await harness.engagementSource.registerView(
      listingId: 'listing_2',
      groupId: '',
      userId: 'user_6',
    );

    final viewModel = await open();

    expect(order(viewModel), ['listing_3', 'listing_2', 'listing_1']);
  });

  test('sin actividad desempata por título sin distinguir mayúsculas',
      () async {
    final lowercase = await harness.listingSource.createListing(
      const Listing(
        id: '',
        title: 'aula abierta',
        description: 'Clases al aire libre',
        category: 'Arte y Cultura',
        creatorId: 'user_6',
        creatorName: 'Alguien',
        maxMembers: 4,
        requiredSkills: [],
        memberIds: ['user_6'],
      ),
    );

    final viewModel = await open();

    // "aula" sorts before "Campus" only when case is ignored.
    expect(order(viewModel), [
      lowercase.id,
      'listing_1',
      'listing_2',
      'listing_3',
    ]);
  });

  test('react recarga y mueve el proyecto a su nuevo lugar', () async {
    final viewModel = await open();
    expect(order(viewModel).first, 'listing_1');

    await viewModel.react('listing_3', ReactionType.like);

    expect(order(viewModel).first, 'listing_3');
    expect(viewModel.ranking.first.stats.myReaction, ReactionType.like);
    expect(viewModel.statsOf(viewModel.ranking.first.listing).likes, 1);
  });

  test('react sobre el mismo voto lo retira', () async {
    final viewModel = await open();
    await viewModel.react('listing_3', ReactionType.like);

    await viewModel.react('listing_3', ReactionType.like);

    final robotics = viewModel.ranking.firstWhere(
      (entry) => entry.listing.id == 'listing_3',
    );
    expect(robotics.stats.likes, 0);
    expect(robotics.stats.myReaction, isNull);
  });

  test('react sobre un proyecto que no está en el ranking no hace nada',
      () async {
    final viewModel = await open();

    await viewModel.react('ghost', ReactionType.like);

    expect(viewModel.error.value, isNull);
    expect(
      viewModel.ranking.every((entry) => entry.stats.likes == 0),
      isTrue,
    );
  });

  test('statsOf de un proyecto ajeno al ranking da ceros', () async {
    final viewModel = await open();

    final outsider = viewModel.ranking.first.listing.copyWith(id: 'ghost');

    expect(viewModel.statsOf(outsider), same(ListingStats.empty));
  });

  test('un fallo al cargar muestra el mensaje de respaldo', () async {
    harness = ViewModelHarness(listingSource: _FailingListingSource());

    final viewModel = await open();

    expect(viewModel.error.value, 'No se pudo cargar el ranking');
    expect(viewModel.ranking, isEmpty);
    expect(viewModel.isLoading.value, isFalse);
  });
}
