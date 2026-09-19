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
    );
  }

  /// False while the project exists only on this device.
  bool get isPersisted => id.isNotEmpty;

  int get availableSlots => maxMembers - memberIds.length;

  bool get isFull => availableSlots <= 0;

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
    );
  }
}
