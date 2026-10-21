import 'models/app_notification.dart';
import 'models/notification_target.dart';
import 'models/notification_type.dart';
import 'repositories/i_notification_repository.dart';

/// Turns "something happened" into the notifications that tell the right people,
/// with the wording in one place.
///
/// Every method is **best effort**: a failure to notify is swallowed. The thing
/// that caused the notification — the comment, the acceptance, the invitation —
/// has already been stored by the time this runs, and telling the user "could
/// not publish your comment" because a bell failed to ring would be wrong, and
/// would invite them to post it twice.
class NotificationPublisher {
  final INotificationRepository _repository;

  NotificationPublisher(this._repository);

  /// Someone commented under a project: tells everybody involved in it.
  Future<void> commentAdded({
    required String listingId,
    required String listingTitle,
    required String authorId,
    required String authorName,
    required String comment,
    required Iterable<String> recipientIds,
  }) {
    return _send(
      recipientIds: recipientIds,
      except: authorId,
      build: (recipientId) => AppNotification.draft(
        recipientId: recipientId,
        type: NotificationType.comment,
        title: 'Nuevo comentario en "$listingTitle"',
        body: '$authorName: ${_snippet(comment)}',
        target: NotificationTarget.listing,
        targetId: listingId,
      ),
    );
  }

  /// A group published a project: tells the rest of the group.
  Future<void> ideaPublished({
    required String listingId,
    required String listingTitle,
    required String groupName,
    required String authorId,
    required String authorName,
    required Iterable<String> recipientIds,
  }) {
    return _send(
      recipientIds: recipientIds,
      except: authorId,
      build: (recipientId) => AppNotification.draft(
        recipientId: recipientId,
        type: NotificationType.ideaPublished,
        title: 'Nueva idea en $groupName',
        body: '$authorName publicó "$listingTitle".',
        target: NotificationTarget.listing,
        targetId: listingId,
      ),
    );
  }

  /// Somebody asked to join a project or a group: tells whoever decides.
  Future<void> joinRequestReceived({
    required NotificationTarget target,
    required String targetId,
    required String targetName,
    required String applicantId,
    required String applicantName,
    required String recipientId,
  }) {
    final isGroup = target == NotificationTarget.group;

    return _send(
      recipientIds: [recipientId],
      except: applicantId,
      build: (id) => AppNotification.draft(
        recipientId: id,
        type: NotificationType.requestReceived,
        title: isGroup
            ? 'Nueva solicitud para tu grupo'
            : 'Nueva solicitud para tu proyecto',
        body: '$applicantName quiere unirse a "$targetName".',
        target: target,
        targetId: targetId,
      ),
    );
  }

  /// A request was accepted or rejected: tells the person who made it.
  Future<void> requestResolved({
    required bool accepted,
    required NotificationTarget target,
    required String targetId,
    required String targetName,
    required String deciderId,
    required String applicantId,
  }) {
    final isGroup = target == NotificationTarget.group;
    final place = isGroup ? 'grupo' : 'proyecto';

    return _send(
      recipientIds: [applicantId],
      except: deciderId,
      build: (id) => AppNotification.draft(
        recipientId: id,
        type: accepted
            ? NotificationType.requestAccepted
            : NotificationType.requestRejected,
        title: accepted ? 'Solicitud aceptada' : 'Solicitud rechazada',
        body: accepted
            ? 'Ya haces parte del $place "$targetName".'
            : 'Tu solicitud para unirte al $place "$targetName" fue '
                'rechazada.',
        target: target,
        targetId: targetId,
      ),
    );
  }

  /// A member invited somebody to the group: tells the invited person.
  Future<void> invitationReceived({
    required String groupId,
    required String groupName,
    required String inviterId,
    required String inviterName,
    required String inviteeId,
  }) {
    return _send(
      recipientIds: [inviteeId],
      except: inviterId,
      build: (id) => AppNotification.draft(
        recipientId: id,
        type: NotificationType.invitationReceived,
        title: 'Te invitaron a un grupo',
        body: '$inviterName te invitó a unirte a "$groupName".',
        target: NotificationTarget.group,
        targetId: groupId,
      ),
    );
  }

  /// The invited person answered: tells whoever invited them.
  Future<void> invitationResolved({
    required bool accepted,
    required String groupId,
    required String groupName,
    required String inviteeId,
    required String inviteeName,
    required String inviterId,
  }) {
    return _send(
      recipientIds: [inviterId],
      except: inviteeId,
      build: (id) => AppNotification.draft(
        recipientId: id,
        type: accepted
            ? NotificationType.invitationAccepted
            : NotificationType.invitationRejected,
        title: accepted ? 'Invitación aceptada' : 'Invitación rechazada',
        body: accepted
            ? '$inviteeName aceptó unirse a "$groupName".'
            : '$inviteeName rechazó la invitación a "$groupName".',
        target: NotificationTarget.group,
        targetId: groupId,
      ),
    );
  }

  /// Somebody gave a task to somebody else: tells the person who has it now.
  Future<void> taskAssigned({
    required String listingId,
    required String listingTitle,
    required String taskTitle,
    required String assignerId,
    required String assignerName,
    required String assigneeId,
  }) {
    return _send(
      recipientIds: [assigneeId],
      except: assignerId,
      build: (id) => AppNotification.draft(
        recipientId: id,
        type: NotificationType.taskAssigned,
        title: 'Tienes una tarea nueva',
        body: '$assignerName te asignó "${_snippet(taskTitle)}" en '
            '"$listingTitle".',
        target: NotificationTarget.listing,
        targetId: listingId,
      ),
    );
  }

  /// The leader took somebody off a project's team: tells that person.
  Future<void> memberRemoved({
    required String listingId,
    required String listingTitle,
    required String deciderId,
    required String userId,
  }) {
    return _send(
      recipientIds: [userId],
      except: deciderId,
      build: (id) => AppNotification.draft(
        recipientId: id,
        type: NotificationType.memberRemoved,
        title: 'Ya no estás en un proyecto',
        body: 'El líder te retiró del equipo de "$listingTitle".',
        target: NotificationTarget.listing,
        targetId: listingId,
      ),
    );
  }

  /// Somebody's role on a project changed, leadership included: tells them.
  Future<void> roleChanged({
    required String listingId,
    required String listingTitle,
    required String deciderId,
    required String userId,
    required String roleLabel,
    required bool isLeadership,
  }) {
    return _send(
      recipientIds: [userId],
      except: deciderId,
      build: (id) => AppNotification.draft(
        recipientId: id,
        type: NotificationType.roleChanged,
        title: isLeadership
            ? 'Ahora lideras "$listingTitle"'
            : 'Tu rol cambió en "$listingTitle"',
        body: isLeadership
            ? 'Te transfirieron el liderazgo del proyecto.'
            : 'Ahora eres ${roleLabel.toLowerCase()} del equipo.',
        target: NotificationTarget.listing,
        targetId: listingId,
      ),
    );
  }

  /// A team asked somebody to mentor its project: tells that person.
  Future<void> mentorshipRequested({
    required String listingId,
    required String listingTitle,
    required String requesterId,
    required String requesterName,
    required String mentorId,
  }) {
    return _send(
      recipientIds: [mentorId],
      except: requesterId,
      build: (id) => AppNotification.draft(
        recipientId: id,
        type: NotificationType.mentorshipRequested,
        title: 'Te pidieron ser mentor',
        body: '$requesterName quiere que acompañes el proyecto '
            '"$listingTitle".',
        target: NotificationTarget.listing,
        targetId: listingId,
      ),
    );
  }

  /// The person asked to mentor answered.
  ///
  /// A yes is news for the whole team — somebody new sees their board — so
  /// [recipientIds] is the team. A no only matters to whoever asked, who is the
  /// one to look for somebody else.
  Future<void> mentorshipResolved({
    required bool accepted,
    required String listingId,
    required String listingTitle,
    required String mentorId,
    required String mentorName,
    required Iterable<String> recipientIds,
  }) {
    return _send(
      recipientIds: recipientIds,
      except: mentorId,
      build: (id) => AppNotification.draft(
        recipientId: id,
        type: accepted
            ? NotificationType.mentorshipAccepted
            : NotificationType.mentorshipRejected,
        title: accepted
            ? 'Su proyecto ya tiene mentor'
            : 'Solicitud de mentoría rechazada',
        body: accepted
            ? '$mentorName aceptó acompañar "$listingTitle".'
            : '$mentorName no puede acompañar "$listingTitle" por ahora. '
                'Pueden pedírsela a otra persona.',
        target: NotificationTarget.listing,
        targetId: listingId,
      ),
    );
  }

  Future<void> _send({
    required Iterable<String> recipientIds,
    required String except,
    required AppNotification Function(String recipientId) build,
  }) async {
    try {
      // A set, so somebody who is both the creator and a member of the group is
      // told once, and the author of the event is never told about their own
      // action.
      final recipients = recipientIds
          .where((id) => id.isNotEmpty && id != except)
          .toSet();

      if (recipients.isEmpty) return;

      await _repository.send(recipients.map(build).toList());
    } catch (_) {
      // Best effort; see the class comment.
    }
  }

  /// A comment can be long and a notification is one line.
  String _snippet(String text) {
    final clean = text.trim().replaceAll(RegExp(r'\s+'), ' ');

    return clean.length <= 80 ? clean : '${clean.substring(0, 77)}...';
  }
}
