import 'package:campus_innovate/core/poller.dart';
import 'package:campus_innovate/features/groups/data/repositories/group_chat_repository.dart';
import 'package:campus_innovate/features/groups/data/repositories/group_repository.dart';
import 'package:campus_innovate/features/listings/data/repositories/engagement_repository.dart';
import 'package:campus_innovate/features/listings/data/repositories/listing_repository.dart';
import 'package:campus_innovate/features/listings/data/repositories/mentorship_repository.dart';
import 'package:campus_innovate/features/listings/data/repositories/project_file_repository.dart';
import 'package:campus_innovate/features/listings/data/repositories/task_repository.dart';
import 'package:campus_innovate/features/notifications/data/repositories/notification_repository.dart';
import 'package:campus_innovate/features/notifications/domain/notification_publisher.dart';
import 'package:campus_innovate/features/users/data/repositories/user_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/fake_file_picker.dart';
import '../../support/fake_link_opener.dart';
import '../../support/in_memory_engagement_source.dart';
import '../../support/in_memory_file_storage.dart';
import '../../support/in_memory_group_chat_source.dart';
import '../../support/in_memory_group_source.dart';
import '../../support/in_memory_listing_source.dart';
import '../../support/in_memory_mentorship_source.dart';
import '../../support/in_memory_notification_source.dart';
import '../../support/in_memory_project_file_source.dart';
import '../../support/in_memory_task_source.dart';
import '../../support/in_memory_user_source.dart';
import '../../support/test_session.dart';

/// The real repositories over the in-memory sources, which is what every view
/// model test builds its subject from. A source can be swapped for a subclass
/// that fails, to drive the error paths through the real repository.
class ViewModelHarness {
  ViewModelHarness({
    TestUser user = TestUsers.leonel,
    InMemoryListingSource? listingSource,
    InMemoryGroupSource? groupSource,
    InMemoryEngagementSource? engagementSource,
    InMemoryGroupChatSource? chatSource,
    InMemoryUserSource? userSource,
    InMemoryNotificationSource? notificationSource,
    InMemoryTaskSource? taskSource,
    InMemoryProjectFileSource? fileSource,
    InMemoryFileStorage? fileStorage,
    InMemoryMentorshipSource? mentorshipSource,
  })  : session = TestSession(user),
        listingSource = listingSource ?? InMemoryListingSource(),
        groupSource = groupSource ?? InMemoryGroupSource(),
        engagementSource = engagementSource ?? InMemoryEngagementSource(),
        chatSource = chatSource ?? InMemoryGroupChatSource(),
        userSource = userSource ?? InMemoryUserSource(),
        notificationSource =
            notificationSource ?? InMemoryNotificationSource(),
        taskSource = taskSource ?? InMemoryTaskSource(),
        fileSource = fileSource ?? InMemoryProjectFileSource(),
        fileStorage = fileStorage ?? InMemoryFileStorage(),
        mentorshipSource = mentorshipSource ?? InMemoryMentorshipSource();

  final TestSession session;
  final InMemoryListingSource listingSource;
  final InMemoryGroupSource groupSource;
  final InMemoryEngagementSource engagementSource;
  final InMemoryGroupChatSource chatSource;
  final InMemoryUserSource userSource;
  final InMemoryNotificationSource notificationSource;
  final InMemoryTaskSource taskSource;
  final InMemoryProjectFileSource fileSource;
  final InMemoryFileStorage fileStorage;
  final InMemoryMentorshipSource mentorshipSource;
  final picker = FakeFilePicker();
  final links = FakeLinkOpener();

  late final listings = ListingRepository(listingSource);
  late final engagement = EngagementRepository(engagementSource);
  late final groups = GroupRepository(groupSource);
  late final chat = GroupChatRepository(chatSource, groups);
  late final users = UserRepository(userSource);
  late final notifications = NotificationRepository(notificationSource);
  late final publisher = NotificationPublisher(notifications);
  late final tasks = TaskRepository(taskSource);
  late final files = ProjectFileRepository(fileSource, fileStorage, listings);
  late final mentorships = MentorshipRepository(mentorshipSource, listings);
}

/// What every view model test file needs around each test: a binding for
/// `Get.engine` (the `onReady` post-frame callback), no pollers, and a clean
/// GetX container afterwards.
void setUpViewModelTests() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Poller.enabled = false;
    Get.parameters = {};
  });

  tearDown(Get.reset);
}

/// Lets the `load()` that `onInit` fires without awaiting run to the end. The
/// in-memory sources only chain microtasks, and a zero timer runs after all of
/// them.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// Registers [viewModel] the way a route binding would — which runs `onInit` —
/// and waits for its first load.
Future<T> start<T extends GetxController>(T viewModel, {String? routeId}) async {
  if (routeId != null) Get.parameters = {'id': routeId};

  Get.put<T>(viewModel);
  await settle();

  return viewModel;
}
