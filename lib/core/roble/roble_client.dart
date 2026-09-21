import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'roble_config.dart';
import 'roble_exception.dart';
import 'roble_session.dart';
import 'roble_user.dart';

/// Thin transport over the ROBLE REST API: two groups of endpoints
/// (`/auth/{contract}/…` and `/database/{contract}/…`), one Bearer token, and
/// the retry rule that keeps a long session alive.
///
/// Deliberately free of Flutter imports so `tool/seed_roble.dart` can reuse it
/// from the command line.
///
/// What ROBLE does *not* offer shapes every caller above this class:
///
/// * `read` filters by **equality only** — no `LIKE`, no ranges, no ordering, no
///   pagination. Searching and sorting happen in Dart, over the whole table.
/// * There are **no transactions and no conditional writes**. Two related rows
///   mean two requests that can half-fail, so the order of writes is chosen to
///   leave recoverable state.
/// * There are **no foreign keys**, so a `listing_id` can outlive its listing.
class RobleClient {
  RobleClient({
    required this.session,
    http.Client? httpClient,
    this.baseUrl = RobleConfig.baseUrl,
    this.contractId = RobleConfig.contractId,
    this.timeout = const Duration(seconds: 20),
  }) : _http = httpClient ?? http.Client();

  /// A campus network on a bad day is slow, not dead; 20 s is long enough to
  /// ride that out and short enough that the UI is not stuck forever.
  final Duration timeout;

  /// The tokens this client sends and keeps up to date.
  final RobleSession session;
  final String baseUrl;
  final String contractId;

  final http.Client _http;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Whether [value] can be sent as an `_id`.
  ///
  /// The column is a PostgreSQL `uuid`, so comparing it against anything else
  /// makes the query fail inside the database and ROBLE answers **500** — a
  /// server error for what is really a bad argument. Callers check first and
  /// treat a non-UUID as "no such row".
  static bool isRowId(String value) => _uuid.hasMatch(value);

  // ---------------------------------------------------------------- auth

  /// Creates an account and leaves it ready to use, no e-mail code.
  ///
  /// Limited to **5 per hour per IP**, and a rejected password still spends one:
  /// validate against the policy (8+ chars, upper, lower, digit, and one of
  /// `! @ # $ _ - .`) before calling.
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    await _send(
      method: 'POST',
      uri: _authUri('signup-direct'),
      body: {'email': email, 'password': password, 'name': name},
      authenticated: false,
    );
  }

  /// Exchanges credentials for tokens and stores them in the session.
  ///
  /// Limited to **10 per 15 minutes per IP** — the tightest budget in the app,
  /// which is why the session is persisted instead of re-established at startup.
  Future<RobleUser> login({
    required String email,
    required String password,
  }) async {
    final payload = await _send(
      method: 'POST',
      uri: _authUri('login'),
      body: {'email': email, 'password': password},
      authenticated: false,
    );

    return _openSession(_asMap(payload), flow: 'el inicio de sesión');
  }

  /// Opens the provider's flow and returns where to send the person.
  ///
  /// [redirect] is the **name** of a return destination registered in the ROBLE
  /// console, never a URL: the console keeps the list of allowed addresses, so an
  /// app cannot send anyone back to a destination the project owner did not
  /// approve. [extra] is stored on the account like `signup`'s, and travels in the
  /// body instead of the query so it does not reach the server's logs, the proxy's
  /// or the browser's history.
  ///
  /// `state` comes back for the caller to keep if it wants to check the return;
  /// ROBLE validates it on its own at the callback, so the app can ignore it.
  Future<({String url, String state})> startSocialLogin({
    String provider = 'google',
    String redirect = RobleConfig.socialRedirect,
    Map<String, dynamic>? extra,
  }) async {
    final payload = await _send(
      method: 'POST',
      uri: _authUri('auth/$provider/start'),
      body: {'redirect': redirect, 'extra': ?extra},
      authenticated: false,
    );

    final json = _asMap(payload);
    final url = json['url']?.toString();

    if (url == null || url.isEmpty) {
      throw const RobleServerException(
        'ROBLE no dijo a dónde enviar el inicio de sesión con el proveedor.',
        201,
      );
    }

    return (url: url, state: json['state']?.toString() ?? '');
  }

  /// Turns the one-time code the provider left on the return address into a
  /// session.
  ///
  /// The code is the whole credential — it identifies the account, the project
  /// and the provider — so nothing else travels, and it is valid **once**:
  /// sending it twice answers 400, which is why the caller drops it from the
  /// address before spending it.
  ///
  /// Note that this route is the project's (`/auth/{contract}/auth/token`) and not
  /// the provider's: the flow is already tied to the contract by the code.
  Future<RobleUser> exchangeSocialCode(String code) async {
    final payload = await _send(
      method: 'POST',
      uri: _authUri('auth/token'),
      body: {'code': code},
      authenticated: false,
    );

    return _openSession(
      _asMap(payload),
      flow: 'el inicio de sesión con el proveedor',
    );
  }

  /// Stores the tokens of a session that ROBLE just issued and returns its owner.
  ///
  /// `login` and the social exchange answer with the same pair of tokens and
  /// neither includes the account, so both end here.
  Future<RobleUser> _openSession(
    Map<String, dynamic> json, {
    required String flow,
  }) async {
    final accessToken = json['accessToken']?.toString();

    if (accessToken == null || accessToken.isEmpty) {
      throw RobleServerException(
        'ROBLE aceptó $flow pero no devolvió el token.',
        200,
      );
    }

    final refreshToken = json['refreshToken']?.toString();

    // The token has to be in place before `me`, which is an authenticated call.
    // Until the user comes back the session is not `isActive`, so a failure here
    // cannot leave the app believing someone is signed in.
    await session.renew(accessToken, refreshToken: refreshToken);

    try {
      final user = await me();
      await session.save(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );
      return user;
    } on RobleException {
      // Never leave the half-written session behind: it would look active and
      // fail on the first read.
      await session.clear();
      rethrow;
    }
  }

  Future<RobleUser> me() async {
    final payload = await _send(method: 'GET', uri: _authUri('me'));

    try {
      return RobleUser.fromJson(_asMap(payload));
    } on FormatException catch (error) {
      throw RobleServerException(error.message, 200);
    }
  }

  /// Asks ROBLE whether the stored access token is still good.
  ///
  /// Returns false only when ROBLE says the session is over: a network failure
  /// throws instead, because "we could not ask" must not be mistaken for "you
  /// are logged out" — that would sign people out every time the wifi drops.
  Future<bool> verifyToken() async {
    if (session.accessToken == null) return false;

    try {
      await _send(method: 'GET', uri: _authUri('verify-token'));
      return true;
    } on RobleUnauthorizedException {
      return false;
    } on RobleForbiddenException {
      return false;
    }
  }

  /// Starts the password reset flow; ROBLE e-mails a code.
  Future<void> forgotPassword(String email) async {
    await _send(
      method: 'POST',
      uri: _authUri('forgot-password'),
      body: {'email': email},
      authenticated: false,
    );
  }

  /// Finishes the reset with the code from the e-mail, which ROBLE calls a token.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _send(
      method: 'POST',
      uri: _authUri('reset-password'),
      body: {'token': token, 'newPassword': newPassword},
      authenticated: false,
    );
  }

  /// Confirms an account created with `signup` (the flow that mails a code).
  ///
  /// The app registers through `signup-direct`, which needs no confirmation, so
  /// this exists for accounts created from the ROBLE console.
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _send(
      method: 'POST',
      uri: _authUri('verify-email'),
      body: {'email': email, 'code': code},
      authenticated: false,
    );
  }

  /// Invalidates the refresh token server-side and forgets the local session.
  ///
  /// The local part happens even if the request fails: from the user's point of
  /// view "cerrar sesión" must always work.
  Future<void> logout() async {
    try {
      await _send(method: 'POST', uri: _authUri('logout'), body: const {});
    } on RobleException {
      // Already-invalid token, no network: nothing here changes what we do next.
    } finally {
      await session.clear();
    }
  }

  /// Trades the refresh token for a fresh access token.
  ///
  /// Returns false when there is nothing to refresh or ROBLE refuses, in which
  /// case the session is cleared and the caller must send the user to login.
  Future<bool> refreshSession() async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final payload = await _send(
        method: 'POST',
        uri: _authUri('refresh-token'),
        body: {'refreshToken': refreshToken},
        authenticated: false,
        allowRefresh: false,
      );

      final json = _asMap(payload);
      final accessToken = json['accessToken']?.toString();
      if (accessToken == null || accessToken.isEmpty) return false;

      await session.renew(
        accessToken,
        refreshToken: json['refreshToken']?.toString(),
      );
      return true;
    } on RobleUnauthorizedException {
      await session.clear();
      return false;
    } on RobleForbiddenException {
      await session.clear();
      return false;
    }
  }

  // ------------------------------------------------------------ database

  /// Reads rows from [tableName], optionally narrowed by equality [filters].
  ///
  /// Every filter value travels as a query string; ROBLE casts it to the column
  /// type on the other side.
  Future<List<Map<String, dynamic>>> read(
    String tableName, {
    Map<String, String> filters = const {},
  }) async {
    final payload = await _send(
      method: 'GET',
      uri: _dataUri('read', {'tableName': tableName, ...filters}),
    );

    return _asRows(payload);
  }

  /// Inserts one row and returns it as stored, `_id` included.
  ///
  /// A **400** here means the record carries a field the table does not have:
  /// ROBLE validates against the real columns and rejects the whole row.
  Future<Map<String, dynamic>> insertOne(
    String tableName,
    Map<String, dynamic> record,
  ) async {
    final payload = await _send(
      method: 'POST',
      uri: _dataUri('insert-one'),
      body: {'tableName': tableName, 'record': record},
    );

    return _insertedRow(payload, fallback: record);
  }

  /// Inserts several rows in one request. Partial success is normal and comes
  /// back as **200** with the rejects listed in `skipped`, so the result is
  /// returned whole instead of being reduced to a boolean.
  Future<({List<Map<String, dynamic>> inserted, List<dynamic> skipped})>
      insertMany(
    String tableName,
    List<Map<String, dynamic>> records,
  ) async {
    final payload = await _send(
      method: 'POST',
      uri: _dataUri('insert'),
      body: {'tableName': tableName, 'records': records},
    );

    final json = _asMap(payload);

    return (
      inserted: _asRows(json['inserted']),
      skipped: json['skipped'] is List ? json['skipped'] as List : const [],
    );
  }

  /// Updates the row addressed by `_id`.
  ///
  /// `_id` and `id` are stripped from [updates] because ROBLE refuses to write
  /// the key column, and sending it fails the whole update.
  Future<void> update({
    required String tableName,
    required String idValue,
    required Map<String, dynamic> updates,
  }) async {
    if (!isRowId(idValue)) {
      throw RobleNotFoundException('El registro $idValue no existe.');
    }

    final clean = Map<String, dynamic>.from(updates)
      ..remove('_id')
      ..remove('id');

    await _send(
      method: 'PUT',
      uri: _dataUri('update'),
      body: {
        'tableName': tableName,
        'idColumn': '_id',
        'idValue': idValue,
        'updates': clean,
      },
    );
  }

  Future<void> delete({
    required String tableName,
    required String idValue,
  }) async {
    if (!isRowId(idValue)) {
      throw RobleNotFoundException('El registro $idValue no existe.');
    }

    await _send(
      method: 'DELETE',
      uri: _dataUri('delete'),
      body: {
        'tableName': tableName,
        'idColumn': '_id',
        'idValue': idValue,
      },
    );
  }

  void close() => _http.close();

  // ------------------------------------------------------------ plumbing

  Uri _authUri(String path) =>
      Uri.parse('$baseUrl/auth/$contractId/$path');

  Uri _dataUri(String path, [Map<String, String>? query]) => Uri.parse(
        '$baseUrl/database/$contractId/$path',
      ).replace(queryParameters: query);

  /// Performs the request and returns the decoded body.
  ///
  /// On **401** for an authenticated request it refreshes the access token once
  /// and retries once — never in a loop: if the retry also comes back 401 the
  /// session is genuinely over, and looping would burn the rate limit while
  /// making the user wait.
  Future<dynamic> _send({
    required String method,
    required Uri uri,
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool allowRefresh = true,
  }) async {
    final response = await _dispatch(
      method: method,
      uri: uri,
      body: body,
      authenticated: authenticated,
    );

    if (response.statusCode == 401 && authenticated && allowRefresh) {
      if (await refreshSession()) {
        final retry = await _dispatch(
          method: method,
          uri: uri,
          body: body,
          authenticated: authenticated,
        );
        return _decode(retry);
      }
    }

    return _decode(response);
  }

  Future<http.Response> _dispatch({
    required String method,
    required Uri uri,
    required Map<String, dynamic>? body,
    required bool authenticated,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authenticated && session.accessToken != null)
        'Authorization': 'Bearer ${session.accessToken}',
    };

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const RobleTimeoutException();
    } on SocketException {
      throw const RobleNetworkException();
    } on http.ClientException {
      throw const RobleNetworkException();
    } on HandshakeException {
      throw const RobleNetworkException(
        'No se pudo establecer una conexión segura con ROBLE.',
      );
    }
  }

  dynamic _decode(http.Response response) {
    final status = response.statusCode;
    final payload = _tryDecodeBody(response.body);

    if (status >= 200 && status < 300) return payload;

    final detail = _messageOf(payload);

    switch (status) {
      case 400:
        throw RobleBadRequestException(
          detail ??
              'ROBLE rechazó los datos enviados. Revisa que las columnas de la '
                  'tabla coincidan con la aplicación.',
        );
      case 401:
        throw const RobleUnauthorizedException();
      case 403:
        throw RobleForbiddenException(
          detail ?? 'Tu cuenta no tiene permiso para esta operación.',
        );
      case 404:
        throw RobleNotFoundException(detail ?? 'El registro no existe.');
      case 429:
        final reset = int.tryParse(
          response.headers['x-ratelimit-reset'] ?? '',
        );
        throw RobleRateLimitException(
          reset == null
              ? 'Demasiadas solicitudes a ROBLE. Espera un momento.'
              : 'Demasiadas solicitudes a ROBLE. Intenta de nuevo en '
                  '$reset segundos.',
          retryAfter: reset,
        );
      default:
        if (status >= 500) {
          throw RobleServerException(
            detail == null
                ? 'ROBLE respondió con un error ($status).'
                : 'ROBLE respondió con un error ($status): $detail',
            status,
          );
        }
        throw RobleServerException(
          detail ?? 'Respuesta inesperada de ROBLE ($status).',
          status,
        );
    }
  }

  dynamic _tryDecodeBody(String body) {
    if (body.isEmpty) return null;

    try {
      return jsonDecode(body);
    } on FormatException {
      // A non-JSON body means we are not talking to the API: usually the
      // console host, which serves HTML.
      return body;
    }
  }

  /// Digs the human part out of a ROBLE error body, whose `message` is sometimes
  /// a string and sometimes a list of validation messages.
  String? _messageOf(dynamic payload) {
    if (payload is String) {
      final trimmed = payload.trim();
      return trimmed.isEmpty || trimmed.startsWith('<') ? null : trimmed;
    }

    if (payload is! Map) return null;

    final message = payload['message'] ?? payload['error'];
    if (message is List) {
      final parts = message.map((item) => item.toString()).where(
            (item) => item.isNotEmpty,
          );
      return parts.isEmpty ? null : parts.join('. ');
    }

    final text = message?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, dynamic> _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) return payload;
    if (payload is Map) return Map<String, dynamic>.from(payload);

    throw const RobleServerException(
      'ROBLE devolvió una respuesta con un formato inesperado.',
      200,
    );
  }

  /// Normalises the two shapes ROBLE uses for a set of rows: a bare list, or an
  /// object wrapping it under `data`.
  List<Map<String, dynamic>> _asRows(dynamic payload) {
    final list = switch (payload) {
      List list => list,
      Map map when map['data'] is List => map['data'] as List,
      Map map when map['records'] is List => map['records'] as List,
      _ => const [],
    };

    return list
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// The stored row after an insert. `insert-one` has answered with the record
  /// itself and with `{inserted: [record]}` depending on the endpoint version,
  /// and [fallback] covers the case where it answers with neither: the row did
  /// go in, but without `_id` the caller cannot address it, so it is better to
  /// return what we sent than to pretend the insert failed.
  Map<String, dynamic> _insertedRow(
    dynamic payload, {
    required Map<String, dynamic> fallback,
  }) {
    if (payload is Map && payload['inserted'] is List) {
      final rows = _asRows(payload['inserted']);
      if (rows.isNotEmpty) return rows.first;
    }

    if (payload is Map && payload.containsKey('_id')) {
      return Map<String, dynamic>.from(payload);
    }

    if (payload is Map && payload['record'] is Map) {
      return Map<String, dynamic>.from(payload['record'] as Map);
    }

    return fallback;
  }
}
