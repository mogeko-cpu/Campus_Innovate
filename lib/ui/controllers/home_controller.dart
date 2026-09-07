import 'package:get/get.dart';

import '../../domain/entities/idea.dart';
import '../../domain/repositories/idea_repository.dart';

class HomeController extends GetxController {
  final IdeaRepository repository;

  HomeController(this.repository);

  final RxList<Idea> featuredIdeas = <Idea>[].obs;

  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadIdeas();
  }

  Future<void> loadIdeas() async {
    try {
      isLoading.value = true;

      final ideas = await repository.getFeaturedIdeas();

      featuredIdeas.assignAll(ideas);
    } catch (e) {
      Get.snackbar(
        'Error',
        'No se pudieron cargar las ideas',
      );
    } finally {
      isLoading.value = false;
    }
  }
}