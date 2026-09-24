import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../../shell/ui/widgets/app_bottom_nav.dart';
import '../../../shell/ui/widgets/empty_state.dart';
import '../../../shell/ui/widgets/gradient_header.dart';
import '../../domain/models/ranked_listing.dart';
import '../viewmodels/ranking_view_model.dart';
import '../widgets/listing_card.dart';

/// Projects ordered by how the campus valued them.
///
/// Voting happens on the detail screen and not here on purpose: the list is for
/// reading the standings, and a list that reordered itself under the finger that
/// just tapped it would be hard to follow.
class RankingPage extends GetView<RankingViewModel> {
  const RankingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking'),
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: const AppBottomNav(current: AppTab.ranking),
      body: SafeArea(
        bottom: false,
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.error.value != null) {
            return EmptyState.screen(
              icon: Icons.error_outline,
              title: 'No se pudo cargar el ranking',
              message: controller.error.value!,
            );
          }

          if (controller.ranking.isEmpty) {
            return const EmptyState.screen(
              icon: Icons.leaderboard_outlined,
              title: 'Todavía no hay proyectos publicados',
              message: 'Cuando se publiquen, aparecerán aquí ordenados por '
                  'valoración.',
            );
          }

          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: controller.ranking.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _RankingHeader(ranking: controller.ranking);
                }

                final entry = controller.ranking[index - 1];

                return ListingCard(
                  listing: entry.listing,
                  stats: entry.stats,
                  leading: _PositionBadge(position: entry.position),
                  onTap: () async {
                    await Get.toNamed(AppRoutes.detailOf(entry.listing.id));
                    await controller.load();
                  },
                );
              },
            ),
          );
        }),
      ),
    );
  }
}

class _RankingHeader extends StatelessWidget {
  final List<RankedListing> ranking;

  const _RankingHeader({required this.ranking});

  @override
  Widget build(BuildContext context) {
    final totalLikes = ranking.fold<int>(
      0,
      (sum, entry) => sum + entry.stats.likes,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GradientHeader(
        icon: Icons.leaderboard_outlined,
        title: 'Ranking del campus',
        subtitle: 'El puntaje son los me gusta menos los no me gusta; los '
            'comentarios y las vistas desempatan.',
        stats: [
          ('${ranking.length}', ranking.length == 1 ? 'proyecto' : 'proyectos'),
          ('$totalLikes', 'me gusta en total'),
        ],
      ),
    );
  }
}

/// The place a project holds. The top three get the accent colour so the head of
/// the list can be read at a glance.
class _PositionBadge extends StatelessWidget {
  final int position;

  const _PositionBadge({required this.position});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isPodium = position <= 3;
    final background = isPodium ? AppTheme.gold : colors.surfaceContainerHighest;
    final foreground = isPodium ? Colors.white : colors.onSurfaceVariant;

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Text(
        '$position',
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

