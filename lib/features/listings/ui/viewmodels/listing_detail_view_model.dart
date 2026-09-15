import 'package:get/get.dart';

import '../../../../core/data/mock_session.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/i_listing_repository.dart';

class ListingDetailViewModel extends GetxController {
  final IListingRepository repository;

  ListingDetailViewModel(this.repository);

  final Rxn<Listing> listing = Rxn<Listing>();

  final RxBool isLoading = false.obs;

  String? message;
  String? error;

  Future<void> loadListing(int id) async {
    try {
      isLoading.value = true;

      final result = await repository.getListingById(id);

      listing.value = result;
    } catch (e) {
      error = 'No se pudo cargar el proyecto';
    } finally {
      isLoading.value = false;
    }
  }

  bool get isCreator {
    return listing.value?.creatorId ==
        MockSession.currentUserId;
  }

  bool get isMember {
    return listing.value?.memberIds.contains(
          MockSession.currentUserId,
        ) ??
        false;
  }

  Future<bool> sendJoinRequest({
    required String motivation,
    required String skills,
    required String availability,
  }) async {
    try {
      if (listing.value == null) {
        error = 'Proyecto no encontrado';
        return false;
      }

      final request = JoinRequest(
        id: DateTime.now().millisecondsSinceEpoch,
        listingId: listing.value!.id,
        applicantId: MockSession.currentUserId,
        applicantName: MockSession.currentUserName,
        motivation: motivation,
        skills: skills,
        availability: availability,
        status: 'pending',
      );

      await repository.createJoinRequest(request);

      message = 'Solicitud enviada correctamente';

      return true;
    } catch (e) {
      error = 'No se pudo enviar la solicitud';

      return false;
    }
  }
}