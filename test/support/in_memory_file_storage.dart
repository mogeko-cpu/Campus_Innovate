import 'dart:typed_data';

import 'package:campus_innovate/features/listings/data/datasources/i_file_storage.dart';

/// One object kept by [InMemoryFileStorage].
typedef StoredObject = ({
  String fileName,
  Uint8List bytes,
  String? mimeType,
  String? folder,
});

/// [IFileStorage] in memory: the project's bucket without a bucket.
class InMemoryFileStorage implements IFileStorage {
  final Map<String, StoredObject> _objects = {};

  var _nextId = 1;

  /// What is in the bucket now, by id.
  Map<String, StoredObject> get objects => Map.unmodifiable(_objects);

  /// The address a download link is made of, so a test can tell which object a
  /// screen asked to open.
  static String linkOf(String storageId) =>
      'https://almacenamiento.test/$storageId';

  @override
  Future<String> upload({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
    String? folder,
  }) async {
    final id = 'object_${_nextId++}';
    _objects[id] = (
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
      folder: folder,
    );

    return id;
  }

  @override
  Future<String> downloadUrl(String storageId) async {
    if (!_objects.containsKey(storageId)) {
      throw StateError('El objeto $storageId no existe');
    }

    return linkOf(storageId);
  }

  @override
  Future<void> delete(String storageId) async => _objects.remove(storageId);
}
