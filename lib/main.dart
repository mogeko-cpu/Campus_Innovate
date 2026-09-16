import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/app_theme.dart';
import 'di/app_bindings.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

void main() {
  runApp(const CampusInnovateApp());
}

class CampusInnovateApp extends StatelessWidget {
  const CampusInnovateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Innovate',
      initialBinding: AppBindings(),
      initialRoute: AppRoutes.home,
      getPages: AppPages.pages,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
    );
  }
}
