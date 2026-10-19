import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../../core/poller.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_message.dart';
import '../../domain/repositories/i_group_chat_repository.dart';
import '../../domain/repositories/i_group_repository.dart';

/// The chat of one group.
///
/// "Live" here is the screen asking again every few seconds: ROBLE cannot push a
/// message to the other phones, so each one polls. That is a trade-off made
/// knowingly — a message takes up to one interval to appear — and it is also why
/// the interval is not shorter: every poll is requests against ROBLE's budget of
/// 100 per minute.
class GroupChatViewModel extends GetxController {
  final IGroupChatRepository _chat;
  final IGroupRepository _groups;
  final ISessionService _session;

  GroupChatViewModel(this._chat, this._groups, this._session) {
    _poller = Poller(
      interval: const Duration(seconds: 5),
      action: refreshMessages,
    );
  }

  late final Poller _poller;

  final Rxn<Group> group = Rxn<Group>();

  /// Oldest first, as the repository returns them. The screen reverses the list
  /// so the newest message sits at the bottom, next to the input.
  final RxList<GroupMessage> messages = <GroupMessage>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSending = false.obs;
  final RxnString error = RxnString();

  /// Why the last message failed to send; apart from [error] so that a failed
  /// send does not replace the conversation.
  String? lastSendError;

  late final String groupId;

  String get currentUserId => _session.currentUserId;

  @override
  void onInit() {
    super.onInit();
    groupId = Get.parameters['id'] ?? '';
    load();
  }

  @override
  void onReady() {
    super.onReady();
    _poller.start();
  }

  @override
  void onClose() {
    _poller.stop();
    super.onClose();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final found = await _groups.getGroupById(groupId);

      if (found == null) {
        error.value = 'Este grupo ya no existe.';
        return;
      }

      group.value = found;

      messages.assignAll(
        await _chat.getMessages(groupId: groupId, userId: currentUserId),
      );
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo abrir el chat',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// What the timer runs. A failure keeps the conversation on screen; the one
  /// failure that matters — the person was removed from the group — surfaces on
  /// the next [load] or the next send, both of which check membership.
  Future<void> refreshMessages() async {
    if (isSending.value || isLoading.value || group.value == null) return;

    final fetched = await _chat.getMessages(
      groupId: groupId,
      userId: currentUserId,
    );

    // Only when something changed, so a quiet chat does not rebuild the list
    // every few seconds.
    final changed = fetched.length != messages.length ||
        (fetched.isNotEmpty &&
            messages.isNotEmpty &&
            fetched.last.id != messages.last.id);

    if (changed) messages.assignAll(fetched);
  }

  Future<bool> send(String body) async {
    if (isSending.value) return false;

    try {
      isSending.value = true;
      lastSendError = null;

      final stored = await _chat.send(
        GroupMessage.draft(
          groupId: groupId,
          senderId: currentUserId,
          senderName: _session.currentUserName,
          body: body,
        ),
      );

      // Appended at once so the message is on screen the moment it is sent; the
      // next poll replaces the list with what the database holds.
      messages.add(stored);

      return true;
    } catch (failure) {
      lastSendError = errorMessage(
        failure,
        fallback: 'No se pudo enviar el mensaje',
      );

      return false;
    } finally {
      isSending.value = false;
    }
  }
}
