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
          count: stats.likes,
          selected: stats.myReaction == ReactionType.like,
          onPressed: isBusy ? null : () => onReact(ReactionType.like),
        ),
        _ReactionButton(
          icon: Icons.thumb_down_outlined,
          selectedIcon: Icons.thumb_down,
          count: stats.dislikes,
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

/// A vote button that bounces when it becomes the selected one.
///
/// The bounce plays on the transition into `selected`, never on the transition
/// out of it or on an unrelated rebuild: pressing "like" should feel like it
/// landed, but the button quietly turning back to outline when you undo it, or
/// redrawing after a reload, should not replay the same flourish.
class _ReactionButton extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final int count;
  final bool selected;
  final VoidCallback? onPressed;

  const _ReactionButton({
    required this.icon,
    required this.selectedIcon,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0), weight: 55),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void didUpdateWidget(_ReactionButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.selected && !oldWidget.selected) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final button = widget.selected
        ? FilledButton.tonalIcon(
            onPressed: widget.onPressed,
            icon: Icon(widget.selectedIcon, size: 18),
            label: _AnimatedCount(count: widget.count),
          )
        : OutlinedButton.icon(
            onPressed: widget.onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
            ),
            icon: Icon(widget.icon, size: 18),
            label: _AnimatedCount(count: widget.count),
          );

    return ScaleTransition(scale: _scale, child: button);
  }
}

/// A counter that slides the new value in and the old one out, instead of
/// snapping straight to the new number.
class _AnimatedCount extends StatelessWidget {
  final int count;

  const _AnimatedCount({required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text('$count', key: ValueKey(count)),
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
