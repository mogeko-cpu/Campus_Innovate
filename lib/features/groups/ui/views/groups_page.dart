import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';
import '../../../shell/ui/widgets/app_bottom_nav.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../../shell/ui/widgets/gradient_header.dart';
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
            return EmptyState.screen(
              icon: Icons.error_outline,
              title: 'No se pudieron cargar los grupos',
              message: controller.error.value!,
            );
          }

          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                GradientHeader(
                  icon: Icons.groups_outlined,
                  title: 'Grupos',
                  subtitle: 'Publica proyectos a nombre de un equipo y '
                      'gestiona quién entra.',
                  stats: [
                    ('${controller.myGroups.length}', 'tuyos'),
                    ('${controller.otherGroups.length}', 'en el campus'),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Mis grupos'),
                const SizedBox(height: 12),
                if (controller.myGroups.isEmpty)
                  EmptyState.inline(
                    icon: Icons.groups_outlined,
                    title: 'Todavía no tienes grupos',
                    message: 'Crea uno para publicar proyectos a su nombre.',
                    actionLabel: 'Crear grupo',
                    onAction: () => _openAndRefresh(AppRoutes.createGroup),
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
                  const EmptyState.inline(
                    icon: Icons.public_off_outlined,
                    title: 'No hay otros grupos por ahora',
                  )
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

