import '../models/listing.dart';

abstract class IListingRepository {
  Future<List<Listing>> getFeaturedListings();
}