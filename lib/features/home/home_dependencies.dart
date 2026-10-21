import 'package:get/get.dart';

import '../../core/i_session_service.dart';
import '../listings/domain/repositories/i_engagement_repository.dart';
import '../listings/domain/repositories/i_listing_repository.dart';
import '../listings/domain/repositories/i_mentorship_repository.dart';
import '../users/domain/repositories/i_user_repository.dart';
import 'ui/viewmodels/home_view_model.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => HomeViewModel(
        Get.find<IListingRepository>(),
        Get.find<IEngagementRepository>(),
        Get.find<IUserRepository>(),
        Get.find<ISessionService>(),
        Get.find<IMentorshipRepository>(),
      ),
    );
  }
}
