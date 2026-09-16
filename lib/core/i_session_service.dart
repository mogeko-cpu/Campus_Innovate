/// Identity of the user currently operating the app.
///
/// Presentation code depends on this contract instead of a global singleton so
/// the mock session can be swapped for real authentication without touching
/// view models.
abstract class ISessionService {
  String get currentUserId;
  String get currentUserName;
}
