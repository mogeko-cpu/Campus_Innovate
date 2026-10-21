import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/name_avatar.dart';
import '../../../../routes/app_routes.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../../shell/ui/widgets/info_banner.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_comment.dart';
import '../../domain/models/listing_member.dart';
import '../../domain/models/listing_role.dart';
import '../../domain/models/listing_status.dart';
import '../../domain/models/listing_task.dart';
import '../viewmodels/listing_detail_view_model.dart';
import '../viewmodels/requests_view_model.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/status_chip.dart';

class ListingDetailPage extends GetView<ListingDetailViewModel> {
  const ListingDetailPage({super.key});

  void _toast(String title, String message) =>
      Get.snackbar(title, message, snackPosition: SnackPosition.BOTTOM);

  static String _nameOf(ListingMember member) =>
      member.userName.isEmpty ? 'Integrante sin nombre' : member.userName;

  Future<void> _openAndReload(String route) async {
    await Get.toNamed(route);
    await controller.load();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await confirmAction(
      title: '¿Eliminar el proyecto?',
      message: 'Se van a borrar su equipo, sus solicitudes, sus tareas, sus '
          'comentarios y sus valoraciones. Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );

    if (!confirmed) return;

    final deleted = await controller.deleteListing();

    if (deleted) {
      Get.back();
      Get.snackbar(
        'Proyecto eliminado',
        'Ya no aparece en el campus',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar(
        'No se pudo eliminar',
        controller.error.value ?? '',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _remove(ListingMember member) async {
    final name = _nameOf(member);

    final confirmed = await confirmAction(
      title: '¿Quitar a $name del equipo?',
      message: 'Deja de ser parte del proyecto y sus tareas quedan sin '
          'asignar.',
      confirmLabel: 'Quitar',
    );
    if (!confirmed) return;

    final done = await controller.removeMember(member);

    _toast(
      done ? 'Listo' : 'No se pudo quitar',
      done
          ? '$name ya no está en el equipo'
          : controller.error.value ?? 'Intenta de nuevo',
    );
  }

  Future<void> _setRole(ListingMember member, ListingRole role) async {
    final name = _nameOf(member);
    final done = await controller.setRole(member, role);

    _toast(
      done ? 'Rol actualizado' : 'No se pudo cambiar el rol',
      done
          ? '$name ahora es ${role.label.toLowerCase()}'
          : controller.error.value ?? 'Intenta de nuevo',
    );
  }

  Future<void> _transfer(ListingMember member) async {
    final name = _nameOf(member);

    final confirmed = await confirmAction(
      title: '¿Transferir el liderazgo?',
      message: '$name pasará a dirigir el proyecto y tú quedarás como '
          'integrante.',
      confirmLabel: 'Transferir',
    );
    if (!confirmed) return;

    final done = await controller.transferLeadership(member);

    _toast(
      done ? 'Liderazgo transferido' : 'No se pudo transferir',
      done
          ? '$name ahora lidera el proyecto'
          : controller.error.value ?? 'Intenta de nuevo',
    );
  }

  Future<void> _leave() async {
    final confirmed = await confirmAction(
      title: '¿Salir del proyecto?',
      message: 'Dejarás de ser parte del equipo y tus tareas quedarán sin '
          'asignar.',
      confirmLabel: 'Salir',
    );
    if (!confirmed) return;

    final done = await controller.leave();

    _toast(
      done ? 'Saliste del proyecto' : 'No se pudo salir',
      done
          ? 'Ya no haces parte del equipo'
          : controller.error.value ?? 'Intenta de nuevo',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del proyecto'),
        actions: [
          Obx(() {
            final listing = controller.listing.value;
            if (listing == null || !controller.isLeader) {
              return const SizedBox.shrink();
            }

            final busy = controller.isWorking.value;

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Editar proyecto',
                  onPressed: busy
                      ? null
                      : () => _openAndReload(AppRoutes.editOf(listing.id)),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Eliminar proyecto',
                  onPressed: busy ? null : _confirmDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            );
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final listing = controller.listing.value;

        if (listing == null) {
          return Center(
            child: Text(controller.error.value ?? 'Proyecto no encontrado'),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _Header(listing: listing),
            const SizedBox(height: 24),
            _Section(
              title: 'Sobre el proyecto',
              child: Text(
                listing.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (listing.requiredSkills.isNotEmpty) ...[
              const SizedBox(height: 24),
              _Section(
                title: 'Habilidades buscadas',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final skill in listing.requiredSkills)
                      Chip(label: Text(skill)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _Section(
              title: 'Equipo',
              child: _TeamSection(
                listing: listing,
                team: controller.team,
                currentUserId: controller.currentUserId,
                isLeader: controller.isLeader,
                isBusy: controller.isWorking.value,
                onRemove: _remove,
                onSetRole: _setRole,
                onTransfer: _transfer,
                onLeave: _leave,
              ),
            ),
            if (controller.myRole != null) ...[
              const SizedBox(height: 24),
              _Section(
                title: 'Tareas',
                child: _TasksSummary(
                  progress: controller.progress.value,
                  onOpen: () => _openAndReload(AppRoutes.tasksOf(listing.id)),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _Section(
              title: 'Valoración',
              child: ReactionBar(
                stats: controller.stats.value,
                isBusy: controller.isWorking.value,
                onReact: controller.react,
              ),
            ),
            const SizedBox(height: 32),
            _JoinAction(controller: controller, listing: listing),
            if (controller.isLeader) ...[
              const SizedBox(height: 32),
              _Section(
                title: 'Solicitudes recibidas',
                child: _RequestsInbox(
                  listingId: listing.id,
                  listingTitle: listing.title,
                  revision: controller.revision.value,
                ),
              ),
            ],
            const SizedBox(height: 32),
            _Section(
              title: 'Comentarios (${controller.stats.value.comments})',
              child: _Comments(
                comments: controller.comments.toList(),
                isBusy: controller.isWorking.value,
                canDelete: controller.canDeleteComment,
                onSend: controller.comment,
                onDelete: controller.deleteComment,
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  final Listing listing;

  const _Header({required this.listing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
            StatusChip(status: listing.status),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          listing.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            NameAvatar(name: listing.creatorName, radius: 16),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.creatorName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Creador del proyecto',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(Icons.groups_outlined, size: 17, color: colors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                // Projects published before groups existed have no group, and
                // they are still real projects: the screen says so instead of
                // pretending otherwise.
                listing.belongsToGroup
                    ? 'Publicado por ${listing.groupName.isEmpty ? 'un grupo del campus' : listing.groupName}'
                    : 'Publicado sin grupo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _JoinAction extends StatelessWidget {
  final ListingDetailViewModel controller;
  final Listing listing;

  const _JoinAction({required this.controller, required this.listing});

  @override
  Widget build(BuildContext context) {
    if (controller.isLeader) {
      return const InfoBanner(
        icon: Icons.verified_outlined,
        text: 'Este es tu proyecto.',
      );
    }

    if (controller.isMember) {
      return const InfoBanner(
        icon: Icons.check_circle_outline,
        text: 'Ya formas parte de este equipo.',
      );
    }

    final request = controller.myRequest.value;

    if (request != null) {
      return InfoBanner(
        icon: Icons.schedule,
        text: 'Solicitud enviada — estado: ${request.status.label}.',
      );
    }

    if (listing.status == ListingStatus.done) {
      return const InfoBanner(
        icon: Icons.check_circle_outline,
        text: 'Este proyecto ya terminó y no recibe solicitudes.',
      );
    }

    if (!listing.status.acceptsRequests) {
      return const InfoBanner(
        icon: Icons.pause_circle_outline,
        text: 'Este proyecto está pausado y no recibe solicitudes por ahora.',
      );
    }

    if (listing.isFull) {
      return const InfoBanner(
        icon: Icons.group_off_outlined,
        text: 'El equipo ya está completo.',
      );
    }

    return FilledButton.icon(
      onPressed: () async {
        await Get.toNamed(AppRoutes.joinOf(listing.id));
        await controller.load();
      },
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      icon: const Icon(Icons.group_add_outlined),
      label: const Text('Solicitar unirme'),
    );
  }
}

/// Who is on the team and what each one is, with what the leader can do about
/// it and the way out for everybody else.
class _TeamSection extends StatelessWidget {
  final Listing listing;
  final List<ListingMember> team;
  final String currentUserId;
  final bool isLeader;
  final bool isBusy;
  final Future<void> Function(ListingMember) onRemove;
  final Future<void> Function(ListingMember, ListingRole) onSetRole;
  final Future<void> Function(ListingMember) onTransfer;
  final Future<void> Function() onLeave;

  /// Every value arrives as a parameter, read inside the page's `Obx`: a
  /// `build` method runs later, outside it, and would not notice a change.
  const _TeamSection({
    required this.listing,
    required this.team,
    required this.currentUserId,
    required this.isLeader,
    required this.isBusy,
    required this.onRemove,
    required this.onSetRole,
    required this.onTransfer,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isOnTeam = team.any((member) => member.userId == currentUserId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.group_outlined, color: colors.primary),
            const SizedBox(width: 10),
            Text(
              '${listing.memberIds.length} de ${listing.maxMembers} integrantes',
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final member in team)
          _MemberTile(
            member: member,
            isMe: member.userId == currentUserId,
            canManage: isLeader &&
                member.userId != currentUserId &&
                member.role != ListingRole.leader,
            isBusy: isBusy,
            onRemove: () => onRemove(member),
            onToggleMentor: () => onSetRole(
              member,
              member.role == ListingRole.mentor
                  ? ListingRole.member
                  : ListingRole.mentor,
            ),
            onTransfer: () => onTransfer(member),
          ),
        if (isOnTeam && !isLeader) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onLeave,
            icon: const Icon(Icons.logout),
            label: const Text('Salir del proyecto'),
          ),
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final ListingMember member;
  final bool isMe;
  final bool canManage;
  final bool isBusy;
  final VoidCallback onRemove;
  final VoidCallback onToggleMentor;
  final VoidCallback onTransfer;

  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canManage,
    required this.isBusy,
    required this.onRemove,
    required this.onToggleMentor,
    required this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    final name = ListingDetailPage._nameOf(member);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: NameAvatar(name: member.userName, radius: 17),
      title: Text(name),
      subtitle: Text(isMe ? '${member.role.label} · tú' : member.role.label),
      trailing: canManage
          ? PopupMenuButton<String>(
              tooltip: 'Opciones de $name',
              enabled: !isBusy,
              onSelected: (choice) => switch (choice) {
                'role' => onToggleMentor(),
                'leader' => onTransfer(),
                _ => onRemove(),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'role',
                  child: Text(
                    member.role == ListingRole.mentor
                        ? 'Hacer integrante'
                        : 'Hacer mentor',
                  ),
                ),
                const PopupMenuItem(
                  value: 'leader',
                  child: Text('Transferir liderazgo'),
                ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Quitar del proyecto'),
                ),
              ],
            )
          : null,
    );
  }
}

/// How far along the board is, with the way into it. Shown to the team only.
class _TasksSummary extends StatelessWidget {
  final TaskProgress? progress;
  final VoidCallback onOpen;

  const _TasksSummary({required this.progress, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final current = progress;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current == null)
          Text(
            'No se pudo leer el tablero.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          )
        else ...[
          Text(current.total == 0 ? 'Todavía no hay tareas' : current.label),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: current.fraction,
              minHeight: 8,
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: onOpen,
          icon: const Icon(Icons.view_kanban_outlined),
          label: const Text('Ver tablero'),
        ),
      ],
    );
  }
}


/// The creator's inbox for this project.
///
/// Stateful only so it can ask [RequestsViewModel] to load when it appears: it
/// is mounted exactly when the creator opens their own project, so nobody else
/// pays for the read.
class _RequestsInbox extends StatefulWidget {
  final String listingId;
  final String listingTitle;

  /// The detail's [ListingDetailViewModel.revision] when this was built: a new
  /// value means the project was read again, and so must its requests be.
  final int revision;

  const _RequestsInbox({
    required this.listingId,
    required this.listingTitle,
    required this.revision,
  });

  @override
  State<_RequestsInbox> createState() => _RequestsInboxState();
}

class _RequestsInboxState extends State<_RequestsInbox> {
  RequestsViewModel get _requests => Get.find<RequestsViewModel>();

  ListingDetailViewModel get _detail => Get.find<ListingDetailViewModel>();

  @override
  void initState() {
    super.initState();
    _requests.load(widget.listingId, listingTitle: widget.listingTitle);
  }

  @override
  void didUpdateWidget(_RequestsInbox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.revision != oldWidget.revision) {
      _requests.load(widget.listingId, listingTitle: widget.listingTitle);
    }
  }

  Future<void> _resolve({
    required String requestId,
    required bool accept,
    required String applicantName,
  }) async {
    if (accept) {
      await _requests.accept(requestId);
    } else {
      await _requests.reject(requestId);
    }

    final failure = _requests.error.value;

    if (failure != null) {
      Get.snackbar('Error', failure, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Accepting adds a member, so the team counter above is now out of date.
    await _detail.load();

    Get.snackbar(
      accept ? 'Solicitud aceptada' : 'Solicitud rechazada',
      accept
          ? '$applicantName ya hace parte del equipo'
          : 'La persona verá el estado en su perfil',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (_requests.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      if (_requests.error.value != null) {
        return InfoBanner(
          icon: Icons.error_outline,
          text: _requests.error.value!,
          tint: Theme.of(context).colorScheme.error,
        );
      }

      final pending = _requests.requests
          .where((request) => request.status == JoinRequestStatus.pending)
          .toList();

      if (pending.isEmpty) {
        return const EmptyState.inline(
          icon: Icons.inbox_outlined,
          title: 'No hay solicitudes pendientes',
        );
      }

      return Column(
        children: [
          for (final request in pending)
            _RequestCard(
              request: request,
              onAccept: () => _resolve(
                requestId: request.id,
                accept: true,
                applicantName: request.applicantName,
              ),
              onReject: () => _resolve(
                requestId: request.id,
                accept: false,
                applicantName: request.applicantName,
              ),
            ),
        ],
      );
    });
  }
}

class _RequestCard extends StatelessWidget {
  final JoinRequest request;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
            const SizedBox(height: 8),
            _Field(label: 'Motivación', value: request.motivation),
            _Field(label: 'Habilidades', value: request.skills),
            _Field(label: 'Disponibilidad', value: request.availability),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onReject,
                  style: TextButton.styleFrom(foregroundColor: colors.outline),
                  child: const Text('Rechazar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onAccept,
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

class _Field extends StatelessWidget {
  final String label;
  final String value;

  const _Field({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

/// The conversation under a project: a box to write in and what has been said.
class _Comments extends StatefulWidget {
  final List<ListingComment> comments;
  final bool isBusy;
  final bool Function(ListingComment) canDelete;
  final Future<bool> Function(String) onSend;
  final Future<void> Function(String) onDelete;

  const _Comments({
    required this.comments,
    required this.isBusy,
    required this.canDelete,
    required this.onSend,
    required this.onDelete,
  });

  @override
  State<_Comments> createState() => _CommentsState();
}

class _CommentsState extends State<_Comments> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;

    final sent = await widget.onSend(body);

    // The comment can come back after the person left the screen.
    if (!sent || !mounted) return;

    _controller.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Escribe un comentario',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: widget.isBusy ? null : _send,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.comments.isEmpty)
          const EmptyState.inline(
            icon: Icons.mode_comment_outlined,
            title: 'Todavía no hay comentarios',
            message: 'Sé la primera persona en escribir algo.',
          )
        else
          for (final comment in widget.comments)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NameAvatar(name: comment.authorName, radius: 15),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.authorName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          comment.body,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (widget.canDelete(comment))
                    IconButton(
                      tooltip: 'Eliminar comentario',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.isBusy
                          ? null
                          : () => widget.onDelete(comment.id),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
