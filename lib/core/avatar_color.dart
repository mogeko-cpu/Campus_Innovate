import 'package:flutter/material.dart';

/// A color for an avatar, chosen from a person's name.
///
/// Deterministic and not random: the same name always lands on the same color,
/// in every card, every time the app is opened, without storing anything. The
/// palette is deliberately outside the brand's crimson/navy/gold — those two
/// already mean "this app", and reusing them for avatars would make every
/// person look like part of the interface chrome instead of a person.
abstract final class AvatarColor {
  static const _palette = [
    Color(0xFF2F6FED),
    Color(0xFF1E9E6B),
    Color(0xFFE07A1E),
    Color(0xFF7A4FE0),
    Color(0xFFD1447A),
    Color(0xFF1B8B9E),
    Color(0xFFB0793F),
    Color(0xFF4C6FA8),
  ];

  static Color of(String name) {
    if (name.isEmpty) return _palette.first;

    // Sums the code units instead of hashing: it only needs to be stable and
    // spread names across the palette, not to be a real hash function.
    final seed = name.codeUnits.fold<int>(0, (sum, unit) => sum + unit);

    return _palette[seed % _palette.length];
  }

  /// Two letters at most, so "Ana María Pérez" reads as "AP" and a
  /// single-word name still shows something.
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
