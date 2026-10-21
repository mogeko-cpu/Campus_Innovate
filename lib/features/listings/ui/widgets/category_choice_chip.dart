import 'package:flutter/material.dart';

import '../../../../core/category_style.dart';

/// A category choice colored like the chip the finished card will show, so
/// picking one already previews how the project will look once published.
///
/// Shared by the publish and edit forms, which offer the same six categories.
class CategoryChoiceChip extends StatelessWidget {
  final String category;
  final bool selected;
  final VoidCallback onSelected;

  const CategoryChoiceChip({
    super.key,
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(context, category);

    return ChoiceChip(
      avatar: Icon(
        style.icon,
        size: 16,
        color: selected ? Colors.white : style.color,
      ),
      label: Text(category),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: style.color,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: selected ? FontWeight.w700 : null,
      ),
      side: BorderSide(color: style.color.withValues(alpha: selected ? 0 : 0.4)),
    );
  }
}
