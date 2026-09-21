import 'package:get/get.dart';

import '../../../../core/error_message.dart';
import '../../../../core/i_session_service.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_comment.dart';
import '../../domain/models/listing_stats.dart';
import '../../domain/models/reaction_type.dart';
import '../../domain/repositories/i_engagement_repository.dart';
import '../../domain/repositories/i_listing_repository.dart';

class ListingDetailViewModel extends GetxController {
  final IListingRepository _repository;
  final IEngagementRepository _engagement;
  final ISessionService _session;

  ListingDetailViewModel(this._repository, this._engagement, this._session);

  final Rxn<Listing> listing = Rxn<Listing>();
  final Rxn<JoinRequest> myRequest = Rxn<JoinRequest>();
  final Rx<ListingStats> stats = ListingStats.empty.obs;
  final RxList<ListingComment> comments = <ListingComment>[].obs;
  final RxBool isLoading = false.obs;

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
    } catch (failure) {
      error.value = errorMessage(
        failure,
        fallback: 'No se pudo cargar el proyecto',
      );
    } finally {
      isLoading.value = false;
    }
  }

  bool get isCreator => listing.value?.creatorId == _session.currentUserId;

  bool get isMember =>
      listing.value?.memberIds.contains(_session.currentUserId) ?? false;

  bool get canRequestToJoin =>
      listing.value != null &&
      !isCreator &&
      !isMember &&
      !listing.value!.isFull &&
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
  /// The likes, views and comments go first: if the run stops halfway the
  /// project is still there and the owner can try again, whereas deleting the
  /// project first would leave rows nobody could reach or clean up.
  Future<bool> deleteListing() async {
    if (!isCreator) {
      error.value = 'Solo quien publicó el proyecto puede eliminarlo.';
      return false;
    }

    if (isWorking.value) return false;

    try {
      isWorking.value = true;
      error.value = null;

      await _engagement.purgeListing(listingId);
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
