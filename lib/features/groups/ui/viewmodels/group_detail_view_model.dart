import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../listings/domain/models/listing.dart';
import '../../../listings/domain/repositories/i_listing_repository.dart';
import '../../domain/models/group.dart';
import '../../domain/models/group_request.dart';
import '../../domain/repositories/i_group_repository.dart';

/// One group: who is in it, who wants in, and what it has published.
///
/// Everything about running a group happens on this screen — asking to join,
/// accepting, rejecting, removing someone, deleting the group — so that a person
/// never has to remember which other screen held the other half of the job.
class GroupDetailViewModel extends GetxController {
  final IGroupRepository _groups;
  final IListingRepository _listings;
  final ISessionService _session;

  GroupDetailViewModel(this._groups, this._listings, this._session);

  final Rxn<Group> group = Rxn<Group>();
  final RxList<GroupRequest> requests = <GroupRequest>[].obs;
  final RxList<Listing> projects = <Listing>[].obs;
  final Rxn<GroupRequest> myRequest = Rxn<GroupRequest>();
  final RxBool isLoading = false.obs;

  /// True while a write is in flight, so the buttons can be disabled and a
  /// double tap cannot send the same acceptance twice.
  final RxBool isWorking = false.obs;
  final RxnString error = RxnString();

  /// The `_id` of the group, straight out of the route. Not parsed: it is a
  /// UUID, and the source treats anything that is not one as "not found".
  late final String groupId;

  @override
  void onInit() {
    super.onInit();
    groupId = Get.parameters['id'] ?? '';
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final found = await _groups.getGroupById(groupId);

      if (found == null) {
        error.value = 'Grupo no encontrado';
        group.value = null;
        return;
      }

      group.value = found;
      projects.assignAll(await _listings.getListingsByGroup(groupId));

      // Only the owner decides on requests, so only the owner pays for the read.
      if (found.isOwner(_session.currentUserId)) {
        requests.assignAll(await _groups.getRequestsForGroup(groupId));
        myRequest.value = null;
      } else {
        requests.clear();
        myRequest.value = await _groups.getMyRequestForGroup(
          groupId: groupId,
          applicantId: _session.currentUserId,
        );
      }
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo cargar el grupo',
      );
    } finally {
      isLoading.value = false;
    }
  }

  bool get isOwner => group.value?.isOwner(_session.currentUserId) ?? false;

  bool get isMember => group.value?.hasMember(_session.currentUserId) ?? false;

  bool get canRequestToJoin =>
      group.value != null && !isOwner && !isMember && myRequest.value == null;

  List<GroupRequest> get pendingRequests =>
      requests.where((request) => request.isPending).toList();

  Future<bool> requestToJoin(String message) async {
    final current = group.value;
    if (current == null) return false;

    return _write(
      fallback: 'No se pudo enviar la solicitud',
      action: () => _groups.requestToJoin(
        GroupRequest.draft(
          groupId: current.id,
          applicantId: _session.currentUserId,
          applicantName: _session.currentUserName,
          message: message.trim(),
        ),
      ),
    );
  }

  Future<bool> accept(String requestId) => _write(
        fallback: 'No se pudo aceptar la solicitud',
        action: () => _groups.acceptRequest(requestId),
      );

  Future<bool> reject(String requestId) => _write(
        fallback: 'No se pudo rechazar la solicitud',
        action: () => _groups.rejectRequest(requestId),
      );

  Future<bool> removeMember(String userId) => _write(
        fallback: 'No se pudo quitar al integrante',
        action: () => _groups.removeMember(groupId: groupId, userId: userId),
      );

  Future<bool> leave() => removeMember(_session.currentUserId);

  /// Deletes the group, but only once it has no projects left.
  ///
  /// Removing a group is not a reason to remove what it published: other people
  /// applied to those projects and may be on their teams. The owner deletes the
  /// projects first, on each project's own screen, and the refusal says so.
  Future<bool> deleteGroup() async {
    if (!isOwner) {
      error.value = 'Solo quien creó el grupo puede eliminarlo.';
      return false;
    }

    if (projects.isNotEmpty) {
      final count = projects.length;
      error.value = count == 1
          ? 'Este grupo tiene 1 proyecto publicado. Elimínalo antes de '
              'eliminar el grupo.'
          : 'Este grupo tiene $count proyectos publicados. Elimínalos antes '
              'de eliminar el grupo.';
      return false;
    }

    return _write(
      fallback: 'No se pudo eliminar el grupo',
      reload: false,
      action: () => _groups.deleteGroup(groupId),
    );
  }

  /// Runs a write with the loading flag, the error message and the reload that
  /// every one of them needs, so each action above is one line.
  Future<bool> _write({
    required Future<void> Function() action,
    required String fallback,
    bool reload = true,
  }) async {
    if (isWorking.value) return false;

    try {
      isWorking.value = true;
      error.value = null;

      await action();

      if (reload) await load();

      return true;
    } catch (failure) {
      error.value = errorMessage(failure, fallback: fallback);

      return false;
    } finally {
      isWorking.value = false;
    }
  }
}
