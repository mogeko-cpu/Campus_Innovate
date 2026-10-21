import 'listing_member.dart';
import 'listing_role.dart';
import 'listing_status.dart';

class Listing {
  /// Identity assigned by the database.
  ///
  /// It is the `_id` UUID of the row, a [String] and not an [int], because the
  /// app no longer invents ids: only ROBLE can, and it must do so before any
  /// member or request can point at the project. Empty on a draft that has not
  /// been saved yet — see [Listing.draft].
  final String id;
  final String title;
  final String description;
  final String category;
  final String creatorId;
  final String creatorName;
  final int maxMembers;
  final List<String> requiredSkills;
  final List<String> memberIds;

  /// The group that owns the project, or empty for the projects published
  /// before groups existed.
  ///
  /// Every like, view and comment is filed under this same id, which is what
  /// keeps the activity of one group from ever being counted for another.
  final String groupId;

  /// Name of that group, copied in when the row is written so a card can show
  /// it without a second read — ROBLE offers no join.
  final String groupName;

  /// Where the project stands. Only [ListingStatus.acceptsRequests] states take
  /// new people.
  final ListingStatus status;

  /// Name and role of each person in [memberIds], as far as the rows say.
  ///
  /// [memberIds] stays the one answer to "who is in": this only adds what each
  /// of them is. Somebody listed there without an entry here — every member
  /// written before roles existed — is described by [team] from what is known.
  final List<ListingMember> members;

  const Listing({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.creatorId,
    required this.creatorName,
    required this.maxMembers,
    required this.requiredSkills,
    required this.memberIds,
    this.groupId = '',
    this.groupName = '',
    this.status = ListingStatus.idea,
    this.members = const [],
  });

  /// A project filled in by the user but not yet stored, so without an [id].
  ///
  /// The creator is already its first member, which is what leaves a new project
  /// showing "1 de N integrantes" the moment it is published.
  factory Listing.draft({
    required String title,
    required String description,
    required String category,
    required String creatorId,
    required String creatorName,
    required int maxMembers,
    required List<String> requiredSkills,
    String groupId = '',
    String groupName = '',
  }) {
    return Listing(
      id: '',
      title: title,
      description: description,
      category: category,
      creatorId: creatorId,
      creatorName: creatorName,
      maxMembers: maxMembers,
      requiredSkills: requiredSkills,
      memberIds: [creatorId],
      groupId: groupId,
      groupName: groupName,
      members: [
        ListingMember(
          userId: creatorId,
          userName: creatorName,
          role: ListingRole.leader,
        ),
      ],
    );
  }

  /// False while the project exists only on this device.
  bool get isPersisted => id.isNotEmpty;

  /// The people who take a place on the team: everybody but the mentors, who
  /// follow and advise without being one of the [maxMembers]. A professor asked
  /// to mentor a full team still gets in, and nobody loses a seat for it.
  int get memberCount =>
      team.where((member) => member.role != ListingRole.mentor).length;

  int get availableSlots => maxMembers - memberCount;

  /// The mentors on the team; usually none or one.
  List<ListingMember> get mentors =>
      team.where((member) => member.role == ListingRole.mentor).toList();

  bool get hasMentor => team.any((member) => member.role == ListingRole.mentor);

  bool get isFull => availableSlots <= 0;

  /// False for the projects that predate groups. Screens fall back to "Sin
  /// grupo" instead of hiding them: an old row is still a real project.
  bool get belongsToGroup => groupId.isNotEmpty;

  /// Whether somebody new can ask to join: the project is looking for people
  /// and there is room.
  bool get isRecruiting => status.acceptsRequests && !isFull;

  /// Everybody in [memberIds], in that order, with a name and a role.
  ///
  /// A member with no row details is the creator — who leads unless somebody
  /// else was explicitly made leader — or a plain member. That is what keeps the
  /// projects published before roles working without a migration of their rows.
  List<ListingMember> get team {
    final known = {for (final member in members) member.userId: member};
    final someoneLeads = members.any(
      (member) =>
          member.role == ListingRole.leader &&
          memberIds.contains(member.userId),
    );

    return [
      for (final id in memberIds)
        known[id] ??
            ListingMember(
              userId: id,
              userName: id == creatorId ? creatorName : '',
              role: id == creatorId && !someoneLeads
                  ? ListingRole.leader
                  : ListingRole.member,
            ),
    ];
  }

  /// Null for somebody outside the team.
  ListingRole? roleOf(String userId) {
    for (final member in team) {
      if (member.userId == userId) return member.role;
    }

    return null;
  }

  bool isLeader(String userId) => roleOf(userId) == ListingRole.leader;

  /// Who runs the project. The creator when the team says nothing else.
  String get leaderId {
    for (final member in team) {
      if (member.role == ListingRole.leader) return member.userId;
    }

    return creatorId;
  }

  Listing copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? creatorId,
    String? creatorName,
    int? maxMembers,
    List<String>? requiredSkills,
    List<String>? memberIds,
    String? groupId,
    String? groupName,
    ListingStatus? status,
    List<ListingMember>? members,
  }) {
    return Listing(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      maxMembers: maxMembers ?? this.maxMembers,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      memberIds: memberIds ?? this.memberIds,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      status: status ?? this.status,
      members: members ?? this.members,
    );
  }
}
