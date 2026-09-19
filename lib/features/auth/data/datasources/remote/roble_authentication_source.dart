import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_exception.dart';
import '../../../../../core/roble/roble_password_policy.dart';
import '../../../../../core/roble/roble_session.dart';
import '../../../domain/models/authentication_user.dart';
import 'i_authentication_source.dart';

/// Authentication against ROBLE.
///
/// Replaces the template's local account store, which kept e-mails and passwords
/// in the device's preferences: that made every device its own island — an
/// account created on one phone did not exist on another — and it is also why the
/// projects could not be shared, since there was no identity a row could point at.
class RobleAuthenticationSource implements IAuthenticationSource {
  RobleAuthenticationSource(this._client, this._session);

  final RobleClient _client;
  final RobleSession _session;

  /// Set once ROBLE has confirmed the token in this run of the app.
  ///
  /// Startup asks twice — `main()` to pick the first route, then the controller
  /// when it is created — and the second answer cannot have changed. Remembering
  /// it saves a request that would otherwise be spent on every launch.
  bool _verified = false;

  @override
  Future<bool> login(AuthenticationUser user) async {
    try {
      await _client.login(email: user.email.trim(), password: user.password);
    } on RobleUnauthorizedException {
      // A 401 here is a wrong password, not an expired session: the generic
      // message ("vuelve a iniciar sesión") would be nonsense on the login form.
      throw const RobleUnauthorizedException(
        'Correo o contraseña incorrectos.',
      );
    }

    // ROBLE just issued the token, so there is nothing to verify.
    _verified = true;

    return true;
  }

  /// Loads the stored session and confirms it with ROBLE.
  ///
  /// A network failure is deliberately *not* a failed restore: the session stays
  /// and the app opens. Otherwise opening the app on the bus would sign the user
  /// out and force a new login — and `login` is the endpoint with the tightest
  /// rate limit.
  @override
  Future<bool> restoreSession() async {
    await _session.restore();

    if (!_session.isActive) return false;
    if (_verified) return true;

    try {
      _verified = await _client.verifyToken();

      return _verified;
    } on RobleNetworkException {
      return true;
    } on RobleTimeoutException {
      return true;
    }
  }

  @override
  Future<AuthenticationUser?> getLoggedUser() async {
    final user = _session.user;

    if (user == null) return null;

    return AuthenticationUser(id: user.id, email: user.email, name: user.name);
  }

  /// Creates the account with `signup-direct`, which leaves it usable right away
  /// instead of waiting for an e-mailed code — the ROBLE console keeps the door
  /// open for confirming accounts created the other way.
  @override
  Future<bool> signUp(AuthenticationUser user) async {
    final rejection = RoblePasswordPolicy.validate(user.password);

    // Checked here and not only in the form, because every rejected attempt
    // counts against the 5-per-hour signup budget of the whole network.
    if (rejection != null) {
      throw RobleBadRequestException(rejection);
    }

    await _client.signUp(
      email: user.email.trim(),
      password: user.password,
      name: user.name.trim(),
    );

    return true;
  }

  @override
  Future<bool> logOut() async {
    _verified = false;
    await _client.logout();

    return true;
  }

  @override
  Future<bool> validate(String email, String validationCode) async {
    await _client.verifyEmail(email: email.trim(), code: validationCode.trim());

    return true;
  }

  @override
  Future<bool> refreshToken() => _client.refreshSession();

  @override
  Future<bool> forgotPassword(String email) async {
    await _client.forgotPassword(email.trim());

    return true;
  }

  /// [validationCode] is the token ROBLE mails; [email] is not sent, because the
  /// token already identifies the account. It stays in the signature to keep the
  /// contract the rest of the app was written against.
  @override
  Future<bool> resetPassword(
    String email,
    String newPassword,
    String validationCode,
  ) async {
    final rejection = RoblePasswordPolicy.validate(newPassword);

    if (rejection != null) {
      throw RobleBadRequestException(rejection);
    }

    await _client.resetPassword(
      token: validationCode.trim(),
      newPassword: newPassword,
    );

    return true;
  }

  @override
  Future<bool> verifyToken() => _client.verifyToken();
}
