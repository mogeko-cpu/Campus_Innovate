import '../../domain/models/app_user.dart';

/// Storage contract for the directory of people the app has seen.
abstract class IUserSource {
  /// Creates the row for [user], or brings it up to date if the name or the
  /// e-mail changed. Idempotent: calling it on every launch costs one read and
  /// no write once the row is current.
  Future<void> upsert(AppUser user);

  Future<List<AppUser>> getUsers();
}
