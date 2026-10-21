/// A team asking somebody outside it — usually a professor — to mentor the
/// project, as a row of `mentorship_requests`.
///
/// The row exists only while the answer is pending. Saying yes makes the person
/// a member of the team with the mentor role, and saying no, withdrawing it or
/// answering it in any other way deletes the row: the notification is the
/// record, the same as with the answered requests of a group.
class MentorshipRequest {
  /// `_id` of the row; empty on a draft.
  final String id;
  final String listingId;

  /// Copied in so the person asked can see which project it is — on their home
  /// screen, in the notification — without reading it.
  final String listingTitle;
  final String requesterId;
  final String requesterName;
  final String mentorId;
  final String mentorName;

  /// What the team needs help with, in the words of whoever asked.
  final String message;
  final DateTime createdAt;

  const MentorshipRequest({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.requesterId,
    required this.requesterName,
    required this.mentorId,
    required this.mentorName,
    required this.message,
    required this.createdAt,
  });

  MentorshipRequest.draft({
    required this.listingId,
    required this.listingTitle,
    required this.requesterId,
    required this.requesterName,
    required this.mentorId,
    required this.mentorName,
    required this.message,
  })  : id = '',
        createdAt = DateTime.now();

  bool get isPersisted => id.isNotEmpty;

  MentorshipRequest copyWith({String? id, String? message, String? listingTitle}) {
    return MentorshipRequest(
      id: id ?? this.id,
      listingId: listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      requesterId: requesterId,
      requesterName: requesterName,
      mentorId: mentorId,
      mentorName: mentorName,
      message: message ?? this.message,
      createdAt: createdAt,
    );
  }
}
