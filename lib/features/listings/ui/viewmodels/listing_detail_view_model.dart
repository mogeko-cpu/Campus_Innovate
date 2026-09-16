import 'package:get/get.dart';

import '../../../../core/i_session_service.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/i_listing_repository.dart';

class ListingDetailViewModel extends GetxController {
  final IListingRepository _repository;
  final ISessionService _session;

  ListingDetailViewModel(this._repository, this._session);

  final Rxn<Listing> listing = Rxn<Listing>();
  final Rxn<JoinRequest> myRequest = Rxn<JoinRequest>();
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();

  late final int listingId;

  @override
  void onInit() {
    super.onInit();
    listingId = int.tryParse(Get.parameters['id'] ?? '') ?? -1;
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final found = await _repository.getListingById(listingId);

      if (found == null) {
        error.value = 'Proyecto no encontrado';
        return;
      }

      listing.value = found;
      myRequest.value = await _repository.getMyRequestForListing(
        listingId: listingId,
        applicantId: _session.currentUserId,
      );
    } catch (_) {
      error.value = 'No se pudo cargar el proyecto';
    } finally {
      isLoading.value = false;
    }
  }

  bool get isCreator => listing.value?.creatorId == _session.currentUserId;

  bool get isMember =>
      listing.value?.memberIds.contains(_session.currentUserId) ?? false;

  bool get canRequestToJoin =>
      listing.value != null &&
      !isCreator &&
      !isMember &&
      !listing.value!.isFull &&
      myRequest.value == null;
}
