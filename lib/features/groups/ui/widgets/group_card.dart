import 'package:flutter/material.dart';

import '../../domain/models/group.dart';

/// One group in a list: who runs it, how many people are in it and how much it
/// has published.
class GroupCard extends StatelessWidget {
  final Group group;
  final int projectCount;

  /// Short word for the user's relationship with this group — "Creador",
  /// "Integrante", "Solicitud pendiente" — or null when there is none.
  final String? badge;

  final VoidCallback onTap;

  const GroupCard({
    super.key,
    required this.group,
    required this.projectCount,
    required this.onTap,
    this.badge,
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
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(
                      Icons.groups_outlined,
                      size: 19,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      group.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSecondaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (group.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  group.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: colors.outline),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      group.ownerName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Icon(Icons.group_outlined, size: 16, color: colors.outline),
                  const SizedBox(width: 4),
                  Text('${group.memberCount}', style: theme.textTheme.bodySmall),
                  const SizedBox(width: 12),
                  Icon(Icons.work_outline, size: 16, color: colors.outline),
                  const SizedBox(width: 4),
                  Text('$projectCount', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
