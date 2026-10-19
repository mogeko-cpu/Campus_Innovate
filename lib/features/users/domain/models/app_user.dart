/// Someone who uses Campus Innovate, as far as the app needs to know them to
/// invite them to a group.
class AppUser {
  /// The account's id — the `userId` of the ROBLE session, the same value that
  /// lands in `owner_id`, `user_id` and `applicant_id` everywhere else. It is
  /// **not** the `_id` of the row in `app_users`.
  final String id;
  final String name;
  final String email;

  const AppUser({required this.id, required this.name, required this.email});
}
