import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/repositories/i_listing_repository.dart';

/// Backs the creator-facing request inbox, which lives inside the project's
/// detail screen: whoever published a project decides there who joins it.
class RequestsViewModel extends GetxController {
  final IListingRepository _repository;

  RequestsViewModel(this._repository);

  final RxList<JoinRequest> requests = <JoinRequest>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();

  Future<void> load(String listingId) async {
    try {
      isLoading.value = true;
      error.value = null;

      requests.assignAll(await _repository.getRequestsForListing(listingId));
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudieron cargar las solicitudes',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> accept(String requestId) =>
      _resolve(requestId, JoinRequestStatus.accepted);

  Future<void> reject(String requestId) =>
      _resolve(requestId, JoinRequestStatus.rejected);

  Future<void> _resolve(String requestId, JoinRequestStatus status) async {
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
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo actualizar la solicitud',
      );
    }
  }
}
