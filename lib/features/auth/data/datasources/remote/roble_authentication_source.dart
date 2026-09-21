import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_exception.dart';
import '../../../../../core/roble/roble_password_policy.dart';
import '../../../../../core/roble/roble_session.dart';
import '../../../../../core/roble/social/social_browser.dart';
import '../../../../../core/roble/social/social_login_unsupported.dart';
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

  /// Set once the address has been read for a provider's code.
  ///
  /// The code is single-use, so looking twice can only find one that ROBLE has
  /// already invalidated and turn a working session into an error message.
  bool _socialCodeRead = false;

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

  /// Sends the person to Google.
  ///
  /// There is no password to check and no account to create here: ROBLE receives
  /// Google's answer, and because Google states whether the address is verified,
  /// it links the login to an account with that e-mail if one already exists, or
  /// creates it otherwise. That is why the login and the signup screens offer the
  /// very same button.
  @override
  Future<void> startGoogleSignIn() async {
    // Asked before the request: the flow would otherwise cost a round trip only
    // to fail at the last step, with the account already waiting on Google's side.
    if (!SocialBrowser.isSupported) {
      throw const SocialLoginUnsupported();
    }

    final start = await _client.startSocialLogin();

    SocialBrowser.goTo(start.url);
  }

  /// Reads the address this launch started with and finishes the flow if it is a
  /// return from Google.
  ///
  /// ROBLE sends the browser back to the registered destination with `?code=…`,
  /// or with `?error=…&error_description=…` when the person cancelled or Google
  /// refused. Both are dropped from the address before anything else happens: the
  /// code is single-use, so leaving it there would turn a reload into an error
  /// about a code that was in fact spent successfully.
  @override
  Future<bool> completeGoogleSignIn() async {
    if (_socialCodeRead) return false;
    _socialCodeRead = true;

    final query = Uri.base.queryParameters;
    final error = query['error'];
    final code = query['code'];

    if ((error == null || error.isEmpty) && (code == null || code.isEmpty)) {
      return false;
    }

    SocialBrowser.dropQuery();

    if (error != null && error.isNotEmpty) {
      final detail = query['error_description']?.trim();

      throw RobleUnauthorizedException(
        detail == null || detail.isEmpty
            ? 'Google no autorizó el inicio de sesión ($error).'
            : 'Google no autorizó el inicio de sesión: $detail',
      );
    }

    await _client.exchangeSocialCode(code!);

    // ROBLE just issued the token, so there is nothing to verify.
    _verified = true;

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
