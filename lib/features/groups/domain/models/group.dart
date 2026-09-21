import 'group_member.dart';

/// A standing team. Projects are published **by** a group, which is what ties
/// every listing — and every like, view and comment on it — to one owner.
class Group {
  /// `_id` of the row in `groups`, assigned by ROBLE. Empty on a draft.
  final String id;
  final String name;
  final String description;

  /// Whoever created the group. The owner is also its first member, and cannot
  /// be removed: a group with nobody in charge has no screen that could fix it.
  final String ownerId;
  final String ownerName;

  final List<GroupMember> members;

  const Group({
    required this.id,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.ownerName,
    required this.members,
  });

  /// A group filled in by the user but not stored yet, so without an [id].
  ///
  /// The owner is already its first member, which leaves a new group showing
  /// "1 integrante" the moment it is created.
  factory Group.draft({
    required String name,
    required String description,
    required String ownerId,
    required String ownerName,
  }) {
    return Group(
      id: '',
      name: name,
      description: description,
      ownerId: ownerId,
      ownerName: ownerName,
      members: [
        GroupMember(groupId: '', userId: ownerId, userName: ownerName),
      ],
    );
  }

  bool get isPersisted => id.isNotEmpty;

  int get memberCount => members.length;

  List<String> get memberIds =>
      members.map((member) => member.userId).toList(growable: false);

  bool isOwner(String userId) => ownerId == userId;

  bool hasMember(String userId) =>
      members.any((member) => member.userId == userId);

  Group copyWith({
    String? id,
    String? name,
    String? description,
    String? ownerId,
    String? ownerName,
    List<GroupMember>? members,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      members: members ?? this.members,
    );
  }
}
