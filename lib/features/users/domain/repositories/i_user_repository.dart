import '../models/app_user.dart';

abstract class IUserRepository {
  /// Makes sure the person using the app can be found by the others.
  Future<void> registerCurrentUser(AppUser user);

  /// Everybody who has registered, sorted by name.
  Future<List<AppUser>> getUsers();
}
