import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loggy/loggy.dart';

import 'core/app_theme.dart';
import 'di/app_bindings.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  // Reading the stored session touches a plugin, so the bindings have to exist
  // before the graph is built.
  WidgetsFlutterBinding.ensureInitialized();

  // Several classes log through `UiLoggy`, which needs Loggy set up first.
  Loggy.initLoggy(logPrinter: const PrettyPrinter());

  final bindings = await AppBindings.boot();

  runApp(
    CampusInnovateApp(
      initialBinding: bindings,
      initialRoute: bindings.initialRoute,
      initialThemeMode: bindings.themeMode,
    ),
  );
}

class CampusInnovateApp extends StatelessWidget {
  /// [initialBinding] and [initialRoute] are parameters so the composition root
  /// stays outside the widget: `main` decides between home and login after
  /// checking the session, and the tests install their own doubles and open the
  /// screen they are exercising.
  const CampusInnovateApp({
    super.key,
    this.initialBinding,
    this.initialRoute = AppRoutes.home,
    this.initialThemeMode = ThemeMode.system,
  });

  final Bindings? initialBinding;
  final String initialRoute;

  /// The theme the person chose last time, read before the first frame. Tests
  /// that build this widget directly, without going through [AppBindings.boot],
  /// get the ordinary default of following the system.
  final ThemeMode initialThemeMode;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Innovate',
      initialBinding: initialBinding,
      initialRoute: initialRoute,
      getPages: AppPages.pages,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: initialThemeMode,
    );
  }
}
