import 'package:get/get.dart';

import '../../core/i_session_service.dart';
import '../groups/domain/repositories/i_group_repository.dart';
import '../listings/domain/repositories/i_engagement_repository.dart';
import '../listings/domain/repositories/i_listing_repository.dart';
import 'ui/viewmodels/profile_view_model.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ProfileViewModel(
        Get.find<ISessionService>(),
        Get.find<IListingRepository>(),
        Get.find<IGroupRepository>(),
        Get.find<IEngagementRepository>(),
      ),
    );
  }
}
