import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../listings/domain/models/listing.dart';
import '../../../listings/domain/models/listing_stats.dart';
import '../../../listings/domain/repositories/i_engagement_repository.dart';
import '../../../listings/domain/repositories/i_listing_repository.dart';

class HomeViewModel extends GetxController {
  final IListingRepository _repository;
  final IEngagementRepository _engagement;
  final ISessionService _session;

  HomeViewModel(this._repository, this._engagement, this._session);

  final RxList<Listing> featuredListings = <Listing>[].obs;
  final RxList<Listing> myListings = <Listing>[].obs;

  /// Counters by project id, so a card can show them without a read of its own.
  final RxMap<String, ListingStats> stats = <String, ListingStats>{}.obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();

  /// Empty counters for a project nobody has touched yet, which is why this
  /// never returns null: a card with no stats and a card with zeros look the
  /// same, and one of the two is a special case the widget would have to know
  /// about.
  ListingStats statsOf(Listing listing) =>
      stats[listing.id] ?? ListingStats.empty;

  String get userName => _session.currentUserName;

  String get firstName => userName.split(' ').first;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final featured = await _repository.getFeaturedListings();
      final mine = await _repository.getJoinedListings(_session.currentUserId);
      final counters = await _engagement.getStats(
        userId: _session.currentUserId,
      );

      featuredListings.assignAll(featured);
      myListings.assignAll(mine);
      stats.assignAll(counters);
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudieron cargar las ideas',
      );
    } finally {
      isLoading.value = false;
    }
  }
}
