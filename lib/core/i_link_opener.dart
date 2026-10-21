/// Opens an address outside the app: a shared Drive folder, a repository, the
/// signed download link of an uploaded file.
///
/// Behind an interface for the same reason as `IFilePicker`: what a widget test
/// can check is that the screen asked to open the right address, not that a
/// browser appeared.
abstract class ILinkOpener {
  /// False when the platform had nothing able to open [url].
  Future<bool> open(String url);
}
