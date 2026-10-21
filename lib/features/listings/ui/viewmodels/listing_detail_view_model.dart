import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../../groups/domain/repositories/i_group_repository.dart';
import '../../../notifications/domain/notification_publisher.dart';
import '../../../users/domain/models/app_user.dart';
import '../../../users/domain/repositories/i_user_repository.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_comment.dart';
import '../../domain/models/listing_member.dart';
import '../../domain/models/listing_role.dart';
import '../../domain/models/listing_stats.dart';
import '../../domain/models/listing_task.dart';
import '../../domain/models/mentorship_request.dart';
import '../../domain/models/reaction_type.dart';
import '../../domain/repositories/i_engagement_repository.dart';
import '../../domain/repositories/i_listing_repository.dart';
import '../../domain/repositories/i_mentorship_repository.dart';
import '../../domain/repositories/i_project_file_repository.dart';
import '../../domain/repositories/i_task_repository.dart';

class ListingDetailViewModel extends GetxController {
  final IListingRepository _repository;
  final IEngagementRepository _engagement;
  final IGroupRepository _groups;
  final NotificationPublisher _notifier;
  final ISessionService _session;
  final ITaskRepository _tasks;
  final IProjectFileRepository _files;
  final IMentorshipRepository _mentorships;
  final IUserRepository _users;

  ListingDetailViewModel(
    this._repository,
    this._engagement,
    this._groups,
    this._notifier,
    this._session,
    this._tasks,
    this._files,
    this._mentorships,
    this._users,
  );

  final Rxn<Listing> listing = Rxn<Listing>();
  final Rxn<JoinRequest> myRequest = Rxn<JoinRequest>();
  final Rx<ListingStats> stats = ListingStats.empty.obs;
  final RxList<ListingComment> comments = <ListingComment>[].obs;

  /// How far along the board is. Null when it could not be read: the board is a
  /// part of the project, and failing to count its cards must not take the rest
  /// of the screen down with it.
  final Rxn<TaskProgress> progress = Rxn<TaskProgress>();

  /// How many files and links the team shares. Null when it could not be read,
  /// for the same reason as [progress].
  final RxnInt fileCount = RxnInt();

  /// The mentorship this project is waiting on, if somebody asked for one. Read
  /// for everybody: the team sees it waiting, and the person asked answers it
  /// from here.
  final Rxn<MentorshipRequest> mentorshipRequest = Rxn<MentorshipRequest>();
  final RxBool isLoading = false.obs;

  /// Goes up after every load, so what hangs off the project — the creator's
  /// inbox — knows to read again. A load can finish within a frame, too fast
  /// for the screen to swap in a spinner and rebuild those parts by itself.
  final RxInt revision = 0.obs;

  /// True while a vote, a comment or a deletion is being written, so a double
  /// tap cannot send two opposite writes.
  final RxBool isWorking = false.obs;
  final RxnString error = RxnString();

  /// The `_id` of the project, straight out of the route. Not parsed: it is a
  /// UUID, and the source treats anything that is not one as "not found".
  late final String listingId;

  /// Whether this screen already counted a visit in this session, so coming back
  /// from the join form does not try to write the row again.
  bool _viewRegistered = false;

  @override
  void onInit() {
    super.onInit();
    listingId = Get.parameters['id'] ?? '';
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      error.value = null;

      final found = await _repository.getListingById(listingId);

      if (found == null) {
        error.value = 'Proyecto no encontrado';
        return;
      }

      listing.value = found;
      myRequest.value = await _repository.getMyRequestForListing(
        listingId: listingId,
        applicantId: _session.currentUserId,
      );

      // Opening the project is what counts as a visit, and it has to happen
      // before the counters are read or the number would be one behind.
      await _registerView(found);

      stats.value = await _engagement.getStatsFor(
        listingId: listingId,
        userId: _session.currentUserId,
      );
      comments.assignAll(await _engagement.getComments(listingId));
      await _loadProgress();
      await _loadTeamSpace(found);
      revision.value++;
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo cargar el proyecto',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadProgress() async {
    try {
      progress.value = await _tasks.progressOf(listingId);
    } catch (_) {
      progress.value = null;
    }
  }

  /// The team's files and the mentorship, each one best effort: what the
  /// project is must still show when a part of what hangs off it cannot be
  /// read — the tables not created yet, a dropped request.
  Future<void> _loadTeamSpace(Listing found) async {
    if (found.roleOf(_session.currentUserId) != null) {
      try {
        fileCount.value = (await _files.getFiles(listingId)).length;
      } catch (_) {
        fileCount.value = null;
      }
    }

    try {
      mentorshipRequest.value = await _mentorships.getPendingFor(listingId);
    } catch (_) {
      mentorshipRequest.value = null;
    }
  }

  String get currentUserId => _session.currentUserId;

  /// Somebody this project asked to mentor it, who has not answered yet.
  bool get isInvitedMentor =>
      myRole == null &&
      mentorshipRequest.value?.mentorId == _session.currentUserId;

  /// Whoever works the project may look for a mentor, while it has none and
  /// nobody has been asked yet.
  bool get canRequestMentorship =>
      (myRole?.canWorkTasks ?? false) &&
      !(listing.value?.hasMentor ?? true) &&
      mentorshipRequest.value == null;

  /// Whoever sent the request, or the leader.
  bool get canCancelMentorship {
    final request = mentorshipRequest.value;
    if (request == null) return false;

    return request.requesterId == _session.currentUserId || isLeader;
  }

  /// People who could mentor the project: everybody in the directory who is
  /// not already on its team.
  Future<List<AppUser>> mentorCandidates() async {
    final current = listing.value;
    if (current == null) return const [];

    final everybody = await _users.getUsers();

    return everybody
        .where((user) => current.roleOf(user.id) == null)
        .toList();
  }

  Future<bool> requestMentorship(AppUser mentor, String message) async {
    final current = listing.value;
    if (current == null) return false;

    MentorshipRequest? stored;

    final done = await _teamWrite(
      fallback: 'No se pudo enviar la solicitud de mentoría',
      action: () async {
        stored = await _mentorships.request(
          MentorshipRequest.draft(
            listingId: current.id,
            listingTitle: current.title,
            requesterId: _session.currentUserId,
            requesterName: _session.currentUserName,
            mentorId: mentor.id,
            mentorName: mentor.name,
            message: message,
          ),
        );

        mentorshipRequest.value = stored;
      },
    );

    if (done) {
      await _notifier.mentorshipRequested(
        listingId: current.id,
        listingTitle: current.title,
        requesterId: _session.currentUserId,
        requesterName: _session.currentUserName,
        mentorId: stored!.mentorId,
      );
    }

    return done;
  }

  Future<bool> cancelMentorshipRequest() async {
    final request = mentorshipRequest.value;
    if (request == null) return false;

    return _teamWrite(
      fallback: 'No se pudo cancelar la solicitud',
      action: () async {
        await _mentorships.cancel(
          requestId: request.id,
          actorId: _session.currentUserId,
        );

        mentorshipRequest.value = null;
      },
    );
  }

  /// The person asked says yes and joins the team as its mentor; the whole team
  /// hears about it, since somebody new now sees their board.
  Future<bool> acceptMentorship() async {
    final request = mentorshipRequest.value;
    if (request == null) return false;

    final done = await _teamWrite(
      fallback: 'No se pudo aceptar la mentoría',
      action: () async {
        await _mentorships.accept(
          requestId: request.id,
          actorId: _session.currentUserId,
        );

        mentorshipRequest.value = null;
      },
    );

    if (!done) return false;

    // On the team now: what only the team sees can be read.
    final joined = listing.value;
    if (joined != null) {
      await _loadProgress();
      await _loadTeamSpace(joined);
    }

    await _notifier.mentorshipResolved(
      accepted: true,
      listingId: request.listingId,
      listingTitle: request.listingTitle,
      mentorId: _session.currentUserId,
      mentorName: _session.currentUserName,
      recipientIds: joined?.memberIds ?? [request.requesterId],
    );

    return true;
  }

  Future<bool> rejectMentorship() async {
    final request = mentorshipRequest.value;
    if (request == null) return false;

    final done = await _teamWrite(
      fallback: 'No se pudo rechazar la mentoría',
      action: () async {
        await _mentorships.reject(
          requestId: request.id,
          actorId: _session.currentUserId,
        );

        mentorshipRequest.value = null;
      },
    );

    if (done) {
      await _notifier.mentorshipResolved(
        accepted: false,
        listingId: request.listingId,
        listingTitle: request.listingTitle,
        mentorId: _session.currentUserId,
        mentorName: _session.currentUserName,
        recipientIds: [request.requesterId],
      );
    }

    return done;
  }

  bool get isCreator => listing.value?.creatorId == _session.currentUserId;

  bool get isMember =>
      listing.value?.memberIds.contains(_session.currentUserId) ?? false;

  /// What this person is to the team; null when they are not on it.
  ListingRole? get myRole => listing.value?.roleOf(_session.currentUserId);

  /// The leader runs the project: edits it, answers requests, manages the team
  /// and deletes it. Whoever published it leads until they hand it over.
  bool get isLeader => myRole == ListingRole.leader;

  List<ListingMember> get team => listing.value?.team ?? const [];

  bool get canRequestToJoin =>
      listing.value != null &&
      !isCreator &&
      !isMember &&
      listing.value!.isRecruiting &&
      myRequest.value == null;

  /// Applies a tap on like or dislike.
  ///
  /// The repository decides what the tap means — pressing the button you already
  /// pressed takes the vote back — and the counters are read again afterwards
  /// rather than guessed, so what the screen shows is what the database holds.
  Future<void> react(ReactionType reaction) async {
    final current = listing.value;
    if (current == null || isWorking.value) return;

    try {
      isWorking.value = true;
      error.value = null;

      await _engagement.toggleReaction(
        listingId: current.id,
        groupId: current.groupId,
        userId: _session.currentUserId,
        reaction: reaction,
        current: stats.value.myReaction,
      );

      stats.value = await _engagement.getStatsFor(
        listingId: current.id,
        userId: _session.currentUserId,
      );
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo registrar tu valoración',
      );
    } finally {
      isWorking.value = false;
    }
  }

  Future<bool> comment(String body) async {
    final current = listing.value;
    if (current == null || isWorking.value) return false;

    try {
      isWorking.value = true;
      error.value = null;

      final stored = await _engagement.addComment(
        ListingComment.draft(
          listingId: current.id,
          // The comment is filed under the project's group, which is what keeps
          // the conversation of one group from ever being counted for another.
          groupId: current.groupId,
          authorId: _session.currentUserId,
          authorName: _session.currentUserName,
          body: body,
        ),
      );

      comments.insert(0, stored);
      stats.value = stats.value.copyWith(comments: stats.value.comments + 1);

      await _notifyComment(current, body);

      return true;
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo publicar tu comentario',
      );

      return false;
    } finally {
      isWorking.value = false;
    }
  }

  /// Tells everybody involved in the project: its creator, its team, and the
  /// members of the group that published it.
  ///
  /// Reading the group can fail, and that must not turn a comment that was
  /// stored into an error: without it, the creator and the team are still told.
  Future<void> _notifyComment(Listing current, String body) async {
    final recipients = <String>{current.creatorId, ...current.memberIds};

    if (current.belongsToGroup) {
      try {
        final group = await _groups.getGroupById(current.groupId);

        if (group != null) recipients.addAll(group.memberIds);
      } catch (_) {
        // See above.
      }
    }

    await _notifier.commentAdded(
      listingId: current.id,
      listingTitle: current.title,
      authorId: _session.currentUserId,
      authorName: _session.currentUserName,
      comment: body,
      recipientIds: recipients,
    );
  }

  /// Only the author of a comment can remove it — the project's creator does not
  /// get to edit what people said about the project.
  bool canDeleteComment(ListingComment comment) =>
      comment.authorId == _session.currentUserId;

  Future<void> deleteComment(String commentId) async {
    if (isWorking.value) return;

    try {
      isWorking.value = true;
      error.value = null;

      await _engagement.deleteComment(commentId);

      comments.removeWhere((comment) => comment.id == commentId);
      stats.value = stats.value.copyWith(
        comments: stats.value.comments > 0 ? stats.value.comments - 1 : 0,
      );
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo eliminar el comentario',
      );
    } finally {
      isWorking.value = false;
    }
  }

  /// Deletes the project and everything hanging off it.
  ///
  /// The likes, views, comments and tasks go first: if the run stops halfway the
  /// project is still there and the leader can try again, whereas deleting the
  /// project first would leave rows nobody could reach or clean up.
  Future<bool> deleteListing() async {
    if (!isLeader) {
      error.value = 'Solo el líder del proyecto puede eliminarlo.';
      return false;
    }

    if (isWorking.value) return false;

    try {
      isWorking.value = true;
      error.value = null;

      await _engagement.purgeListing(listingId);
      await _tasks.purgeListing(listingId);
      await _files.purgeListing(listingId, actorId: _session.currentUserId);
      await _mentorships.purgeListing(listingId);
      await _repository.deleteListing(listingId);

      return true;
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo eliminar el proyecto',
      );

      return false;
    } finally {
      isWorking.value = false;
    }
  }

  /// The leader takes somebody off the team. Their tasks are left without
  /// anybody rather than with a person who can no longer see the board.
  Future<bool> removeMember(ListingMember member) async {
    final current = listing.value;
    if (current == null) return false;

    final done = await _teamWrite(
      fallback: 'No se pudo quitar a la persona del equipo',
      action: () => _repository.removeMember(
        listingId: listingId,
        userId: member.userId,
        actorId: _session.currentUserId,
      ),
    );

    if (done) {
      await _freeTasksOf(member.userId);
      await _notifier.memberRemoved(
        listingId: current.id,
        listingTitle: current.title,
        deciderId: _session.currentUserId,
        userId: member.userId,
      );
    }

    return done;
  }

  /// This person leaves the team by their own decision.
  Future<bool> leave() async {
    final done = await _teamWrite(
      fallback: 'No se pudo salir del proyecto',
      action: () => _repository.leaveListing(
        listingId: listingId,
        userId: _session.currentUserId,
      ),
    );

    if (done) await _freeTasksOf(_session.currentUserId);

    return done;
  }

  /// Member or mentor; leadership goes through [transferLeadership].
  Future<bool> setRole(ListingMember member, ListingRole role) async {
    final current = listing.value;
    if (current == null || member.role == role) return false;

    final done = await _teamWrite(
      fallback: 'No se pudo cambiar el rol',
      action: () => _repository.setMemberRole(
        listingId: listingId,
        userId: member.userId,
        role: role,
        actorId: _session.currentUserId,
      ),
    );

    if (done) {
      await _notifier.roleChanged(
        listingId: current.id,
        listingTitle: current.title,
        deciderId: _session.currentUserId,
        userId: member.userId,
        roleLabel: role.label,
        isLeadership: false,
      );
    }

    return done;
  }

  Future<bool> transferLeadership(ListingMember member) async {
    final current = listing.value;
    if (current == null) return false;

    final done = await _teamWrite(
      fallback: 'No se pudo transferir el liderazgo',
      action: () => _repository.transferLeadership(
        listingId: listingId,
        newLeaderId: member.userId,
        actorId: _session.currentUserId,
      ),
    );

    if (done) {
      await _notifier.roleChanged(
        listingId: current.id,
        listingTitle: current.title,
        deciderId: _session.currentUserId,
        userId: member.userId,
        roleLabel: ListingRole.leader.label,
        isLeadership: true,
      );
    }

    return done;
  }

  /// Best effort: the person is already off the team, and a task still showing
  /// their name is something the leader can fix on the board.
  Future<void> _freeTasksOf(String userId) async {
    try {
      await _tasks.unassignAll(listingId: listingId, userId: userId);
    } catch (_) {
      // See above.
    }
  }

  /// Runs a team change with the working flag and the error message, then reads
  /// the project again so the list shows what the table holds.
  Future<bool> _teamWrite({
    required Future<void> Function() action,
    required String fallback,
  }) async {
    if (isWorking.value) return false;

    try {
      isWorking.value = true;
      error.value = null;

      await action();

      listing.value = await _repository.getListingById(listingId);

      return true;
    } catch (failure) {
      error.value = errorMessage(failure, fallback: fallback);

      return false;
    } finally {
      isWorking.value = false;
    }
  }

  /// A visit is a side effect of opening a screen, so a failure here must never
  /// turn into an error in front of the user: the project loaded fine.
  Future<void> _registerView(Listing found) async {
    if (_viewRegistered) return;
    _viewRegistered = true;

    try {
      await _engagement.registerView(
        listingId: found.id,
        groupId: found.groupId,
        userId: _session.currentUserId,
      );
    } catch (_) {
      // Ignored on purpose.
    }
  }
}
