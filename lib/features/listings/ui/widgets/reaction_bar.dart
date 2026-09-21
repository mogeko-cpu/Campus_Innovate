import 'package:flutter/material.dart';

import '../../domain/models/listing_stats.dart';
import '../../domain/models/reaction_type.dart';

/// Like and dislike, with the counters next to them, plus the views and
/// comments a project has collected.
///
/// The button you already pressed is filled; pressing it again takes the vote
/// back, which is why both buttons stay enabled once one is chosen.
class ReactionBar extends StatelessWidget {
  final ListingStats stats;
  final ValueChanged<ReactionType> onReact;

  /// Null while a vote is being written, to keep a double tap from sending two
  /// opposite writes.
  final bool isBusy;

  const ReactionBar({
    super.key,
    required this.stats,
    required this.onReact,
    this.isBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ReactionButton(
          icon: Icons.thumb_up_outlined,
          selectedIcon: Icons.thumb_up,
          label: '${stats.likes}',
          selected: stats.myReaction == ReactionType.like,
          onPressed: isBusy ? null : () => onReact(ReactionType.like),
        ),
        _ReactionButton(
          icon: Icons.thumb_down_outlined,
          selectedIcon: Icons.thumb_down,
          label: '${stats.dislikes}',
          selected: stats.myReaction == ReactionType.dislike,
          onPressed: isBusy ? null : () => onReact(ReactionType.dislike),
        ),
        _Passive(
          icon: Icons.visibility_outlined,
          label: stats.views == 1 ? '1 vista' : '${stats.views} vistas',
          color: colors.onSurfaceVariant,
        ),
        _Passive(
          icon: Icons.mode_comment_outlined,
          label: stats.comments == 1
              ? '1 comentario'
              : '${stats.comments} comentarios',
          color: colors.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  const _ReactionButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (selected) {
      return FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(selectedIcon, size: 18),
        label: Text(label),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(foregroundColor: colors.onSurfaceVariant),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _Passive extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Passive({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
