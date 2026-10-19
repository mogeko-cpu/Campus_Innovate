import '../models/group.dart';
import '../models/group_invitation.dart';
import '../models/group_request.dart';

abstract class IGroupRepository {
  Future<List<Group>> getGroups();

  /// Groups the user owns or belongs to, owned ones first.
  Future<List<Group>> getMyGroups(String userId);

  Future<Group?> getGroupById(String id);

  Future<Group> createGroup(Group group);

  Future<void> deleteGroup(String groupId);

  Future<GroupRequest> requestToJoin(GroupRequest request);

  Future<List<GroupRequest>> getRequestsForGroup(String groupId);

  Future<GroupRequest?> getMyRequestForGroup({
    required String groupId,
    required String applicantId,
  });

  /// Requests the user sent that nobody has answered yet.
  Future<List<GroupRequest>> getMyRequests(String applicantId);

  /// Adds the applicant to the group and removes the request. Returns the
  /// request that was answered, so the caller knows whom to tell.
  Future<GroupRequest> acceptRequest(String requestId);

  /// Removes the request. Returns it, for the same reason.
  Future<GroupRequest> rejectRequest(String requestId);

  /// A member invites somebody who is not in the group.
  Future<GroupInvitation> inviteUser(GroupInvitation invitation);

  Future<List<GroupInvitation>> getInvitationsForGroup(String groupId);

  /// Invitations waiting for the user's answer.
  Future<List<GroupInvitation>> getMyInvitations(String inviteeId);

  /// Adds the invited person to the group and removes the invitation. Returns the
  /// invitation, so the caller knows whom to tell.
  Future<GroupInvitation> acceptInvitation(String invitationId);

  Future<GroupInvitation> rejectInvitation(String invitationId);

  /// Withdraws an invitation nobody has answered yet.
  Future<void> cancelInvitation(String invitationId);

  Future<void> removeMember({required String groupId, required String userId});
}
