abstract class AppRoutes {
  static const home = '/home';

  static const listings = '/listings';
  static const createListing = '/listings/create';
  static const listingDetail = '/listings/detail/:id';
  static const joinRequest = '/listings/join/:id';

  static String detailOf(int id) => '/listings/detail/$id';

  static String joinOf(int id) => '/listings/join/$id';
}
