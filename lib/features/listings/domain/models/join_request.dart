import 'join_request_status.dart';

class JoinRequest {
  /// `_id` of the row in `join_requests`; empty on a draft. Strings rather than
  /// ints because ROBLE assigns UUIDs and the app never invents an id.
  final String id;
  final String listingId;
  final String applicantId;
  final String applicantName;
  final String motivation;
  final String skills;
  final String availability;
  final JoinRequestStatus status;

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

  /// A request as the form leaves it: no [id] yet, and pending by definition.
  const JoinRequest.draft({
    required this.listingId,
    required this.applicantId,
    required this.applicantName,
    required this.motivation,
    required this.skills,
    required this.availability,
  })  : id = '',
        status = JoinRequestStatus.pending;

  bool get isPersisted => id.isNotEmpty;

  JoinRequest copyWith({
    String? id,
    String? listingId,
    String? applicantId,
    String? applicantName,
    String? motivation,
    String? skills,
    String? availability,
    JoinRequestStatus? status,
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
