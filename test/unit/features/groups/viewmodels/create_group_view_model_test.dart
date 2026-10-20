import 'package:campus_innovate/features/groups/domain/group_exception.dart';
import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/ui/viewmodels/create_group_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_group_source.dart';
import '../../view_model_harness.dart';

class _FailingGroupSource extends InMemoryGroupSource {
  _FailingGroupSource(this.failure);

  final Object failure;

  @override
  Future<Group> createGroup(Group group) async => throw failure;
}

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  CreateGroupViewModel build() =>
      CreateGroupViewModel(harness.groups, harness.session);

  setUp(() => harness = ViewModelHarness());

  test('crea el grupo con quien lo crea como dueño e integrante', () async {
    final viewModel = build();

    final created = await viewModel.submit(
      name: '  Semillero IA  ',
      description: '  Aprendizaje automático  ',
    );

    expect(created, isNotNull);
    expect(created!.id, isNotEmpty);
    expect(created.name, 'Semillero IA');
    expect(created.description, 'Aprendizaje automático');
    expect(created.ownerId, 'user_1');
    expect(created.ownerName, 'Leonel Triana');
    expect(created.memberIds, ['user_1']);
    expect(viewModel.error.value, isNull);
    expect(viewModel.isSaving.value, isFalse);

    final groups = await harness.groups.getGroups();
    expect(groups.map((group) => group.id), contains(created.id));
  });

  test('isSaving se enciende mientras se guarda', () async {
    final viewModel = build();

    final pending = viewModel.submit(name: 'Grupo', description: 'Desc');

    expect(viewModel.isSaving.value, isTrue);
    await pending;
    expect(viewModel.isSaving.value, isFalse);
  });

  test('un error genérico muestra el mensaje de respaldo', () async {
    harness = ViewModelHarness(
      groupSource: _FailingGroupSource(StateError('groups')),
    );
    final viewModel = build();

    final created = await viewModel.submit(name: 'Grupo', description: 'Desc');

    expect(created, isNull);
    expect(viewModel.error.value, 'No se pudo crear el grupo');
    expect(viewModel.isSaving.value, isFalse);
  });

  test('un error para el usuario se muestra tal cual', () async {
    harness = ViewModelHarness(
      groupSource: _FailingGroupSource(
        const GroupException('Espera 40 segundos.'),
      ),
    );
    final viewModel = build();

    await viewModel.submit(name: 'Grupo', description: 'Desc');

    expect(viewModel.error.value, 'Espera 40 segundos.');
  });

  test('un envío exitoso limpia el error anterior', () async {
    final viewModel = build();
    viewModel.error.value = 'anterior';

    await viewModel.submit(name: 'Grupo', description: 'Desc');

    expect(viewModel.error.value, isNull);
  });
}
