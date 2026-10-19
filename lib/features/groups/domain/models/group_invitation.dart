/// A member of a group asking somebody outside it to join.
///
/// The mirror image of a request: a request is somebody asking to get in and the
/// owner deciding; an invitation is a member asking somebody to come in and that
/// person deciding.
///
/// A row exists only while it is waiting. Once answered it is deleted, and what
/// happened is carried by the notification sent to whoever invited. That is what
/// stops an answered invitation from sitting on the screen, and lets somebody
/// who declined be invited again later. `UNIQUE (group_id, invitee_id)` keeps two
/// members from inviting the same person at once.
class GroupInvitation {
  /// `_id` of the row in `group_invitations`; empty on a draft.
  final String id;
  final String groupId;

  /// Copied in so the invitee's list can say which group without a read per
  /// invitation — ROBLE offers no join.
  final String groupName;
  final String inviterId;
  final String inviterName;
  final String inviteeId;
  final String inviteeName;

  const GroupInvitation({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.inviterId,
    required this.inviterName,
    required this.inviteeId,
    required this.inviteeName,
  });

  const GroupInvitation.draft({
    required this.groupId,
    required this.groupName,
    required this.inviterId,
    required this.inviterName,
    required this.inviteeId,
    required this.inviteeName,
  }) : id = '';

  bool get isPersisted => id.isNotEmpty;

  GroupInvitation copyWith({String? id}) {
    return GroupInvitation(
      id: id ?? this.id,
      groupId: groupId,
      groupName: groupName,
      inviterId: inviterId,
      inviterName: inviterName,
      inviteeId: inviteeId,
      inviteeName: inviteeName,
    );
  }
}
