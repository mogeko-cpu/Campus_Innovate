import 'package:get/get.dart';

import '../features/auth/ui/views/login_page.dart';
import '../features/auth/ui/views/signup_page.dart';
import '../features/groups/groups_dependencies.dart';
import '../features/groups/ui/views/create_group_page.dart';
import '../features/groups/ui/views/group_detail_page.dart';
import '../features/groups/ui/views/groups_page.dart';
import '../features/home/home_dependencies.dart';
import '../features/home/ui/views/home_page.dart';
import '../features/listings/listings_dependencies.dart';
import '../features/listings/ui/views/create_listing_page.dart';
import '../features/listings/ui/views/join_request_page.dart';
import '../features/listings/ui/views/listing_detail_page.dart';
import '../features/listings/ui/views/listings_page.dart';
import '../features/listings/ui/views/ranking_page.dart';
import '../features/profile/profile_dependencies.dart';
import '../features/profile/ui/views/profile_page.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = <GetPage>[
    // The auth pages need no binding: [AuthenticationController] is registered
    // by the composition root, since the session outlives any single route.
    GetPage(name: AppRoutes.login, page: () => const LoginPage()),
    GetPage(name: AppRoutes.signup, page: () => const SignUpPage()),
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
    GetPage(
      name: AppRoutes.ranking,
      page: () => const RankingPage(),
      binding: RankingBinding(),
    ),
    GetPage(
      name: AppRoutes.groups,
      page: () => const GroupsPage(),
      binding: GroupsBinding(),
    ),
    GetPage(
      name: AppRoutes.createGroup,
      page: () => const CreateGroupPage(),
      binding: CreateGroupBinding(),
    ),
    GetPage(
      name: AppRoutes.groupDetail,
      page: () => const GroupDetailPage(),
      binding: GroupDetailBinding(),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfilePage(),
      binding: ProfileBinding(),
    ),
  ];
}
