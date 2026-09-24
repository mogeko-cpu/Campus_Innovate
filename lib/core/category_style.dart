import 'package:flutter/material.dart';

import '../features/listings/domain/models/listing_category.dart';

/// The color and icon a project category is drawn with.
///
/// A category is a `String` throughout the domain — nothing here changes that,
/// this is purely how the UI paints one. Every entry in [listingCategories]
/// has an entry here; a category the campus adds later without touching this
/// map falls back to the app's own primary color and a generic icon rather
/// than crashing the chip that draws it.
class CategoryStyle {
  final Color color;
  final IconData icon;

  const CategoryStyle(this.color, this.icon);

  static const _byName = <String, CategoryStyle>{
    'Tecnología': CategoryStyle(Color(0xFF2F6FED), Icons.memory_outlined),
    'Investigación': CategoryStyle(
      Color(0xFF7A4FE0),
      Icons.science_outlined,
    ),
    'Sostenibilidad': CategoryStyle(Color(0xFF1E9E6B), Icons.eco_outlined),
    'Emprendimiento': CategoryStyle(
      Color(0xFFE07A1E),
      Icons.rocket_launch_outlined,
    ),
    'Arte y Cultura': CategoryStyle(
      Color(0xFFD1447A),
      Icons.palette_outlined,
    ),
    'Impacto Social': CategoryStyle(
      Color(0xFF1B8B9E),
      Icons.volunteer_activism_outlined,
    ),
  };

  static CategoryStyle of(BuildContext context, String category) {
    final found = _byName[category];
    if (found != null) return found;

    return CategoryStyle(
      Theme.of(context).colorScheme.primary,
      Icons.lightbulb_outline,
    );
  }
}
