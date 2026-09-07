import '../entities/idea.dart';

abstract class IdeaRepository {
  Future<List<Idea>> getFeaturedIdeas();
}