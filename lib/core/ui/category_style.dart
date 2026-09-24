import 'package:flutter/material.dart';

import '../../features/listings/domain/models/listing_category.dart';

/// The color and icon that stand for one project category.
///
/// A fixed lookup rather than something derived from the string, because a
/// category is one of the six in [listingCategories] — a closed, known set —
/// and giving each of them a color and icon the person can learn is worth more
/// than any rule that generated one automatically.
class CategoryStyle {
  final Color color;
  final IconData icon;

  const CategoryStyle._(this.color, this.icon);

  static const _byCategory = <String, CategoryStyle>{
    'Tecnología': CategoryStyle._(Color(0xFF3D5AFE), Icons.memory_outlined),
    'Investigación': CategoryStyle._(
      Color(0xFF6A4C93),
      Icons.science_outlined,
    ),
    'Sostenibilidad': CategoryStyle._(Color(0xFF2E7D32), Icons.eco_outlined),
    'Emprendimiento': CategoryStyle._(
      Color(0xFFEF6C00),
      Icons.rocket_launch_outlined,
    ),
    'Arte y Cultura': CategoryStyle._(
      Color(0xFFD81B60),
      Icons.palette_outlined,
    ),
    'Impacto Social': CategoryStyle._(
      Color(0xFF00838F),
      Icons.volunteer_activism_outlined,
    ),
  };

  /// Falls back to the app's own primary color and a generic folder icon for a
  /// category outside the known six, so a value typed by hand in ROBLE (or a
  /// category retired later) still renders instead of crashing the card.
  static CategoryStyle of(BuildContext context, String category) {
    final found = _byCategory[category];
    if (found != null) return found;

    return CategoryStyle._(
      Theme.of(context).colorScheme.primary,
      Icons.folder_outlined,
    );
  }
}
