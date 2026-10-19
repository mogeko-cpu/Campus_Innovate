import 'package:campus_innovate/features/groups/data/repositories/group_chat_repository.dart';
import 'package:campus_innovate/features/groups/data/repositories/group_repository.dart';
import 'package:campus_innovate/features/groups/domain/group_exception.dart';
import 'package:campus_innovate/features/groups/domain/models/group_invitation.dart';
import 'package:campus_innovate/features/groups/domain/models/group_message.dart';
import 'package:campus_innovate/features/groups/domain/models/group_request.dart';
import 'package:campus_innovate/features/notifications/data/datasources/i_notification_source.dart';
import 'package:campus_innovate/features/notifications/data/repositories/notification_repository.dart';
import 'package:campus_innovate/features/notifications/domain/models/app_notification.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:campus_innovate/features/notifications/domain/notification_publisher.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_group_chat_source.dart';
import '../../support/in_memory_group_source.dart';
import '../../support/in_memory_notification_source.dart';

/// The rules of requests, invitations, the group chat and notifications, run on
/// the real repositories over in-memory storage. No widgets: these are the rules
/// that were wrong before, and they do not need a screen to be checked.
void main() {
  late InMemoryGroupSource source;
  late GroupRepository groups;

  // The seeded group is `group_1`, owned by `user_1`, who is its only member.
  setUp(() {
    source = InMemoryGroupSource();
    groups = GroupRepository(source);
  });

  GroupRequest requestFrom(String id, String name) => GroupRequest.draft(
        groupId: 'group_1',
        applicantId: id,
        applicantName: name,
        message: 'Quiero entrar',
      );

  GroupInvitation invitationFor(
    String id,
    String name, {
    String inviterId = 'user_1',
  }) =>
      GroupInvitation.draft(
        groupId: 'group_1',
        groupName: 'Innovación UN',
        inviterId: inviterId,
        inviterName: 'Leonel Triana',
        inviteeId: id,
        inviteeName: name,
      );

  group('answering a request', () {
    test('accepting adds the member and removes the request', () async {
      final sent = await groups.requestToJoin(
        requestFrom('user_2', 'Mariana Ospina'),
      );

      final answered = await groups.acceptRequest(sent.id);

      expect(answered.applicantId, 'user_2');
      expect((await groups.getGroupById('group_1'))!.hasMember('user_2'), true);
      expect(await groups.getRequestsForGroup('group_1'), isEmpty);
      expect(
        await groups.getMyRequestForGroup(
          groupId: 'group_1',
          applicantId: 'user_2',
        ),
        isNull,
      );
    });

    test('rejecting removes the request and adds nobody', () async {
      final sent = await groups.requestToJoin(
        requestFrom('user_2', 'Mariana Ospina'),
      );

      await groups.rejectRequest(sent.id);

      expect((await groups.getGroupById('group_1'))!.hasMember('user_2'), false);
      expect(await groups.getRequestsForGroup('group_1'), isEmpty);
    });

    test('after a rejection the person can ask again', () async {
      final first = await groups.requestToJoin(
        requestFrom('user_2', 'Mariana Ospina'),
      );
      await groups.rejectRequest(first.id);

      final second = await groups.requestToJoin(
        requestFrom('user_2', 'Mariana Ospina'),
      );

      expect(second.id, isNotEmpty);
      expect(await groups.getRequestsForGroup('group_1'), hasLength(1));
    });

    test('asking twice while the first one waits is refused', () async {
      await groups.requestToJoin(requestFrom('user_2', 'Mariana Ospina'));

      expect(
        groups.requestToJoin(requestFrom('user_2', 'Mariana Ospina')),
        throwsA(isA<GroupException>()),
      );
    });
  });

  group('invitations', () {
    test('a member can invite somebody outside the group', () async {
      final sent = await groups.inviteUser(
        invitationFor('user_2', 'Mariana Ospina'),
      );

      expect(sent.id, isNotEmpty);
      expect(await groups.getInvitationsForGroup('group_1'), hasLength(1));
      expect(await groups.getMyInvitations('user_2'), hasLength(1));
      expect(await groups.getMyInvitations('user_1'), isEmpty);
    });

    test('somebody outside the group cannot invite', () async {
      expect(
        groups.inviteUser(
          invitationFor('user_2', 'Mariana Ospina', inviterId: 'user_3'),
        ),
        throwsA(isA<GroupException>()),
      );
    });

    test('somebody already inside cannot be invited', () async {
      expect(
        groups.inviteUser(invitationFor('user_1', 'Leonel Triana')),
        throwsA(isA<GroupException>()),
      );
    });

    test('the same person cannot be invited twice', () async {
      await groups.inviteUser(invitationFor('user_2', 'Mariana Ospina'));

      expect(
        groups.inviteUser(invitationFor('user_2', 'Mariana Ospina')),
        throwsA(isA<GroupException>()),
      );
    });

    test('somebody whose request is waiting cannot be invited', () async {
      await groups.requestToJoin(requestFrom('user_2', 'Mariana Ospina'));

      expect(
        groups.inviteUser(invitationFor('user_2', 'Mariana Ospina')),
        throwsA(isA<GroupException>()),
      );
    });

    test('somebody who was invited cannot also ask to join', () async {
      await groups.inviteUser(invitationFor('user_2', 'Mariana Ospina'));

      expect(
        groups.requestToJoin(requestFrom('user_2', 'Mariana Ospina')),
        throwsA(isA<GroupException>()),
      );
    });

    test('accepting joins the group and removes the invitation', () async {
      final sent = await groups.inviteUser(
        invitationFor('user_2', 'Mariana Ospina'),
      );

      final answered = await groups.acceptInvitation(sent.id);

      expect(answered.inviterId, 'user_1');
      expect((await groups.getGroupById('group_1'))!.hasMember('user_2'), true);
      expect(await groups.getMyInvitations('user_2'), isEmpty);
    });

    test('rejecting removes the invitation and adds nobody', () async {
      final sent = await groups.inviteUser(
        invitationFor('user_2', 'Mariana Ospina'),
      );

      await groups.rejectInvitation(sent.id);

      expect((await groups.getGroupById('group_1'))!.hasMember('user_2'), false);
      expect(await groups.getMyInvitations('user_2'), isEmpty);
    });

    test('after rejecting, the person can be invited again', () async {
      final first = await groups.inviteUser(
        invitationFor('user_2', 'Mariana Ospina'),
      );
      await groups.rejectInvitation(first.id);

      final second = await groups.inviteUser(
        invitationFor('user_2', 'Mariana Ospina'),
      );

      expect(second.id, isNotEmpty);
    });

    test('a new member can invite somebody else', () async {
      final sent = await groups.inviteUser(
        invitationFor('user_2', 'Mariana Ospina'),
      );
      await groups.acceptInvitation(sent.id);

      final next = await groups.inviteUser(
        invitationFor('user_3', 'Camilo Pérez', inviterId: 'user_2'),
      );

      expect(next.id, isNotEmpty);
    });
  });

  group('the group chat', () {
    late GroupChatRepository chat;

    setUp(() {
      chat = GroupChatRepository(InMemoryGroupChatSource(), groups);
    });

    GroupMessage lineFrom(String id, String body) => GroupMessage.draft(
          groupId: 'group_1',
          senderId: id,
          senderName: 'Alguien',
          body: body,
        );

    test('a member can send and read', () async {
      final stored = await chat.send(lineFrom('user_1', '  Hola equipo  '));

      expect(stored.id, isNotEmpty);

      final messages = await chat.getMessages(
        groupId: 'group_1',
        userId: 'user_1',
      );

      expect(messages, hasLength(1));
      expect(messages.single.body, 'Hola equipo');
    });

    test('somebody outside the group can neither send nor read', () async {
      expect(
        chat.send(lineFrom('user_2', 'Hola')),
        throwsA(isA<GroupException>()),
      );
      expect(
        chat.getMessages(groupId: 'group_1', userId: 'user_2'),
        throwsA(isA<GroupException>()),
      );
    });

    test('an empty line is refused', () async {
      expect(
        chat.send(lineFrom('user_1', '   ')),
        throwsA(isA<GroupException>()),
      );
    });

    test('a line over the limit is refused', () async {
      expect(
        chat.send(lineFrom('user_1', 'a' * (GroupChatRepository.maxLength + 1))),
        throwsA(isA<GroupException>()),
      );
    });
  });

  group('notifications', () {
    test('a comment tells everybody involved except its author', () async {
      final store = InMemoryNotificationSource();
      final publisher = NotificationPublisher(NotificationRepository(store));

      await publisher.commentAdded(
        listingId: 'listing_1',
        listingTitle: 'Semillero de Robótica',
        authorId: 'user_1',
        authorName: 'Leonel Triana',
        comment: 'Muy buena idea',
        // The author, a repeated person and an empty id: only user_2 is left.
        recipientIds: ['user_1', 'user_2', 'user_2', ''],
      );

      expect(store.all, hasLength(1));
      expect(store.all.single.recipientId, 'user_2');
      expect(store.all.single.type, NotificationType.comment);
      expect(store.all.single.target, NotificationTarget.listing);
      expect(store.all.single.targetId, 'listing_1');
      expect(store.all.single.isRead, false);
    });

    test('an answered request tells the applicant, not the decider', () async {
      final store = InMemoryNotificationSource();
      final publisher = NotificationPublisher(NotificationRepository(store));

      await publisher.requestResolved(
        accepted: true,
        target: NotificationTarget.group,
        targetId: 'group_1',
        targetName: 'Innovación UN',
        deciderId: 'user_1',
        applicantId: 'user_2',
      );
      await publisher.requestResolved(
        accepted: false,
        target: NotificationTarget.group,
        targetId: 'group_1',
        targetName: 'Innovación UN',
        deciderId: 'user_1',
        applicantId: 'user_3',
      );

      expect(
        store.all.map((n) => (n.recipientId, n.type)).toList(),
        [
          ('user_2', NotificationType.requestAccepted),
          ('user_3', NotificationType.requestRejected),
        ],
      );
    });

    test('marking all as read leaves nothing unread', () async {
      final store = InMemoryNotificationSource();
      final repository = NotificationRepository(store);
      final publisher = NotificationPublisher(repository);

      await publisher.invitationReceived(
        groupId: 'group_1',
        groupName: 'Innovación UN',
        inviterId: 'user_1',
        inviterName: 'Leonel Triana',
        inviteeId: 'user_2',
      );

      expect(
        (await repository.getMine('user_2')).where((n) => !n.isRead),
        hasLength(1),
      );

      await repository.markAllRead('user_2');

      expect(
        (await repository.getMine('user_2')).where((n) => !n.isRead),
        isEmpty,
      );
    });

    test('a failing store never makes the publisher throw', () async {
      final publisher = NotificationPublisher(
        NotificationRepository(_BrokenSource()),
      );

      await expectLater(
        publisher.commentAdded(
          listingId: 'listing_1',
          listingTitle: 'Robot',
          authorId: 'user_1',
          authorName: 'Leonel',
          comment: 'Hola',
          recipientIds: ['user_2'],
        ),
        completes,
      );
    });
  });
}

/// A source that fails on every write, to prove that failing to notify cannot
/// break the action that caused the notification.
class _BrokenSource implements INotificationSource {
  @override
  Future<List<AppNotification>> getForRecipient(String userId) async =>
      throw StateError('sin conexión');

  @override
  Future<void> insertAll(List<AppNotification> notifications) async =>
      throw StateError('sin conexión');

  @override
  Future<void> markRead(String notificationId) async =>
      throw StateError('sin conexión');
}
