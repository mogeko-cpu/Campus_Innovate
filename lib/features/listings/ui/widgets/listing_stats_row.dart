import 'package:flutter/material.dart';

import '../../domain/models/listing_stats.dart';

/// The counters of a project, read-only, for cards and lists.
///
/// Zeroes are shown instead of hidden: a project with no likes yet is
/// information, and a row whose icons appeared one by one would make every card
/// a different height.
class ListingStatsRow extends StatelessWidget {
  final ListingStats stats;

  const ListingStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      children: [
        _Counter(
          icon: Icons.thumb_up_outlined,
          value: stats.likes,
          color: colors.primary,
        ),
        const SizedBox(width: 14),
        _Counter(
          icon: Icons.thumb_down_outlined,
          value: stats.dislikes,
          color: colors.outline,
        ),
        const SizedBox(width: 14),
        _Counter(
          icon: Icons.visibility_outlined,
          value: stats.views,
          color: colors.outline,
        ),
        const SizedBox(width: 14),
        _Counter(
          icon: Icons.mode_comment_outlined,
          value: stats.comments,
          color: colors.outline,
        ),
      ],
    );
  }
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;

  const _Counter({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: theme.textTheme.labelMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
