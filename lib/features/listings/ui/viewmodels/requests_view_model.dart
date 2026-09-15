import 'package:get/get.dart';

import '../../domain/models/join_request.dart';
import '../../domain/repositories/i_listing_repository.dart';

class RequestsViewModel extends GetxController {
  final IListingRepository repository;

  RequestsViewModel(this.repository);

  final RxList<JoinRequest> requests = <JoinRequest>[].obs;

  String? message;
  String? error;

  Future<void> loadRequests(int listingId) async {
    try {
      final result = await repository.getRequestsForListing(
        listingId,
      );

      requests.assignAll(result);
    } catch (e) {
      error = 'No se pudieron cargar las solicitudes';
    }
  }

  Future<void> acceptRequest(int requestId) async {
    try {
      await repository.acceptJoinRequest(requestId);

      message = 'Solicitud aceptada';

      final request = requests.firstWhere(
        (item) => item.id == requestId,
      );

      final index = requests.indexOf(request);

      requests[index] = request.copyWith(
        status: 'accepted',
      );
    } catch (e) {
      error = 'No se pudo aceptar la solicitud';
    }
  }

  Future<void> rejectRequest(int requestId) async {
    try {
      await repository.rejectJoinRequest(requestId);

      message = 'Solicitud rechazada';

      final request = requests.firstWhere(
        (item) => item.id == requestId,
      );

      final index = requests.indexOf(request);

      requests[index] = request.copyWith(
        status: 'rejected',
      );
    } catch (e) {
      error = 'No se pudo rechazar la solicitud';
    }
  }
}