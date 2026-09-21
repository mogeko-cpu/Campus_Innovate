import '../../../../../core/roble/roble_client.dart';
import '../../../../../core/roble/roble_config.dart';
import '../../../../../core/roble/roble_duplicate.dart';
import '../../../../../core/roble/roble_exception.dart';
import '../../../domain/group_exception.dart';
import '../../../domain/models/group.dart';
import '../../../domain/models/group_member.dart';
import '../../../domain/models/group_request.dart';
import '../../../domain/models/group_request_status.dart';
import '../i_group_source.dart';

/// Groups, their members and their requests, stored in ROBLE.
///
/// Three tables, shaped like the listings ones and for the same reasons: members
/// are rows so that being accepted is a single insert, and the composite
/// `UNIQUE`s — not this class — are what make a double membership or a double
/// request impossible when two devices race.
class RobleGroupSource implements IGroupSource {
  RobleGroupSource(this._client);

  final RobleClient _client;

  @override
  Future<List<Group>> getGroups() async {
    // Two full table reads: ROBLE has no join and no `IN (…)`, so the members
    // are grouped here. Fine at course scale, and the first thing to revisit if
    // the data grows — same trade-off as `RobleListingSource.getListings`.
    final rows = await _client.read(RobleConfig.groupsTable);
    final memberRows = await _client.read(RobleConfig.groupMembersTable);

    final membersByGroup = <String, List<GroupMember>>{};
    for (final row in memberRows) {
      final member = _memberFrom(row);
      if (member == null) continue;

      membersByGroup.putIfAbsent(member.groupId, () => []).add(member);
    }

    // Newest first. ROBLE cannot order a read, so the app sorts what it got.
    rows.sort(
      (a, b) => _dateOf(b['created_at']).compareTo(_dateOf(a['created_at'])),
    );

    return rows
        .map((row) => _groupFrom(row, membersByGroup))
        .whereType<Group>()
        .toList();
  }

  @override
  Future<Group?> getGroupById(String id) async {
    // A malformed id is "not found", never a request: `_id` is a `uuid` column
    // and comparing it with something else makes ROBLE answer 500.
    if (!RobleClient.isRowId(id)) return null;

    final rows = await _client.read(
      RobleConfig.groupsTable,
      filters: {'_id': id},
    );
    if (rows.isEmpty) return null;

    return _groupFrom(rows.first, {id: await _membersOf(id)});
  }

  @override
  Future<Group> createGroup(Group group) async {
    final row = await _client.insertOne(RobleConfig.groupsTable, {
      'name': group.name,
      'description': group.description,
      'owner_id': group.ownerId,
      'owner_name': group.ownerName,
      'created_at': _now(),
    });

    final id = row['_id']?.toString();

    if (id == null || id.isEmpty) {
      throw const GroupException(
        'ROBLE guardó el grupo pero no devolvió su identificador. '
        'Recarga la lista antes de volver a crearlo.',
      );
    }

    // The owner's membership is a second write. If it fails the group would
    // exist with nobody in it and no screen to fix that, so the insert is undone
    // and the user sees the original error and can create it again.
    try {
      await _addMemberRow(
        GroupMember(
          groupId: id,
          userId: group.ownerId,
          userName: group.ownerName,
        ),
      );
    } catch (_) {
      await _deleteQuietly(RobleConfig.groupsTable, id);
      rethrow;
    }

    return group.copyWith(
      id: id,
      members: [
        GroupMember(
          groupId: id,
          userId: group.ownerId,
          userName: group.ownerName,
        ),
      ],
    );
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    if (!RobleClient.isRowId(groupId)) {
      throw GroupException('El grupo $groupId ya no existe.');
    }

    // Children first, parent last, because there are no transactions: a failure
    // halfway leaves the group row in place, still listed and still deletable.
    // The opposite order would leave members and requests pointing at a group
    // nobody can open.
    await _deleteRowsWhere(RobleConfig.groupMembersTable, 'group_id', groupId);
    await _deleteRowsWhere(RobleConfig.groupRequestsTable, 'group_id', groupId);

    await _client.delete(
      tableName: RobleConfig.groupsTable,
      idValue: groupId,
    );
  }

  @override
  Future<void> addMember(GroupMember member) async {
    final group = await getGroupById(member.groupId);

    if (group == null) {
      throw GroupException('El grupo ${member.groupId} ya no existe.');
    }

    if (group.hasMember(member.userId)) return;

    await _addMemberRow(member);
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String userId,
  }) async {
    final rows = await _client.read(
      RobleConfig.groupMembersTable,
      filters: {'group_id': groupId, 'user_id': userId},
    );

    for (final row in rows) {
      final id = row['_id']?.toString();
      if (id == null) continue;

      await _client.delete(
        tableName: RobleConfig.groupMembersTable,
        idValue: id,
      );
    }
  }

  @override
  Future<GroupRequest> createRequest(GroupRequest request) async {
    final Map<String, dynamic> row;

    try {
      row = await _client.insertOne(RobleConfig.groupRequestsTable, {
        'group_id': request.groupId,
        'applicant_id': request.applicantId,
        'applicant_name': request.applicantName,
        'message': request.message,
        'status': request.status.name,
        'created_at': _now(),
      });
    } on RobleException catch (error) {
      if (isDuplicateRow(error)) {
        throw const GroupException('Ya enviaste una solicitud a este grupo.');
      }
      rethrow;
    }

    return request.copyWith(id: row['_id']?.toString() ?? '');
  }

  @override
  Future<List<GroupRequest>> getRequestsForGroup(String groupId) async {
    if (!RobleClient.isRowId(groupId)) return const [];

    final rows = await _client.read(
      RobleConfig.groupRequestsTable,
      filters: {'group_id': groupId},
    );

    // Oldest first: whoever asked earliest is at the top of the queue.
    rows.sort(
      (a, b) => _dateOf(a['created_at']).compareTo(_dateOf(b['created_at'])),
    );

    return rows.map(_requestFrom).whereType<GroupRequest>().toList();
  }

  @override
  Future<List<GroupRequest>> getRequestsByApplicant(String applicantId) async {
    final rows = await _client.read(
      RobleConfig.groupRequestsTable,
      filters: {'applicant_id': applicantId},
    );

    rows.sort(
      (a, b) => _dateOf(b['created_at']).compareTo(_dateOf(a['created_at'])),
    );

    return rows.map(_requestFrom).whereType<GroupRequest>().toList();
  }

  @override
  Future<GroupRequest?> getRequestById(String id) async {
    if (!RobleClient.isRowId(id)) return null;

    final rows = await _client.read(
      RobleConfig.groupRequestsTable,
      filters: {'_id': id},
    );

    return rows.isEmpty ? null : _requestFrom(rows.first);
  }

  @override
  Future<void> updateRequestStatus(
    String requestId,
    GroupRequestStatus status,
  ) async {
    await _client.update(
      tableName: RobleConfig.groupRequestsTable,
      idValue: requestId,
      updates: {'status': status.name},
    );
  }

  // ------------------------------------------------------------- helpers

  Future<void> _addMemberRow(GroupMember member) async {
    try {
      await _client.insertOne(RobleConfig.groupMembersTable, {
        'group_id': member.groupId,
        'user_id': member.userId,
        'user_name': member.userName,
        'joined_at': _now(),
      });
    } on RobleException catch (error) {
      // The composite UNIQUE did its job: they are already in, which is what the
      // caller wanted, so this counts as success.
      if (isDuplicateRow(error)) return;
      rethrow;
    }
  }

  Future<List<GroupMember>> _membersOf(String groupId) async {
    final rows = await _client.read(
      RobleConfig.groupMembersTable,
      filters: {'group_id': groupId},
    );

    return rows.map(_memberFrom).whereType<GroupMember>().toList();
  }

  /// Deletes every row of [tableName] whose [column] equals [value].
  ///
  /// ROBLE deletes by `_id` only, so this is a read followed by one delete per
  /// row. At course scale that is a handful of requests against a budget of 100
  /// per minute.
  Future<void> _deleteRowsWhere(
    String tableName,
    String column,
    String value,
  ) async {
    final rows = await _client.read(tableName, filters: {column: value});

    for (final row in rows) {
      final id = row['_id']?.toString();
      if (id == null || id.isEmpty) continue;

      await _client.delete(tableName: tableName, idValue: id);
    }
  }

  /// Best-effort cleanup: if this fails there is nothing more to try, and the
  /// caller's error is the one worth reporting.
  Future<void> _deleteQuietly(String tableName, String id) async {
    try {
      await _client.delete(tableName: tableName, idValue: id);
    } on RobleException {
      // Ignored on purpose.
    }
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  /// Rows missing their date sort last instead of crashing the list.
  DateTime _dateOf(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  Group? _groupFrom(
    Map<String, dynamic> row,
    Map<String, List<GroupMember>> membersByGroup,
  ) {
    final id = row['_id']?.toString();
    if (id == null || id.isEmpty) return null;

    return Group(
      id: id,
      name: row['name']?.toString() ?? '',
      description: row['description']?.toString() ?? '',
      ownerId: row['owner_id']?.toString() ?? '',
      ownerName: row['owner_name']?.toString() ?? '',
      members: membersByGroup[id] ?? const [],
    );
  }

  GroupMember? _memberFrom(Map<String, dynamic> row) {
    final groupId = row['group_id']?.toString();
    final userId = row['user_id']?.toString();
    if (groupId == null || userId == null) return null;

    return GroupMember(
      id: row['_id']?.toString() ?? '',
      groupId: groupId,
      userId: userId,
      userName: row['user_name']?.toString() ?? 'Estudiante',
    );
  }

  GroupRequest? _requestFrom(Map<String, dynamic> row) {
    final id = row['_id']?.toString();
    final groupId = row['group_id']?.toString();
    if (id == null || id.isEmpty || groupId == null) return null;

    return GroupRequest(
      id: id,
      groupId: groupId,
      applicantId: row['applicant_id']?.toString() ?? '',
      applicantName: row['applicant_name']?.toString() ?? '',
      message: row['message']?.toString() ?? '',
      status: _statusOf(row['status']),
    );
  }

  /// `status` is a plain `text` column holding the enum's name. An unknown value
  /// reads as pending, the state that leaves the request visible and actionable.
  GroupRequestStatus _statusOf(dynamic value) {
    final name = value?.toString();

    return GroupRequestStatus.values.firstWhere(
      (status) => status.name == name,
      orElse: () => GroupRequestStatus.pending,
    );
  }
}
