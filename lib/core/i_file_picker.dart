import 'dart:typed_data';

/// A file the person chose from their device, already read into memory.
///
/// Read whole because the upload is one `PUT` of the bytes to a signed URL, and
/// because the web build has no path to read from later: the browser hands the
/// content over once, at the moment of picking.
class PickedFile {
  const PickedFile({required this.name, required this.bytes, this.mimeType});

  final String name;
  final Uint8List bytes;

  /// What the platform said the file is, when it said anything. Otherwise it is
  /// guessed from the extension — see [mimeTypeOf].
  final String? mimeType;

  int get sizeBytes => bytes.lengthInBytes;

  /// [mimeType] when the platform gave one, else a guess from the name, else
  /// null: the bucket stores the file the same, it just cannot tell a browser
  /// how to show it.
  String? get resolvedMimeType => mimeType ?? mimeTypeOf(name);
}

/// Opens the device's own file chooser.
///
/// An interface, and not a direct call to the plugin, because the screens that
/// use it are tested without a device: a native dialog cannot be driven from a
/// widget test, and a double that hands back a file can.
abstract class IFilePicker {
  /// The chosen file, or null when the person closed the chooser without
  /// picking anything — which is not an error and must not show one.
  Future<PickedFile?> pickFile();
}

/// The usual MIME type of a file name, for the formats a student team shares:
/// documents, slides, spreadsheets, images, archives and plain text.
String? mimeTypeOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot == -1 || dot == fileName.length - 1) return null;

  return _mimeByExtension[fileName.substring(dot + 1).toLowerCase()];
}

const _mimeByExtension = <String, String>{
  'pdf': 'application/pdf',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'odt': 'application/vnd.oasis.opendocument.text',
  'csv': 'text/csv',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'json': 'application/json',
  'zip': 'application/zip',
  'rar': 'application/vnd.rar',
  '7z': 'application/x-7z-compressed',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'svg': 'image/svg+xml',
  'mp4': 'video/mp4',
  'mp3': 'audio/mpeg',
};
