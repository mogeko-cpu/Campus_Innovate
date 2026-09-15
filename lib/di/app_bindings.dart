import 'package:get/get.dart';

import '../features/listings/data/repositories/local_listing_repository.dart';
import '../features/listings/domain/repositories/i_listing_repository.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<IListingRepository>(
      () => LocalListingRepository(),
      fenix: true,
    );
  }
}