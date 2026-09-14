import '../../features/listings/domain/models/listing.dart';

class MockData {
  static const List<Listing> featuredListings = [
    Listing(
      id: 1,
      title: 'Campus App',
      description:
          'Una aplicación para mejorar la experiencia de los estudiantes.',
      category: 'Tecnología',
      creator: 'Sebastián González',
      collaboratorsNeeded: 2,
    ),
    Listing(
      id: 2,
      title: 'EcoCampus',
      description:
          'Proyecto para promover prácticas sostenibles dentro del campus.',
      category: 'Sostenibilidad',
      creator: 'Kevin Ruiz',
      collaboratorsNeeded: 3,
    ),
    Listing(
      id: 3,
      title: 'Mentoría Universitaria',
      description:
          'Plataforma para conectar estudiantes con mentores.',
      category: 'Educación',
      creator: 'Alejandro Santiago',
      collaboratorsNeeded: 1,
    ),
  ];
}