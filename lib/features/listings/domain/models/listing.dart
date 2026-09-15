class Listing {
  final int id;
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

  Listing copyWith({
    int? id,
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