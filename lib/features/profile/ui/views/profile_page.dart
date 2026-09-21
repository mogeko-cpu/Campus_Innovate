import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';
import '../../../auth/ui/viewmodels/authentication_controller.dart';
import '../../../shell/ui/widgets/app_bottom_nav.dart';
import '../viewmodels/profile_view_model.dart';

/// Who you are in Campus Innovate: your account, your numbers, your groups,
/// your projects and the applications you are still waiting on.
class ProfilePage extends GetView<ProfileViewModel> {
  const ProfilePage({super.key});

  Future<void> _openAndRefresh(String route) async {
    await Get.toNamed(route);
    await controller.load();
  }

  /// Ends the session and goes back to login.
  ///
  /// Confirmed first because signing in again costs a request against a limit of
  /// 10 logins per 15 minutes shared by everyone on the same network — an
  /// accidental tap is not free here.
  Future<void> _confirmLogOut() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a escribir tu correo y contraseña para entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await Get.find<AuthenticationController>().logOut();
    await Get.offAllNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _confirmLogOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.profile),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                _Identity(
                  initials: controller.initials,
                  name: controller.userName,
                  email: controller.userEmail,
                ),
                if (controller.error.value != null) ...[
                  const SizedBox(height: 16),
                  _Message(text: controller.error.value!),
                ],
                const SizedBox(height: 22),
                _Numbers(
                  groups: controller.myGroups.length,
                  published: controller.myListings.length,
                  participations: controller.participations.length,
                  likes: controller.likesReceived.value,
                  views: controller.viewsReceived.value,
                ),
                const SizedBox(height: 28),
                const _SectionTitle(title: 'Mis grupos'),
                const SizedBox(height: 10),
                if (controller.myGroups.isEmpty)
                  const _Message(text: 'Todavía no haces parte de un grupo.')
                else
                  for (final group in controller.myGroups)
                    _Tile(
                      icon: Icons.groups_outlined,
                      title: group.name,
                      subtitle: group.isOwner(controller.userId)
                          ? 'Creador · ${group.memberCount} integrantes'
                          : 'Integrante · ${group.memberCount} integrantes',
                      onTap: () => _openAndRefresh(
                        AppRoutes.groupOf(group.id),
                      ),
                    ),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Proyectos que publiqué'),
                const SizedBox(height: 10),
                if (controller.myListings.isEmpty)
                  const _Message(text: 'Aún no has publicado proyectos.')
                else
                  for (final listing in controller.myListings)
                    _Tile(
                      icon: Icons.lightbulb_outline,
                      title: listing.title,
                      subtitle:
                          '${listing.memberIds.length} de ${listing.maxMembers} '
                          'integrantes · ${listing.category}',
                      onTap: () => _openAndRefresh(
                        AppRoutes.detailOf(listing.id),
                      ),
                    ),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Proyectos en los que participo'),
                const SizedBox(height: 10),
                if (controller.participations.isEmpty)
                  const _Message(
                    text: 'Todavía no te has unido a un proyecto de otra '
                        'persona.',
                  )
                else
                  for (final listing in controller.participations)
                    _Tile(
                      icon: Icons.handshake_outlined,
                      title: listing.title,
                      subtitle: 'Creado por ${listing.creatorName}',
                      onTap: () => _openAndRefresh(
                        AppRoutes.detailOf(listing.id),
                      ),
                    ),
                const SizedBox(height: 24),
                const _SectionTitle(title: 'Mis solicitudes'),
                const SizedBox(height: 10),
                if (controller.myRequests.isEmpty)
                  const _Message(text: 'No has enviado solicitudes.')
                else
                  for (final request in controller.myRequests)
                    _Tile(
                      icon: Icons.send_outlined,
                      title: request.status.label,
                      subtitle: request.motivation.isEmpty
                          ? 'Solicitud enviada'
                          : request.motivation,
                      onTap: () => _openAndRefresh(
                        AppRoutes.detailOf(request.listingId),
                      ),
                    ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  final String initials;
  final String name;
  final String email;

  const _Identity({
    required this.initials,
    required this.name,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.secondary],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: colors.onPrimary,
            child: Text(
              initials,
              style: theme.textTheme.titleLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Numbers extends StatelessWidget {
  final int groups;
  final int published;
  final int participations;
  final int likes;
  final int views;

  const _Numbers({
    required this.groups,
    required this.published,
    required this.participations,
    required this.likes,
    required this.views,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Stat(label: 'Grupos', value: groups),
        _Stat(label: 'Publicados', value: published),
        _Stat(label: 'Participaciones', value: participations),
        _Stat(label: 'Me gusta recibidos', value: likes),
        _Stat(label: 'Vistas', value: views),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.primary,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
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
