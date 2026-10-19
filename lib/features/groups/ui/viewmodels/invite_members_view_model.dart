import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../notifications/domain/notification_publisher.dart';
import '../../../users/domain/models/app_user.dart';
import '../../../users/domain/repositories/i_user_repository.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_invitation.dart';
import '../../domain/models/group_request.dart';
import '../../domain/repositories/i_group_repository.dart';

/// Searching the campus for somebody to bring into the group.
///
/// Leader or member can do it. The people offered are the ones who have opened
/// the app and are not already inside; for each one it says whether an
/// invitation is already out or they have already asked to get in, instead of
/// letting a second one be sent and failing afterwards.
class InviteMembersViewModel extends GetxController {
  final IGroupRepository _groups;
  final IUserRepository _users;
  final NotificationPublisher _notifier;
  final ISessionService _session;

  InviteMembersViewModel(
    this._groups,
    this._users,
    this._notifier,
    this._session,
  );

  final Rxn<Group> group = Rxn<Group>();
  final RxList<AppUser> users = <AppUser>[].obs;
  final RxList<GroupInvitation> invitations = <GroupInvitation>[].obs;
  final RxList<GroupRequest> requests = <GroupRequest>[].obs;
  final RxString query = ''.obs;
  final RxBool isLoading = false.obs;

  /// The `id` of the person whose invitation is being sent, so only that row
  /// shows a spinner and the others stay usable.
  final RxnString sendingTo = RxnString();
  final RxnString error = RxnString();

  /// Why the last invitation failed; apart from [error] for the same reason as
  /// in the groups screen — a button that failed must not replace the list.
  String? lastActionError;

  late final String groupId;

  @override
  void onInit() {
    super.onInit();
    groupId = Get.parameters['id'] ?? '';
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final found = await _groups.getGroupById(groupId);

      if (found == null) {
        error.value = 'Grupo no encontrado';
        return;
      }

      group.value = found;
      users.assignAll(await _users.getUsers());
      invitations.assignAll(await _groups.getInvitationsForGroup(groupId));
      requests.assignAll(await _groups.getRequestsForGroup(groupId));
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo cargar la lista de personas',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// Everybody who could be invited and matches the search.
  List<AppUser> get candidates {
    final current = group.value;
    if (current == null) return const [];

    final text = query.value.trim().toLowerCase();

    return users.where((user) {
      if (current.hasMember(user.id)) return false;
      if (text.isEmpty) return true;

      return user.name.toLowerCase().contains(text) ||
          user.email.toLowerCase().contains(text);
    }).toList();
  }

  bool isInvited(AppUser user) =>
      invitations.any((invitation) => invitation.inviteeId == user.id);

  bool hasRequested(AppUser user) => requests.any(
        (request) => request.applicantId == user.id && request.isPending,
      );

  Future<bool> invite(AppUser user) async {
    final current = group.value;
    if (current == null || sendingTo.value != null) return false;

    try {
      sendingTo.value = user.id;
      lastActionError = null;

      await _groups.inviteUser(
        GroupInvitation.draft(
          groupId: current.id,
          groupName: current.name,
          inviterId: _session.currentUserId,
          inviterName: _session.currentUserName,
          inviteeId: user.id,
          inviteeName: user.name,
        ),
      );

      await _notifier.invitationReceived(
        groupId: current.id,
        groupName: current.name,
        inviterId: _session.currentUserId,
        inviterName: _session.currentUserName,
        inviteeId: user.id,
      );

      invitations.assignAll(await _groups.getInvitationsForGroup(groupId));

      return true;
    } catch (failure) {
      lastActionError = errorMessage(
        failure,
        fallback: 'No se pudo enviar la invitación',
      );

      return false;
    } finally {
      sendingTo.value = null;
    }
  }
}
