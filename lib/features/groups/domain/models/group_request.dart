import 'group_request_status.dart';

/// Someone asking to be let into a group.
///
/// `UNIQUE (group_id, applicant_id)` in the table is what makes a second request
/// impossible; the screen also checks, but that check can go stale between the
/// read and the write and the constraint cannot.
class GroupRequest {
  /// `_id` of the row in `group_requests`; empty on a draft.
  final String id;
  final String groupId;
  final String applicantId;
  final String applicantName;
  final String message;
  final GroupRequestStatus status;

  const GroupRequest({
    required this.id,
    required this.groupId,
    required this.applicantId,
    required this.applicantName,
    required this.message,
    required this.status,
  });

  /// A request as the form leaves it: no [id] yet, and pending by definition.
  const GroupRequest.draft({
    required this.groupId,
    required this.applicantId,
    required this.applicantName,
    required this.message,
  })  : id = '',
        status = GroupRequestStatus.pending;

  bool get isPersisted => id.isNotEmpty;

  bool get isPending => status == GroupRequestStatus.pending;

  GroupRequest copyWith({
    String? id,
    String? groupId,
    String? applicantId,
    String? applicantName,
    String? message,
    GroupRequestStatus? status,
  }) {
    return GroupRequest(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      applicantId: applicantId ?? this.applicantId,
      applicantName: applicantName ?? this.applicantName,
      message: message ?? this.message,
      status: status ?? this.status,
    );
  }
}
