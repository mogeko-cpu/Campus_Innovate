import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../listings/domain/repositories/i_listing_repository.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_request.dart';
import '../../domain/repositories/i_group_repository.dart';

/// The groups screen: the ones the user belongs to, and the rest of the campus.
///
/// It also counts how many projects each group has published. That number comes
/// from the listings repository rather than from the group itself, because a
/// project belongs to the listings feature and a group should not have to know
/// how one is stored.
class GroupsViewModel extends GetxController {
  final IGroupRepository _groups;
  final IListingRepository _listings;
  final ISessionService _session;

  GroupsViewModel(this._groups, this._listings, this._session);

  final RxList<Group> myGroups = <Group>[].obs;
  final RxList<Group> otherGroups = <Group>[].obs;
  final RxMap<String, int> projectCounts = <String, int>{}.obs;
  final RxList<GroupRequest> myRequests = <GroupRequest>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();

  String get currentUserId => _session.currentUserId;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final all = await _groups.getGroups();
      final requests = await _groups.getMyRequests(_session.currentUserId);
      final listings = await _listings.getListings();

      final counts = <String, int>{};
      for (final listing in listings) {
        if (!listing.belongsToGroup) continue;

        counts[listing.groupId] = (counts[listing.groupId] ?? 0) + 1;
      }

      myGroups.assignAll(
        all.where(
          (group) =>
              group.isOwner(_session.currentUserId) ||
              group.hasMember(_session.currentUserId),
        ),
      );
      otherGroups.assignAll(
        all.where(
          (group) =>
              !group.isOwner(_session.currentUserId) &&
              !group.hasMember(_session.currentUserId),
        ),
      );
      projectCounts.assignAll(counts);
      myRequests.assignAll(requests);
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudieron cargar los grupos',
      );
    } finally {
      isLoading.value = false;
    }
  }

  int projectsOf(Group group) => projectCounts[group.id] ?? 0;

  /// The request the user already sent to [group], if any, so the card can say
  /// "Solicitud pendiente" instead of offering to send another one.
  GroupRequest? myRequestFor(Group group) {
    final index = myRequests.indexWhere(
      (request) => request.groupId == group.id,
    );

    return index == -1 ? null : myRequests[index];
  }
}
