/// One person inside a group, as a row of `group_members`.
///
/// Members are rows and not a `jsonb` array inside `groups` for the same reason
/// project members are: ROBLE has no transactions, so an array would need
/// read-modify-write and two people accepted in the same second would overwrite
/// each other. One row per member makes joining a single insert.
class GroupMember {
  /// `_id` of the row; empty while the member has not been stored yet.
  final String id;
  final String groupId;
  final String userId;

  /// Copied in when the row is written so the group screen can list people
  /// without a lookup per member — ROBLE offers no join.
  final String userName;

  const GroupMember({
    this.id = '',
    required this.groupId,
    required this.userId,
    required this.userName,
  });

  GroupMember copyWith({
    String? id,
    String? groupId,
    String? userId,
    String? userName,
  }) {
    return GroupMember(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
    );
  }
}
