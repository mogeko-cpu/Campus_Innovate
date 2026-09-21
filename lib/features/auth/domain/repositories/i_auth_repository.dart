import '../models/authentication_user.dart';

abstract class IAuthRepository {
  Future<bool> login(AuthenticationUser user);

  Future<bool> restoreSession();

  Future<AuthenticationUser?> getLoggedUser();

  Future<bool> signUp(AuthenticationUser user);

  /// Sends the person to Google. On the web the app is left behind, so the
  /// session shows up on the next launch and not when this future completes.
  Future<void> startGoogleSignIn();

  /// Finishes a Google sign-in when the app was opened by the return from one;
  /// false when it was an ordinary launch.
  Future<bool> completeGoogleSignIn();

  Future<bool> logOut();

  Future<bool> validate(String email, String validationCode);

  Future<bool> validateToken();

  Future<void> forgotPassword(String email);
}
