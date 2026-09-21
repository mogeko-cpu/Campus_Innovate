import '../../domain/group_exception.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';
import '../../domain/models/group_request.dart';
import '../../domain/models/group_request_status.dart';
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
    final index = requests.indexWhere(
      (request) => request.applicantId == applicantId,
    );

    return index == -1 ? null : requests[index];
  }

  @override
  Future<List<GroupRequest>> getMyRequests(String applicantId) =>
      _source.getRequestsByApplicant(applicantId);

  /// Accepting is two writes and ROBLE has no transactions, so the order is
  /// chosen for what a failure between them leaves behind: the membership goes
  /// in **first**, and only then is the request marked accepted.
  ///
  /// Fail after the membership and the request still reads "Pendiente", so the
  /// owner accepts again and the second run fixes it — [IGroupSource.addMember]
  /// is idempotent. The opposite order would show an accepted request whose
  /// applicant never joined, and retrying would look like a no-op.
  @override
  Future<void> acceptRequest(String requestId) async {
    final request = await _source.getRequestById(requestId);

    if (request == null) {
      throw const GroupException('Esta solicitud ya no existe.');
    }

    await _source.addMember(
      GroupMember(
        groupId: request.groupId,
        userId: request.applicantId,
        userName: request.applicantName,
      ),
    );
    await _source.updateRequestStatus(requestId, GroupRequestStatus.accepted);
  }

  @override
  Future<void> rejectRequest(String requestId) =>
      _source.updateRequestStatus(requestId, GroupRequestStatus.rejected);

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
