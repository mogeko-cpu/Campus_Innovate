import 'package:get/get.dart';

import '../../../../core/data/mock_session.dart';
import '../../domain/models/listing.dart';
import '../../domain/repositories/i_listing_repository.dart';

class CreateListingViewModel extends GetxController {
  final IListingRepository repository;

  CreateListingViewModel(this.repository);

  String? message;
  String? error;

  bool isLoading = false;

  Future<bool> createListing({
    required String title,
    required String description,
    required String category,
    required int maxMembers,
    required List<String> requiredSkills,
  }) async {
    try {
      isLoading = true;
      update();

      final listing = Listing(
        id: DateTime.now().millisecondsSinceEpoch,
        title: title,
        description: description,
        category: category,
        creatorId: MockSession.currentUserId,
        creatorName: MockSession.currentUserName,
        maxMembers: maxMembers,
        requiredSkills: requiredSkills,
        memberIds: [
          MockSession.currentUserId,
        ],
      );

      await repository.createListing(listing);

      message = 'Proyecto creado correctamente';

      return true;
    } catch (e) {
      error = 'No se pudo crear el proyecto';

      return false;
    } finally {
      isLoading = false;
      update();
    }
  }
}