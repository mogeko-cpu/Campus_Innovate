/// What kind of thing a team shared: bytes in the project's bucket, or an
/// address somewhere else.
enum ProjectFileKind {
  /// Uploaded to the bucket. Opening it asks ROBLE for a link that lasts a few
  /// minutes.
  file,

  /// A Drive folder, a repository, a Figma board: the team keeps the content
  /// there and the project only keeps the address.
  link;

  static ProjectFileKind fromName(String? name) =>
      name == ProjectFileKind.link.name ? ProjectFileKind.link : ProjectFileKind.file;
}

/// One entry of the project's shared files, as a row of `project_files`.
///
/// The row is what makes a file belong to a project and say who shared it:
/// ROBLE's storage only knows names and sizes, and would list the files of
/// every project of the contract together.
class ProjectFile {
  /// `_id` of the row; empty on a draft.
  final String id;
  final String listingId;
  final String name;
  final ProjectFileKind kind;

  /// The id ROBLE's storage gave the bytes, for [ProjectFileKind.file]; empty
  /// for a link.
  final String storageId;

  /// The address, for [ProjectFileKind.link]; empty for an upload, whose link
  /// expires and is therefore asked for each time.
  final String url;
  final String mimeType;
  final int sizeBytes;
  final String uploaderId;
  final String uploaderName;
  final DateTime createdAt;

  const ProjectFile({
    required this.id,
    required this.listingId,
    required this.name,
    required this.kind,
    required this.storageId,
    required this.url,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploaderId,
    required this.uploaderName,
    required this.createdAt,
  });

  factory ProjectFile.upload({
    required String listingId,
    required String name,
    required String storageId,
    required String mimeType,
    required int sizeBytes,
    required String uploaderId,
    required String uploaderName,
  }) {
    return ProjectFile(
      id: '',
      listingId: listingId,
      name: name,
      kind: ProjectFileKind.file,
      storageId: storageId,
      url: '',
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      uploaderId: uploaderId,
      uploaderName: uploaderName,
      createdAt: DateTime.now(),
    );
  }

  factory ProjectFile.link({
    required String listingId,
    required String name,
    required String url,
    required String uploaderId,
    required String uploaderName,
  }) {
    return ProjectFile(
      id: '',
      listingId: listingId,
      name: name,
      kind: ProjectFileKind.link,
      storageId: '',
      url: url,
      mimeType: '',
      sizeBytes: 0,
      uploaderId: uploaderId,
      uploaderName: uploaderName,
      createdAt: DateTime.now(),
    );
  }

  bool get isPersisted => id.isNotEmpty;

  bool get isLink => kind == ProjectFileKind.link;

  /// The part after the last dot, lower case, for the icon. Empty for a link or
  /// a name without one.
  String get extension {
    if (isLink) return '';

    final dot = name.lastIndexOf('.');
    return dot == -1 || dot == name.length - 1
        ? ''
        : name.substring(dot + 1).toLowerCase();
  }

  ProjectFile copyWith({String? id}) {
    return ProjectFile(
      id: id ?? this.id,
      listingId: listingId,
      name: name,
      kind: kind,
      storageId: storageId,
      url: url,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      uploaderId: uploaderId,
      uploaderName: uploaderName,
      createdAt: createdAt,
    );
  }
}

/// "850 KB", "2,4 MB", "12 MB": the size the way a person reads it, with a
/// decimal only while it still says something.
String readableSize(int bytes) {
  if (bytes < 1024) return '$bytes B';

  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.round()} KB';

  final megabytes = kilobytes / 1024;
  if (megabytes >= 10) return '${megabytes.round()} MB';

  return '${megabytes.toStringAsFixed(1).replaceAll('.', ',')} MB';
}
