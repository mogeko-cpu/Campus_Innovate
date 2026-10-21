import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_config.dart';
import '../../../domain/listing_exception.dart';
import '../../../domain/models/project_file.dart';
import '../i_project_file_source.dart';

/// The shared files of a project, as rows of `project_files` in ROBLE.
///
/// One read filtered by `listing_id` per screen: the storage service would list
/// the files of every project of the contract together, and knows nothing of
/// who shared what.
class RobleProjectFileSource implements IProjectFileSource {
  RobleProjectFileSource(this._client);

  final RobleClient _client;

  @override
  Future<List<ProjectFile>> getFiles(String listingId) async {
    if (!RobleClient.isRowId(listingId)) return const [];

    final rows = await _client.read(
      RobleConfig.projectFilesTable,
      filters: {'listing_id': listingId},
    );

    rows.sort(
      (a, b) => _dateOf(b['created_at']).compareTo(_dateOf(a['created_at'])),
    );

    return rows.map(_fileFrom).whereType<ProjectFile>().toList();
  }

  @override
  Future<ProjectFile?> getFileById(String id) async {
    if (!RobleClient.isRowId(id)) return null;

    final rows = await _client.read(
      RobleConfig.projectFilesTable,
      filters: {'_id': id},
    );

    return rows.isEmpty ? null : _fileFrom(rows.first);
  }

  @override
  Future<ProjectFile> createFile(ProjectFile file) async {
    final row = await _client.insertOne(RobleConfig.projectFilesTable, {
      'listing_id': file.listingId,
      'name': file.name,
      'kind': file.kind.name,
      'storage_id': file.storageId,
      'url': file.url,
      'mime_type': file.mimeType,
      'size_bytes': file.sizeBytes,
      'uploader_id': file.uploaderId,
      'uploader_name': file.uploaderName,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    final id = row['_id']?.toString() ?? '';

    if (id.isEmpty) {
      throw const ListingException(
        'ROBLE guardó el archivo pero no devolvió su identificador. '
        'Actualiza la lista antes de volver a subirlo.',
      );
    }

    return file.copyWith(id: id);
  }

  @override
  Future<void> deleteFile(String fileId) async {
    await _client.delete(
      tableName: RobleConfig.projectFilesTable,
      idValue: fileId,
    );
  }

  @override
  Future<void> deleteFilesOf(String listingId) async {
    if (!RobleClient.isRowId(listingId)) return;

    // ROBLE deletes by `_id` only: a read, then one delete per row.
    final rows = await _client.read(
      RobleConfig.projectFilesTable,
      filters: {'listing_id': listingId},
    );

    for (final row in rows) {
      final id = row['_id']?.toString();
      if (id == null || id.isEmpty) continue;

      await deleteFile(id);
    }
  }

  /// Rows missing their date sort last instead of crashing the list.
  DateTime _dateOf(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  int _intOf(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  ProjectFile? _fileFrom(Map<String, dynamic> row) {
    final id = row['_id']?.toString();
    final listingId = row['listing_id']?.toString();
    if (id == null || id.isEmpty || listingId == null) return null;

    return ProjectFile(
      id: id,
      listingId: listingId,
      name: row['name']?.toString() ?? 'Archivo',
      kind: ProjectFileKind.fromName(row['kind']?.toString()),
      storageId: row['storage_id']?.toString() ?? '',
      url: row['url']?.toString() ?? '',
      mimeType: row['mime_type']?.toString() ?? '',
      sizeBytes: _intOf(row['size_bytes']),
      uploaderId: row['uploader_id']?.toString() ?? '',
      uploaderName: row['uploader_name']?.toString() ?? 'Integrante',
      createdAt: _dateOf(row['created_at']),
    );
  }
}
