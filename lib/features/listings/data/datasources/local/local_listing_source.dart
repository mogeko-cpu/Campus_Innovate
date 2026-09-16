import '../../../domain/models/join_request.dart';
import '../../../domain/models/join_request_status.dart';
import '../../../domain/models/listing.dart';
import '../i_listing_source.dart';

/// In-memory listing store seeded with demo content.
///
/// State lives for the lifetime of the instance, so it resets on every app
/// restart. Registered as a singleton in [AppBindings].
class LocalListingSource implements IListingSource {
  final List<Listing> _listings = [
    const Listing(
      id: 1,
      title: 'Campus App',
      description:
          'Aplicación para mejorar la experiencia de los estudiantes dentro del campus: '
          'horarios, mapas y notificaciones en un solo lugar.',
      category: 'Tecnología',
      creatorId: 'user_2',
      creatorName: 'Sebastián González',
      maxMembers: 4,
      requiredSkills: ['Flutter', 'Diseño UI'],
      memberIds: ['user_2'],
    ),
    const Listing(
      id: 2,
      title: 'Huerta Universitaria',
      description:
          'Proyecto de sostenibilidad para cultivar alimentos en zonas verdes del campus '
          'y abastecer la cafetería con producto local.',
      category: 'Sostenibilidad',
      creatorId: 'user_3',
      creatorName: 'Mariana Ospina',
      maxMembers: 6,
      requiredSkills: ['Biología', 'Gestión de proyectos'],
      memberIds: ['user_3', 'user_4'],
    ),
    const Listing(
      id: 3,
      title: 'Semillero de Robótica',
      description:
          'Construcción de un robot autónomo para competir en el torneo interuniversitario '
          'del próximo semestre.',
      category: 'Investigación',
      creatorId: 'user_5',
      creatorName: 'Andrés Betancur',
      maxMembers: 5,
      requiredSkills: ['Electrónica', 'Python', 'Impresión 3D'],
      memberIds: ['user_5'],
    ),
  ];

  final List<JoinRequest> _requests = [];

  @override
  Future<List<Listing>> getListings() async => List.unmodifiable(_listings);

  @override
  Future<Listing?> getListingById(int id) async {
    final index = _listings.indexWhere((listing) => listing.id == id);

    return index == -1 ? null : _listings[index];
  }

  @override
  Future<Listing> createListing(Listing listing) async {
    _listings.insert(0, listing);

    return listing;
  }

  @override
  Future<JoinRequest> createJoinRequest(JoinRequest request) async {
    _requests.add(request);

    return request;
  }

  @override
  Future<List<JoinRequest>> getRequestsForListing(int listingId) async {
    return _requests.where((request) => request.listingId == listingId).toList();
  }

  @override
  Future<JoinRequest?> getRequestById(int id) async {
    final index = _requests.indexWhere((request) => request.id == id);

    return index == -1 ? null : _requests[index];
  }

  @override
  Future<void> updateRequestStatus(
    int requestId,
    JoinRequestStatus status,
  ) async {
    final index = _requests.indexWhere((request) => request.id == requestId);

    if (index == -1) {
      throw StateError('Solicitud $requestId no encontrada');
    }

    _requests[index] = _requests[index].copyWith(status: status);
  }

  @override
  Future<void> addMember({
    required int listingId,
    required String userId,
  }) async {
    final index = _listings.indexWhere((listing) => listing.id == listingId);

    if (index == -1) {
      throw StateError('Proyecto $listingId no encontrado');
    }

    final listing = _listings[index];

    if (listing.memberIds.contains(userId)) {
      return;
    }

    _listings[index] = listing.copyWith(
      memberIds: [...listing.memberIds, userId],
    );
  }
}
