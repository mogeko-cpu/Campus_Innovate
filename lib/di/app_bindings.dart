import 'package:get/get.dart';

import '../core/i_session_service.dart';
import '../core/mock_session_service.dart';
import '../features/listings/data/datasources/i_listing_source.dart';
import '../features/listings/data/datasources/local/local_listing_source.dart';
import '../features/listings/data/repositories/listing_repository.dart';
import '../features/listings/domain/repositories/i_listing_repository.dart';

/// Registers the dependencies shared by every route.
///
/// The listing source is permanent so in-memory data survives navigation.
class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.put<ISessionService>(const MockSessionService(), permanent: true);
    Get.put<IListingSource>(LocalListingSource(), permanent: true);
    Get.put<IListingRepository>(
      ListingRepository(Get.find<IListingSource>()),
      permanent: true,
    );
  }
}
