import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_stats.dart';
import '../../domain/models/ranked_listing.dart';
import '../../domain/models/reaction_type.dart';
import '../../domain/repositories/i_engagement_repository.dart';
import '../../domain/repositories/i_listing_repository.dart';

/// The leaderboard: every project ordered by how the campus valued it.
///
/// The order is worked out here and not by the database. ROBLE cannot sort, and
/// it cannot count either, so the counters arrive as three table reads and the
/// ranking is assembled in Dart.
class RankingViewModel extends GetxController {
  final IListingRepository _listings;
  final IEngagementRepository _engagement;
  final ISessionService _session;

  RankingViewModel(this._listings, this._engagement, this._session);

  final RxList<RankedListing> ranking = <RankedListing>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final listings = await _listings.getListings();
      final stats = await _engagement.getStats(
        userId: _session.currentUserId,
      );

      ranking.assignAll(_rank(listings, stats));
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo cargar el ranking',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Applies a tap on like or dislike and puts the project back in its new
  /// place.
  ///
  /// The whole list is reloaded afterwards rather than patched in memory: one
  /// vote can move a project several positions, and a list that reordered itself
  /// halfway would be worse than one that takes a moment.
  Future<void> react(String listingId, ReactionType reaction) async {
    final index = ranking.indexWhere(
      (entry) => entry.listing.id == listingId,
    );
    if (index == -1) return;

    final entry = ranking[index];

    try {
      error.value = null;

      await _engagement.toggleReaction(
        listingId: listingId,
        groupId: entry.listing.groupId,
        userId: _session.currentUserId,
        reaction: reaction,
        current: entry.stats.myReaction,
      );

      await load();
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo registrar tu valoración',
      );
    }
  }

  ListingStats statsOf(Listing listing) {
    final index = ranking.indexWhere(
      (entry) => entry.listing.id == listing.id,
    );

    return index == -1 ? ListingStats.empty : ranking[index].stats;
  }

  List<RankedListing> _rank(
    List<Listing> listings,
    Map<String, ListingStats> stats,
  ) {
    final entries = listings
        .map(
          (listing) => (
            listing: listing,
            stats: stats[listing.id] ?? ListingStats.empty,
          ),
        )
        .toList();

    entries.sort(RankedListing.compare);

    return [
      for (var index = 0; index < entries.length; index++)
        RankedListing(
          position: index + 1,
          listing: entries[index].listing,
          stats: entries[index].stats,
        ),
    ];
  }
}
