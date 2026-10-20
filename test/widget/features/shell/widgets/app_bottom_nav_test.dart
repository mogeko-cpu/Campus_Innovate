import 'package:campus_innovate/features/shell/ui/widgets/app_bottom_nav.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  /// One stub page per tab, so the test is about the bar and not about what the
  /// real screens load.
  Future<void> pump(WidgetTester tester, AppTab start) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: start.route,
        getPages: [
          for (final tab in AppTab.values)
            GetPage(
              name: tab.route,
              page: () => Scaffold(
                body: Text('Pantalla ${tab.label}'),
                bottomNavigationBar: AppBottomNav(current: tab),
              ),
            ),
          GetPage(
            name: '/otra',
            page: () => const Scaffold(body: Text('Pantalla empujada')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  testWidgets('muestra las cinco pestañas en el orden de AppTab',
      (tester) async {
    await pump(tester, AppTab.home);

    final labels = ['Inicio', 'Explorar', 'Ranking', 'Grupos', 'Perfil'];

    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }

    final xs = [for (final label in labels) tester.getCenter(find.text(label)).dx];
    expect(xs, orderedEquals([...xs]..sort()));
  });

  testWidgets('marca la pestaña actual con su ícono relleno', (tester) async {
    await pump(tester, AppTab.ranking);

    expect(selectedIndex(tester), AppTab.ranking.index);
    expect(find.byIcon(Icons.leaderboard), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });

  testWidgets('cada pestaña lleva a su ruta y queda seleccionada',
      (tester) async {
    await pump(tester, AppTab.home);

    for (final tab in [
      AppTab.explore,
      AppTab.ranking,
      AppTab.groups,
      AppTab.profile,
      AppTab.home,
    ]) {
      await tester.tap(find.text(tab.label));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, tab.route);
      expect(find.text('Pantalla ${tab.label}'), findsOneWidget);
      expect(selectedIndex(tester), tab.index);
    }
  });

  testWidgets('cambiar de pestaña reemplaza la pila en vez de apilar',
      (tester) async {
    await pump(tester, AppTab.home);

    Get.toNamed('/otra');
    await tester.pumpAndSettle();
    Get.back();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.listings);
    // A tab is a root: there is nothing to go back to.
    expect(Navigator.of(tester.element(find.text('Pantalla Explorar'))).canPop(),
        isFalse);
  });

  testWidgets('tocar la pestaña actual no navega', (tester) async {
    await pump(tester, AppTab.groups);

    final before = tester.element(find.text('Pantalla Grupos'));

    await tester.tap(find.text('Grupos'));
    await tester.pumpAndSettle();

    expect(Get.currentRoute, AppRoutes.groups);
    // The same element: the page was not rebuilt by a new route.
    expect(tester.element(find.text('Pantalla Grupos')), same(before));
  });
}
