import 'package:campus_innovate/features/users/data/repositories/user_repository.dart';
import 'package:campus_innovate/features/users/domain/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_user_source.dart';

/// The in-memory directory starts with Mariana Ospina (`user_2`).
void main() {
  late InMemoryUserSource source;
  late UserRepository repository;

  setUp(() {
    source = InMemoryUserSource();
    repository = UserRepository(source);
  });

  test('registrarse agrega a la persona al directorio', () async {
    await repository.registerCurrentUser(
      const AppUser(id: 'user_1', name: 'Leonel', email: 'l@u.co'),
    );

    expect((await repository.getUsers()).map((u) => u.id),
        containsAll(['user_1', 'user_2']));
  });

  test('registrarse de nuevo actualiza en vez de duplicar', () async {
    await repository.registerCurrentUser(
      const AppUser(id: 'user_2', name: 'Mariana O.', email: 'nuevo@u.co'),
    );

    final users = await repository.getUsers();

    expect(users, hasLength(1));
    expect(users.single.name, 'Mariana O.');
    expect(users.single.email, 'nuevo@u.co');
  });

  test('el directorio sale ordenado por nombre sin importar mayúsculas',
      () async {
    for (final user in const [
      AppUser(id: 'a', name: 'zoe', email: ''),
      AppUser(id: 'b', name: 'Andrés', email: ''),
      AppUser(id: 'c', name: 'beatriz', email: ''),
    ]) {
      await repository.registerCurrentUser(user);
    }

    final names = (await repository.getUsers()).map((u) => u.name);

    expect(names, ['Andrés', 'beatriz', 'Mariana Ospina', 'zoe']);
  });
}
