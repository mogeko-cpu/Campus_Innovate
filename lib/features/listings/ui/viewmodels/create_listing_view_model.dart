import 'package:get/get.dart';

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

      final listing = Listing(
        id: DateTime.now().millisecondsSinceEpoch,
        title: title.trim(),
        description: description.trim(),
        category: category.value,
        creatorId: _session.currentUserId,
        creatorName: _session.currentUserName,
        maxMembers: maxMembers.value,
        requiredSkills: List.unmodifiable(requiredSkills),
        memberIds: [_session.currentUserId],
      );

      return await _repository.createListing(listing);
    } catch (_) {
      error.value = 'No se pudo crear el proyecto';

      return null;
    } finally {
      isSaving.value = false;
    }
  }
}
