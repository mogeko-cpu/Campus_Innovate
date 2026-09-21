import '../../domain/models/group.dart';
import '../../domain/models/group_member.dart';
import '../../domain/models/group_request.dart';
import '../../domain/models/group_request_status.dart';

/// Storage contract for groups, their members and the requests to join them.
///
/// Implemented against ROBLE by `RobleGroupSource`, which the app uses, and in
/// memory by the double the widget tests run on.
///
/// Ids are the `_id` UUIDs of the rows, as strings: whoever creates a row gets
/// its id back and only then can point at it.
abstract class IGroupSource {
  Future<List<Group>> getGroups();

  Future<Group?> getGroupById(String id);

  /// Stores [group] — which arrives without an id — and returns it with the id
  /// the database assigned, owner already inside.
  Future<Group> createGroup(Group group);

  /// Removes the group and everything that only made sense inside it: its
  /// members and its requests. Its projects are **not** touched here; the caller
  /// checks first, because deleting someone's published project as a side effect
  /// of tidying up a group would be a surprise.
  Future<void> deleteGroup(String groupId);

  /// Adds [member] to its group. Idempotent: adding someone who is already in is
  /// not an error, it is the outcome the caller wanted.
  Future<void> addMember(GroupMember member);

  Future<void> removeMember({required String groupId, required String userId});

  Future<GroupRequest> createRequest(GroupRequest request);

  Future<List<GroupRequest>> getRequestsForGroup(String groupId);

  Future<List<GroupRequest>> getRequestsByApplicant(String applicantId);

  Future<GroupRequest?> getRequestById(String id);

  Future<void> updateRequestStatus(String requestId, GroupRequestStatus status);
}
