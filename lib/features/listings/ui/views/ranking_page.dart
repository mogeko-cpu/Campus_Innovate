import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/app_theme.dart';
import '../../../../routes/app_routes.dart';
import '../../../shell/ui/widgets/app_bottom_nav.dart';
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
            return _Empty(
              icon: Icons.error_outline,
              text: controller.error.value!,
            );
          }

          if (controller.ranking.isEmpty) {
            return const _Empty(
              icon: Icons.leaderboard_outlined,
              text: 'Todavía no hay proyectos publicados.',
            );
          }

          return RefreshIndicator(
            onRefresh: controller.load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              itemCount: controller.ranking.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) return const _Intro();

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

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        'Los proyectos mejor valorados del campus. El puntaje son los me gusta '
        'menos los no me gusta; los comentarios y las vistas desempatan.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
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
