import 'package:f_clean_template/features/auth/domain/models/authentication_user.dart';
import 'package:f_clean_template/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:get/get.dart';

import 'package:loggy/loggy.dart';

import '../../../../core/error_message.dart';

class AuthenticationController extends GetxController with UiLoggy {
  final IAuthRepository repoAuthentication;
  final _logged = false.obs;
  final _loggedUser = Rxn<AuthenticationUser>();
  final _isLoading = false.obs;

  /// Empty while the latest authentication request completed successfully.
  final RxString error = ''.obs;

  AuthenticationController(this.repoAuthentication);

  bool get isLoading => _isLoading.value;
  bool get isLogged => _logged.value;
  String get loggedEmail => _loggedUser.value?.email ?? '';

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
      loggy.warning(
        'AuthenticationController: Could not restore session: $exception',
      );
      _logged.value = false;
      _loggedUser.value = null;
    }
  }

  Future<bool> login(String email, String password) async {
    loggy.debug('AuthenticationController: Login $email');
    error.value = '';
    if (!_validate(email, password)) {
      loggy.warning('AuthenticationController: Invalid email or password');
      error.value =
          'Enter a valid email and a password with at least 7 characters.';
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
      if (!loggedIn) error.value = 'Unable to sign in. Check your credentials.';
      return loggedIn;
    } catch (exception) {
      loggy.error('AuthenticationController: Login error $exception');
      error.value = errorMessage(exception);
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> signUp(String email, String password) async {
    loggy.debug('AuthenticationController: Sign Up $email');
    error.value = '';
    if (!_validate(email, password)) {
      loggy.warning('AuthenticationController: Invalid email or password');
      error.value =
          'Enter a valid email and a password with at least 7 characters.';
      return false;
    }
    _isLoading.value = true;
    try {
      final created = await repoAuthentication.signUp(
        AuthenticationUser(email: email, name: email, password: password),
      );
      if (!created) {
        error.value = 'Unable to create the account. Please try again.';
      }
      return created;
    } catch (exception) {
      loggy.error('AuthenticationController: Sign up error $exception');
      error.value = errorMessage(exception);
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> logOut() async {
    loggy.debug('AuthenticationController: Log Out');
    error.value = '';
    try {
      final loggedOut = await repoAuthentication.logOut();
      _logged.value = false;
      _loggedUser.value = null;
      if (!loggedOut) error.value = 'Unable to sign out. Please try again.';
      return loggedOut;
    } catch (exception) {
      loggy.error('AuthenticationController: Logout error $exception');
      error.value = errorMessage(exception);
      // A failed remote request should not keep a user in a local session that
      // is no longer trustworthy.
      _logged.value = false;
      _loggedUser.value = null;
      return false;
    }
  }

  bool _validate(String email, String password) =>
      email.isNotEmpty && password.length > 6;
}
