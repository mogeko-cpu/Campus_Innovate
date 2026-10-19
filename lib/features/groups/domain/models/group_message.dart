/// One line of a group's chat.
///
/// Not the same thing as a comment: a comment is public, under a project, for the
/// whole campus to read; a message is private to the members of one group.
class GroupMessage {
  /// `_id` of the row in `group_messages`; empty on a draft.
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime createdAt;

  const GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
  });

  GroupMessage.draft({
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.body,
  })  : id = '',
        createdAt = DateTime.now();

  bool get isPersisted => id.isNotEmpty;

  GroupMessage copyWith({String? id}) {
    return GroupMessage(
      id: id ?? this.id,
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      body: body,
      createdAt: createdAt,
    );
  }
}
