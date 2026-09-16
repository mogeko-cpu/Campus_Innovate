import 'package:get/get.dart';

import '../../core/i_session_service.dart';
import 'domain/repositories/i_listing_repository.dart';
import 'ui/viewmodels/create_listing_view_model.dart';
import 'ui/viewmodels/join_request_view_model.dart';
import 'ui/viewmodels/listing_detail_view_model.dart';
import 'ui/viewmodels/listings_view_model.dart';

class ListingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ListingsViewModel(
        Get.find<IListingRepository>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}

class CreateListingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CreateListingViewModel(
        Get.find<IListingRepository>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}

class ListingDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ListingDetailViewModel(
        Get.find<IListingRepository>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}

class JoinRequestBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => JoinRequestViewModel(
        Get.find<IListingRepository>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}
