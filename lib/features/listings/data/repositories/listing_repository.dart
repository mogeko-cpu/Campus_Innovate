import '../../domain/listing_exception.dart';
import '../../domain/models/join_request.dart';
import '../../domain/models/join_request_status.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/listing_role.dart';
import '../../domain/repositories/i_listing_repository.dart';
import '../datasources/i_listing_source.dart';

class ListingRepository implements IListingRepository {
  final IListingSource _source;

  ListingRepository(this._source);

  /// The smallest and largest team the form offers.
  static const minTeamSize = 2;
  static const maxTeamSize = 12;

  @override
  Future<List<Listing>> getListings() => _source.getListings();

  /// What the home screen offers: projects that are looking for people. A
  /// finished or paused one is not, however many slots it has left.
  @override
  Future<List<Listing>> getFeaturedListings() async {
    final listings = await _source.getListings();

    return listings.where((listing) => listing.isRecruiting).take(5).toList();
  }

  @override
  Future<Listing?> getListingById(String id) => _source.getListingById(id);

  @override
  Future<Listing> createListing(Listing listing) =>
      _source.createListing(listing);

  @override
  Future<JoinRequest> createJoinRequest(JoinRequest request) async {
    final listing = await _source.getListingById(request.listingId);

    // Checked here and not only on the screen: the button can be stale, and a
    // request to a project that stopped recruiting would wait forever.
    if (listing != null && !listing.status.acceptsRequests) {
      throw ListingException(
        'Este proyecto está ${listing.status.label.toLowerCase()} y ya no '
        'recibe solicitudes.',
      );
    }

    return _source.createJoinRequest(request);
  }

  @override
  Future<List<JoinRequest>> getRequestsForListing(String listingId) =>
      _source.getRequestsForListing(listingId);

  @override
  Future<JoinRequest?> getMyRequestForListing({
    required String listingId,
    required String applicantId,
  }) async {
    final requests = await _source.getRequestsForListing(listingId);
    final index = requests.indexWhere(
      (request) => request.applicantId == applicantId,
    );

    return index == -1 ? null : requests[index];
  }

  @override
  /// Accepting is two writes and ROBLE has no transactions, so the order is
  /// chosen for what a failure between them leaves behind: the membership goes
  /// in **first**, and only then is the request marked accepted.
  ///
  /// Fail after the membership and the request still reads "Pendiente", so the
  /// creator accepts again and the second run fixes it — [IListingSource.addMember]
  /// is idempotent. The opposite order would show an accepted request whose
  /// applicant never joined, and retrying would look like a no-op.
  Future<void> acceptJoinRequest(String requestId) async {
    final request = await _source.getRequestById(requestId);

    if (request == null) {
      throw StateError('Solicitud $requestId no encontrada');
    }

    final listing = await _source.getListingById(request.listingId);

    if (listing != null && !listing.status.acceptsRequests) {
      throw ListingException(
        'Este proyecto está ${listing.status.label.toLowerCase()}: ya no se '
        'aceptan integrantes nuevos.',
      );
    }

    await _source.addMember(
      listingId: request.listingId,
      userId: request.applicantId,
      userName: request.applicantName,
    );
    await _source.updateRequestStatus(requestId, JoinRequestStatus.accepted);
  }

  @override
  Future<void> rejectJoinRequest(String requestId) =>
      _source.updateRequestStatus(requestId, JoinRequestStatus.rejected);

  @override
  Future<List<Listing>> getMyListings(String userId) async {
    final listings = await _source.getListings();

    return listings.where((listing) => listing.creatorId == userId).toList();
  }

  @override
  Future<List<Listing>> getJoinedListings(String userId) async {
    final listings = await _source.getListings();

    return listings
        .where((listing) => listing.memberIds.contains(userId))
        .toList();
  }

  @override
  Future<List<Listing>> getListingsByGroup(String groupId) async {
    if (groupId.isEmpty) return const [];

    final listings = await _source.getListings();

    return listings.where((listing) => listing.groupId == groupId).toList();
  }

  @override
  Future<List<JoinRequest>> getMyRequests(String applicantId) =>
      _source.getRequestsByApplicant(applicantId);

  @override
  Future<void> deleteListing(String listingId) =>
      _source.deleteListing(listingId);

  @override
  Future<Listing> updateListing(
    Listing updated, {
    required String actorId,
  }) async {
    final current = await _requireListing(updated.id);
    _requireLeader(current, actorId, 'editar el proyecto');

    final title = updated.title.trim();
    final description = updated.description.trim();

    if (title.length < 5) {
      throw const ListingException(
        'El título debe tener al menos 5 caracteres.',
      );
    }

    if (description.length < 20) {
      throw const ListingException(
        'La descripción debe tener al menos 20 caracteres.',
      );
    }

    if (updated.maxMembers < minTeamSize || updated.maxMembers > maxTeamSize) {
      throw const ListingException(
        'El equipo debe ser de $minTeamSize a $maxTeamSize personas.',
      );
    }

    // Shrinking below the people already in would leave somebody over the
    // limit with no rule for who goes; the leader removes someone first.
    if (updated.maxMembers < current.memberCount) {
      throw ListingException(
        'El equipo ya tiene ${current.memberCount} personas: el tamaño no '
        'puede ser menor.',
      );
    }

    // Only what the form edits is taken from [updated]; who is in and who leads
    // come from the stored row, so a stale screen cannot write them back.
    return _source.updateListing(
      current.copyWith(
        title: title,
        description: description,
        category: updated.category,
        maxMembers: updated.maxMembers,
        requiredSkills: updated.requiredSkills,
        status: updated.status,
      ),
    );
  }

  @override
  Future<List<JoinRequest>> closePendingRequests(String listingId) async {
    final pending = (await _source.getRequestsForListing(listingId))
        .where((request) => request.status == JoinRequestStatus.pending)
        .toList();

    for (final request in pending) {
      await _source.updateRequestStatus(
        request.id,
        JoinRequestStatus.rejected,
      );
    }

    return pending;
  }

  @override
  Future<void> removeMember({
    required String listingId,
    required String userId,
    required String actorId,
  }) async {
    final listing = await _requireListing(listingId);
    _requireLeader(listing, actorId, 'quitar integrantes');

    if (listing.isLeader(userId)) {
      throw const ListingException(
        'No se puede quitar al líder. Transfiere el liderazgo primero.',
      );
    }

    if (!listing.memberIds.contains(userId)) {
      throw const ListingException('Esa persona ya no está en el equipo.');
    }

    await _source.removeMember(listingId: listingId, userId: userId);
  }

  @override
  Future<void> leaveListing({
    required String listingId,
    required String userId,
  }) async {
    final listing = await _requireListing(listingId);

    if (!listing.memberIds.contains(userId)) return;

    // A project with nobody in charge has no screen that could fix it.
    if (listing.isLeader(userId)) {
      throw const ListingException(
        'Eres el líder: transfiere el liderazgo antes de salir del proyecto.',
      );
    }

    await _source.removeMember(listingId: listingId, userId: userId);
  }

  @override
  Future<void> setMemberRole({
    required String listingId,
    required String userId,
    required ListingRole role,
    required String actorId,
  }) async {
    if (role == ListingRole.leader) {
      throw const ListingException(
        'El liderazgo se transfiere, no se asigna: usa "Transferir liderazgo".',
      );
    }

    final listing = await _requireListing(listingId);
    _requireLeader(listing, actorId, 'cambiar roles');

    if (listing.isLeader(userId)) {
      throw const ListingException(
        'El líder no puede cambiar su propio rol. Transfiere el liderazgo '
        'primero.',
      );
    }

    if (!listing.memberIds.contains(userId)) {
      throw const ListingException('Esa persona ya no está en el equipo.');
    }

    await _source.setMemberRole(
      listingId: listingId,
      userId: userId,
      role: role,
    );
  }

  @override
  Future<void> addMentor({
    required String listingId,
    required String userId,
    required String userName,
  }) =>
      _source.addMember(
        listingId: listingId,
        userId: userId,
        userName: userName,
        role: ListingRole.mentor,
      );

  /// Two writes with no transaction, ordered for what a failure in between
  /// leaves behind: the new leader is promoted **first**. Stopping there leaves
  /// two leaders — both can still run the project and the old one can finish
  /// stepping down — whereas demoting first would leave a project nobody leads.
  @override
  Future<void> transferLeadership({
    required String listingId,
    required String newLeaderId,
    required String actorId,
  }) async {
    final listing = await _requireListing(listingId);
    _requireLeader(listing, actorId, 'transferir el liderazgo');

    if (newLeaderId == actorId) return;

    if (!listing.memberIds.contains(newLeaderId)) {
      throw const ListingException('Esa persona ya no está en el equipo.');
    }

    await _source.setMemberRole(
      listingId: listingId,
      userId: newLeaderId,
      role: ListingRole.leader,
    );
    await _source.setMemberRole(
      listingId: listingId,
      userId: actorId,
      role: ListingRole.member,
    );
  }

  Future<Listing> _requireListing(String listingId) async {
    final listing = await _source.getListingById(listingId);

    if (listing == null) {
      throw ListingException('El proyecto $listingId ya no existe.');
    }

    return listing;
  }

  /// The repository checks and not only the screen: a hidden button is a hint,
  /// not a rule, and nothing on ROBLE's side knows who leads what.
  void _requireLeader(Listing listing, String actorId, String action) {
    if (!listing.isLeader(actorId)) {
      throw ListingException('Solo el líder del proyecto puede $action.');
    }
  }
}
