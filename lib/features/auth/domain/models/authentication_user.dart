class AuthenticationUser {
  /// The ROBLE `userId`: a string, since it is a UUID and not a row number.
  final String? id;
  final String email;
  final String name;

  /// Only filled while a form is being submitted.
  ///
  /// It is empty on the user returned by `getLoggedUser`, because the app never
  /// keeps a password: ROBLE hands out tokens and those are what get stored. The
  /// version of this app that kept accounts locally wrote passwords in cleartext,
  /// which is what this integration removes.
  final String password;

  const AuthenticationUser({
    this.id,
    required this.email,
    required this.name,
    this.password = '',
  });

  factory AuthenticationUser.fromJson(Map<String, dynamic> json) {
    return AuthenticationUser(
      id: json['id']?.toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
    );
  }

  /// Never includes the password: this is what gets logged and cached.
  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name};
}
