import 'package:flutter/material.dart';

import '../../domain/models/listing_status.dart';

/// Where a project stands, as a small colored pill.
class StatusChip extends StatelessWidget {
  final ListingStatus status;

  const StatusChip({super.key, required this.status});

  /// One color and icon per state, the same everywhere the state shows.
  static ({Color color, IconData icon}) styleOf(ListingStatus status) =>
      switch (status) {
        ListingStatus.idea => (
            color: const Color(0xFFE07A1E),
            icon: Icons.lightbulb_outline,
          ),
        ListingStatus.inProgress => (
            color: const Color(0xFF2F6FED),
            icon: Icons.play_circle_outline,
          ),
        ListingStatus.paused => (
            color: const Color(0xFF7B8794),
            icon: Icons.pause_circle_outline,
          ),
        ListingStatus.done => (
            color: const Color(0xFF1E9E6B),
            icon: Icons.check_circle_outline,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final style = styleOf(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: style.color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
