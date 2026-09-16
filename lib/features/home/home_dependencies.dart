import 'package:get/get.dart';

import '../../core/i_session_service.dart';
import '../listings/domain/repositories/i_listing_repository.dart';
import 'ui/viewmodels/home_view_model.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => HomeViewModel(
        Get.find<IListingRepository>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}
