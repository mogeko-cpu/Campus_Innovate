import '../../features/listings/domain/models/listing.dart';
import '../../features/listings/domain/models/join_request.dart';

class MockData {
  static final List<Listing> listings = [
    const Listing(
      id: 1,
      title: 'Campus App',
      description:
          'Aplicación para mejorar la experiencia de los estudiantes dentro del campus.',
      category: 'Tecnología',
      creatorId: 'user_2',
      creatorName: 'Sebastián González',
      maxMembers: 4,
      requiredSkills: [
        'Flutter',
        'Diseño UI',
      ],
      memberIds: [
        'user_2',
      ],
    ),
  ];

  static final List<JoinRequest> requests = [];
}