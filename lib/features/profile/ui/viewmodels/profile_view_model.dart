import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../groups/domain/models/group.dart';
import '../../../groups/domain/repositories/i_group_repository.dart';
import '../../../listings/domain/models/join_request.dart';
import '../../../listings/domain/models/listing.dart';
import '../../../listings/domain/models/listing_stats.dart';
import '../../../listings/domain/repositories/i_engagement_repository.dart';
import '../../../listings/domain/repositories/i_listing_repository.dart';

/// The user's own corner of the app: who they are, what they run, what they
/// joined and what they are still waiting on.
///
/// It reads from three repositories because that is genuinely what a profile
/// is — a view across features — and none of them has to know about the others
/// for it to work.
class ProfileViewModel extends GetxController {
  final ISessionService _session;
  final IListingRepository _listings;
  final IGroupRepository _groups;
  final IEngagementRepository _engagement;

  ProfileViewModel(
    this._session,
    this._listings,
    this._groups,
    this._engagement,
  );

  final RxList<Listing> myListings = <Listing>[].obs;
  final RxList<Listing> joinedListings = <Listing>[].obs;
  final RxList<Group> myGroups = <Group>[].obs;
  final RxList<JoinRequest> myRequests = <JoinRequest>[].obs;
  final RxInt likesReceived = 0.obs;
  final RxInt viewsReceived = 0.obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();

  String get userId => _session.currentUserId;

  String get userName => _session.currentUserName;

  String get userEmail => _session.currentUserEmail;

  /// Initials for the avatar: two letters at most, so "Ana María Pérez" reads
  /// as "AP" and a single-word name still shows something.
  String get initials {
    final parts = userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  /// Projects the user joined without having created them.
  List<Listing> get participations => joinedListings
      .where((listing) => listing.creatorId != userId)
      .toList();

  /// Requests still waiting on somebody else's decision.
  List<JoinRequest> get pendingRequests =>
      myRequests.where((request) => request.status.name == 'pending').toList();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final mine = await _listings.getMyListings(userId);
      final joined = await _listings.getJoinedListings(userId);
      final groups = await _groups.getMyGroups(userId);
      final requests = await _listings.getMyRequests(userId);
      final stats = await _engagement.getStats(userId: userId);

      myListings.assignAll(mine);
      joinedListings.assignAll(joined);
      myGroups.assignAll(groups);
      myRequests.assignAll(requests);

      // How the campus received what this person published, added up across
      // their own projects only.
      var likes = 0;
      var views = 0;
      for (final listing in mine) {
        final listingStats = stats[listing.id] ?? ListingStats.empty;
        likes += listingStats.likes;
        views += listingStats.views;
      }

      likesReceived.value = likes;
      viewsReceived.value = views;
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo cargar tu perfil',
      );
    } finally {
      isLoading.value = false;
    }
  }
}
