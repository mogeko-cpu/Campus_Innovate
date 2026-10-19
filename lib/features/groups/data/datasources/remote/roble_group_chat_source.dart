import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_config.dart';
import '../../../domain/group_exception.dart';
import '../../../domain/models/group_message.dart';
import '../i_group_chat_source.dart';

/// A group's chat, stored in ROBLE.
///
/// ROBLE has no push channel, so "live" is the screen asking again every few
/// seconds. That is why this reads the whole conversation each time: `read`
/// filters by equality only, so there is no way to ask for "messages after this
/// one", and the cap below is what keeps the cost of a poll bounded.
class RobleGroupChatSource implements IGroupChatSource {
  RobleGroupChatSource(this._client);

  final RobleClient _client;

  /// Only the most recent messages are returned. Older ones stay in the table,
  /// but a conversation of thousands of lines would make every poll heavier
  /// than the one before.
  static const _maxMessages = 200;

  @override
  Future<List<GroupMessage>> getMessages(String groupId) async {
    if (!RobleClient.isRowId(groupId)) return const [];

    final rows = await _client.read(
      RobleConfig.groupMessagesTable,
      filters: {'group_id': groupId},
    );

    rows.sort(
      (a, b) => _dateOf(a['created_at']).compareTo(_dateOf(b['created_at'])),
    );

    final recent = rows.length > _maxMessages
        ? rows.sublist(rows.length - _maxMessages)
        : rows;

    return recent.map(_messageFrom).whereType<GroupMessage>().toList();
  }

  @override
  Future<GroupMessage> sendMessage(GroupMessage message) async {
    final row = await _client.insertOne(RobleConfig.groupMessagesTable, {
      'group_id': message.groupId,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'body': message.body,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    final id = row['_id']?.toString();

    if (id == null || id.isEmpty) {
      throw const GroupException(
        'ROBLE guardó el mensaje pero no devolvió su identificador. '
        'Actualiza el chat antes de volver a enviarlo.',
      );
    }

    return message.copyWith(id: id);
  }

  DateTime _dateOf(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  GroupMessage? _messageFrom(Map<String, dynamic> row) {
    final id = row['_id']?.toString();
    final groupId = row['group_id']?.toString();
    if (id == null || id.isEmpty || groupId == null) return null;

    return GroupMessage(
      id: id,
      groupId: groupId,
      senderId: row['sender_id']?.toString() ?? '',
      senderName: row['sender_name']?.toString() ?? 'Estudiante',
      body: row['body']?.toString() ?? '',
      createdAt: _dateOf(row['created_at']),
    );
  }
}
