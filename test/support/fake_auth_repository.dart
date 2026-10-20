import 'package:campus_innovate/features/auth/domain/models/authentication_user.dart';
import 'package:campus_innovate/features/auth/domain/repositories/i_auth_repository.dart';

import 'test_session.dart';

/// [IAuthRepository] without ROBLE.
///
/// Knows a set of accounts by e-mail, and when it was given a [TestSession] it
/// signs that session in and out, so a test can log in as one person, log out
/// and log in as another the way a user would.
class FakeAuthRepository implements IAuthRepository {
  FakeAuthRepository({this.session, Map<String, FakeAccount>? accounts})
      : accounts = accounts ?? defaultAccounts();

  /// The two seeded students, both with the password [password].
  static Map<String, FakeAccount> defaultAccounts() => {
        TestUsers.leonel.email: const FakeAccount(TestUsers.leonel, password),
        TestUsers.mariana.email: const FakeAccount(TestUsers.mariana, password),
      };

  /// Meets ROBLE's policy, so the sign-up form accepts it too.
  static const password = 'Campus2026!';

  final TestSession? session;
  final Map<String, FakeAccount> accounts;

  int logins = 0;
  int signUps = 0;
  int logOuts = 0;
  int googleStarts = 0;

  /// Thrown by the next call that reaches it, to test how a screen reports a
  /// failure.
  Object? loginFailure;
  Object? signUpFailure;
  Object? googleFailure;

  AuthenticationUser? _logged;

  @override
  Future<bool> login(AuthenticationUser user) async {
    logins++;

    if (loginFailure != null) throw loginFailure!;

    final account = accounts[user.email.trim()];

    if (account == null || account.password != user.password) return false;

    _logged = AuthenticationUser(
      email: account.user.email,
      name: account.user.name,
      password: '',
    );
    session?.signInAs(account.user);

    return true;
  }

  @override
  Future<bool> signUp(AuthenticationUser user) async {
    signUps++;

    if (signUpFailure != null) throw signUpFailure!;

    final email = user.email.trim();

    if (accounts.containsKey(email)) return false;

    // Not `user_<n>`: the seeded projects already use those ids for their
    // creators, and a new account must not inherit somebody else's project.
    accounts[email] = FakeAccount(
      TestUser(id: 'signup_$signUps', name: user.name, email: email),
      user.password,
    );

    return true;
  }

  @override
  Future<bool> logOut() async {
    logOuts++;
    _logged = null;
    session?.signOut();

    return true;
  }

  @override
  Future<AuthenticationUser?> getLoggedUser() async => _logged;

  @override
  Future<bool> restoreSession() async => _logged != null;

  @override
  Future<bool> validateToken() async => _logged != null;

  @override
  Future<void> startGoogleSignIn() async {
    googleStarts++;

    if (googleFailure != null) throw googleFailure!;
  }

  @override
  Future<bool> completeGoogleSignIn() async => false;

  @override
  Future<bool> validate(String email, String validationCode) async => false;

  @override
  Future<void> forgotPassword(String email) async {}
}

class FakeAccount {
  const FakeAccount(this.user, this.password);

  final TestUser user;
  final String password;
}
