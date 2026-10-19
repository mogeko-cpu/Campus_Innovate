import '../../domain/group_exception.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_message.dart';
import '../../domain/repositories/i_group_chat_repository.dart';
import '../../domain/repositories/i_group_repository.dart';
import '../datasources/i_group_chat_source.dart';

class GroupChatRepository implements IGroupChatRepository {
  final IGroupChatSource _source;
  final IGroupRepository _groups;

  GroupChatRepository(this._source, this._groups);

  /// The longest line the chat accepts. A message is not a document, and an
  /// unbounded `text` column is an invitation to paste one.
  static const maxLength = 1000;

  @override
  Future<List<GroupMessage>> getMessages({
    required String groupId,
    required String userId,
  }) async {
    await _requireMember(groupId: groupId, userId: userId);

    return _source.getMessages(groupId);
  }

  @override
  Future<GroupMessage> send(GroupMessage message) async {
    final body = message.body.trim();

    if (body.isEmpty) {
      throw const GroupException('Escribe algo antes de enviar.');
    }

    if (body.length > maxLength) {
      throw const GroupException(
        'El mensaje es muy largo. Máximo $maxLength caracteres.',
      );
    }

    await _requireMember(groupId: message.groupId, userId: message.senderId);

    return _source.sendMessage(
      GroupMessage.draft(
        groupId: message.groupId,
        senderId: message.senderId,
        senderName: message.senderName,
        body: body,
      ),
    );
  }

  Future<Group> _requireMember({
    required String groupId,
    required String userId,
  }) async {
    final group = await _groups.getGroupById(groupId);

    if (group == null) {
      throw const GroupException('Este grupo ya no existe.');
    }

    if (!group.hasMember(userId)) {
      throw const GroupException(
        'Solo las personas del grupo pueden usar su chat.',
      );
    }

    return group;
  }
}
