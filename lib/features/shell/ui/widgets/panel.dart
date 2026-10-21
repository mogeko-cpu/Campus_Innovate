import 'package:flutter/material.dart';

/// A raised surface that holds one part of a screen: the team, the board's
/// progress, the comments.
///
/// It is what gives the screens their layers: the page is the tinted ground,
/// and each panel sits on it a little lighter, with a soft shadow, so the eye
/// reads the sections as separate things before it reads a single word. Every
/// screen uses this instead of drawing its own, so the depth is the same
/// everywhere.
class Panel extends StatelessWidget {
  final Widget child;

  /// The heading inside the panel, when it has one.
  final String? title;

  /// Drawn before [title] in a small tinted square.
  final IconData? icon;

  /// The color of [icon] and its square; the primary color when null.
  final Color? accent;

  /// Next to the title: a count, a small action.
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const Panel({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.accent,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  /// The look of a panel, for the few places that need it on a widget of
  /// their own — a tappable card, an animated container.
  static BoxDecoration decorationOf(
    BuildContext context, {
    double radius = 20,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return BoxDecoration(
      color: color ??
          (dark ? colors.surfaceContainer : colors.surfaceContainerLowest),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: colors.outlineVariant.withValues(alpha: dark ? 0.35 : 0.55),
      ),
      boxShadow: [
        BoxShadow(
          color: colors.shadow.withValues(alpha: dark ? 0.28 : 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: colors.shadow.withValues(alpha: dark ? 0.2 : 0.04),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = accent ?? theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: tint),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Loose, so a long trailing text gives way on a narrow phone
                // instead of pushing the row past the edge.
                if (trailing != null) Flexible(child: trailing!),
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}
