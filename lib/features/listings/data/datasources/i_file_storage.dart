import 'dart:typed_data';

/// Where the bytes of an uploaded file live: the project's bucket, through
/// ROBLE's storage.
///
/// Apart from `IWorkspaceSource` because it is a different service with
/// different rules — it signs URLs instead of storing rows, and only whoever
/// uploaded a file may delete it.
abstract class IFileStorage {
  /// Uploads [bytes] and returns the id the storage filed them under.
  Future<String> upload({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String? folder,
  });

  /// A link to download [storageId] that expires within minutes.
  Future<String> downloadUrl(String storageId);

  /// Idempotent: an object that is already gone counts as deleted, so a delete
  /// that failed halfway can simply be run again.
  Future<void> delete(String storageId);
}
