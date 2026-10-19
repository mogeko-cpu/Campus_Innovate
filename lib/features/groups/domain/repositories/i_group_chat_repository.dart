import '../models/group_message.dart';

abstract class IGroupChatRepository {
  /// Messages of the group, oldest first. Only a member can read them.
  Future<List<GroupMessage>> getMessages({
    required String groupId,
    required String userId,
  });

  /// Only a member can write, and not an empty line.
  Future<GroupMessage> send(GroupMessage message);
}
