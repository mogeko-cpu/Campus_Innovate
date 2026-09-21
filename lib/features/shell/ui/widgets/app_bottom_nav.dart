import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../routes/app_routes.dart';

/// The five screens reachable from the bar at the bottom.
///
/// The order is the order of the destinations, so the enum's index is what the
/// [NavigationBar] selects — one list to keep in sync instead of two.
enum AppTab {
  home(AppRoutes.home, Icons.home_outlined, Icons.home, 'Inicio'),
  explore(
    AppRoutes.listings,
    Icons.explore_outlined,
    Icons.explore,
    'Explorar',
  ),
  ranking(
    AppRoutes.ranking,
    Icons.leaderboard_outlined,
    Icons.leaderboard,
    'Ranking',
  ),
  groups(AppRoutes.groups, Icons.groups_outlined, Icons.groups, 'Grupos'),
  profile(AppRoutes.profile, Icons.person_outline, Icons.person, 'Perfil');

  const AppTab(this.route, this.icon, this.selectedIcon, this.label);

  final String route;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The navigation bar every root screen shares.
///
/// It lives in one widget so the five screens cannot drift apart, and so a tab
/// added later is a single edit to [AppTab].
///
/// Switching tabs uses `offAllNamed`: a tab is a root, not a step in a journey,
/// and pushing them on top of each other would grow the stack every time someone
/// went back and forth. Screens opened *from* a tab are pushed as usual, and the
/// back button returns to it.
class AppBottomNav extends StatelessWidget {
  final AppTab current;

  const AppBottomNav({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: current.index,
      onDestinationSelected: (index) {
        final tab = AppTab.values[index];
        if (tab == current) return;

        Get.offAllNamed(tab.route);
      },
      destinations: [
        for (final tab in AppTab.values)
          NavigationDestination(
            icon: Icon(tab.icon),
            selectedIcon: Icon(tab.selectedIcon),
            label: tab.label,
          ),
      ],
    );
  }
}
