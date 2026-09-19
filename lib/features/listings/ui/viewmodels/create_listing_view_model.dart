import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_category.dart';
import '../../domain/repositories/i_listing_repository.dart';

class CreateListingViewModel extends GetxController {
  final IListingRepository _repository;
  final ISessionService _session;

  CreateListingViewModel(this._repository, this._session);

  final RxString category = listingCategories.first.obs;
  final RxInt maxMembers = 4.obs;
  final RxList<String> requiredSkills = <String>[].obs;
  final RxBool isSaving = false.obs;
  final RxnString error = RxnString();

  void selectCategory(String value) => category.value = value;

  void setMaxMembers(int value) => maxMembers.value = value.clamp(2, 12);

  void addSkill(String skill) {
    final clean = skill.trim();

    if (clean.isEmpty || requiredSkills.contains(clean)) {
      return;
    }

    requiredSkills.add(clean);
  }

  void removeSkill(String skill) => requiredSkills.remove(skill);

  Future<Listing?> submit({
    required String title,
    required String description,
  }) async {
    try {
      isSaving.value = true;
      error.value = null;

      // A draft with no id: ROBLE assigns it, and the saved project comes back
      // with it. The app used to make one up from the clock, which two devices
      // publishing in the same millisecond would have collided on.
      final draft = Listing.draft(
        title: title.trim(),
        description: description.trim(),
        category: category.value,
        creatorId: _session.currentUserId,
        creatorName: _session.currentUserName,
        maxMembers: maxMembers.value,
        requiredSkills: List.unmodifiable(requiredSkills),
      );

      return await _repository.createListing(draft);
    } catch (failure) {
      // ROBLE's own wording is the useful part here: "espera 40 segundos" or
      // "tu sesión expiró" tell the user what to do; a generic line does not.
      error.value = errorMessage(failure, fallback: 'No se pudo crear el proyecto');

      return null;
    } finally {
      isSaving.value = false;
    }
  }
}
