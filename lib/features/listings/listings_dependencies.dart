import 'package:get/get.dart';

import '../../core/i_file_picker.dart';
import '../../core/i_link_opener.dart';
import '../../core/i_session_service.dart';
import '../groups/domain/repositories/i_group_repository.dart';
import '../notifications/domain/notification_publisher.dart';
import '../users/domain/repositories/i_user_repository.dart';
import 'domain/repositories/i_engagement_repository.dart';
import 'domain/repositories/i_listing_repository.dart';
import 'domain/repositories/i_mentorship_repository.dart';
import 'domain/repositories/i_project_file_repository.dart';
import 'domain/repositories/i_task_repository.dart';
import 'ui/viewmodels/create_listing_view_model.dart';
import 'ui/viewmodels/edit_listing_view_model.dart';
import 'ui/viewmodels/files_view_model.dart';
import 'ui/viewmodels/join_request_view_model.dart';
import 'ui/viewmodels/listing_detail_view_model.dart';
import 'ui/viewmodels/listings_view_model.dart';
import 'ui/viewmodels/ranking_view_model.dart';
import 'ui/viewmodels/requests_view_model.dart';
import 'ui/viewmodels/tasks_view_model.dart';

class ListingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ListingsViewModel(
        Get.find<IListingRepository>(),
        Get.find<IEngagementRepository>(),
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
        Get.find<IGroupRepository>(),
        Get.find<NotificationPublisher>(),
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
        Get.find<IEngagementRepository>(),
        Get.find<IGroupRepository>(),
        Get.find<NotificationPublisher>(),
        Get.find<ISessionService>(),
        Get.find<ITaskRepository>(),
        Get.find<IProjectFileRepository>(),
        Get.find<IMentorshipRepository>(),
        Get.find<IUserRepository>(),
      ),
    );

    // The creator's inbox lives on this screen, so its view model is built with
    // it. Lazy, so a visitor who is not the creator never pays for it.
    Get.lazyPut(
      () => RequestsViewModel(
        Get.find<IListingRepository>(),
        Get.find<NotificationPublisher>(),
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
        Get.find<NotificationPublisher>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}

class RankingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => RankingViewModel(
        Get.find<IListingRepository>(),
        Get.find<IEngagementRepository>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}

class EditListingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => EditListingViewModel(
        Get.find<IListingRepository>(),
        Get.find<NotificationPublisher>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}

class FilesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => FilesViewModel(
        Get.find<IProjectFileRepository>(),
        Get.find<IListingRepository>(),
        Get.find<ISessionService>(),
        Get.find<IFilePicker>(),
        Get.find<ILinkOpener>(),
      ),
    );
  }
}

class TasksBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => TasksViewModel(
        Get.find<ITaskRepository>(),
        Get.find<IListingRepository>(),
        Get.find<NotificationPublisher>(),
        Get.find<ISessionService>(),
      ),
    );
  }
}
