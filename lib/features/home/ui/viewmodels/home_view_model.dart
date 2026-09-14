import 'package:get/get.dart';

import '../../../listings/domain/models/listing.dart';
import '../../../listings/domain/repositories/i_listing_repository.dart';

class HomeViewModel extends GetxController {
  final IListingRepository listingRepository;

  HomeViewModel(this.listingRepository);

  final RxList<Listing> featuredListings = <Listing>[].obs;

  final RxBool isLoading = false.obs;

  String? message;
  String? error;

  @override
  void onInit() {
    super.onInit();
    loadFeaturedListings();
  }

  Future<void> loadFeaturedListings() async {
    try {
      isLoading.value = true;
      error = null;

      final listings =
          await listingRepository.getFeaturedListings();

      featuredListings.assignAll(listings);

      message = 'Ideas destacadas cargadas correctamente';
    } catch (e) {
      error = 'No se pudieron cargar las ideas';
    } finally {
      isLoading.value = false;
    }
  }
}