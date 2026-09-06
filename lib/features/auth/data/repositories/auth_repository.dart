import '../../domain/models/authentication_user.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/remote/i_authentication_source.dart';

class AuthRepository implements IAuthRepository {
  late IAuthenticationSource authenticationSource;

  AuthRepository(this.authenticationSource);

  @override
  Future<bool> login(AuthenticationUser user) async =>
      await authenticationSource.login(user);

  @override
  Future<bool> restoreSession() async =>
      await authenticationSource.restoreSession();

  @override
  Future<AuthenticationUser?> getLoggedUser() async =>
      await authenticationSource.getLoggedUser();

  @override
  Future<bool> signUp(AuthenticationUser user) async =>
      await authenticationSource.signUp(user);

  @override
  Future<bool> logOut() async => await authenticationSource.logOut();

  @override
  Future<bool> validate(String email, String validationCode) async =>
      await authenticationSource.validate(email, validationCode);

  @override
  Future<bool> validateToken() async =>
      await authenticationSource.verifyToken();

  @override
  Future<void> forgotPassword(String email) async =>
      await authenticationSource.forgotPassword(email);
}
