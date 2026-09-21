import 'package:campus_innovate/features/groups/data/datasources/i_group_source.dart';
import 'package:campus_innovate/features/groups/domain/group_exception.dart';
import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request_status.dart';

/// [IGroupSource] in memory, seeded with one group the test user owns.
///
/// That seed is not decoration: publishing a project requires a group, so
/// without it the "publish a project" flow could not run at all.
class InMemoryGroupSource implements IGroupSource {
  final List<Group> _groups = [
    const Group(
      id: 'group_1',
      name: 'Innovación UN',
      description:
          'Grupo de estudiantes que arma equipos para concursos y semilleros.',
      ownerId: 'user_1',
      ownerName: 'Leonel Triana',
      members: [
        GroupMember(
          id: 'group_member_1',
          groupId: 'group_1',
          userId: 'user_1',
          userName: 'Leonel Triana',
        ),
      ],
    ),
  ];

  final List<GroupRequest> _requests = [];

  var _nextId = 300;

  String _newId(String prefix) => '${prefix}_${_nextId++}';

  @override
  Future<List<Group>> getGroups() async => List.unmodifiable(_groups);

  @override
  Future<Group?> getGroupById(String id) async {
    final index = _groups.indexWhere((group) => group.id == id);

    return index == -1 ? null : _groups[index];
  }

  @override
  Future<Group> createGroup(Group group) async {
    final id = _newId('group');
    final stored = group.copyWith(
      id: id,
      members: [
        GroupMember(
          id: _newId('group_member'),
          groupId: id,
          userId: group.ownerId,
          userName: group.ownerName,
        ),
      ],
    );

    _groups.insert(0, stored);

    return stored;
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    _groups.removeWhere((group) => group.id == groupId);
    _requests.removeWhere((request) => request.groupId == groupId);
  }

  @override
  Future<void> addMember(GroupMember member) async {
    final index = _groups.indexWhere((group) => group.id == member.groupId);

    if (index == -1) {
      throw GroupException('El grupo ${member.groupId} ya no existe.');
    }

    final group = _groups[index];

    if (group.hasMember(member.userId)) return;

    _groups[index] = group.copyWith(
      members: [
        ...group.members,
        member.copyWith(id: _newId('group_member')),
      ],
    );
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    final index = _groups.indexWhere((group) => group.id == groupId);
    if (index == -1) return;

    final group = _groups[index];

    _groups[index] = group.copyWith(
      members:
          group.members.where((member) => member.userId != userId).toList(),
    );
  }

  @override
  Future<GroupRequest> createRequest(GroupRequest request) async {
    final duplicate = _requests.any(
      (existing) =>
          existing.groupId == request.groupId &&
          existing.applicantId == request.applicantId,
    );

    // The `UNIQUE (group_id, applicant_id)` of the real table.
    if (duplicate) {
      throw const GroupException('Ya enviaste una solicitud a este grupo.');
    }

    final stored = request.copyWith(id: _newId('group_request'));
    _requests.add(stored);

    return stored;
  }

  @override
  Future<List<GroupRequest>> getRequestsForGroup(String groupId) async =>
      _requests.where((request) => request.groupId == groupId).toList();

  @override
  Future<List<GroupRequest>> getRequestsByApplicant(String applicantId) async =>
      _requests.where((request) => request.applicantId == applicantId).toList();

  @override
  Future<GroupRequest?> getRequestById(String id) async {
    final index = _requests.indexWhere((request) => request.id == id);

    return index == -1 ? null : _requests[index];
  }

  @override
  Future<void> updateRequestStatus(
    String requestId,
    GroupRequestStatus status,
  ) async {
    final index = _requests.indexWhere((request) => request.id == requestId);

    if (index == -1) {
      throw GroupException('La solicitud $requestId ya no existe.');
    }

    _requests[index] = _requests[index].copyWith(status: status);
  }
}
