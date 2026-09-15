import 'package:get/get.dart';

import '../../../../core/data/mock_session.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/i_listing_repository.dart';

class ListingsViewModel extends GetxController {
  final IListingRepository repository;

  ListingsViewModel(this.repository);

  final RxList<Listing> listings = <Listing>[].obs;
  final RxBool isLoading = false.obs;

  String? message;
  String? error;

  @override
  void onInit() {
    super.onInit();
    loadListings();
  }

  Future<void> loadListings() async {
    try {
      isLoading.value = true;
      error = null;

      final result = await repository.getListings();

      listings.assignAll(result);
    } catch (e) {
      error = 'No se pudieron cargar los proyectos';
    } finally {
      isLoading.value = false;
    }
  }

  bool isMember(Listing listing) {
    return listing.memberIds.contains(
      MockSession.currentUserId,
    );
  }
}