import '../../domain/models/listing.dart';
import '../../domain/repositories/i_listing_repository.dart';
import '../../../../core/data/mock_data.dart';

class LocalListingRepository implements IListingRepository {
  @override
  Future<List<Listing>> getFeaturedListings() async {
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    return MockData.featuredListings;
  }
}