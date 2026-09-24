import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/name_avatar.dart';
import '../../../../routes/app_routes.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../../shell/ui/widgets/info_banner.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_comment.dart';
import '../viewmodels/listing_detail_view_model.dart';
import '../viewmodels/requests_view_model.dart';
import '../widgets/reaction_bar.dart';

class ListingDetailPage extends GetView<ListingDetailViewModel> {
  const ListingDetailPage({super.key});

  Future<void> _confirmDelete() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('¿Eliminar el proyecto?'),
        content: const Text(
          'Se van a borrar su equipo, sus solicitudes, sus comentarios y sus '
          'valoraciones. Esta acción no se puede deshacer.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del proyecto'),
        actions: [
          Obx(() {
            if (!controller.isCreator) return const SizedBox.shrink();

            return IconButton(
              tooltip: 'Eliminar proyecto',
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
              child: Row(
                children: [
                  Icon(
                    Icons.group_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${listing.memberIds.length} de ${listing.maxMembers} integrantes',
                  ),
                ],
              ),
            ),
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
            if (controller.isCreator) ...[
              const SizedBox(height: 32),
              _Section(
                title: 'Solicitudes recibidas',
                child: _RequestsInbox(listingId: listing.id),
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
    if (controller.isCreator) {
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


/// The creator's inbox for this project.
///
/// Stateful only so it can ask [RequestsViewModel] to load when it appears: it
/// is mounted exactly when the creator opens their own project, so nobody else
/// pays for the read.
class _RequestsInbox extends StatefulWidget {
  final String listingId;

  const _RequestsInbox({required this.listingId});

  @override
  State<_RequestsInbox> createState() => _RequestsInboxState();
}

class _RequestsInboxState extends State<_RequestsInbox> {
  RequestsViewModel get _requests => Get.find<RequestsViewModel>();

  ListingDetailViewModel get _detail => Get.find<ListingDetailViewModel>();

  @override
  void initState() {
    super.initState();
    _requests.load(widget.listingId);
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

    if (await widget.onSend(body)) {
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
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
