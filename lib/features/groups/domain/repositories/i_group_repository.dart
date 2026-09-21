import '../models/group.dart';
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

  Future<List<GroupRequest>> getMyRequests(String applicantId);

  Future<void> acceptRequest(String requestId);

  Future<void> rejectRequest(String requestId);

  Future<void> removeMember({required String groupId, required String userId});
}
