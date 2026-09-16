import 'package:get/get.dart';

import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/repositories/i_listing_repository.dart';

/// Backs the creator-facing request inbox. Not routed yet.
class RequestsViewModel extends GetxController {
  final IListingRepository _repository;

  RequestsViewModel(this._repository);

  final RxList<JoinRequest> requests = <JoinRequest>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();

  Future<void> load(int listingId) async {
    try {
      isLoading.value = true;
      error.value = null;

      requests.assignAll(await _repository.getRequestsForListing(listingId));
    } catch (_) {
      error.value = 'No se pudieron cargar las solicitudes';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> accept(int requestId) =>
      _resolve(requestId, JoinRequestStatus.accepted);

  Future<void> reject(int requestId) =>
      _resolve(requestId, JoinRequestStatus.rejected);

  Future<void> _resolve(int requestId, JoinRequestStatus status) async {
    try {
      error.value = null;

      if (status == JoinRequestStatus.accepted) {
        await _repository.acceptJoinRequest(requestId);
      } else {
        await _repository.rejectJoinRequest(requestId);
      }

      final index = requests.indexWhere((request) => request.id == requestId);

      if (index != -1) {
        requests[index] = requests[index].copyWith(status: status);
      }
    } catch (_) {
      error.value = 'No se pudo actualizar la solicitud';
    }
  }
}
