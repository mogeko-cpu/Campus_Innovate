import 'package:get/get.dart';

import '../../core/i_session_service.dart';
import '../listings/domain/repositories/i_listing_repository.dart';
import '../notifications/domain/notification_publisher.dart';
import '../users/domain/repositories/i_user_repository.dart';
import 'domain/repositories/i_group_chat_repository.dart';
import 'domain/repositories/i_group_repository.dart';
import 'ui/viewmodels/create_group_view_model.dart';
import 'ui/viewmodels/group_chat_view_model.dart';
import 'ui/viewmodels/group_detail_view_model.dart';
import 'ui/viewmodels/groups_view_model.dart';
import 'ui/viewmodels/invite_members_view_model.dart';

class GroupsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => GroupsViewModel(
        Get.find<IGroupRepository>(),
        Get.find<IListingRepository>(),
        Get.find<NotificationPublisher>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}

class CreateGroupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CreateGroupViewModel(
        Get.find<IGroupRepository>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}

class GroupDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => GroupDetailViewModel(
        Get.find<IGroupRepository>(),
        Get.find<IListingRepository>(),
        Get.find<NotificationPublisher>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}

class InviteMembersBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => InviteMembersViewModel(
        Get.find<IGroupRepository>(),
        Get.find<IUserRepository>(),
        Get.find<NotificationPublisher>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}

class GroupChatBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => GroupChatViewModel(
        Get.find<IGroupChatRepository>(),
        Get.find<IGroupRepository>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}
