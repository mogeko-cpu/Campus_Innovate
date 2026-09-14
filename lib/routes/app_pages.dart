import 'package:get/get.dart';

import '../features/home/ui/pages/home_page.dart';
import '../features/home/ui/viewmodels/home_view_model.dart';
import '../routes/app_routes.dart';
import '../di/app_bindings.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),
  ];
}