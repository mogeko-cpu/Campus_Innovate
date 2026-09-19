import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../domain/models/join_request.dart';
import '../../domain/repositories/i_listing_repository.dart';

class JoinRequestViewModel extends GetxController {
  final IListingRepository _repository;
  final ISessionService _session;

  JoinRequestViewModel(this._repository, this._session);

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
}
