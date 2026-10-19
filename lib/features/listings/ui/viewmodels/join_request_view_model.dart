import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../notifications/domain/models/notification_target.dart';
import '../../../notifications/domain/notification_publisher.dart';
import '../../domain/models/join_request.dart';
import '../../domain/repositories/i_listing_repository.dart';

class JoinRequestViewModel extends GetxController {
  final IListingRepository _repository;
  final NotificationPublisher _notifier;
  final ISessionService _session;

  JoinRequestViewModel(this._repository, this._notifier, this._session);

  final RxBool isSending = false.obs;
  final RxnString error = RxnString();

  late final String listingId;

  @override
  void onInit() {
    super.onInit();
    listingId = Get.parameters['id'] ?? '';
  }

  Future<bool> submit({
    required String motivation,
    required String skills,
    required String availability,
  }) async {
    try {
      isSending.value = true;
      error.value = null;

      await _repository.createJoinRequest(
        JoinRequest.draft(
          listingId: listingId,
          applicantId: _session.currentUserId,
          applicantName: _session.currentUserName,
          motivation: motivation.trim(),
          skills: skills.trim(),
          availability: availability.trim(),
        ),
      );

      await _notifyCreator();

      return true;
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo enviar la solicitud',
      );

      return false;
    } finally {
      isSending.value = false;
    }
  }

  /// Tells whoever published the project that somebody wants in. Best effort:
  /// the request is already stored, and failing to find the project to notify
  /// its creator must not make the applicant think it was not sent.
  Future<void> _notifyCreator() async {
    try {
      final listing = await _repository.getListingById(listingId);
      if (listing == null) return;

      await _notifier.joinRequestReceived(
        target: NotificationTarget.listing,
        targetId: listing.id,
        targetName: listing.title,
        applicantId: _session.currentUserId,
        applicantName: _session.currentUserName,
        recipientId: listing.creatorId,
      );
    } catch (_) {
      // See above.
    }
  }
}
