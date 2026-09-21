import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';
import '../../../shell/ui/widgets/app_bottom_nav.dart';
import '../../domain/models/group.dart';
import '../viewmodels/groups_view_model.dart';
import '../widgets/group_card.dart';

/// Group management: the teams you belong to and the ones you can ask to join.
class GroupsPage extends GetView<GroupsViewModel> {
  const GroupsPage({super.key});

  Future<void> _openAndRefresh(String route) async {
    await Get.toNamed(route);
    await controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.groups),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAndRefresh(AppRoutes.createGroup),
        icon: const Icon(Icons.add),
        label: const Text('Crear grupo'),
      ),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.error.value != null) {
            return _Empty(
              icon: Icons.error_outline,
              text: controller.error.value!,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                const _SectionHeader(title: 'Mis grupos'),
                const SizedBox(height: 12),
                if (controller.myGroups.isEmpty)
                  const _Message(
                    text: 'Todavía no haces parte de ningún grupo. Crea uno '
                        'para publicar proyectos a su nombre.',
                  )
                else
                  for (final group in controller.myGroups)
                    GroupCard(
                      group: group,
                      projectCount: controller.projectsOf(group),
                      badge: group.isOwner(controller.currentUserId)
                          ? 'Creador'
                          : 'Integrante',
                      onTap: () => _openAndRefresh(AppRoutes.groupOf(group.id)),
                    ),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Otros grupos del campus'),
                const SizedBox(height: 12),
                if (controller.otherGroups.isEmpty)
                  const _Message(text: 'No hay otros grupos por ahora.')
                else
                  for (final group in controller.otherGroups)
                    GroupCard(
                      group: group,
                      projectCount: controller.projectsOf(group),
                      badge: _badgeFor(group),
                      onTap: () => _openAndRefresh(AppRoutes.groupOf(group.id)),
                    ),
              ],
            ),
          );
        }),
      ),
    );
  }

  String? _badgeFor(Group group) {
    final request = controller.myRequestFor(group);
    if (request == null) return null;

    return request.isPending ? 'Solicitud pendiente' : request.status.label;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;

  const _Message({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: colors.outline),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
