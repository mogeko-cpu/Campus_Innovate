import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';
import '../../../auth/ui/viewmodels/authentication_controller.dart';
import '../../../listings/ui/widgets/listing_card.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/action_card.dart';

class HomePage extends GetView<HomeViewModel> {
  const HomePage({super.key});

  /// Listings and memberships can change on the pushed route, so the home
  /// snapshot is reloaded once the user comes back.
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
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: Obx(
            () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _Greeting(
                  name: controller.firstName,
                  onLogOut: _confirmLogOut,
                ),
                const SizedBox(height: 24),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ActionCard(
                          icon: Icons.add_circle_outline,
                          title: 'Publicar idea',
                          subtitle: 'Arma tu equipo',
                          filled: true,
                          onTap: () => _openAndRefresh(AppRoutes.createListing),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ActionCard(
                          icon: Icons.explore_outlined,
                          title: 'Explorar',
                          subtitle: 'Únete a un proyecto',
                          onTap: () => _openAndRefresh(AppRoutes.listings),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                _SectionHeader(
                  title: 'Ideas destacadas',
                  actionLabel: 'Ver todas',
                  onAction: () => _openAndRefresh(AppRoutes.listings),
                ),
                const SizedBox(height: 14),
                if (controller.isLoading.value)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (controller.error.value != null)
                  _Message(text: controller.error.value!)
                else if (controller.featuredListings.isEmpty)
                  const _Message(
                    text: 'Todavía no hay ideas con cupos disponibles.',
                  )
                else
                  for (final listing in controller.featuredListings)
                    ListingCard(
                      listing: listing,
                      onTap: () => _openAndRefresh(
                        AppRoutes.detailOf(listing.id),
                      ),
                    ),
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Mis proyectos'),
                const SizedBox(height: 14),
                if (controller.myListings.isEmpty)
                  const _Message(
                    text: 'Aún no participas en ningún proyecto.',
                  )
                else
                  for (final listing in controller.myListings)
                    ListingCard(
                      listing: listing,
                      onTap: () => _openAndRefresh(
                        AppRoutes.detailOf(listing.id),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            _openAndRefresh(AppRoutes.listings);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'Explorar',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            label: 'Proyectos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String name;
  final Future<void> Function() onLogOut;

  const _Greeting({required this.name, required this.onLogOut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.secondary],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, color: colors.onPrimary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CAMPUS INNOVATE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              IconButton(
                onPressed: onLogOut,
                tooltip: 'Cerrar sesión',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.logout, color: colors.onPrimary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Hola, $name',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Encuentra un equipo o publica tu propia idea.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
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
