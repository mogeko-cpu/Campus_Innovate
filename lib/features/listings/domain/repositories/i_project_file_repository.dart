import '../../../../core/i_file_picker.dart';
import '../models/project_file.dart';

/// The files and links a project's team shares.
///
/// Every write names who is acting, because the rules depend on it: only the
/// team shares, and only whoever shared a file removes it.
abstract class IProjectFileRepository {
  /// Newest first.
  Future<List<ProjectFile>> getFiles(String listingId);

  Future<ProjectFile> uploadFile({
    required String listingId,
    required String uploaderId,
    required String uploaderName,
    required PickedFile file,
  });

  Future<ProjectFile> addLink({
    required String listingId,
    required String uploaderId,
    required String uploaderName,
    required String name,
    required String url,
  });

  /// What to open for [file]: the link itself, or a download link for an
  /// upload, signed at this moment because it expires within minutes.
  Future<String> urlToOpen(ProjectFile file);

  Future<void> deleteFile({required String fileId, required String actorId});

  /// Removes the files of a project that is being deleted.
  ///
  /// [actorId] is who deletes it: ROBLE only lets each person remove the bytes
  /// they uploaded, so theirs leave the bucket and the rest stay there,
  /// unreachable, once their rows are gone.
  Future<void> purgeListing(String listingId, {required String actorId});
}
