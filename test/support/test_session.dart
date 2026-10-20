import 'package:campus_innovate/core/i_session_service.dart';

/// Somebody who can be signed in during a test.
class TestUser {
  const TestUser({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;
}

/// The two students the seeded doubles already know: Leonel owns `group_1`, and
/// Mariana is the other person in the user directory, so the invite flow has
/// somebody to find.
abstract final class TestUsers {
  static const leonel = TestUser(
    id: 'user_1',
    name: 'Leonel Triana',
    email: 'leonel@uninorte.edu.co',
  );

  static const mariana = TestUser(
    id: 'user_2',
    name: 'Mariana Ospina',
    email: 'mariana@uninorte.edu.co',
  );
}

/// An [ISessionService] whose user can change while the app is running.
///
/// [FakeSessionService] is fixed for the whole test; this one is what the flows
/// with two people need — one publishes or invites, signs out, and the other
/// signs in on the same app to answer.
class TestSession implements ISessionService {
  TestSession([TestUser user = TestUsers.leonel]) : _user = user;

  TestUser? _user;

  bool get isSignedIn => _user != null;

  void signInAs(TestUser user) => _user = user;

  void signOut() => _user = null;

  TestUser get _current {
    final user = _user;

    // The same thing the real service does without a session: the notification
    // center relies on it to stop polling after a logout.
    if (user == null) throw StateError('No hay una sesión activa');

    return user;
  }

  @override
  String get currentUserId => _current.id;

  @override
  String get currentUserName => _current.name;

  @override
  String get currentUserEmail => _current.email;
}
