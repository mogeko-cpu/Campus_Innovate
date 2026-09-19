import 'dart:convert';

/// The account behind the current session, as ROBLE describes it.
///
/// `GET /auth/{contract}/me` already returns the display name, so the app needs
/// no profiles table of its own: this is the whole user record.
class RobleUser {
  const RobleUser({required this.id, required this.email, required this.name});

  /// Reads the shape of `GET /me`: `{id, userId, email, name, extra, …}`.
  ///
  /// `userId` is the `sub` of the JWT and the value stored in `creator_id` /
  /// `user_id` columns; `id` is the row id of ROBLE's own user table. They are
  /// usually equal, but only `userId` is guaranteed to be the identity, so it
  /// wins when both are present.
  factory RobleUser.fromJson(Map<String, dynamic> json) {
    final id = (json['userId'] ?? json['id'] ?? json['sub'])?.toString();

    if (id == null || id.isEmpty) {
      throw const FormatException('La respuesta de ROBLE no trae el id del usuario');
    }

    return RobleUser(
      id: id,
      email: (json['email'] ?? '').toString(),
      // Accounts created outside the app may have no name; the email's local
      // part is a better greeting than an empty string.
      name: _nameOf(json, email: (json['email'] ?? '').toString()),
    );
  }

  /// Rebuilds a user cached by [RobleSession]; strict, since we wrote it.
  factory RobleUser.fromCache(String raw) =>
      RobleUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  final String id;
  final String email;
  final String name;

  /// First word of the name, for greetings like "Hola, Leonel".
  String get firstName => name.split(' ').first;

  String toCache() => jsonEncode({'userId': id, 'email': email, 'name': name});

  static String _nameOf(Map<String, dynamic> json, {required String email}) {
    final name = (json['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final local = email.split('@').first;
    return local.isEmpty ? 'Estudiante' : local;
  }
}
