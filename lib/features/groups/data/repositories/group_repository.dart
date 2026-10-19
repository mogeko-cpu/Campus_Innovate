import '../../domain/group_exception.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_invitation.dart';
import '../../domain/models/group_member.dart';
import '../../domain/models/group_request.dart';
import '../../domain/repositories/i_group_repository.dart';
import '../datasources/i_group_source.dart';

class GroupRepository implements IGroupRepository {
  final IGroupSource _source;

  GroupRepository(this._source);

  @override
  Future<List<Group>> getGroups() => _source.getGroups();

  @override
  Future<List<Group>> getMyGroups(String userId) async {
    final groups = await _source.getGroups();

    final mine = groups
        .where((group) => group.isOwner(userId) || group.hasMember(userId))
        .toList();

    // The ones the user runs come first: those are the ones with decisions
    // waiting on them.
    mine.sort((a, b) {
      final aOwned = a.isOwner(userId) ? 0 : 1;
      final bOwned = b.isOwner(userId) ? 0 : 1;

      return aOwned.compareTo(bOwned);
    });

    return mine;
  }

  @override
  Future<Group?> getGroupById(String id) => _source.getGroupById(id);

  @override
  Future<Group> createGroup(Group group) => _source.createGroup(group);

  @override
  Future<void> deleteGroup(String groupId) => _source.deleteGroup(groupId);

  @override
  Future<GroupRequest> requestToJoin(GroupRequest request) async {
    final group = await _source.getGroupById(request.groupId);

    if (group == null) {
      throw const GroupException('Este grupo ya no existe.');
    }

    if (group.hasMember(request.applicantId)) {
      throw const GroupException('Ya haces parte de este grupo.');
    }

    // A pending request is a real one, and asking twice is refused. Any other is
    // a leftover from before answered requests were deleted: it would hit the
    // `UNIQUE (group_id, applicant_id)` and stop this person from ever asking
    // again, so it is cleared out of the way.
    final previous = (await _source.getRequestsForGroup(request.groupId))
        .where((existing) => existing.applicantId == request.applicantId);

    for (final existing in previous) {
      if (existing.isPending) {
        throw const GroupException('Ya enviaste una solicitud a este grupo.');
      }

      await _source.deleteRequest(existing.id);
    }

    final invitations = await _source.getInvitationsForInvitee(
      request.applicantId,
    );

    if (invitations.any((invitation) => invitation.groupId == request.groupId)) {
      throw const GroupException(
        'Este grupo ya te invitó. Acepta la invitación desde la pestaña '
        'Grupos.',
      );
    }

    return _source.createRequest(request);
  }

  @override
  Future<List<GroupRequest>> getRequestsForGroup(String groupId) =>
      _source.getRequestsForGroup(groupId);

  @override
  Future<GroupRequest?> getMyRequestForGroup({
    required String groupId,
    required String applicantId,
  }) async {
    final requests = await _source.getRequestsForGroup(groupId);

    // Only a request still waiting counts: an answered one is not "yours" any
    // more, and showing it is what left requests sitting on the screen.
    final index = requests.indexWhere(
      (request) => request.applicantId == applicantId && request.isPending,
    );

    return index == -1 ? null : requests[index];
  }

  @override
  Future<List<GroupRequest>> getMyRequests(String applicantId) async {
    final requests = await _source.getRequestsByApplicant(applicantId);

    return requests.where((request) => request.isPending).toList();
  }

  /// Accepting is two writes and ROBLE has no transactions, so the order is
  /// chosen for what a failure between them leaves behind: the membership goes
  /// in **first**, and only then is the request deleted.
  ///
  /// Fail after the membership and the request is still there, still pending, so
  /// the owner accepts again and the second run fixes it —
  /// [IGroupSource.addMember] is idempotent. The opposite order would lose the
  /// request while its applicant never joined, with nothing left to retry.
  ///
  /// The request is deleted and not marked "accepted": what happened is carried
  /// by the notification the caller sends, and a row that stays behind is what
  /// kept answered requests on the screen.
  @override
  Future<GroupRequest> acceptRequest(String requestId) async {
    final request = await _requireRequest(requestId);

    await _source.addMember(
      GroupMember(
        groupId: request.groupId,
        userId: request.applicantId,
        userName: request.applicantName,
      ),
    );
    await _source.deleteRequest(requestId);

    return request;
  }

  @override
  Future<GroupRequest> rejectRequest(String requestId) async {
    final request = await _requireRequest(requestId);

    await _source.deleteRequest(requestId);

    return request;
  }

  Future<GroupRequest> _requireRequest(String requestId) async {
    final request = await _source.getRequestById(requestId);

    if (request == null) {
      throw const GroupException('Esta solicitud ya no existe.');
    }

    return request;
  }

  @override
  Future<GroupInvitation> inviteUser(GroupInvitation invitation) async {
    final group = await _source.getGroupById(invitation.groupId);

    if (group == null) {
      throw const GroupException('Este grupo ya no existe.');
    }

    // Leader or member: anybody inside can bring somebody in. Outsiders cannot.
    if (!group.hasMember(invitation.inviterId)) {
      throw const GroupException(
        'Solo las personas del grupo pueden invitar a otras.',
      );
    }

    if (group.hasMember(invitation.inviteeId)) {
      throw const GroupException('Esta persona ya hace parte del grupo.');
    }

    final requests = await _source.getRequestsForGroup(invitation.groupId);

    final alreadyAsked = requests.any(
      (request) =>
          request.applicantId == invitation.inviteeId && request.isPending,
    );

    if (alreadyAsked) {
      throw const GroupException(
        'Esta persona ya pidió entrar al grupo; su solicitud está pendiente '
        'de revisión.',
      );
    }

    return _source.createInvitation(invitation);
  }

  @override
  Future<List<GroupInvitation>> getInvitationsForGroup(String groupId) =>
      _source.getInvitationsForGroup(groupId);

  @override
  Future<List<GroupInvitation>> getMyInvitations(String inviteeId) =>
      _source.getInvitationsForInvitee(inviteeId);

  /// Same order as [acceptRequest], for the same reason: the membership first,
  /// and only then is the invitation deleted, so a failure between the two
  /// leaves an invitation that can simply be accepted again.
  @override
  Future<GroupInvitation> acceptInvitation(String invitationId) async {
    final invitation = await _requireInvitation(invitationId);

    await _source.addMember(
      GroupMember(
        groupId: invitation.groupId,
        userId: invitation.inviteeId,
        userName: invitation.inviteeName,
      ),
    );
    await _source.deleteInvitation(invitationId);

    // If this person had also asked to get in, that request has nothing left to
    // decide. It is cleared out so it does not sit in the owner's list.
    final requests = await _source.getRequestsForGroup(invitation.groupId);

    for (final request in requests) {
      if (request.applicantId == invitation.inviteeId) {
        await _source.deleteRequest(request.id);
      }
    }

    return invitation;
  }

  @override
  Future<GroupInvitation> rejectInvitation(String invitationId) async {
    final invitation = await _requireInvitation(invitationId);

    await _source.deleteInvitation(invitationId);

    return invitation;
  }

  @override
  Future<void> cancelInvitation(String invitationId) =>
      _source.deleteInvitation(invitationId);

  Future<GroupInvitation> _requireInvitation(String invitationId) async {
    final invitation = await _source.getInvitationById(invitationId);

    if (invitation == null) {
      throw const GroupException('Esta invitación ya no existe.');
    }

    return invitation;
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    final group = await _source.getGroupById(groupId);

    if (group == null) {
      throw const GroupException('Este grupo ya no existe.');
    }

    // A group without an owner has no screen that could give it one back.
    if (group.isOwner(userId)) {
      throw const GroupException(
        'El creador no puede salir del grupo. Elimina el grupo si ya no lo '
        'necesitas.',
      );
    }

    await _source.removeMember(groupId: groupId, userId: userId);
  }
}
