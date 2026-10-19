import '../../domain/models/app_user.dart';
import '../../domain/repositories/i_user_repository.dart';
import '../datasources/i_user_source.dart';

class UserRepository implements IUserRepository {
  final IUserSource _source;

  UserRepository(this._source);

  @override
  Future<void> registerCurrentUser(AppUser user) => _source.upsert(user);

  @override
  Future<List<AppUser>> getUsers() async {
    final users = await _source.getUsers();

    users.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return users;
  }
}
