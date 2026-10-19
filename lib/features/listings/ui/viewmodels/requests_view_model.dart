import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../notifications/domain/models/notification_target.dart';
import '../../../notifications/domain/notification_publisher.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/repositories/i_listing_repository.dart';

/// Backs the creator-facing request inbox, which lives inside the project's
/// detail screen: whoever published a project decides there who joins it.
class RequestsViewModel extends GetxController {
  final IListingRepository _repository;
  final NotificationPublisher _notifier;
  final ISessionService _session;

  RequestsViewModel(this._repository, this._notifier, this._session);

  final RxList<JoinRequest> requests = <JoinRequest>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString error = RxnString();

  String _listingId = '';
  String _listingTitle = '';

  /// [listingTitle] is only for the wording of the notification the applicant
  /// receives when their request is answered.
  Future<void> load(String listingId, {String listingTitle = ''}) async {
    _listingId = listingId;
    _listingTitle = listingTitle;

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

      final index = requests.indexWhere((request) => request.id == requestId);
      final request = index == -1 ? null : requests[index];

      if (status == JoinRequestStatus.accepted) {
        await _repository.acceptJoinRequest(requestId);
      } else {
        await _repository.rejectJoinRequest(requestId);
      }

      // The inbox only lists pending requests, so changing the status is what
      // takes it off the screen.
      final current = requests.indexWhere((item) => item.id == requestId);

      if (current != -1) {
        requests[current] = requests[current].copyWith(status: status);
      }

      if (request != null) {
        await _notifier.requestResolved(
          accepted: status == JoinRequestStatus.accepted,
          target: NotificationTarget.listing,
          targetId: _listingId,
          targetName: _listingTitle,
          deciderId: _session.currentUserId,
          applicantId: request.applicantId,
        );
      }
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo actualizar la solicitud',
      );
    }
  }
}
