import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/i_listing_repository.dart';

class ListingsViewModel extends GetxController {
  final IListingRepository _repository;
  final ISessionService _session;

  ListingsViewModel(this._repository, this._session);

  final RxList<Listing> _all = <Listing>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();
  final RxnString selectedCategory = RxnString();
  final RxString query = ''.obs;

  List<Listing> get listings {
    final category = selectedCategory.value;
    final text = query.value.trim().toLowerCase();

    return _all.where((listing) {
      final matchesCategory = category == null || listing.category == category;
      final matchesText = text.isEmpty ||
          listing.title.toLowerCase().contains(text) ||
          listing.description.toLowerCase().contains(text);

      return matchesCategory && matchesText;
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      _all.assignAll(await _repository.getListings());
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudieron cargar los proyectos',
      );
    } finally {
      isLoading.value = false;
    }
  }

  void filterByCategory(String? category) => selectedCategory.value = category;

  void search(String text) => query.value = text;

  bool isMember(Listing listing) =>
      listing.memberIds.contains(_session.currentUserId);
}
