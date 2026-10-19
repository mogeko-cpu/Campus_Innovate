import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';
import '../viewmodels/notification_center.dart';

/// The bell with the unread count, for the app bar of every root screen.
///
/// It also starts the polling the first time one appears, so the screens that
/// show it do not each have to remember to.
class NotificationBell extends StatefulWidget {
  /// For the bell that sits on the gradient greeting, where the default icon
  /// color would not be readable.
  final Color? color;

  const NotificationBell({super.key, this.color});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  NotificationCenter get _center => Get.find<NotificationCenter>();

  @override
  void initState() {
    super.initState();
    _center.start();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final count = _center.unreadCount.value;

      return IconButton(
        tooltip: 'Notificaciones',
        visualDensity: VisualDensity.compact,
        onPressed: () async {
          await Get.toNamed(AppRoutes.notifications);
          await _center.refresh();
        },
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 9 ? '9+' : '$count'),
          child: Icon(Icons.notifications_outlined, color: widget.color),
        ),
      );
    });
  }
}
