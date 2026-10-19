import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../../core/poller.dart';
import '../../../listings/domain/models/listing.dart';
import '../../../listings/domain/repositories/i_listing_repository.dart';
import '../../../notifications/domain/models/notification_target.dart';
import '../../../notifications/domain/notification_publisher.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_invitation.dart';
import '../../domain/models/group_request.dart';
import '../../domain/repositories/i_group_repository.dart';

/// One group: who is in it, who wants in, who has been invited, and what it has
/// published.
///
/// Everything about running a group happens on this screen — asking to join,
/// accepting, rejecting, inviting, removing someone, deleting the group — so
/// that a person never has to remember which other screen held the other half of
/// the job.
///
/// It refreshes itself every few seconds while it is on screen. Other people act
/// on the same group from their own phones — a request arrives, an invitation is
/// answered — and ROBLE cannot push that here, so without this the screen would
/// keep showing what was true when it opened.
class GroupDetailViewModel extends GetxController {
  final IGroupRepository _groups;
  final IListingRepository _listings;
  final NotificationPublisher _notifier;
  final ISessionService _session;

  GroupDetailViewModel(
    this._groups,
    this._listings,
    this._notifier,
    this._session,
  ) {
    _poller = Poller(
      interval: const Duration(seconds: 15),
      action: _refreshQuietly,
    );
  }

  late final Poller _poller;

  final Rxn<Group> group = Rxn<Group>();
  final RxList<GroupRequest> requests = <GroupRequest>[].obs;
  final RxList<Listing> projects = <Listing>[].obs;
  final Rxn<GroupRequest> myRequest = Rxn<GroupRequest>();

  /// Invitations sent from this group that nobody has answered yet.
  final RxList<GroupInvitation> invitations = <GroupInvitation>[].obs;

  /// The invitation this person has received from the group, if any.
  final Rxn<GroupInvitation> myInvitation = Rxn<GroupInvitation>();
  final RxBool isLoading = false.obs;

  /// True while a write is in flight, so the buttons can be disabled and a
  /// double tap cannot send the same acceptance twice.
  final RxBool isWorking = false.obs;
  final RxnString error = RxnString();

  /// The `_id` of the group, straight out of the route. Not parsed: it is a
  /// UUID, and the source treats anything that is not one as "not found".
  late final String groupId;

  @override
  void onInit() {
    super.onInit();
    groupId = Get.parameters['id'] ?? '';
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

  /// Stops the timer while another screen is on top of this one — the chat, the
  /// invite list — so the two are not both asking ROBLE for the same group.
  void pauseRefresh() => _poller.pause();

  void resumeRefresh() => _poller.resume();

  /// Reads the group again.
  ///
  /// [silent] is what the timer uses: no spinner, and a failure keeps what is on
  /// screen instead of replacing it with an error. The person did not ask for
  /// this read, so it must not be able to interrupt them.
  Future<void> load({bool silent = false}) async {
    try {
      if (!silent) {
        isLoading.value = true;
        error.value = null;
      }

      final found = await _groups.getGroupById(groupId);

      if (found == null) {
        error.value = 'Grupo no encontrado';
        group.value = null;
        return;
      }

      final userId = _session.currentUserId;

      group.value = found;
      projects.assignAll(await _listings.getListingsByGroup(groupId));

      final inside = found.isOwner(userId) || found.hasMember(userId);

      // Only the owner decides on requests, so only the owner pays for the read.
      if (found.isOwner(userId)) {
        requests.assignAll(await _groups.getRequestsForGroup(groupId));
        myRequest.value = null;
      } else {
        requests.clear();
        myRequest.value = inside
            ? null
            : await _groups.getMyRequestForGroup(
                groupId: groupId,
                applicantId: userId,
              );
      }

      // Anybody inside can see who has been invited; somebody outside only
      // needs to know whether it is *them*.
      if (inside) {
        invitations.assignAll(await _groups.getInvitationsForGroup(groupId));
        myInvitation.value = null;
      } else {
        invitations.clear();

        final mine = await _groups.getMyInvitations(userId);
        final index = mine.indexWhere((item) => item.groupId == groupId);

        myInvitation.value = index == -1 ? null : mine[index];
      }
    } catch (failure) {
      if (!silent) {
        error.value = errorMessage(
          failure,
          fallback: 'No se pudo cargar el grupo',
        );
      }
    } finally {
      if (!silent) isLoading.value = false;
    }
  }

  Future<void> _refreshQuietly() async {
    // Never while a write is in flight: the read could land between the write
    // and its reload and put the old state back on screen for a moment.
    if (isWorking.value || isLoading.value) return;

    await load(silent: true);
  }

  bool get isOwner => group.value?.isOwner(_session.currentUserId) ?? false;

  bool get isMember => group.value?.hasMember(_session.currentUserId) ?? false;

  /// Leader or member: the two kinds of person who may invite and use the chat.
  bool get isInside => isOwner || isMember;

  bool get canRequestToJoin =>
      group.value != null &&
      !isInside &&
      myRequest.value == null &&
      myInvitation.value == null;

  List<GroupRequest> get pendingRequests =>
      requests.where((request) => request.isPending).toList();

  /// Whether this person may withdraw [invitation]: whoever sent it, or the
  /// leader of the group.
  bool canCancel(GroupInvitation invitation) =>
      isOwner || invitation.inviterId == _session.currentUserId;

  Future<bool> requestToJoin(String message) async {
    final current = group.value;
    if (current == null) return false;

    final sent = await _write(
      fallback: 'No se pudo enviar la solicitud',
      action: () => _groups.requestToJoin(
        GroupRequest.draft(
          groupId: current.id,
          applicantId: _session.currentUserId,
          applicantName: _session.currentUserName,
          message: message.trim(),
        ),
      ),
    );

    if (sent) {
      await _notifier.joinRequestReceived(
        target: NotificationTarget.group,
        targetId: current.id,
        targetName: current.name,
        applicantId: _session.currentUserId,
        applicantName: _session.currentUserName,
        recipientId: current.ownerId,
      );
    }

    return sent;
  }

  Future<bool> accept(String requestId) => _resolveRequest(
        requestId,
        accepted: true,
        fallback: 'No se pudo aceptar la solicitud',
      );

  Future<bool> reject(String requestId) => _resolveRequest(
        requestId,
        accepted: false,
        fallback: 'No se pudo rechazar la solicitud',
      );

  /// Answers a request and tells the applicant.
  ///
  /// The repository deletes the request, so the reload that follows no longer
  /// finds it: the request leaves the screen by itself, which is the point.
  Future<bool> _resolveRequest(
    String requestId, {
    required bool accepted,
    required String fallback,
  }) async {
    final current = group.value;
    final index = requests.indexWhere((request) => request.id == requestId);
    final request = index == -1 ? null : requests[index];

    final done = await _write(
      fallback: fallback,
      action: () => accepted
          ? _groups.acceptRequest(requestId)
          : _groups.rejectRequest(requestId),
    );

    if (done && current != null && request != null) {
      await _notifier.requestResolved(
        accepted: accepted,
        target: NotificationTarget.group,
        targetId: current.id,
        targetName: current.name,
        deciderId: _session.currentUserId,
        applicantId: request.applicantId,
      );
    }

    return done;
  }

  Future<bool> removeMember(String userId) => _write(
        fallback: 'No se pudo quitar al integrante',
        action: () => _groups.removeMember(groupId: groupId, userId: userId),
      );

  Future<bool> leave() => removeMember(_session.currentUserId);

  /// The invited person's own answer, from the banner on the group screen.
  Future<bool> acceptMyInvitation() => _answerMyInvitation(accepted: true);

  Future<bool> rejectMyInvitation() => _answerMyInvitation(accepted: false);

  Future<bool> _answerMyInvitation({required bool accepted}) async {
    final invitation = myInvitation.value;
    if (invitation == null) return false;

    final done = await _write(
      fallback: accepted
          ? 'No se pudo aceptar la invitación'
          : 'No se pudo rechazar la invitación',
      action: () => accepted
          ? _groups.acceptInvitation(invitation.id)
          : _groups.rejectInvitation(invitation.id),
    );

    if (done) {
      await _notifier.invitationResolved(
        accepted: accepted,
        groupId: invitation.groupId,
        groupName: invitation.groupName,
        inviteeId: invitation.inviteeId,
        inviteeName: invitation.inviteeName,
        inviterId: invitation.inviterId,
      );
    }

    return done;
  }

  Future<bool> cancelInvitation(String invitationId) => _write(
        fallback: 'No se pudo cancelar la invitación',
        action: () => _groups.cancelInvitation(invitationId),
      );

  /// Deletes the group, but only once it has no projects left.
  ///
  /// Removing a group is not a reason to remove what it published: other people
  /// applied to those projects and may be on their teams. The owner deletes the
  /// projects first, on each project's own screen, and the refusal says so.
  Future<bool> deleteGroup() async {
    if (!isOwner) {
      error.value = 'Solo quien creó el grupo puede eliminarlo.';
      return false;
    }

    if (projects.isNotEmpty) {
      final count = projects.length;
      error.value = count == 1
          ? 'Este grupo tiene 1 proyecto publicado. Elimínalo antes de '
              'eliminar el grupo.'
          : 'Este grupo tiene $count proyectos publicados. Elimínalos antes '
              'de eliminar el grupo.';
      return false;
    }

    return _write(
      fallback: 'No se pudo eliminar el grupo',
      reload: false,
      action: () => _groups.deleteGroup(groupId),
    );
  }

  /// Runs a write with the loading flag, the error message and the reload that
  /// every one of them needs, so each action above is one line.
  Future<bool> _write({
    required Future<void> Function() action,
    required String fallback,
    bool reload = true,
  }) async {
    if (isWorking.value) return false;

    try {
      isWorking.value = true;
      error.value = null;

      await action();

      // Silent: the screen is already showing the group, and a spinner that
      // replaced it for a moment after every tap is what made it feel broken.
      if (reload) await load(silent: true);

      return true;
    } catch (failure) {
      error.value = errorMessage(failure, fallback: fallback);

      return false;
    } finally {
      isWorking.value = false;
    }
  }
}
