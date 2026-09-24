import 'package:campus_innovate/core/i_session_service.dart';
import 'package:campus_innovate/core/theme_controller.dart';
import 'package:campus_innovate/features/groups/data/datasources/i_group_source.dart';
import 'package:flutter/material.dart';
import 'package:campus_innovate/features/groups/data/repositories/group_repository.dart';
import 'package:campus_innovate/features/groups/domain/repositories/i_group_repository.dart';
import 'package:campus_innovate/features/listings/data/datasources/i_engagement_source.dart';
import 'package:campus_innovate/features/listings/data/datasources/i_listing_source.dart';
import 'package:campus_innovate/features/listings/data/repositories/engagement_repository.dart';
import 'package:campus_innovate/features/listings/data/repositories/listing_repository.dart';
import 'package:campus_innovate/features/listings/domain/repositories/i_engagement_repository.dart';
import 'package:campus_innovate/features/listings/domain/repositories/i_listing_repository.dart';
import 'package:get/get.dart';

import 'in_memory_engagement_source.dart';
import 'in_memory_group_source.dart';
import 'in_memory_listing_source.dart';
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
  })  : source = source ?? InMemoryListingSource(),
        groupSource = groupSource ?? InMemoryGroupSource(),
        engagementSource = engagementSource ?? InMemoryEngagementSource();

  final IListingSource source;
  final IGroupSource groupSource;
  final IEngagementSource engagementSource;

  @override
  void dependencies() {
    Get.put<ISessionService>(const FakeSessionService(), permanent: true);
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
