import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_config.dart';
import '../../../../../core/roble/roble_duplicate.dart';
import '../../../../../core/roble/roble_exception.dart';
import '../../../domain/models/app_user.dart';
import '../i_user_source.dart';

/// The directory of people, stored in ROBLE.
///
/// ROBLE keeps accounts in its auth service and has no call that lists them, so
/// the app keeps its own table and every person adds themselves to it when they
/// open the app. The consequence is the one to remember: someone who has not
/// opened the app since this table existed cannot be found, and therefore cannot
/// be invited, until they do.
class RobleUserSource implements IUserSource {
  RobleUserSource(this._client);

  final RobleClient _client;

  @override
  Future<void> upsert(AppUser user) async {
    final rows = await _client.read(
      RobleConfig.appUsersTable,
      filters: {'user_id': user.id},
    );

    if (rows.isNotEmpty) {
      final row = rows.first;

      final isCurrent = row['name']?.toString() == user.name &&
          row['email']?.toString() == user.email;
      if (isCurrent) return;

      final id = row['_id']?.toString();
      if (id == null || id.isEmpty) return;

      await _client.update(
        tableName: RobleConfig.appUsersTable,
        idValue: id,
        updates: {
          'name': user.name,
          'email': user.email,
          'updated_at': _now(),
        },
      );

      return;
    }

    try {
      await _client.insertOne(RobleConfig.appUsersTable, {
        'user_id': user.id,
        'name': user.name,
        'email': user.email,
        'updated_at': _now(),
      });
    } on RobleException catch (error) {
      // Two devices of the same person opened the app at once and the other one
      // won the insert: the row exists, which is all this wanted.
      if (isDuplicateRow(error)) return;
      rethrow;
    }
  }

  @override
  Future<List<AppUser>> getUsers() async {
    final rows = await _client.read(RobleConfig.appUsersTable);

    return rows.map(_userFrom).whereType<AppUser>().toList();
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  AppUser? _userFrom(Map<String, dynamic> row) {
    final id = row['user_id']?.toString();
    if (id == null || id.isEmpty) return null;

    return AppUser(
      id: id,
      name: row['name']?.toString() ?? 'Estudiante',
      email: row['email']?.toString() ?? '',
    );
  }
}
