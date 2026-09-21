import '../../user_facing_exception.dart';

/// The flow cannot leave this build and come back to it.
///
/// Deliberately **not** a `RobleException`: nothing was asked of ROBLE, and
/// dressing a platform limitation as a server failure sends whoever debugs it to
/// the wrong place. It implements [UserFacingException] so `errorMessage()` puts
/// the sentence on screen as it is.
class SocialLoginUnsupported implements UserFacingException {
  const SocialLoginUnsupported([
    this.message =
        'Por ahora el inicio de sesión con Google funciona en la versión web '
        'de Campus Innovate.',
  ]);

  @override
  final String message;

  @override
  String toString() => message;
}
