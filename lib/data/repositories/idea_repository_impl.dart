    import '../../domain/entities/idea.dart';
import '../../domain/repositories/idea_repository.dart';
import '../sources/idea_data_source.dart';

class IdeaRepositoryImpl implements IdeaRepository {
  final IdeaDataSource dataSource;

  IdeaRepositoryImpl(this.dataSource);

  @override
  Future<List<Idea>> getFeaturedIdeas() async {
    return await dataSource.getFeaturedIdeas();
  }
}