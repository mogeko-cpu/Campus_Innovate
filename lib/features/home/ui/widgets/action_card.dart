import 'package:flutter/material.dart';

import '../../../shell/ui/widgets/hero_decor.dart';

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final background = filled ? colors.primary : colors.surfaceContainerLow;
    final foreground = filled ? colors.onPrimary : colors.onSurface;

    // The filled one is the main thing to do on the screen: it gets the glow
    // the headers have, and a deeper crimson at one end so it reads as raised.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: filled ? heroShadow(colors) : null,
      ),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: filled ? null : Border.all(color: colors.outlineVariant),
              gradient: filled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primary,
                        Color.lerp(colors.primary, Colors.black, 0.22)!,
                      ],
                    )
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (filled) HeroDecor(color: foreground),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: foreground.withValues(alpha: filled ? 0.16 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, size: 26, color: foreground),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: foreground.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: foreground.withValues(alpha: 0.85),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
