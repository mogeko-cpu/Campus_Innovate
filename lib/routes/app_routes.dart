abstract class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';

  static const home = '/home';

  static const listings = '/listings';
  static const createListing = '/listings/create';
  static const listingDetail = '/listings/detail/:id';
  static const joinRequest = '/listings/join/:id';

  /// Ids in the path are the `_id` UUIDs of the rows.
  static String detailOf(String id) => '/listings/detail/$id';

  static String joinOf(String id) => '/listings/join/$id';
}
