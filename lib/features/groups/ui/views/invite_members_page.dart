import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/name_avatar.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../../users/domain/models/app_user.dart';
import '../viewmodels/invite_members_view_model.dart';

/// Search the campus and invite somebody to the group.
class InviteMembersPage extends GetView<InviteMembersViewModel> {
  const InviteMembersPage({super.key});

  Future<void> _invite(AppUser user) async {
    final sent = await controller.invite(user);

    Get.snackbar(
      sent ? 'Invitación enviada' : 'No se pudo invitar',
      sent
          ? '${user.name} recibirá una notificación'
          : controller.lastActionError ?? 'Intenta de nuevo',
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitar al grupo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              onChanged: (value) => controller.query.value = value,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre o correo',
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.error.value != null) {
                return EmptyState.screen(
                  icon: Icons.error_outline,
                  title: 'No se pudo cargar',
                  message: controller.error.value!,
                );
              }

              final people = controller.candidates;

              if (people.isEmpty) {
                return EmptyState.screen(
                  icon: Icons.person_search_outlined,
                  title: controller.query.value.trim().isEmpty
                      ? 'No hay nadie más para invitar'
                      : 'Nadie coincide con tu búsqueda',
                  message: 'Solo aparecen las personas que ya abrieron '
                      'Campus Innovate.',
                );
              }

              return RefreshIndicator(
                onRefresh: controller.load,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: people.length,
                  itemBuilder: (context, index) {
                    final user = people[index];

                    return _PersonTile(
                      user: user,
                      isInvited: controller.isInvited(user),
                      hasRequested: controller.hasRequested(user),
                      isSending: controller.sendingTo.value == user.id,
                      isLocked: controller.sendingTo.value != null,
                      onInvite: () => _invite(user),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final AppUser user;
  final bool isInvited;
  final bool hasRequested;
  final bool isSending;

  /// Some invitation is in flight: every button waits, so two taps cannot race.
  final bool isLocked;
  final VoidCallback onInvite;

  const _PersonTile({
    required this.user,
    required this.isInvited,
    required this.hasRequested,
    required this.isSending,
    required this.isLocked,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final Widget trailing;

    if (isSending) {
      trailing = const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (isInvited) {
      trailing = Chip(
        label: const Text('Invitación enviada'),
        avatar: Icon(Icons.check, size: 16, color: colors.primary),
      );
    } else if (hasRequested) {
      trailing = const Chip(label: Text('Ya solicitó'));
    } else {
      trailing = FilledButton.tonal(
        onPressed: isLocked ? null : onInvite,
        child: const Text('Invitar'),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: NameAvatar(name: user.name, radius: 18),
        title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: user.email.isEmpty
            ? null
            : Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: trailing,
      ),
    );
  }
}
