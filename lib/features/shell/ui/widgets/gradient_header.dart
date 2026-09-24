import 'package:flutter/material.dart';

/// A crimson-to-navy banner for the screens that deserve one glance of
/// identity before their list starts — Ranking and Groups open on a plain
/// [AppBar] otherwise, the same visual weight as every other screen even
/// though what they hold is the campus-wide picture, not just "my stuff".
///
/// [Profile]'s own header uses the same gradient for the same reason; this
/// widget is the version for a page that needs the color but not an avatar.
class GradientHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  /// Small stat chips shown under the subtitle — e.g. "4 grupos", "12
  /// proyectos" — so the header carries real numbers, not just decoration.
  final List<(String value, String label)> stats;

  const GradientHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.stats = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.secondary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                for (final (value, label) in stats) ...[
                  _StatChip(value: value, label: label),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;

  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
