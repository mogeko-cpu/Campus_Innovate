import 'package:get/get.dart';

import '../features/home/home_dependencies.dart';
import '../features/home/ui/views/home_page.dart';
import '../features/listings/listings_dependencies.dart';
import '../features/listings/ui/views/create_listing_page.dart';
import '../features/listings/ui/views/join_request_page.dart';
import '../features/listings/ui/views/listing_detail_page.dart';
import '../features/listings/ui/views/listings_page.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = <GetPage>[
    GetPage(
      name: AppRoutes.home,
      page: () => const HomePage(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.listings,
      page: () => const ListingsPage(),
      binding: ListingsBinding(),
    ),
    GetPage(
      name: AppRoutes.createListing,
      page: () => const CreateListingPage(),
      binding: CreateListingBinding(),
    ),
    GetPage(
      name: AppRoutes.listingDetail,
      page: () => const ListingDetailPage(),
      binding: ListingDetailBinding(),
    ),
    GetPage(
      name: AppRoutes.joinRequest,
      page: () => const JoinRequestPage(),
      binding: JoinRequestBinding(),
    ),
  ];
}
