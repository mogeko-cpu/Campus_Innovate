import '../../../../core/i_file_picker.dart';
import '../../domain/listing_exception.dart';
import '../../domain/models/project_file.dart';
import '../../domain/repositories/i_listing_repository.dart';
import '../../domain/repositories/i_project_file_repository.dart';
import '../datasources/i_file_storage.dart';
import '../datasources/i_project_file_source.dart';

/// Owns the rules of a project's shared files, which neither source knows:
///
/// - the **team** shares — leader, members and mentor alike, since a mentor's
///   reading list is exactly the kind of thing a team wants at hand;
/// - only whoever shared a file removes it (ROBLE enforces the same for the
///   bytes);
/// - an upload is capped at [maxFileBytes], and a link has to be a web address.
///
/// The team is checked against the project as stored on every write, like the
/// board's leader checks: a screen can be open on a team the person just left.
class ProjectFileRepository implements IProjectFileRepository {
  ProjectFileRepository(this._source, this._storage, this._listings);

  final IProjectFileSource _source;
  final IFileStorage _storage;
  final IListingRepository _listings;

  static const maxNameLength = 120;

  /// The largest file the app uploads. The bucket would take more, but the file
  /// is read whole into memory before it travels, and a team's shared folder is
  /// for documents and images — a video belongs in a link.
  static const maxFileBytes = 10 * 1024 * 1024;

  @override
  Future<List<ProjectFile>> getFiles(String listingId) =>
      _source.getFiles(listingId);

  /// The bytes go first and the row second, because the row is what makes the
  /// file appear: if the bytes fail nothing shows up, and if the row fails the
  /// bytes are removed again so nothing is left in the bucket that no screen
  /// can reach. The person sees the original error and can try again.
  @override
  Future<ProjectFile> uploadFile({
    required String listingId,
    required String uploaderId,
    required String uploaderName,
    required PickedFile file,
  }) async {
    final name = file.name.trim();

    if (name.isEmpty) {
      throw const ListingException('El archivo no tiene nombre.');
    }

    if (file.sizeBytes == 0) {
      throw const ListingException('El archivo está vacío.');
    }

    if (file.sizeBytes > maxFileBytes) {
      throw ListingException(
        'El archivo pesa ${readableSize(file.sizeBytes)} y el máximo es '
        '${readableSize(maxFileBytes)}. Para algo más grande, comparte un '
        'enlace.',
      );
    }

    await _requireTeam(listingId, uploaderId, 'subir archivos');

    final mimeType = file.resolvedMimeType;

    final storageId = await _storage.upload(
      fileName: name,
      bytes: file.bytes,
      mimeType: mimeType,
      folder: 'proyectos/$listingId',
    );

    try {
      return await _source.createFile(
        ProjectFile.upload(
          listingId: listingId,
          name: name,
          storageId: storageId,
          mimeType: mimeType ?? '',
          sizeBytes: file.sizeBytes,
          uploaderId: uploaderId,
          uploaderName: uploaderName,
        ),
      );
    } catch (_) {
      await _deleteBytesQuietly(storageId);
      rethrow;
    }
  }

  @override
  Future<ProjectFile> addLink({
    required String listingId,
    required String uploaderId,
    required String uploaderName,
    required String name,
    required String url,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      throw const ListingException('Ponle un nombre al enlace.');
    }

    if (cleanName.length > maxNameLength) {
      throw const ListingException(
        'El nombre es muy largo. Máximo $maxNameLength caracteres.',
      );
    }

    final address = normalizeUrl(url);

    if (address == null) {
      throw const ListingException(
        'Escribe un enlace válido, por ejemplo https://drive.google.com/…',
      );
    }

    await _requireTeam(listingId, uploaderId, 'compartir enlaces');

    return _source.createFile(
      ProjectFile.link(
        listingId: listingId,
        name: cleanName,
        url: address,
        uploaderId: uploaderId,
        uploaderName: uploaderName,
      ),
    );
  }

  @override
  Future<String> urlToOpen(ProjectFile file) async {
    if (file.isLink) return file.url;

    if (file.storageId.isEmpty) {
      throw const ListingException('Este archivo no tiene contenido.');
    }

    return _storage.downloadUrl(file.storageId);
  }

  /// The bytes first and the row last: if the run stops halfway the file is
  /// still listed, and deleting it again finishes the job — the storage treats
  /// bytes that are already gone as deleted. The other order could leave bytes
  /// in the bucket that no screen lists any more.
  @override
  Future<void> deleteFile({
    required String fileId,
    required String actorId,
  }) async {
    final file = await _source.getFileById(fileId);

    if (file == null) {
      throw const ListingException('Este archivo ya no existe.');
    }

    if (file.uploaderId != actorId) {
      throw const ListingException(
        'Solo quien compartió el archivo puede eliminarlo.',
      );
    }

    if (!file.isLink && file.storageId.isNotEmpty) {
      await _storage.delete(file.storageId);
    }

    await _source.deleteFile(fileId);
  }

  @override
  Future<void> purgeListing(
    String listingId, {
    required String actorId,
  }) async {
    for (final file in await _source.getFiles(listingId)) {
      if (file.isLink || file.storageId.isEmpty) continue;
      if (file.uploaderId != actorId) continue;

      await _deleteBytesQuietly(file.storageId);
    }

    await _source.deleteFilesOf(listingId);
  }

  /// The address as it will be stored, or null when it cannot be one.
  ///
  /// People paste `drive.google.com/…` without the scheme, so a missing one is
  /// read as `https://` rather than refused.
  static String? normalizeUrl(String input) {
    var text = input.trim();
    if (text.isEmpty || text.contains(' ')) return null;

    if (!text.contains('://')) text = 'https://$text';

    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty || !uri.host.contains('.')) return null;

    // `usuario:clave@sitio` is how a credential ends up in a shared list, and
    // how `mailto:alguien@sitio` would sneak past the missing-scheme rule.
    if (uri.userInfo.isNotEmpty) return null;

    return uri.toString();
  }

  /// Anybody with a role on the project: leader, member or mentor.
  Future<void> _requireTeam(
    String listingId,
    String userId,
    String action,
  ) async {
    final listing = await _listings.getListingById(listingId);

    if (listing == null) {
      throw const ListingException('Este proyecto ya no existe.');
    }

    if (listing.roleOf(userId) == null) {
      throw ListingException('Solo el equipo del proyecto puede $action.');
    }
  }

  /// Best effort: if this fails there is nothing more to try, and the caller's
  /// error is the one worth reporting.
  Future<void> _deleteBytesQuietly(String storageId) async {
    try {
      await _storage.delete(storageId);
    } catch (_) {
      // Ignored on purpose.
    }
  }
}
