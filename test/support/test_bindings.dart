import 'package:campus_innovate/core/i_session_service.dart';
import 'package:campus_innovate/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:campus_innovate/features/auth/ui/viewmodels/authentication_controller.dart';
import 'package:campus_innovate/core/poller.dart';
import 'package:campus_innovate/core/theme_controller.dart';
import 'package:campus_innovate/features/groups/data/datasources/i_group_chat_source.dart';
import 'package:campus_innovate/features/groups/data/datasources/i_group_source.dart';
import 'package:campus_innovate/features/groups/data/repositories/group_chat_repository.dart';
import 'package:campus_innovate/features/groups/data/repositories/group_repository.dart';
import 'package:campus_innovate/features/groups/domain/repositories/i_group_chat_repository.dart';
import 'package:campus_innovate/features/groups/domain/repositories/i_group_repository.dart';
import 'package:campus_innovate/features/notifications/data/datasources/i_notification_source.dart';
import 'package:campus_innovate/features/notifications/data/repositories/notification_repository.dart';
import 'package:campus_innovate/features/notifications/domain/notification_publisher.dart';
import 'package:campus_innovate/features/notifications/domain/repositories/i_notification_repository.dart';
import 'package:campus_innovate/features/notifications/ui/viewmodels/notification_center.dart';
import 'package:campus_innovate/features/users/data/datasources/i_user_source.dart';
import 'package:campus_innovate/features/users/data/repositories/user_repository.dart';
import 'package:campus_innovate/features/users/domain/repositories/i_user_repository.dart';
import 'package:flutter/material.dart';
import 'package:campus_innovate/features/listings/data/datasources/i_engagement_source.dart';
import 'package:campus_innovate/features/listings/data/datasources/i_listing_source.dart';
import 'package:campus_innovate/features/listings/data/repositories/engagement_repository.dart';
import 'package:campus_innovate/features/listings/data/repositories/listing_repository.dart';
import 'package:campus_innovate/features/listings/domain/repositories/i_engagement_repository.dart';
import 'package:campus_innovate/features/listings/domain/repositories/i_listing_repository.dart';
import 'package:get/get.dart';

import 'fake_auth_repository.dart';
import 'in_memory_engagement_source.dart';
import 'in_memory_group_chat_source.dart';
import 'in_memory_group_source.dart';
import 'in_memory_listing_source.dart';
import 'in_memory_notification_source.dart';
import 'in_memory_user_source.dart';
import 'memory_preferences.dart';

/// The app's graph with storage and identity replaced by doubles.
///
/// Mirrors `AppBindings` from `ISessionService` down, so the widget tests exercise
/// the real view models, repository and screens; only ROBLE is absent.
class TestBindings extends Bindings {
  TestBindings({
    IListingSource? source,
    IGroupSource? groupSource,
    IEngagementSource? engagementSource,
    IGroupChatSource? chatSource,
    IUserSource? userSource,
    INotificationSource? notificationSource,
    ISessionService? session,
    IAuthRepository? authRepository,
  })  : source = source ?? InMemoryListingSource(),
        groupSource = groupSource ?? InMemoryGroupSource(),
        engagementSource = engagementSource ?? InMemoryEngagementSource(),
        chatSource = chatSource ?? InMemoryGroupChatSource(),
        userSource = userSource ?? InMemoryUserSource(),
        notificationSource = notificationSource ?? InMemoryNotificationSource(),
        session = session ?? const FakeSessionService(),
        authRepository = authRepository ?? FakeAuthRepository();

  final IListingSource source;
  final IGroupSource groupSource;
  final IEngagementSource engagementSource;
  final IGroupChatSource chatSource;
  final IUserSource userSource;
  final INotificationSource notificationSource;

  /// Who is using the app. A [FakeSessionService] unless the test needs to
  /// switch people halfway, which takes a `TestSession`.
  final ISessionService session;

  /// What login, sign-up and logout talk to. The screens that sign out (home,
  /// profile) need an [AuthenticationController] to exist.
  final IAuthRepository authRepository;

  @override
  void dependencies() {
    // Screens refresh themselves on a timer in the app. A periodic timer left
    // running when a widget test ends is reported as a failure, and nothing in a
    // test needs a screen to refresh by itself.
    Poller.enabled = false;

    Get.put<ISessionService>(session, permanent: true);
    Get.put(
      ThemeController(MemoryPreferences(), initialMode: ThemeMode.system),
      permanent: true,
    );
    Get.put<IListingSource>(source, permanent: true);
    Get.put<IListingRepository>(
      ListingRepository(Get.find<IListingSource>()),
      permanent: true,
    );

    Get.put<IEngagementSource>(engagementSource, permanent: true);
    Get.put<IEngagementRepository>(
      EngagementRepository(Get.find<IEngagementSource>()),
      permanent: true,
    );

    Get.put<IGroupSource>(groupSource, permanent: true);
    Get.put<IGroupRepository>(
      GroupRepository(Get.find<IGroupSource>()),
      permanent: true,
    );

    Get.put<IGroupChatSource>(chatSource, permanent: true);
    Get.put<IGroupChatRepository>(
      GroupChatRepository(
        Get.find<IGroupChatSource>(),
        Get.find<IGroupRepository>(),
      ),
      permanent: true,
    );

    Get.put<IUserSource>(userSource, permanent: true);
    Get.put<IUserRepository>(
      UserRepository(Get.find<IUserSource>()),
      permanent: true,
    );

    Get.put<INotificationSource>(notificationSource, permanent: true);
    Get.put<INotificationRepository>(
      NotificationRepository(Get.find<INotificationSource>()),
      permanent: true,
    );
    Get.put(
      NotificationPublisher(Get.find<INotificationRepository>()),
      permanent: true,
    );
    Get.put(
      NotificationCenter(
        Get.find<INotificationRepository>(),
        Get.find<ISessionService>(),
      ),
      permanent: true,
    );

    Get.put<IAuthRepository>(authRepository, permanent: true);
    Get.put(AuthenticationController(authRepository), permanent: true);
  }
}

/// A signed-in student, without ROBLE.
///
/// The name is the one the home greeting asserts on; the id is what ends up in
/// `creator_id` and `member_ids` in the assertions about who owns what.
class FakeSessionService implements ISessionService {
  const FakeSessionService({
    this.currentUserId = 'user_1',
    this.currentUserName = 'Leonel Triana',
    this.currentUserEmail = 'leonel@uninorte.edu.co',
  });

  @override
  final String currentUserId;

  @override
  final String currentUserName;

  @override
  final String currentUserEmail;
}
