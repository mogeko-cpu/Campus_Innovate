import 'package:get/get.dart';
import 'package:loggy/loggy.dart';

import '../../../../core/error_message.dart';
import '../../../../core/roble/roble_password_policy.dart';
import '../../domain/models/authentication_user.dart';
import '../../domain/repositories/i_auth_repository.dart';

/// Session state for the UI: who is signed in, whether a request is in flight,
/// and what to tell the user when one fails.
class AuthenticationController extends GetxController with UiLoggy {
  final IAuthRepository repoAuthentication;
  final _logged = false.obs;
  final _loggedUser = Rxn<AuthenticationUser>();
  final _isLoading = false.obs;

  /// Empty while the latest authentication request completed successfully.
  final RxString error = ''.obs;

  /// [initialError] carries a failure that happened before any screen existed:
  /// the return from Google is exchanged while the app boots, so there is nobody
  /// to tell when it goes wrong. The login screen shows it on its first frame.
  AuthenticationController(this.repoAuthentication, {String initialError = ''}) {
    error.value = initialError;
  }

  bool get isLoading => _isLoading.value;
  bool get isLogged => _logged.value;
  String get loggedEmail => _loggedUser.value?.email ?? '';
  String get loggedName => _loggedUser.value?.name ?? '';

  @override
  void onInit() {
    super.onInit();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      _logged.value = await repoAuthentication.restoreSession();
      _loggedUser.value = _logged.value
          ? await repoAuthentication.getLoggedUser()
          : null;
    } catch (exception) {
      loggy.warning('AuthenticationController: no se pudo restaurar la sesión: $exception');
      _logged.value = false;
      _loggedUser.value = null;
    }
  }

  Future<bool> login(String email, String password) async {
    loggy.debug('AuthenticationController: login $email');
    error.value = '';

    if (!_isEmail(email) || password.isEmpty) {
      error.value = 'Escribe tu correo institucional y tu contraseña.';
      return false;
    }

    _isLoading.value = true;
    try {
      final loggedIn = await repoAuthentication.login(
        AuthenticationUser(email: email, name: email, password: password),
      );
      _logged.value = loggedIn;
      _loggedUser.value = loggedIn
          ? await repoAuthentication.getLoggedUser()
          : null;
      if (!loggedIn) error.value = 'No se pudo iniciar sesión. Revisa tus datos.';
      return loggedIn;
    } catch (exception) {
      loggy.error('AuthenticationController: error de login $exception');
      // ROBLE's answer is the useful one: wrong credentials, rate limit reached,
      // no connection. Each needs a different reaction from the user.
      error.value = errorMessage(
        exception,
        fallback: 'No se pudo iniciar sesión. Intenta de nuevo.',
      );
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Registers the account. [name] is what the rest of the campus sees next to a
  /// project, so it is asked for here instead of being derived from the e-mail.
  Future<bool> signUp(String name, String email, String password) async {
    loggy.debug('AuthenticationController: signup $email');
    error.value = '';

    if (name.trim().length < 3) {
      error.value = 'Escribe tu nombre completo.';
      return false;
    }

    if (!_isEmail(email)) {
      error.value = 'Escribe un correo válido.';
      return false;
    }

    // ROBLE only allows 5 registrations per hour per IP and counts the failures
    // too, so an invalid password never becomes a request.
    final rejection = RoblePasswordPolicy.validate(password);
    if (rejection != null) {
      error.value = rejection;
      return false;
    }

    _isLoading.value = true;
    try {
      final created = await repoAuthentication.signUp(
        AuthenticationUser(email: email, name: name, password: password),
      );
      if (!created) {
        error.value = 'No se pudo crear la cuenta. Intenta de nuevo.';
      }
      return created;
    } catch (exception) {
      loggy.error('AuthenticationController: error de registro $exception');
      error.value = errorMessage(
        exception,
        fallback: 'No se pudo crear la cuenta. Intenta de nuevo.',
      );
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  /// Hands the sign-in to Google, from the login screen or from the signup one.
  ///
  /// A `true` does not mean there is a session: on the web the page is already on
  /// its way to Google and the session appears when the browser comes back. It
  /// only means there was nothing to tell the user about.
  Future<bool> signInWithGoogle() async {
    loggy.debug('AuthenticationController: inicio con Google');
    error.value = '';
    _isLoading.value = true;

    try {
      await repoAuthentication.startGoogleSignIn();
      return true;
    } catch (exception) {
      loggy.error('AuthenticationController: error con Google $exception');
      error.value = errorMessage(
        exception,
        fallback: 'No se pudo iniciar sesión con Google. Intenta de nuevo.',
      );
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> logOut() async {
    loggy.debug('AuthenticationController: logout');
    error.value = '';
    try {
      final loggedOut = await repoAuthentication.logOut();
      _logged.value = false;
      _loggedUser.value = null;
      if (!loggedOut) error.value = 'No se pudo cerrar sesión. Intenta de nuevo.';
      return loggedOut;
    } catch (exception) {
      loggy.error('AuthenticationController: error de logout $exception');
      error.value = errorMessage(
        exception,
        fallback: 'No se pudo cerrar sesión. Intenta de nuevo.',
      );
      // A failed remote request should not keep a user in a local session that
      // is no longer trustworthy.
      _logged.value = false;
      _loggedUser.value = null;
      return false;
    }
  }

  /// Enough to catch a typo, not a whole RFC: ROBLE has the last word when it
  /// rejects the address.
  bool _isEmail(String email) {
    final value = email.trim();

    return value.length > 4 &&
        value.contains('@') &&
        value.contains('.') &&
        !value.contains(' ');
  }
}
