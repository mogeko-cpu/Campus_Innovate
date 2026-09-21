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
    );
  }

  /// False while the project exists only on this device.
  bool get isPersisted => id.isNotEmpty;

  int get availableSlots => maxMembers - memberIds.length;

  bool get isFull => availableSlots <= 0;

  /// False for the projects that predate groups. Screens fall back to "Sin
  /// grupo" instead of hiding them: an old row is still a real project.
  bool get belongsToGroup => groupId.isNotEmpty;

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
    );
  }
}
