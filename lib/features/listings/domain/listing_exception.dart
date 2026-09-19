import '../../../core/user_facing_exception.dart';

/// A rule of the domain said no: the project is full, the row is gone, the
/// request was already sent.
///
/// Separate from the ROBLE exceptions, which are about the transport. Both are
/// [UserFacingException]s, so `errorMessage()` shows [message] as written.
class ListingException implements UserFacingException {
  const ListingException(this.message);

  @override
  final String message;

  @override
  String toString() => message;
}
