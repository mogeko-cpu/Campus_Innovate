import '../models/idea_model.dart';

class IdeaDataSource {
  Future<List<IdeaModel>> getFeaturedIdeas() async {
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    return [
      IdeaModel(
        id: 1,
        title: 'Campus App',
        description:
            'Una aplicación para mejorar la experiencia de los estudiantes.',
        category: 'Tecnología',
        creator: 'Sebastián González',
        collaboratorsNeeded: 2,
      ),
      IdeaModel(
        id: 2,
        title: 'EcoCampus',
        description:
            'Proyecto para promover prácticas sostenibles dentro del campus.',
        category: 'Sostenibilidad',
        creator: 'Kevin Ruiz',
        collaboratorsNeeded: 3,
      ),
      IdeaModel(
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
}