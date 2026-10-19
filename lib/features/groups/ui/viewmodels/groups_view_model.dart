import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../../core/poller.dart';
import '../../../listings/domain/repositories/i_listing_repository.dart';
import '../../../notifications/domain/notification_publisher.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_invitation.dart';
import '../../domain/models/group_request.dart';
import '../../domain/repositories/i_group_repository.dart';

/// The groups screen: the invitations waiting for an answer, the groups the user
/// belongs to, and the rest of the campus.
///
/// It also counts how many projects each group has published. That number comes
/// from the listings repository rather than from the group itself, because a
/// project belongs to the listings feature and a group should not have to know
/// how one is stored.
///
/// Like the group screen, it refreshes itself while it is open: an invitation
/// sent from another phone, or a request somebody answered, shows up without the
/// person having to pull down.
class GroupsViewModel extends GetxController {
  final IGroupRepository _groups;
  final IListingRepository _listings;
  final NotificationPublisher _notifier;
  final ISessionService _session;

  GroupsViewModel(
    this._groups,
    this._listings,
    this._notifier,
    this._session,
  ) {
    _poller = Poller(
      interval: const Duration(seconds: 20),
      action: _refreshQuietly,
    );
  }

  late final Poller _poller;

  final RxList<Group> myGroups = <Group>[].obs;
  final RxList<Group> otherGroups = <Group>[].obs;
  final RxMap<String, int> projectCounts = <String, int>{}.obs;
  final RxList<GroupRequest> myRequests = <GroupRequest>[].obs;

  /// Invitations other people sent to this user and that nobody has answered.
  final RxList<GroupInvitation> invitations = <GroupInvitation>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isWorking = false.obs;
  final RxnString error = RxnString();

  /// Why the last answer to an invitation failed. Apart from [error] on purpose:
  /// that one replaces the whole screen with an error state, which is right when
  /// the list could not load and wrong when one button did not work.
  String? lastActionError;

  String get currentUserId => _session.currentUserId;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onReady() {
    super.onReady();
    _poller.start();
  }

  @override
  void onClose() {
    _poller.stop();
    super.onClose();
  }

  void pauseRefresh() => _poller.pause();

  void resumeRefresh() => _poller.resume();

  Future<void> load({bool silent = false}) async {
    try {
      if (!silent) {
        isLoading.value = true;
        error.value = null;
      }

      final userId = _session.currentUserId;

      final all = await _groups.getGroups();
      final requests = await _groups.getMyRequests(userId);
      final received = await _groups.getMyInvitations(userId);
      final listings = await _listings.getListings();

      final counts = <String, int>{};
      for (final listing in listings) {
        if (!listing.belongsToGroup) continue;

        counts[listing.groupId] = (counts[listing.groupId] ?? 0) + 1;
      }

      myGroups.assignAll(
        all.where((group) => group.isOwner(userId) || group.hasMember(userId)),
      );
      otherGroups.assignAll(
        all.where(
          (group) => !group.isOwner(userId) && !group.hasMember(userId),
        ),
      );
      projectCounts.assignAll(counts);
      myRequests.assignAll(requests);
      invitations.assignAll(received);
    } catch (failure) {
      if (!silent) {
        error.value = errorMessage(
          failure,
          fallback: 'No se pudieron cargar los grupos',
        );
      }
    } finally {
      if (!silent) isLoading.value = false;
    }
  }

  Future<void> _refreshQuietly() async {
    if (isWorking.value || isLoading.value) return;

    await load(silent: true);
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

  Future<bool> acceptInvitation(GroupInvitation invitation) =>
      _answer(invitation, accepted: true);

  Future<bool> rejectInvitation(GroupInvitation invitation) =>
      _answer(invitation, accepted: false);

  Future<bool> _answer(
    GroupInvitation invitation, {
    required bool accepted,
  }) async {
    if (isWorking.value) return false;

    try {
      isWorking.value = true;
      lastActionError = null;

      if (accepted) {
        await _groups.acceptInvitation(invitation.id);
      } else {
        await _groups.rejectInvitation(invitation.id);
      }

      await _notifier.invitationResolved(
        accepted: accepted,
        groupId: invitation.groupId,
        groupName: invitation.groupName,
        inviteeId: invitation.inviteeId,
        inviteeName: invitation.inviteeName,
        inviterId: invitation.inviterId,
      );

      // Reloaded, not patched: accepting moves a group from "others" to "mine".
      await load(silent: true);

      return true;
    } catch (failure) {
      lastActionError = errorMessage(
        failure,
        fallback: 'No se pudo responder la invitación',
      );

      return false;
    } finally {
      isWorking.value = false;
    }
  }
}
