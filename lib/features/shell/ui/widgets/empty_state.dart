import 'package:flutter/material.dart';

/// A friendly placeholder for empty lists, first-time screens and inline
/// errors: the icon sits inside a soft tinted circle instead of standing bare,
/// and an action can live right where the empty state is, so getting unstuck
/// never means leaving the screen to look for a button somewhere else.
///
/// Two shapes for the two places this shows up: [EmptyState.screen] centers
/// itself and fills the space of a whole tab; [EmptyState.inline] is a
/// compact bordered card sized to sit inside a list next to real content.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tint;
  final bool _compact;

  const EmptyState.screen({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tint,
  }) : _compact = false;

  const EmptyState.inline({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.tint,
  }) : _compact = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = tint ?? colors.primary;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _compact ? 52 : 76,
          height: _compact ? 52 : 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.12),
          ),
          child: Icon(icon, size: _compact ? 26 : 36, color: accent),
        ),
        SizedBox(height: _compact ? 12 : 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style:
              (_compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
                  ?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: _compact ? 14 : 20),
          FilledButton.tonalIcon(
            onPressed: onAction,
            icon: const Icon(Icons.add, size: 18),
            label: Text(actionLabel!),
          ),
        ],
      ],
    );

    if (_compact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: content,
      );
    }

    return Center(
      child: Padding(padding: const EdgeInsets.all(40), child: content),
    );
  }
}
