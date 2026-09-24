import 'package:flutter/material.dart';

import '../avatar_color.dart';

/// A circle with someone's initials, colored from their name.
///
/// The one place that decides how a person is drawn across the app — the
/// project card, the comment thread, the group roster, the profile header —
/// so a color always means the same person everywhere it appears, and a new
/// screen gets that consistency by using this instead of building its own
/// `CircleAvatar`.
class NameAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const NameAvatar({super.key, required this.name, this.radius = 15});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AvatarColor.of(name);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.16),
      child: Text(
        AvatarColor.initialsOf(name),
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.62,
        ),
      ),
    );
  }
}
