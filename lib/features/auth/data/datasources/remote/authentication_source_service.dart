import 'dart:convert';

import 'package:loggy/loggy.dart';
import 'package:http/http.dart' as http;
import '../../../../../core/i_local_preferences.dart';
import '../../../domain/models/authentication_user.dart';
import 'i_authentication_source.dart';

class AuthenticationSourceService
    with UiLoggy
    implements IAuthenticationSource {
  static const _usersKey = 'auth_users';
  static const _sessionKey = 'auth_is_logged_in';
  static const _sessionEmailKey = 'auth_session_email';

  final http.Client httpClient;
  final ILocalPreferences preferences;

  AuthenticationSourceService(this.preferences, {http.Client? client})
    : httpClient = client ?? http.Client();

  @override
  Future<bool> login(AuthenticationUser user) async {
    loggy.debug("Attempting login for email: ${user.email}");
    final email = _normalizedEmail(user.email);
    final users = await _getUsers();
    final account = users
        .where((account) => account.email == email)
        .firstOrNull;

    if (account == null || account.password != user.password) {
      throw StateError('Invalid email or password.');
    }

    await _saveSession(email);
    return true;
  }

  @override
  Future<bool> signUp(AuthenticationUser user) async {
    loggy.debug("Attempting sign up for email: ${user.email}");
    final email = _normalizedEmail(user.email);
    final users = await _getUsers();

    if (users.any((account) => account.email == email)) {
      throw StateError('An account with this email already exists.');
    }

    users.add(
      AuthenticationUser(
        id: DateTime.now().microsecondsSinceEpoch,
        email: email,
        name: user.name.trim().isEmpty ? email : user.name.trim(),
        password: user.password,
      ),
    );
    await _saveUsers(users);
    return true;
  }

  @override
  Future<bool> logOut() async {
    loggy.debug('Attempting logout');
    await preferences.remove(_sessionKey);
    await preferences.remove(_sessionEmailKey);
    return true;
  }

  @override
  Future<bool> restoreSession() async {
    final isSignedIn = await preferences.getBool(_sessionKey) ?? false;
    final email = await preferences.getString(_sessionEmailKey);
    if (!isSignedIn || email == null) return false;

    final users = await _getUsers();
    if (users.any((account) => account.email == email)) return true;

    await logOut();
    return false;
  }

  @override
  Future<AuthenticationUser?> getLoggedUser() async {
    final isSignedIn = await preferences.getBool(_sessionKey) ?? false;
    final email = await preferences.getString(_sessionEmailKey);
    if (!isSignedIn || email == null) return null;

    return (await _getUsers())
        .where((account) => account.email == email)
        .firstOrNull;
  }

  @override
  Future<bool> validate(String email, String validationCode) async {
    loggy.debug("Attempting email validation for email: $email");
    return Future.value(true);
  }

  @override
  Future<bool> refreshToken() async {
    loggy.debug('Attempting token refresh');
    return Future.value(true);
  }

  @override
  Future<bool> forgotPassword(String email) async {
    loggy.debug("Attempting password reset for email: $email");
    return Future.value(true);
  }

  @override
  Future<bool> resetPassword(
    String email,
    String newPassword,
    String validationCode,
  ) async {
    return Future.value(true);
  }

  @override
  Future<bool> verifyToken() async {
    loggy.debug('Attempting token verification');
    return Future.value(true);
  }

  Future<List<AuthenticationUser>> _getUsers() async {
    final encoded = await preferences.getString(_usersKey);
    if (encoded == null || encoded.isEmpty) return <AuthenticationUser>[];

    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded
          .map(
            (account) =>
                AuthenticationUser.fromJson(account as Map<String, dynamic>),
          )
          .toList();
    } on FormatException {
      throw StateError('Stored accounts could not be read.');
    }
  }

  Future<void> _saveUsers(List<AuthenticationUser> users) =>
      preferences.setString(
        _usersKey,
        jsonEncode(users.map((user) => user.toJson()).toList()),
      );

  Future<void> _saveSession(String email) async {
    await preferences.setBool(_sessionKey, true);
    await preferences.setString(_sessionEmailKey, email);
  }

  String _normalizedEmail(String email) => email.trim().toLowerCase();
}
