import 'package:campus_innovate/features/users/data/datasources/i_user_source.dart';
import 'package:campus_innovate/features/users/domain/models/app_user.dart';

/// [IUserSource] in memory, with one other student already registered so the
/// invite flow has somebody to find.
class InMemoryUserSource implements IUserSource {
  final List<AppUser> _users = [
    const AppUser(
      id: 'user_2',
      name: 'Mariana Ospina',
      email: 'mariana@uninorte.edu.co',
    ),
  ];

  @override
  Future<void> upsert(AppUser user) async {
    final index = _users.indexWhere((existing) => existing.id == user.id);

    if (index == -1) {
      _users.add(user);
    } else {
      _users[index] = user;
    }
  }

  @override
  Future<List<AppUser>> getUsers() async => List.of(_users);
}
