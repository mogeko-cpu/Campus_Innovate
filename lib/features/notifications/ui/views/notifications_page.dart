import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/notification_target.dart';
import '../../domain/models/notification_type.dart';
import '../viewmodels/notification_center.dart';

/// Everything the app has told the person, newest first.
class NotificationsPage extends GetView<NotificationCenter> {
  const NotificationsPage({super.key});

  Future<void> _open(AppNotification notification) async {
    await controller.markRead(notification);

    switch (notification.target) {
      case NotificationTarget.listing:
        await Get.toNamed(AppRoutes.detailOf(notification.targetId));
      case NotificationTarget.group:
        await Get.toNamed(AppRoutes.groupOf(notification.targetId));
      case NotificationTarget.none:
        return;
    }

    await controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: 'Marcar todas como leídas',
              onPressed:
                  controller.unreadCount.value == 0 ? null : controller.markAllRead,
              icon: const Icon(Icons.done_all),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final items = controller.notifications.toList();

        if (items.isEmpty) {
          return const EmptyState.screen(
            icon: Icons.notifications_none,
            title: 'Todavía no tienes notificaciones',
            message: 'Te avisaremos cuando comenten tus proyectos, respondan '
                'tus solicitudes o te inviten a un grupo.',
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) => _NotificationTile(
              notification: items[index],
              onTap: () => _open(items[index]),
            ),
          ),
        );
      }),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = _styleOf(notification.type, colors);
    final unread = !notification.isRead;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: unread ? colors.primaryContainer.withValues(alpha: 0.35) : null,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: style.color.withValues(alpha: 0.14),
          child: Icon(style.icon, color: style.color, size: 20),
        ),
        title: Text(
          notification.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: unread ? FontWeight.w700 : null),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              _timeAgo(notification.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: unread
            ? Icon(Icons.circle, size: 10, color: colors.primary)
            : null,
      ),
    );
  }

  static ({IconData icon, Color color}) _styleOf(
    NotificationType? type,
    ColorScheme colors,
  ) {
    const green = Color(0xFF1E9E6B);

    return switch (type) {
      NotificationType.comment => (
          icon: Icons.mode_comment_outlined,
          color: colors.primary,
        ),
      NotificationType.ideaPublished => (
          icon: Icons.lightbulb_outline,
          color: const Color(0xFFE07A1E),
        ),
      NotificationType.requestReceived => (
          icon: Icons.person_add_alt_1_outlined,
          color: colors.primary,
        ),
      NotificationType.requestAccepted => (
          icon: Icons.check_circle_outline,
          color: green,
        ),
      NotificationType.requestRejected => (
          icon: Icons.cancel_outlined,
          color: colors.error,
        ),
      NotificationType.invitationReceived => (
          icon: Icons.mail_outline,
          color: colors.primary,
        ),
      NotificationType.invitationAccepted => (
          icon: Icons.check_circle_outline,
          color: green,
        ),
      NotificationType.invitationRejected => (
          icon: Icons.cancel_outlined,
          color: colors.error,
        ),
      NotificationType.taskAssigned => (
          icon: Icons.task_alt,
          color: colors.primary,
        ),
      NotificationType.memberRemoved => (
          icon: Icons.person_remove_outlined,
          color: colors.error,
        ),
      NotificationType.roleChanged => (
          icon: Icons.manage_accounts_outlined,
          color: const Color(0xFF7A4FE0),
        ),
      null => (icon: Icons.notifications_outlined, color: colors.primary),
    };
  }

  /// "hace 5 min", in the shortest unit that is still accurate.
  static String _timeAgo(DateTime moment) {
    final elapsed = DateTime.now().difference(moment);

    if (elapsed.inMinutes < 1) return 'ahora';
    if (elapsed.inMinutes < 60) return 'hace ${elapsed.inMinutes} min';
    if (elapsed.inHours < 24) return 'hace ${elapsed.inHours} h';

    return 'hace ${elapsed.inDays} d';
  }
}
