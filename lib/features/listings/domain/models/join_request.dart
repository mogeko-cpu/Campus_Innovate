class JoinRequest {
  final int id;
  final int listingId;
  final String applicantId;
  final String applicantName;
  final String motivation;
  final String skills;
  final String availability;
  final String status;

  const JoinRequest({
    required this.id,
    required this.listingId,
    required this.applicantId,
    required this.applicantName,
    required this.motivation,
    required this.skills,
    required this.availability,
    required this.status,
  });

  JoinRequest copyWith({
    int? id,
    int? listingId,
    String? applicantId,
    String? applicantName,
    String? motivation,
    String? skills,
    String? availability,
    String? status,
  }) {
    return JoinRequest(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      applicantId: applicantId ?? this.applicantId,
      applicantName: applicantName ?? this.applicantName,
      motivation: motivation ?? this.motivation,
      skills: skills ?? this.skills,
      availability: availability ?? this.availability,
      status: status ?? this.status,
    );
  }
}