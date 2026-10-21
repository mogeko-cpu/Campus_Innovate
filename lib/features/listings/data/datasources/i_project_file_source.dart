import '../../domain/models/project_file.dart';

/// Storage contract for the rows of a project's shared files.
///
/// The row is what makes a file belong to a project and say who shared it; the
/// bytes of an upload live in the bucket, behind `IFileStorage`.
abstract class IProjectFileSource {
  /// Newest first: what was just shared is what people come looking for.
  Future<List<ProjectFile>> getFiles(String listingId);

  Future<ProjectFile?> getFileById(String id);

  /// Stores [file] — which arrives without an id — and returns it with the id
  /// the database assigned.
  Future<ProjectFile> createFile(ProjectFile file);

  Future<void> deleteFile(String fileId);

  /// Removes every row of a project. ROBLE has no cascades.
  Future<void> deleteFilesOf(String listingId);
}
