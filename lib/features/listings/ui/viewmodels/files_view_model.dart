import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_file_picker.dart';
import '../../../../core/i_link_opener.dart';
import '../../../../core/i_session_service.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/project_file.dart';
import '../../domain/repositories/i_listing_repository.dart';
import '../../domain/repositories/i_project_file_repository.dart';

/// What a project's team shares: documents and images uploaded to the bucket,
/// and links to whatever lives elsewhere.
///
/// Only the team sees it — leader, members and mentor — the same people who see
/// the board.
class FilesViewModel extends GetxController {
  final IProjectFileRepository _files;
  final IListingRepository _listings;
  final ISessionService _session;
  final IFilePicker _picker;
  final ILinkOpener _links;

  FilesViewModel(
    this._files,
    this._listings,
    this._session,
    this._picker,
    this._links,
  );

  final Rxn<Listing> listing = Rxn<Listing>();

  /// Newest first, as the repository returns them.
  final RxList<ProjectFile> files = <ProjectFile>[].obs;
  final RxBool isLoading = false.obs;

  /// True while a write is in flight, so a double tap cannot send it twice.
  final RxBool isWorking = false.obs;

  /// The name of the file on its way to the bucket, or null. Apart from
  /// [isWorking] because the upload is the one write slow enough to deserve
  /// its own progress bar.
  final RxnString uploading = RxnString();

  /// Why the screen could not open; replaces the list.
  final RxnString error = RxnString();

  /// Why the last action failed; apart from [error], because a button that
  /// failed must not take the list away.
  String? lastActionError;

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

      final found = await _listings.getListingById(listingId);

      if (found == null) {
        error.value = 'Proyecto no encontrado';
        return;
      }

      // What the team shares is the team's, like its board.
      if (found.roleOf(_session.currentUserId) == null) {
        error.value = 'Solo el equipo del proyecto puede ver sus archivos.';
        return;
      }

      listing.value = found;
      files.assignAll(await _files.getFiles(listingId));
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudieron cargar los archivos',
      );
    } finally {
      isLoading.value = false;
    }
  }

  String get currentUserId => _session.currentUserId;

  bool canDelete(ProjectFile file) => file.uploaderId == currentUserId;

  int get uploadCount => files.where((file) => !file.isLink).length;

  int get linkCount => files.where((file) => file.isLink).length;

  /// Asks for a file and uploads it.
  ///
  /// Null when the person closed the chooser without picking anything, which is
  /// neither a success nor an error and deserves no message.
  Future<bool?> upload() async {
    if (isWorking.value) return false;

    final PickedFile? picked;

    try {
      picked = await _picker.pickFile();
    } catch (failure) {
      lastActionError = errorMessage(
        failure,
        fallback: 'No se pudo abrir el selector de archivos',
      );
      return false;
    }

    if (picked == null) return null;

    uploading.value = picked.name;

    try {
      return await _run(
        fallback: 'No se pudo subir el archivo',
        action: () async {
          files.insert(
            0,
            await _files.uploadFile(
              listingId: listingId,
              uploaderId: currentUserId,
              uploaderName: _session.currentUserName,
              file: picked!,
            ),
          );
        },
      );
    } finally {
      uploading.value = null;
    }
  }

  Future<bool> addLink({required String name, required String url}) => _run(
        fallback: 'No se pudo guardar el enlace',
        action: () async {
          files.insert(
            0,
            await _files.addLink(
              listingId: listingId,
              uploaderId: currentUserId,
              uploaderName: _session.currentUserName,
              name: name,
              url: url,
            ),
          );
        },
      );

  /// Opens a link as it is, or an upload through a download link signed now.
  Future<bool> open(ProjectFile file) async {
    try {
      lastActionError = null;

      final opened = await _links.open(await _files.urlToOpen(file));

      if (!opened) {
        lastActionError = 'Este dispositivo no pudo abrir "${file.name}".';
      }

      return opened;
    } catch (failure) {
      lastActionError = errorMessage(
        failure,
        fallback: 'No se pudo abrir el archivo',
      );

      return false;
    }
  }

  Future<bool> delete(ProjectFile file) => _run(
        fallback: 'No se pudo eliminar el archivo',
        action: () async {
          await _files.deleteFile(fileId: file.id, actorId: currentUserId);
          files.removeWhere((item) => item.id == file.id);
        },
      );

  /// Each action updates the list it touched with the row as stored, instead of
  /// reading everything again.
  Future<bool> _run({
    required Future<void> Function() action,
    required String fallback,
  }) async {
    if (isWorking.value) return false;

    try {
      isWorking.value = true;
      lastActionError = null;

      await action();

      return true;
    } catch (failure) {
      lastActionError = errorMessage(failure, fallback: fallback);

      return false;
    } finally {
      isWorking.value = false;
    }
  }
}
