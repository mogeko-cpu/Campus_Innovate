import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../notifications/domain/models/notification_target.dart';
import '../../../notifications/domain/notification_publisher.dart';
import '../../data/repositories/listing_repository.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_status.dart';
import '../../domain/repositories/i_listing_repository.dart';

/// The leader's edit form: the text of the project, its size and skills, and
/// where it stands.
class EditListingViewModel extends GetxController {
  final IListingRepository _repository;
  final NotificationPublisher _notifier;
  final ISessionService _session;

  EditListingViewModel(this._repository, this._notifier, this._session);

  final Rxn<Listing> listing = Rxn<Listing>();
  final RxString category = ''.obs;
  final RxInt maxMembers = 4.obs;
  final RxList<String> requiredSkills = <String>[].obs;
  final Rx<ListingStatus> status = ListingStatus.idea.obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxnString error = RxnString();

  late final String listingId;

  @override
  void onInit() {
    super.onInit();
    listingId = Get.parameters['id'] ?? '';
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final found = await _repository.getListingById(listingId);

      if (found == null) {
        error.value = 'Proyecto no encontrado';
        return;
      }

      if (!found.isLeader(_session.currentUserId)) {
        error.value = 'Solo el líder del proyecto puede editarlo.';
        return;
      }

      listing.value = found;
      category.value = found.category;
      maxMembers.value = found.maxMembers;
      requiredSkills.assignAll(found.requiredSkills);
      status.value = found.status;
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo cargar el proyecto',
      );
    } finally {
      isLoading.value = false;
    }
  }

  /// The team cannot be made smaller than the people already in it.
  int get minMembers {
    final current = listing.value?.memberIds.length ?? 0;

    return current > ListingRepository.minTeamSize
        ? current
        : ListingRepository.minTeamSize;
  }

  /// Marking the project finished closes it to newcomers, which the form says
  /// before the leader saves.
  bool get closesRequests =>
      status.value == ListingStatus.done &&
      listing.value?.status != ListingStatus.done;

  void selectCategory(String value) => category.value = value;

  void selectStatus(ListingStatus value) => status.value = value;

  void setMaxMembers(int value) => maxMembers.value =
      value.clamp(minMembers, ListingRepository.maxTeamSize);

  void addSkill(String skill) {
    final clean = skill.trim();

    if (clean.isEmpty || requiredSkills.contains(clean)) return;

    requiredSkills.add(clean);
  }

  void removeSkill(String skill) => requiredSkills.remove(skill);

  Future<Listing?> submit({
    required String title,
    required String description,
  }) async {
    final current = listing.value;
    if (current == null || isSaving.value) return null;

    try {
      isSaving.value = true;
      error.value = null;

      final saved = await _repository.updateListing(
        current.copyWith(
          title: title,
          description: description,
          category: category.value,
          maxMembers: maxMembers.value,
          requiredSkills: List.unmodifiable(requiredSkills),
          status: status.value,
        ),
        actorId: _session.currentUserId,
      );

      if (saved.status == ListingStatus.done &&
          current.status != ListingStatus.done) {
        await _closeRequests(saved);
      }

      listing.value = saved;

      return saved;
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudieron guardar los cambios',
      );

      return null;
    } finally {
      isSaving.value = false;
    }
  }

  /// A finished project answers everybody still waiting, so nobody is left with
  /// a request nobody will ever look at. Best effort: the project is already
  /// saved as finished, and its requests can no longer be accepted anyway.
  Future<void> _closeRequests(Listing saved) async {
    try {
      final closed = await _repository.closePendingRequests(saved.id);

      for (final request in closed) {
        await _notifier.requestResolved(
          accepted: false,
          target: NotificationTarget.listing,
          targetId: saved.id,
          targetName: saved.title,
          deciderId: _session.currentUserId,
          applicantId: request.applicantId,
        );
      }
    } catch (_) {
      // See above.
    }
  }
}
