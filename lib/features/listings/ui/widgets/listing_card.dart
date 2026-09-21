import 'package:flutter/material.dart';

import '../../domain/models/listing.dart';
import '../../domain/models/listing_stats.dart';
import 'listing_stats_row.dart';

class ListingCard extends StatelessWidget {
  final Listing listing;
  final VoidCallback onTap;

  /// Counters to show under the card. Null on the screens that do not load
  /// them, so the card keeps working without the engagement tables.
  final ListingStats? stats;

  /// Shown before the category, for the position badge of the ranking.
  final Widget? leading;

  const ListingCard({
    super.key,
    required this.listing,
    required this.onTap,
    this.stats,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 10),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      listing.category,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _SlotsBadge(listing: listing),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                listing.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                listing.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (listing.requiredSkills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final skill in listing.requiredSkills)
                      Chip(
                        label: Text(skill),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
              if (listing.belongsToGroup) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.groups_outlined,
                      size: 15,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        listing.groupName.isEmpty
                            ? 'Grupo del campus'
                            : listing.groupName,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (stats != null) ...[
                const SizedBox(height: 12),
                ListingStatsRow(stats: stats!),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: colors.secondaryContainer,
                    child: Text(
                      listing.creatorName.characters.first,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      listing.creatorName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Icon(Icons.group_outlined, size: 16, color: colors.outline),
                  const SizedBox(width: 4),
                  Text(
                    '${listing.memberIds.length}/${listing.maxMembers}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotsBadge extends StatelessWidget {
  final Listing listing;

  const _SlotsBadge({required this.listing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (listing.isFull) {
      return Text(
        'Equipo completo',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final slots = listing.availableSlots;

    return Text(
      slots == 1 ? '1 cupo libre' : '$slots cupos libres',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
