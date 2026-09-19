import 'dart:convert';

import 'package:campus_innovate/core/roble/roble_client.dart';
import 'package:campus_innovate/core/roble/roble_exception.dart';
import 'package:campus_innovate/core/roble/roble_session.dart';
import 'package:campus_innovate/core/roble/roble_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/memory_preferences.dart';

/// Exercises the parts of the transport that are easy to get wrong and hard to
/// notice: the single refresh-and-retry, the two shapes a row list arrives in,
/// and the guard that keeps a non-UUID from reaching a `uuid` column.
void main() {
  const host = 'https://roble-api.test';
  const contract = 'contrato_test';

  /// The account is irrelevant to these tests; only the tokens matter.
  const user = RobleUser(
    id: 'user-uuid',
    email: 'ana@uninorte.edu.co',
    name: 'Ana Pérez',
  );

  late MemoryPreferences preferences;
  late RobleSession session;

  setUp(() {
    preferences = MemoryPreferences();
    session = RobleSession(preferences);
  });

  RobleClient clientWith(MockClient http) => RobleClient(
        session: session,
        httpClient: http,
        baseUrl: host,
        contractId: contract,
      );

  test('login stores the tokens and the user that /me reports', () async {
    final client = clientWith(
      MockClient((request) async {
        if (request.url.path == '/auth/$contract/login') {
          return http.Response(
            jsonEncode({'accessToken': 'access-1', 'refreshToken': 'refresh-1'}),
            201,
          );
        }

        if (request.url.path == '/auth/$contract/me') {
          expect(request.headers['Authorization'], 'Bearer access-1');

          return http.Response(
            jsonEncode({
              'id': 'row-1',
              'userId': 'user-uuid',
              'email': 'ana@uninorte.edu.co',
              'name': 'Ana Pérez',
            }),
            200,
          );
        }

        return http.Response('no esperado: ${request.url}', 404);
      }),
    );

    final signedIn = await client.login(
      email: 'ana@uninorte.edu.co',
      password: 'Secreta1!',
    );

    // `userId` wins over `id`: it is the value that goes into creator_id.
    expect(signedIn.id, 'user-uuid');
    expect(signedIn.name, 'Ana Pérez');
    expect(session.accessToken, 'access-1');
    expect(session.refreshToken, 'refresh-1');
    expect(session.isActive, isTrue);
  });

  test('a 401 while reading refreshes the token once and retries', () async {
    await session.save(
      accessToken: 'expired',
      refreshToken: 'refresh-1',
      user: user,
    );

    var reads = 0;
    var refreshes = 0;

    final client = clientWith(
      MockClient((request) async {
        if (request.url.path == '/auth/$contract/refresh-token') {
          refreshes++;

          return http.Response(jsonEncode({'accessToken': 'access-2'}), 200);
        }

        reads++;

        // The first read carries the stale token and is rejected; the retry must
        // carry the new one.
        if (request.headers['Authorization'] == 'Bearer expired') {
          return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
        }

        return http.Response(jsonEncode([{'_id': 'a'}]), 200);
      }),
    );

    final rows = await client.read('listings');

    expect(rows, hasLength(1));
    expect(refreshes, 1);
    expect(reads, 2, reason: 'una sola reintento, no un bucle');
    expect(session.accessToken, 'access-2');
  });

  test('a session that cannot be refreshed is cleared and reported', () async {
    await session.save(
      accessToken: 'expired',
      refreshToken: 'refresh-1',
      user: user,
    );

    var reads = 0;

    final client = clientWith(
      MockClient((request) async {
        if (request.url.path == '/auth/$contract/refresh-token') {
          return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
        }

        reads++;

        return http.Response(jsonEncode({'message': 'Unauthorized'}), 401);
      }),
    );

    await expectLater(
      client.read('listings'),
      throwsA(isA<RobleUnauthorizedException>()),
    );

    expect(reads, 1, reason: 'sin refresh no vale la pena reintentar');
    expect(session.isActive, isFalse);
    expect(preferences.values, isEmpty);
  });

  test('rows arrive either as a list or wrapped in data', () async {
    await session.save(
      accessToken: 'access-1',
      refreshToken: null,
      user: user,
    );

    final wrapped = clientWith(
      MockClient(
        (request) async => http.Response(
          jsonEncode({
            'data': [
              {'_id': 'a'},
              {'_id': 'b'},
            ],
          }),
          200,
        ),
      ),
    );

    expect(await wrapped.read('listings'), hasLength(2));

    final bare = clientWith(
      MockClient(
        (request) async => http.Response(jsonEncode([{'_id': 'a'}]), 200),
      ),
    );

    expect(await bare.read('listings'), hasLength(1));
  });

  test('a 429 says how long to wait', () async {
    await session.save(
      accessToken: 'access-1',
      refreshToken: null,
      user: user,
    );

    final client = clientWith(
      MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'ThrottlerException: Too Many Requests'}),
          429,
          headers: {'x-ratelimit-reset': '42'},
        ),
      ),
    );

    await expectLater(
      client.read('listings'),
      throwsA(
        isA<RobleRateLimitException>()
            .having((error) => error.retryAfter, 'retryAfter', 42)
            .having((error) => error.message, 'message', contains('42')),
      ),
    );
  });

  test('an id that is not a UUID never reaches the database', () async {
    await session.save(
      accessToken: 'access-1',
      refreshToken: null,
      user: user,
    );

    var requests = 0;

    final client = clientWith(
      MockClient((request) async {
        requests++;

        return http.Response('{}', 200);
      }),
    );

    // PostgreSQL would fail comparing a `uuid` column with '7', and ROBLE would
    // forward that as a 500 that looks like an outage.
    expect(RobleClient.isRowId('7'), isFalse);
    expect(
      RobleClient.isRowId('3f2504e0-4f89-11d3-9a0c-0305e82c3301'),
      isTrue,
    );

    await expectLater(
      client.update(tableName: 'listings', idValue: '7', updates: {'title': 'x'}),
      throwsA(isA<RobleNotFoundException>()),
    );

    expect(requests, 0);
  });

  test('a 400 on a write keeps the reason ROBLE gave', () async {
    await session.save(
      accessToken: 'access-1',
      refreshToken: null,
      user: user,
    );

    final client = clientWith(
      MockClient(
        (request) async => http.Response(
          jsonEncode({
            'message': ['column "titulo" does not exist'],
          }),
          400,
        ),
      ),
    );

    await expectLater(
      client.insertOne('listings', {'titulo': 'x'}),
      throwsA(
        isA<RobleBadRequestException>().having(
          (error) => error.message,
          'message',
          contains('does not exist'),
        ),
      ),
    );
  });
}
