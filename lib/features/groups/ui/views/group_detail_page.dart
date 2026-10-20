import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/name_avatar.dart';
import '../../../../routes/app_routes.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../../shell/ui/widgets/info_banner.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_invitation.dart';
import '../../domain/models/group_member.dart';
import '../../domain/models/group_request.dart';
import '../viewmodels/group_detail_view_model.dart';
import '../widgets/invitation_card.dart';

/// Everything about one group in a single screen: its people, the requests
/// waiting on the owner, and what the group has published.
class GroupDetailPage extends GetView<GroupDetailViewModel> {
  const GroupDetailPage({super.key});

  void _toast(String title, String message) => Get.snackbar(
        title,
        message,
        snackPosition: SnackPosition.BOTTOM,
      );

  /// Opens another screen on top of this one and comes back to a fresh group.
  ///
  /// The timer is paused while the other screen is up: the chat and the invite
  /// list poll for themselves, and two screens asking ROBLE about the same group
  /// at once only spends the rate limit.
  Future<void> _openRoute(String route) async {
    controller.pauseRefresh();
    await Get.toNamed(route);
    controller.resumeRefresh();
    await controller.load(silent: true);
  }

  /// Asks for a short note and sends the request.
  Future<void> _askToJoin() async {
    // The dialog hands back what was written, or null when it was cancelled.
    final message = await Get.dialog<String>(const _JoinRequestDialog());

    if (message == null) return;

    final sent = await controller.requestToJoin(message);

    if (sent) {
      _toast('Solicitud enviada', 'El creador del grupo la va a revisar');
    } else {
      _toast('Error', controller.error.value ?? 'No se pudo enviar');
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('¿Eliminar el grupo?'),
        content: const Text(
          'Se van a borrar sus integrantes, las solicitudes e invitaciones '
          'pendientes y el chat. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deleted = await controller.deleteGroup();

    if (deleted) {
      Get.back();
      _toast('Grupo eliminado', 'Ya no aparece en el campus');
    } else {
      _toast('No se pudo eliminar', controller.error.value ?? '');
    }
  }

  Future<void> _confirmLeave() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('¿Salir del grupo?'),
        content: const Text(
          'Vas a dejar de ser integrante. Puedes volver a solicitar ingreso '
          'más adelante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (await controller.leave()) {
      _toast('Listo', 'Saliste del grupo');
    } else {
      _toast('Error', controller.error.value ?? 'No se pudo salir del grupo');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupo'),
        actions: [
          Obx(() {
            if (!controller.isOwner) return const SizedBox.shrink();

            return IconButton(
              tooltip: 'Eliminar grupo',
              onPressed: controller.isWorking.value ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline),
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final group = controller.group.value;

        if (group == null) {
          return Center(
            child: Text(controller.error.value ?? 'Grupo no encontrado'),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _Header(group: group),
              if (controller.error.value != null) ...[
                const SizedBox(height: 16),
                InfoBanner(
                  icon: Icons.error_outline,
                  text: controller.error.value!,
                  tint: Theme.of(context).colorScheme.error,
                ),
              ],
              const SizedBox(height: 24),
              _JoinAction(
                isOwner: controller.isOwner,
                isMember: controller.isMember,
                isBusy: controller.isWorking.value,
                myRequest: controller.myRequest.value,
                myInvitation: controller.myInvitation.value,
                onAskToJoin: _askToJoin,
                onLeave: _confirmLeave,
                onAcceptInvitation: () async {
                  final done = await controller.acceptMyInvitation();

                  _toast(
                    done ? 'Bienvenido al grupo' : 'Error',
                    done
                        ? 'Ya eres integrante'
                        : controller.error.value ?? 'No se pudo aceptar',
                  );
                },
                onRejectInvitation: () async {
                  final done = await controller.rejectMyInvitation();

                  _toast(
                    done ? 'Invitación rechazada' : 'Error',
                    done
                        ? 'Se avisó a quien te invitó'
                        : controller.error.value ?? 'No se pudo rechazar',
                  );
                },
              ),
              if (controller.isInside) ...[
                const SizedBox(height: 12),
                _MemberActions(
                  onChat: () => _openRoute(AppRoutes.chatOf(group.id)),
                  onInvite: () => _openRoute(AppRoutes.inviteOf(group.id)),
                ),
              ],
              const SizedBox(height: 28),
              _SectionTitle(
                title: 'Integrantes',
                trailing: '${group.memberCount}',
              ),
              const SizedBox(height: 10),
              for (final member in group.members)
                _MemberTile(
                  member: member,
                  isOwner: group.isOwner(member.userId),
                  canRemove: controller.isOwner &&
                      !group.isOwner(member.userId) &&
                      !controller.isWorking.value,
                  onRemove: () async {
                    final removed =
                        await controller.removeMember(member.userId);

                    _toast(
                      removed ? 'Listo' : 'Error',
                      removed
                          ? '${member.userName} salió del grupo'
                          : controller.error.value ?? 'No se pudo quitar',
                    );
                  },
                ),
              if (controller.isOwner) ...[
                const SizedBox(height: 28),
                _SectionTitle(
                  title: 'Solicitudes',
                  trailing: '${controller.pendingRequests.length}',
                ),
                const SizedBox(height: 10),
                if (controller.pendingRequests.isEmpty)
                  const EmptyState.inline(
                    icon: Icons.inbox_outlined,
                    title: 'No hay solicitudes pendientes',
                  )
                else
                  for (final request in controller.pendingRequests)
                    _RequestTile(
                      request: request,
                      isBusy: controller.isWorking.value,
                      onAccept: () async {
                        final done = await controller.accept(request.id);

                        _toast(
                          done ? 'Solicitud aceptada' : 'Error',
                          done
                              ? '${request.applicantName} ya es integrante'
                              : controller.error.value ?? 'No se pudo aceptar',
                        );
                      },
                      onReject: () async {
                        final done = await controller.reject(request.id);

                        _toast(
                          done ? 'Solicitud rechazada' : 'Error',
                          done
                              ? 'Se le avisó a la persona'
                              : controller.error.value ?? 'No se pudo rechazar',
                        );
                      },
                    ),
              ],
              if (controller.isInside && controller.invitations.isNotEmpty) ...[
                const SizedBox(height: 28),
                _SectionTitle(
                  title: 'Invitaciones enviadas',
                  trailing: '${controller.invitations.length}',
                ),
                const SizedBox(height: 10),
                for (final invitation in controller.invitations)
                  _InvitationTile(
                    invitation: invitation,
                    canCancel: controller.canCancel(invitation),
                    isBusy: controller.isWorking.value,
                    onCancel: () async {
                      final done =
                          await controller.cancelInvitation(invitation.id);

                      _toast(
                        done ? 'Invitación cancelada' : 'Error',
                        done
                            ? 'Ya no está pendiente'
                            : controller.error.value ?? 'No se pudo cancelar',
                      );
                    },
                  ),
              ],
              const SizedBox(height: 28),
              _SectionTitle(
                title: 'Proyectos del grupo',
                trailing: '${controller.projects.length}',
              ),
              const SizedBox(height: 10),
              if (controller.projects.isEmpty)
                const EmptyState.inline(
                  icon: Icons.work_outline,
                  title: 'Este grupo todavía no ha publicado proyectos',
                )
              else
                for (final listing in controller.projects)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      title: Text(listing.title),
                      subtitle: Text(
                        '${listing.memberIds.length} de ${listing.maxMembers} '
                        'integrantes · ${listing.category}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openRoute(AppRoutes.detailOf(listing.id)),
                    ),
                  ),
            ],
          ),
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  final Group group;

  const _Header({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.primaryContainer,
              child: Icon(
                Icons.groups_outlined,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                group.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (group.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(group.description, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 12),
        Text(
          'Creado por ${group.ownerName}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// What this person can do with the group, which depends entirely on who they
/// are to it.
class _JoinAction extends StatelessWidget {
  final bool isOwner;
  final bool isMember;
  final bool isBusy;
  final GroupRequest? myRequest;
  final GroupInvitation? myInvitation;
  final Future<void> Function() onAskToJoin;
  final Future<void> Function() onLeave;
  final Future<void> Function() onAcceptInvitation;
  final Future<void> Function() onRejectInvitation;

  /// Every flag arrives as a parameter instead of being read off the view model
  /// here: the reactive reads have to happen inside the `Obx` that builds this
  /// widget, and a `build` method runs later, outside it.
  const _JoinAction({
    required this.isOwner,
    required this.isMember,
    required this.isBusy,
    required this.myRequest,
    required this.myInvitation,
    required this.onAskToJoin,
    required this.onLeave,
    required this.onAcceptInvitation,
    required this.onRejectInvitation,
  });

  @override
  Widget build(BuildContext context) {
    if (isOwner) {
      return const InfoBanner(
        icon: Icons.verified_outlined,
        text: 'Este grupo es tuyo. Acepta o rechaza las solicitudes abajo.',
      );
    }

    if (isMember) {
      return OutlinedButton.icon(
        onPressed: isBusy ? null : onLeave,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        icon: const Icon(Icons.logout),
        label: const Text('Salir del grupo'),
      );
    }

    final invitation = myInvitation;

    // Somebody invited this person: the answer is the only thing to ask for.
    if (invitation != null) {
      return InvitationCard(
        invitation: invitation,
        isBusy: isBusy,
        onAccept: onAcceptInvitation,
        onReject: onRejectInvitation,
      );
    }

    if (myRequest != null) {
      return InfoBanner(
        icon: Icons.schedule,
        text: 'Solicitud enviada — estado: ${myRequest!.status.label}.',
      );
    }

    return FilledButton.icon(
      onPressed: isBusy ? null : onAskToJoin,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      icon: const Icon(Icons.group_add_outlined),
      label: const Text('Solicitar ingreso'),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupMember member;
  final bool isOwner;
  final bool canRemove;
  final Future<void> Function() onRemove;

  const _MemberTile({
    required this.member,
    required this.isOwner,
    required this.canRemove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: NameAvatar(name: member.userName, radius: 18),
        title: Text(member.userName),
        subtitle: Text(isOwner ? 'Creador' : 'Integrante'),
        trailing: canRemove
            ? IconButton(
                tooltip: 'Quitar del grupo',
                onPressed: onRemove,
                icon: const Icon(Icons.person_remove_outlined),
              )
            : null,
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final GroupRequest request;
  final bool isBusy;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  const _RequestTile({
    required this.request,
    required this.isBusy,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.applicantName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (request.message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                request.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;

  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}


/// The note that goes with a request to join.
///
/// Its own widget so the text controller lives exactly as long as the field: the
/// dialog is still animating out, with the field attached, when `Get.dialog`
/// returns, and disposing the controller at that point broke the closing frames.
class _JoinRequestDialog extends StatefulWidget {
  const _JoinRequestDialog();

  @override
  State<_JoinRequestDialog> createState() => _JoinRequestDialogState();
}

class _JoinRequestDialogState extends State<_JoinRequestDialog> {
  final _message = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Solicitar ingreso'),
      content: TextField(
        controller: _message,
        maxLines: 3,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: '¿Por qué quieres entrar y qué aportas?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Get.back(result: _message.text),
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

/// The two things somebody inside the group can do that an outsider cannot:
/// talk to the others and bring somebody in.
class _MemberActions extends StatelessWidget {
  final VoidCallback onChat;
  final VoidCallback onInvite;

  const _MemberActions({required this.onChat, required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onChat,
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Chat'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Invitar'),
          ),
        ),
      ],
    );
  }
}

/// An invitation somebody inside the group sent and nobody has answered.
class _InvitationTile extends StatelessWidget {
  final GroupInvitation invitation;
  final bool canCancel;
  final bool isBusy;
  final Future<void> Function() onCancel;

  const _InvitationTile({
    required this.invitation,
    required this.canCancel,
    required this.isBusy,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: NameAvatar(name: invitation.inviteeName, radius: 18),
        title: Text(invitation.inviteeName),
        subtitle: Text('Invitó ${invitation.inviterName} · pendiente'),
        trailing: canCancel
            ? IconButton(
                tooltip: 'Cancelar invitación',
                onPressed: isBusy ? null : onCancel,
                icon: const Icon(Icons.close),
              )
            : null,
      ),
    );
  }
}
