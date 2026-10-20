import 'package:campus_innovate/core/roble/roble_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Run without `--dart-define`, so these are the compiled-in defaults.
void main() {
  test('apunta al host de la API y no al de la consola', () {
    final uri = Uri.parse(RobleConfig.baseUrl);

    expect(uri.scheme, 'https');
    expect(uri.host, startsWith('roble-api.'));
  });

  test('trae un contrato y un destino de login social por defecto', () {
    expect(RobleConfig.contractId, isNotEmpty);
    expect(RobleConfig.contractId, isNot(contains('/')));
    expect(RobleConfig.socialRedirect, 'default');
  });

  test('cada tabla tiene un nombre distinto y en snake_case', () {
    const tables = [
      RobleConfig.listingsTable,
      RobleConfig.listingMembersTable,
      RobleConfig.joinRequestsTable,
      RobleConfig.groupsTable,
      RobleConfig.groupMembersTable,
      RobleConfig.groupRequestsTable,
      RobleConfig.listingReactionsTable,
      RobleConfig.listingViewsTable,
      RobleConfig.listingCommentsTable,
      RobleConfig.appUsersTable,
      RobleConfig.groupInvitationsTable,
      RobleConfig.groupMessagesTable,
      RobleConfig.notificationsTable,
    ];

    expect(tables.toSet(), hasLength(tables.length));
    for (final table in tables) {
      expect(table, matches(RegExp(r'^[a-z]+(_[a-z]+)*$')));
    }
  });
}
