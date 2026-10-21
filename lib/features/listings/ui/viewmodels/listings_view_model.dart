import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_stats.dart';
import '../../domain/models/listing_status.dart';
import '../../domain/repositories/i_engagement_repository.dart';
import '../../domain/repositories/i_listing_repository.dart';

class ListingsViewModel extends GetxController {
  final IListingRepository _repository;
  final IEngagementRepository _engagement;
  final ISessionService _session;

  ListingsViewModel(this._repository, this._engagement, this._session);

  final RxList<Listing> _all = <Listing>[].obs;

  /// Counters by project id, so the cards show them without a read each.
  final RxMap<String, ListingStats> stats = <String, ListingStats>{}.obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();
  final RxnString selectedCategory = RxnString();

  /// Null for every state.
  final Rxn<ListingStatus> selectedStatus = Rxn<ListingStatus>();
  final RxString query = ''.obs;

  List<Listing> get listings {
    final category = selectedCategory.value;
    final status = selectedStatus.value;
    final text = query.value.trim().toLowerCase();

    return _all.where((listing) {
      final matchesCategory = category == null || listing.category == category;
      final matchesStatus = status == null || listing.status == status;
      final matchesText = text.isEmpty ||
          listing.title.toLowerCase().contains(text) ||
          listing.description.toLowerCase().contains(text);

      return matchesCategory && matchesStatus && matchesText;
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      _all.assignAll(await _repository.getListings());
      stats.assignAll(
        await _engagement.getStats(userId: _session.currentUserId),
      );
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudieron cargar los proyectos',
      );
    } finally {
      isLoading.value = false;
    }
  }

  void filterByCategory(String? category) => selectedCategory.value = category;

  void filterByStatus(ListingStatus? status) => selectedStatus.value = status;

  void search(String text) => query.value = text;

  bool isMember(Listing listing) =>
      listing.memberIds.contains(_session.currentUserId);

  ListingStats statsOf(Listing listing) =>
      stats[listing.id] ?? ListingStats.empty;
}
