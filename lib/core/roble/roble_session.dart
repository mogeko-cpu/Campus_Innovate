import '../i_local_preferences.dart';
import 'roble_user.dart';

/// The tokens and the user of the signed-in account, kept in memory and mirrored
/// to encrypted storage so closing the app does not force a new login.
///
/// Persisting matters beyond convenience: `POST login` is limited to **10 per
/// 15 minutes per IP**, shared by everyone on the same network. An app that
/// logged in on every launch would lock out a whole classroom.
class RobleSession {
  RobleSession(this._preferences);

  static const _accessTokenKey = 'roble_access_token';
  static const _refreshTokenKey = 'roble_refresh_token';
  static const _userKey = 'roble_user';

  /// Keys written by the template's local account store, which kept e-mails and
  /// **passwords in cleartext**. They are wiped on the first [restore] so an app
  /// updated over that version does not keep the leftovers around.
  static const _legacyKeys = [
    'auth_users',
    'auth_is_logged_in',
    'auth_session_email',
  ];

  final ILocalPreferences _preferences;

  String? _accessToken;
  String? _refreshToken;
  RobleUser? _user;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  RobleUser? get user => _user;

  /// True when there is something to try: the token may still turn out to be
  /// expired, which the first request discovers.
  bool get isActive => _accessToken != null && _user != null;

  /// Loads the stored session. Safe to call once at startup before the UI reads
  /// anything from ROBLE.
  Future<void> restore() async {
    await _dropLegacyKeys();

    _accessToken = await _preferences.getString(_accessTokenKey);
    _refreshToken = await _preferences.getString(_refreshTokenKey);

    final raw = await _preferences.getString(_userKey);
    if (raw == null) return;

    try {
      _user = RobleUser.fromCache(raw);
    } on FormatException {
      // A cached user we cannot parse is not worth a crash at startup; the
      // session simply counts as absent and the user logs in again.
      await clear();
    }
  }

  Future<void> save({
    required String accessToken,
    required String? refreshToken,
    required RobleUser user,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _user = user;

    await _preferences.setString(_accessTokenKey, accessToken);
    await _preferences.setString(_userKey, user.toCache());

    if (refreshToken != null) {
      await _preferences.setString(_refreshTokenKey, refreshToken);
    }
  }

  /// Stores the token obtained from `refresh-token`.
  ///
  /// [refreshToken] is optional because ROBLE currently returns only a new
  /// access token, but the endpoint is documented as free to rotate the refresh
  /// token too — when it does, the new one must replace the old one or the next
  /// refresh fails.
  Future<void> renew(String accessToken, {String? refreshToken}) async {
    _accessToken = accessToken;
    await _preferences.setString(_accessTokenKey, accessToken);

    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await _preferences.setString(_refreshTokenKey, refreshToken);
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _user = null;

    await _preferences.remove(_accessTokenKey);
    await _preferences.remove(_refreshTokenKey);
    await _preferences.remove(_userKey);
  }

  Future<void> _dropLegacyKeys() async {
    for (final key in _legacyKeys) {
      await _preferences.remove(key);
    }
  }
}
