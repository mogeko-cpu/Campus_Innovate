import 'package:get/get.dart';

import '../../../../core/i_session_service.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/repositories/i_listing_repository.dart';

class JoinRequestViewModel extends GetxController {
  final IListingRepository _repository;
  final ISessionService _session;

  JoinRequestViewModel(this._repository, this._session);

  final RxBool isSending = false.obs;
  final RxnString error = RxnString();

  late final int listingId;

  @override
  void onInit() {
    super.onInit();
    listingId = int.tryParse(Get.parameters['id'] ?? '') ?? -1;
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
        JoinRequest(
          id: DateTime.now().millisecondsSinceEpoch,
          listingId: listingId,
          applicantId: _session.currentUserId,
          applicantName: _session.currentUserName,
          motivation: motivation.trim(),
          skills: skills.trim(),
          availability: availability.trim(),
          status: JoinRequestStatus.pending,
        ),
      );

      return true;
    } catch (_) {
      error.value = 'No se pudo enviar la solicitud';

      return false;
    } finally {
      isSending.value = false;
    }
  }
}
