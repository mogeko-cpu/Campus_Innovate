/// The build cannot hand a login to a browser and be returned to.
///
/// Used on Android, iOS and desktop. Nothing here throws at import time so the
/// app still compiles and runs on those targets: only starting the flow fails,
/// and it fails with a sentence the user can act on.
abstract final class SocialBrowser {
  static bool get isSupported => false;

  static void goTo(String url) => throw UnsupportedError(
        'Esta plataforma no puede abrir el inicio de sesión del proveedor.',
      );

  /// Nothing to clean: the address that carries the code only exists on the web.
  static void dropQuery() {}
}
