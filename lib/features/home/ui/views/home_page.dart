import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';
import '../../../auth/ui/viewmodels/authentication_controller.dart';
import '../../../listings/domain/models/mentorship_request.dart';
import '../../../listings/ui/widgets/listing_card.dart';
import '../../../notifications/ui/viewmodels/notification_center.dart';
import '../../../notifications/ui/widgets/notification_bell.dart';
import '../../../shell/ui/widgets/app_bottom_nav.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../../shell/ui/widgets/hero_decor.dart';
import '../../../shell/ui/widgets/panel.dart';
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

    // Before the session goes: the next person to sign in on this device must
    // not see this one's unread count for a moment.
    Get.find<NotificationCenter>().reset();

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
                // Only one card here now: exploring lives in the bar at the
                // bottom, and offering the same trip twice made the two ways in
                // look like two different places.
                ActionCard(
                  icon: Icons.add_circle_outline,
                  title: 'Publicar idea',
                  subtitle: 'Arma tu equipo',
                  filled: true,
                  onTap: () => _openAndRefresh(AppRoutes.createListing),
                ),
                const SizedBox(height: 32),
                const _SectionHeader(title: 'Ideas destacadas'),
                const SizedBox(height: 14),
                if (controller.isLoading.value)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (controller.error.value != null)
                  EmptyState.inline(
                    icon: Icons.error_outline,
                    title: 'No se pudieron cargar las ideas',
                    message: controller.error.value!,
                    tint: Theme.of(context).colorScheme.error,
                  )
                else if (controller.featuredListings.isEmpty)
                  const EmptyState.inline(
                    icon: Icons.lightbulb_outline,
                    title: 'Todavía no hay ideas con cupos disponibles',
                  )
                else
                  for (final listing in controller.featuredListings)
                    ListingCard(
                      listing: listing,
                      stats: controller.statsOf(listing),
                      onTap: () => _openAndRefresh(
                        AppRoutes.detailOf(listing.id),
                      ),
                    ),
                if (controller.mentorshipRequests.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const _SectionHeader(title: 'Te piden ser mentor'),
                  const SizedBox(height: 14),
                  for (final request in controller.mentorshipRequests)
                    _MentorshipRequestTile(
                      request: request,
                      onTap: () => _openAndRefresh(
                        AppRoutes.detailOf(request.listingId),
                      ),
                    ),
                ],
                const SizedBox(height: 24),
                const _SectionHeader(title: 'Mis proyectos'),
                const SizedBox(height: 14),
                if (controller.myListings.isEmpty)
                  const EmptyState.inline(
                    icon: Icons.handshake_outlined,
                    title: 'Aún no participas en ningún proyecto',
                    message: 'Explora las ideas destacadas o publica la tuya.',
                  )
                else
                  for (final listing in controller.myListings)
                    ListingCard(
                      listing: listing,
                      stats: controller.statsOf(listing),
                      onTap: () => _openAndRefresh(
                        AppRoutes.detailOf(listing.id),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.home),
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
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.secondary],
        ),
        boxShadow: heroShadow(colors),
      ),
      child: Stack(
        children: [
          HeroDecor(color: colors.onPrimary),
          Padding(
            padding: const EdgeInsets.all(22),
            child: _content(theme, colors),
          ),
        ],
      ),
    );
  }

  Widget _content(ThemeData theme, ColorScheme colors) {
    return Column(
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
            NotificationBell(color: colors.onPrimary),
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
    );
  }
}

/// A team asking this person to mentor its project, opening the project where
/// the answer is given.
class _MentorshipRequestTile extends StatelessWidget {
  final MentorshipRequest request;
  final VoidCallback onTap;

  const _MentorshipRequestTile({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: Panel.decorationOf(context, radius: 16),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.tertiary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.school_outlined, color: colors.tertiary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.listingTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${request.requesterName} te pidió acompañar al '
                          'equipo',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  /// No trailing "Ver todas" any more: the whole catalogue is one tap away in
  /// the bar at the bottom, and a second door to the same room only made the
  /// screen busier.
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

