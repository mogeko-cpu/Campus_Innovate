import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../groups/domain/models/group.dart';
import '../../../groups/domain/repositories/i_group_repository.dart';
import '../../domain/listing_exception.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_category.dart';
import '../../domain/repositories/i_listing_repository.dart';

class CreateListingViewModel extends GetxController {
  final IListingRepository _repository;
  final IGroupRepository _groups;
  final ISessionService _session;

  CreateListingViewModel(this._repository, this._groups, this._session);

  final RxString category = listingCategories.first.obs;
  final RxInt maxMembers = 4.obs;
  final RxList<String> requiredSkills = <String>[].obs;
  final RxBool isSaving = false.obs;
  final RxnString error = RxnString();

  /// The groups this person can publish on behalf of.
  final RxList<Group> myGroups = <Group>[].obs;
  final Rxn<Group> selectedGroup = Rxn<Group>();
  final RxBool isLoadingGroups = false.obs;

  /// Nothing to publish under yet. The form says so and points at the groups
  /// screen instead of letting someone fill it in for nothing.
  bool get hasNoGroups => !isLoadingGroups.value && myGroups.isEmpty;

  @override
  void onInit() {
    super.onInit();
    loadGroups();
  }

  Future<void> loadGroups() async {
    try {
      isLoadingGroups.value = true;

      final groups = await _groups.getMyGroups(_session.currentUserId);
      myGroups.assignAll(groups);

      // One group is not a choice, so it is made for them.
      selectedGroup.value = groups.length == 1 ? groups.first : null;
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudieron cargar tus grupos',
      );
    } finally {
      isLoadingGroups.value = false;
    }
  }

  void selectGroup(Group group) => selectedGroup.value = group;

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

      final group = selectedGroup.value;

      // Every project belongs to a group: that is what ties its likes, views and
      // comments to one owner, and there is no screen that could adopt an
      // orphan afterwards.
      if (group == null) {
        throw const ListingException(
          'Elige el grupo que publica este proyecto.',
        );
      }

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
        groupId: group.id,
        groupName: group.name,
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
