import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../domain/models/group.dart';
import '../../domain/repositories/i_group_repository.dart';

class CreateGroupViewModel extends GetxController {
  final IGroupRepository _repository;
  final ISessionService _session;

  CreateGroupViewModel(this._repository, this._session);

  final RxBool isSaving = false.obs;
  final RxnString error = RxnString();

  Future<Group?> submit({
    required String name,
    required String description,
  }) async {
    try {
      isSaving.value = true;
      error.value = null;

      // A draft with no id: ROBLE assigns it, and the saved group comes back
      // with it — the same rule the rest of the app follows, so nothing invents
      // an identifier two devices could collide on.
      final draft = Group.draft(
        name: name.trim(),
        description: description.trim(),
        ownerId: _session.currentUserId,
        ownerName: _session.currentUserName,
      );

      return await _repository.createGroup(draft);
    } catch (failure) {
      // ROBLE's own wording is the useful part here: "espera 40 segundos" or
      // "tu sesión expiró" tell the user what to do; a generic line does not.
      error.value = errorMessage(failure, fallback: 'No se pudo crear el grupo');

      return null;
    } finally {
      isSaving.value = false;
    }
  }
}
