import 'package:get/get.dart';

import '../features/home/ui/viewmodels/home_view_model.dart';
import '../features/listings/data/repositories/local_listing_repository.dart';
import '../features/listings/domain/repositories/i_listing_repository.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<IListingRepository>(
      () => LocalListingRepository(),
    );
  }
}

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeViewModel>(
      () => HomeViewModel(
        Get.find<IListingRepository>(),
      ),
    );
  }
}