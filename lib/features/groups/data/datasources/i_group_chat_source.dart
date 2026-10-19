import '../../domain/models/group_message.dart';

/// Storage contract for a group's chat.
abstract class IGroupChatSource {
  /// The most recent messages of the group, oldest first, so the screen can show
  /// them in reading order.
  Future<List<GroupMessage>> getMessages(String groupId);

  /// Stores [message] — which arrives without an id — and returns it with the id
  /// the database assigned.
  Future<GroupMessage> sendMessage(GroupMessage message);
}
