import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'data/repositories/idea_repository_impl.dart';
import 'data/sources/idea_data_source.dart';
import 'ui/controllers/home_controller.dart';
import 'ui/views/home_view.dart';

void main() {
  Get.put(
    IdeaDataSource(),
  );

  Get.put(
    IdeaRepositoryImpl(
      Get.find<IdeaDataSource>(),
    ),
  );

  Get.put(
    HomeController(
      Get.find<IdeaRepositoryImpl>(),
    ),
  );

  runApp(
    const CampusInnovateApp(),
  );
}

class CampusInnovateApp extends StatelessWidget {
  const CampusInnovateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Innovate',

      theme: ThemeData(
        useMaterial3: true,
      ),

      home: const HomeView(),
    );
  }
}