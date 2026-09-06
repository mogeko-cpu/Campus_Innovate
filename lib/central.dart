import 'package:f_clean_template/features/product/ui/views/list_product_page.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'features/auth/ui/viewmodels/authentication_controller.dart';
import 'features/auth/ui/views/login_page.dart';

class Central extends StatelessWidget {
  const Central({super.key});

  @override
  Widget build(BuildContext context) {
    AuthenticationController authenticationController = Get.find();
    return Obx(
      () => authenticationController.isLogged
          ? const ListProductPage()
          : const LoginPage(),
    );
  }
}
