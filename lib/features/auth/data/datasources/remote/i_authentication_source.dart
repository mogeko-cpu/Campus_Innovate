import '../../../domain/models/authentication_user.dart';

abstract class IAuthenticationSource {
  Future<bool> login(AuthenticationUser user);

  Future<bool> restoreSession();

  Future<AuthenticationUser?> getLoggedUser();

  Future<bool> signUp(AuthenticationUser user);

  /// Hands the sign-in over to Google.
  ///
  /// On the web the page navigates away, so this never returns normally: the
  /// session arrives on the next launch, through [completeGoogleSignIn]. It
  /// throws when the build has no browser to hand the flow to.
  Future<void> startGoogleSignIn();

  /// Finishes a Google sign-in when this launch is the return from one.
  ///
  /// Returns false when the address carries no code, which is every ordinary
  /// launch; throws when the return says the provider refused, or when the code
  /// can no longer be exchanged.
  Future<bool> completeGoogleSignIn();

  Future<bool> logOut();

  Future<bool> validate(String email, String validationCode);

  Future<bool> refreshToken();

  Future<bool> forgotPassword(String email);

  Future<bool> resetPassword(
    String email,
    String newPassword,
    String validationCode,
  );

  Future<bool> verifyToken();
}
