import 'package:campus_innovate/main.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'test_bindings.dart';

/// What every screen test needs to drive the app: open it on a route with the
/// doubles installed, and the few gestures that the snackbars and long lists
/// make awkward.
extension AppTester on WidgetTester {
  /// A tall surface, so most screens fit without scrolling and the assertions do
  /// not depend on what happens to be inside the viewport.
  void useTallSurface({Size size = const Size(1000, 2400)}) {
    view.physicalSize = size;
    view.devicePixelRatio = 1;
    addTearDown(view.reset);
  }

  /// Opens the real app on [route] — with its pages, bindings and theme — over
  /// [bindings], or a fresh [TestBindings] when none is given.
  Future<TestBindings> pumpApp({
    String route = AppRoutes.home,
    TestBindings? bindings,
  }) async {
    final graph = bindings ?? TestBindings();

    useTallSurface();

    await pumpWidget(
      CampusInnovateApp(initialBinding: graph, initialRoute: route),
    );
    await pumpAndSettle();

    return graph;
  }

  /// Drains the 3s auto-dismiss timer of [Get.snackbar], so the test does not
  /// end with a pending timer.
  Future<void> settleSnackbars() async {
    await pump(const Duration(seconds: 5));
    await pumpAndSettle();
  }

  /// Scrolls [finder] into view and taps it.
  Future<void> tapVisible(Finder finder) async {
    await ensureVisible(finder);
    await pumpAndSettle();
    await tap(finder);
    await pumpAndSettle();
  }

  Future<void> tapText(String text) => tapVisible(find.text(text));

  /// Types into the [TextFormField] or [TextField] whose label or hint is
  /// [label].
  Future<void> enterField(String label, String text) async {
    final finder = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is TextField || widget is TextFormField,
      ),
    );

    await ensureVisible(finder.first);
    await enterText(finder.first, text);
    await pumpAndSettle();
  }
}

/// Builds a single widget inside a themed [GetMaterialApp], for the tests of
/// the reusable widgets that do not need a route or the graph.
Widget wrapWidget(Widget child, {ThemeData? theme}) {
  return GetMaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  );
}
