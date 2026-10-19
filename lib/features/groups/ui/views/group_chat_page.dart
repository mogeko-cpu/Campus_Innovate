import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/name_avatar.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../domain/models/group_message.dart';
import '../viewmodels/group_chat_view_model.dart';

/// The private chat of a group, apart from the public comments under a project.
class GroupChatPage extends StatefulWidget {
  const GroupChatPage({super.key});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _input = TextEditingController();

  GroupChatViewModel get _controller => Get.find<GroupChatViewModel>();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;

    // Cleared before the request, so the field is ready for the next line while
    // this one travels; put back if it fails, so nothing typed is lost.
    _input.clear();

    final sent = await _controller.send(text);

    if (!sent) {
      _input.text = text;
      _input.selection = TextSelection.collapsed(offset: text.length);

      Get.snackbar(
        'No se envió',
        _controller.lastSendError ?? 'Intenta de nuevo',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final name = _controller.group.value?.name;

          return Text(name == null ? 'Chat del grupo' : 'Chat · $name');
        }),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (_controller.error.value != null) {
                return EmptyState.screen(
                  icon: Icons.lock_outline,
                  title: 'No se pudo abrir el chat',
                  message: _controller.error.value!,
                );
              }

              final messages = _controller.messages.reversed.toList();

              if (messages.isEmpty) {
                return const EmptyState.screen(
                  icon: Icons.forum_outlined,
                  title: 'Todavía no hay mensajes',
                  message: 'Escribe el primero. Solo lo ven las personas del '
                      'grupo.',
                );
              }

              return ListView.builder(
                // Reversed: the newest message sits at the bottom, next to the
                // input, and the list opens there without any scrolling code.
                reverse: true,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];

                  // `messages` is newest-first, so the one *before* in time is
                  // the next index. A name is shown once per run of messages
                  // from the same person.
                  final previous =
                      index + 1 < messages.length ? messages[index + 1] : null;
                  final startsRun = previous?.senderId != message.senderId;

                  return _Bubble(
                    message: message,
                    isMine: message.senderId == _controller.currentUserId,
                    showSender: startsRun,
                  );
                },
              );
            }),
          ),
          _Composer(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final GroupMessage message;
  final bool isMine;
  final bool showSender;

  const _Bubble({
    required this.message,
    required this.isMine,
    required this.showSender,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final background =
        isMine ? colors.primaryContainer : colors.surfaceContainerHighest;
    final foreground =
        isMine ? colors.onPrimaryContainer : colors.onSurface;

    final time = TimeOfDay.fromDateTime(message.createdAt.toLocal())
        .format(context);

    return Padding(
      padding: EdgeInsets.only(top: showSender ? 10 : 2),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            // The avatar only on the first message of a run; the others keep an
            // empty slot of the same width so the bubbles stay aligned.
            SizedBox(
              width: 30,
              child: showSender
                  ? NameAvatar(name: message.senderName, radius: 14)
                  : null,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMine && showSender)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        message.senderName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Text(
                    message.body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      time,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function() onSend;

  const _Composer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Escribe un mensaje',
                    // The counter under the field would take a line of the
                    // composer for a limit almost nobody reaches.
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: 'Enviar',
                onPressed: onSend,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
