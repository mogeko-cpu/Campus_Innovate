import 'package:campus_innovate/features/listings/data/datasources/i_listing_source.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';

/// [IListingSource] in memory, seeded with the same three demo projects that
/// live in ROBLE.
///
/// This is what the widget tests run on. It used to be the app's only storage,
/// under `lib/`; now it is test support, because a test that reached the real
/// ROBLE would need credentials, a network, and would leave rows behind for the
/// next run to trip over.
///
/// It mimics the two guarantees the database provides — ids come from the store,
/// and a person cannot join or apply twice — so a test passing here means the
/// same flow works there.
class InMemoryListingSource implements IListingSource {
  final List<Listing> _listings = [
    const Listing(
      id: 'listing_1',
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
      id: 'listing_2',
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
      id: 'listing_3',
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

  var _nextId = 100;

  String _newId(String prefix) => '${prefix}_${_nextId++}';

  @override
  Future<List<Listing>> getListings() async => List.unmodifiable(_listings);

  @override
  Future<Listing?> getListingById(String id) async {
    final index = _listings.indexWhere((listing) => listing.id == id);

    return index == -1 ? null : _listings[index];
  }

  @override
  Future<Listing> createListing(Listing listing) async {
    final stored = listing.copyWith(id: _newId('listing'));
    _listings.insert(0, stored);

    return stored;
  }

  @override
  Future<JoinRequest> createJoinRequest(JoinRequest request) async {
    final duplicate = _requests.any(
      (existing) =>
          existing.listingId == request.listingId &&
          existing.applicantId == request.applicantId,
    );

    // The `UNIQUE (listing_id, applicant_id)` of the real table.
    if (duplicate) {
      throw const ListingException('Ya enviaste una solicitud a este proyecto.');
    }

    final stored = request.copyWith(id: _newId('request'));
    _requests.add(stored);

    return stored;
  }

  @override
  Future<List<JoinRequest>> getRequestsForListing(String listingId) async {
    return _requests
        .where((request) => request.listingId == listingId)
        .toList();
  }

  @override
  Future<JoinRequest?> getRequestById(String id) async {
    final index = _requests.indexWhere((request) => request.id == id);

    return index == -1 ? null : _requests[index];
  }

  @override
  Future<void> updateRequestStatus(
    String requestId,
    JoinRequestStatus status,
  ) async {
    final index = _requests.indexWhere((request) => request.id == requestId);

    if (index == -1) {
      throw ListingException('La solicitud $requestId ya no existe.');
    }

    _requests[index] = _requests[index].copyWith(status: status);
  }

  @override
  Future<void> addMember({
    required String listingId,
    required String userId,
  }) async {
    final index = _listings.indexWhere((listing) => listing.id == listingId);

    if (index == -1) {
      throw ListingException('El proyecto $listingId ya no existe.');
    }

    final listing = _listings[index];

    if (listing.memberIds.contains(userId)) return;

    if (listing.isFull) {
      throw const ListingException(
        'El proyecto ya alcanzó su número máximo de integrantes.',
      );
    }

    _listings[index] = listing.copyWith(
      memberIds: [...listing.memberIds, userId],
    );
  }
}
