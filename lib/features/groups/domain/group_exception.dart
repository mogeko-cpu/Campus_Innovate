import '../../../core/user_facing_exception.dart';

/// A rule of the groups domain said no: the group is gone, you are not its
/// owner, the owner cannot be removed, the request was already sent.
///
/// Separate from the ROBLE exceptions, which are about the transport. Both are
/// [UserFacingException]s, so `errorMessage()` shows [message] as written.
class GroupException implements UserFacingException {
  const GroupException(this.message);

  @override
  final String message;

  @override
  String toString() => message;
}
