import 'package:campus_innovate/features/groups/data/datasources/i_group_chat_source.dart';
import 'package:campus_innovate/features/groups/domain/models/group_message.dart';

/// [IGroupChatSource] in memory.
class InMemoryGroupChatSource implements IGroupChatSource {
  final List<GroupMessage> _messages = [];

  var _nextId = 900;

  @override
  Future<List<GroupMessage>> getMessages(String groupId) async {
    final messages =
        _messages.where((message) => message.groupId == groupId).toList();

    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return messages;
  }

  @override
  Future<GroupMessage> sendMessage(GroupMessage message) async {
    final stored = message.copyWith(id: 'message_${_nextId++}');
    _messages.add(stored);

    return stored;
  }
}
