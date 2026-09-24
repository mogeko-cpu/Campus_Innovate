import 'package:flutter/material.dart';

/// A color for someone's avatar, picked from their name.
///
/// Deterministic — the same name always lands on the same color — so a person
/// keeps looking like themselves across the project card, the group roster and
/// the comments, without the app storing a color anywhere.
abstract final class AvatarColor {
  static const _palette = <Color>[
    Color(0xFF9E1B32), // crimson, the app's own primary
    Color(0xFF1F2A44), // navy
    Color(0xFF2E7D32), // green
    Color(0xFF6A4C93), // purple
    Color(0xFFEF6C00), // orange
    Color(0xFF00838F), // teal
    Color(0xFFD81B60), // pink
    Color(0xFFB08D3F), // gold
  ];

  static Color of(String name) {
    if (name.isEmpty) return _palette.first;

    // Sums the code units instead of using Dart's own `hashCode`, which is not
    // guaranteed stable across app runs or platforms — the whole point here is
    // that the same name always lands on the same color.
    final sum = name.codeUnits.fold<int>(0, (total, unit) => total + unit);

    return _palette[sum % _palette.length];
  }

  /// White reads on every color in [_palette] — they are all dark or mid-tone —
  /// so initials never need a second color computed from the first.
  static const onColor = Colors.white;
}
