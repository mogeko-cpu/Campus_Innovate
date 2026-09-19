import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../listings/domain/models/listing.dart';
import '../../../listings/domain/repositories/i_listing_repository.dart';

class HomeViewModel extends GetxController {
  final IListingRepository _repository;
  final ISessionService _session;

  HomeViewModel(this._repository, this._session);

  final RxList<Listing> featuredListings = <Listing>[].obs;
  final RxList<Listing> myListings = <Listing>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();

  String get userName => _session.currentUserName;

  String get firstName => userName.split(' ').first;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final featured = await _repository.getFeaturedListings();
      final mine = await _repository.getJoinedListings(_session.currentUserId);

      featuredListings.assignAll(featured);
      myListings.assignAll(mine);
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudieron cargar las ideas',
      );
    } finally {
      isLoading.value = false;
    }
  }
}
