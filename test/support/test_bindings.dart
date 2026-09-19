import 'package:campus_innovate/core/i_session_service.dart';
import 'package:campus_innovate/features/listings/data/datasources/i_listing_source.dart';
import 'package:campus_innovate/features/listings/data/repositories/listing_repository.dart';
import 'package:campus_innovate/features/listings/domain/repositories/i_listing_repository.dart';
import 'package:get/get.dart';

import 'in_memory_listing_source.dart';

/// The app's graph with storage and identity replaced by doubles.
///
/// Mirrors `AppBindings` from `ISessionService` down, so the widget tests exercise
/// the real view models, repository and screens; only ROBLE is absent.
class TestBindings extends Bindings {
  TestBindings({IListingSource? source}) : source = source ?? InMemoryListingSource();

  final IListingSource source;

  @override
  void dependencies() {
    Get.put<ISessionService>(const FakeSessionService(), permanent: true);
    Get.put<IListingSource>(source, permanent: true);
    Get.put<IListingRepository>(
      ListingRepository(Get.find<IListingSource>()),
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
  });

  @override
  final String currentUserId;

  @override
  final String currentUserName;
}
