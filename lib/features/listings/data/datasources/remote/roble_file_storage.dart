import 'dart:typed_data';

import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_exception.dart';
import '../i_file_storage.dart';

/// [IFileStorage] over ROBLE's storage, which keeps the bytes in the S3 bucket
/// connected to the project in the console.
///
/// A thin adapter: the three-step upload and the signed links live in
/// [RobleClient], with the rest of the transport.
class RobleFileStorage implements IFileStorage {
  RobleFileStorage(this._client);

  final RobleClient _client;

  @override
  Future<String> upload({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String? folder,
  }) =>
      _client.uploadFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        folder: folder,
      );

  @override
  Future<String> downloadUrl(String storageId) =>
      _client.fileDownloadUrl(storageId);

  @override
  Future<void> delete(String storageId) async {
    try {
      await _client.deleteFile(storageId);
    } on RobleNotFoundException {
      // Already gone, which is what the caller wanted.
    }
  }
}
