import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// ROBLE's database endpoints over a map of tables.
///
/// Stands in for the service in tests of the data sources: it answers `read`,
/// `insert-one`, `insert`, `update` and `delete` the way ROBLE does, and — the
/// reason it exists — it enforces the same composite `UNIQUE` constraints, so a
/// test can check what happens on the second insert without a network.
///
/// It is deliberately unforgiving where ROBLE is: a filter is an equality on the
/// string form of the value, never a `LIKE`, and rows come back in insertion
/// order, unordered as far as callers are concerned.
class FakeRobleApi {
  FakeRobleApi({this.contractId = 'contrato_test'});

  final String contractId;

  /// Rows by table name, `_id` included once inserted.
  final Map<String, List<Map<String, dynamic>>> tables = {};

  /// Column groups that may not repeat, mirroring the schema in `docs/roble.md`.
  final Map<String, List<String>> uniques = {
    'listing_members': ['listing_id', 'user_id'],
    'join_requests': ['listing_id', 'applicant_id'],
  };

  /// Every path that was hit, in order, for assertions about what the source did
  /// (e.g. that a failed insert was followed by a `delete`).
  final List<String> calls = [];

  var _nextId = 0;

  http.Client get client => MockClient(handle);

  List<Map<String, dynamic>> rowsOf(String table) => tables[table] ??= [];

  /// Seeds a row and returns it with the `_id` the store assigned.
  Map<String, dynamic> seed(String table, Map<String, dynamic> record) {
    final row = {'_id': _newId(), ...record};
    rowsOf(table).add(row);

    return row;
  }

  String _newId() =>
      '00000000-0000-4000-8000-${(++_nextId).toString().padLeft(12, '0')}';

  /// Answers one request. Public so a test can wrap it in its own [MockClient]
  /// and fail a single endpoint while the rest keeps working — an
  /// [http.Request] cannot be sent twice, so forwarding means calling this.
  Future<http.Response> handle(http.Request request) async {
    final endpoint = request.url.pathSegments.last;
    calls.add(endpoint);

    final body = request.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;

    switch (endpoint) {
      case 'read':
        return _read(request.url.queryParameters);
      case 'insert-one':
        return _insertOne(body);
      case 'insert':
        return _insertMany(body);
      case 'update':
        return _update(body);
      case 'delete':
        return _delete(body);
      default:
        return http.Response(
          jsonEncode({'message': 'endpoint no simulado: $endpoint'}),
          404,
        );
    }
  }

  http.Response _read(Map<String, String> query) {
    final table = query['tableName'];
    if (table == null) return _badRequest('tableName is required');

    final filters = Map<String, String>.from(query)..remove('tableName');

    final rows = rowsOf(table).where((row) {
      return filters.entries.every(
        (filter) => row[filter.key]?.toString() == filter.value,
      );
    }).toList();

    return _ok(rows);
  }

  http.Response _insertOne(Map<String, dynamic> body) {
    final table = body['tableName'] as String;
    final record = Map<String, dynamic>.from(body['record'] as Map);

    if (_violatesUnique(table, record)) return _duplicate(table);

    final row = {'_id': _newId(), ...record};
    rowsOf(table).add(row);

    return _ok({'inserted': [row]});
  }

  http.Response _insertMany(Map<String, dynamic> body) {
    final table = body['tableName'] as String;
    final records = (body['records'] as List)
        .map((record) => Map<String, dynamic>.from(record as Map))
        .toList();

    final inserted = <Map<String, dynamic>>[];
    final skipped = <dynamic>[];

    // ROBLE reports a partial insert as a 200 with the rejects listed, not as an
    // error, so the whole batch is never rolled back.
    for (final record in records) {
      if (_violatesUnique(table, record)) {
        skipped.add(record);
        continue;
      }

      final row = {'_id': _newId(), ...record};
      rowsOf(table).add(row);
      inserted.add(row);
    }

    return _ok({'inserted': inserted, 'skipped': skipped});
  }

  http.Response _update(Map<String, dynamic> body) {
    final table = body['tableName'] as String;
    final id = body['idValue']?.toString();
    final updates = Map<String, dynamic>.from(body['updates'] as Map);

    final index = rowsOf(table).indexWhere((row) => row['_id'] == id);
    if (index == -1) return _ok({'updated': 0});

    rowsOf(table)[index] = {...rowsOf(table)[index], ...updates};

    return _ok({'updated': 1});
  }

  http.Response _delete(Map<String, dynamic> body) {
    final table = body['tableName'] as String;
    final id = body['idValue']?.toString();

    rowsOf(table).removeWhere((row) => row['_id'] == id);

    return _ok({'deleted': 1});
  }

  bool _violatesUnique(String table, Map<String, dynamic> record) {
    final columns = uniques[table];
    if (columns == null) return false;

    return rowsOf(table).any(
      (row) => columns.every(
        (column) => row[column]?.toString() == record[column]?.toString(),
      ),
    );
  }

  /// The shape of a `UNIQUE` violation: PostgreSQL's text, forwarded as a 400.
  http.Response _duplicate(String table) => _badRequest(
        'duplicate key value violates unique constraint "${table}_unique"',
      );

  http.Response _badRequest(String message) =>
      http.Response(jsonEncode({'message': message}), 400);

  http.Response _ok(Object payload) => http.Response(
        jsonEncode(payload),
        200,
        headers: {'content-type': 'application/json'},
      );
}
