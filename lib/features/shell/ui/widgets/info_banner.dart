import 'package:flutter/material.dart';

/// A single-line status message with an icon: "this is your project",
/// "request sent — pending", an inline error. Unlike [EmptyState], this is not
/// about an empty collection — it tells the person where a specific thing
/// stands, so it keeps its left-aligned icon-and-text row instead of the
/// centered illustration treatment.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? tint;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = tint ?? colors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
