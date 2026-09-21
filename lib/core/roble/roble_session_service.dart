import '../i_session_service.dart';
import 'roble_session.dart';
import 'roble_user.dart';

/// [ISessionService] over the ROBLE session, so view models keep asking "who is
/// using the app" without knowing where the answer comes from.
///
/// The id it returns is the `userId` of the JWT, which is what lands in
/// `creator_id`, `user_id` and `applicant_id`. Those columns tie rows to accounts
/// across devices, so the mock's fixed `user_1` could not survive the move to a
/// real database.
class RobleSessionService implements ISessionService {
  const RobleSessionService(this._session);

  final RobleSession _session;

  @override
  String get currentUserId => _user.id;

  @override
  String get currentUserName => _user.name;

  @override
  String get currentUserEmail => _user.email;

  /// Reading the identity without a session is a wiring bug, not a user
  /// situation: `main()` routes to login when there is none. Failing loudly beats
  /// returning an empty id that would be written into rows nobody can trace back.
  RobleUser get _user {
    final user = _session.user;

    if (user == null) {
      throw StateError(
        'No hay sesión activa: se intentó leer la identidad del usuario antes '
        'de iniciar sesión en ROBLE.',
      );
    }

    return user;
  }
}
