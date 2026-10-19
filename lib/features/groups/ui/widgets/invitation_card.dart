import 'package:flutter/material.dart';

import '../../../../core/widgets/name_avatar.dart';
import '../../domain/models/group_invitation.dart';

/// An invitation waiting for the user's answer, with the two buttons to give it.
class InvitationCard extends StatelessWidget {
  final GroupInvitation invitation;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  /// Opens the group the invitation is for, so the person can look at it before
  /// deciding. Null where the card already sits inside that group's screen.
  final VoidCallback? onOpenGroup;

  const InvitationCard({
    super.key,
    required this.invitation,
    required this.isBusy,
    required this.onAccept,
    required this.onReject,
    this.onOpenGroup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.primaryContainer.withValues(alpha: 0.4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenGroup,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  NameAvatar(name: invitation.inviterName, radius: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invitation.groupName.isEmpty
                              ? 'Invitación a un grupo'
                              : invitation.groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${invitation.inviterName} te invitó a unirte',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isBusy ? null : onReject,
                    child: const Text('Rechazar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: isBusy ? null : onAccept,
                    child: const Text('Aceptar'),
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
