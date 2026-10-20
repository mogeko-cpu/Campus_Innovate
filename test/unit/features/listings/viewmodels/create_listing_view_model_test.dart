import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/create_listing_view_model.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_group_source.dart';
import '../../../../support/in_memory_listing_source.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

class _FailingListingSource extends InMemoryListingSource {
  _FailingListingSource(this.failure);

  final Object failure;

  @override
  Future<Listing> createListing(Listing listing) async => throw failure;
}

class _FailingGroupSource extends InMemoryGroupSource {
  @override
  Future<List<Group>> getGroups() async => throw StateError('groups');
}

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  CreateListingViewModel build() => CreateListingViewModel(
        harness.listings,
        harness.groups,
        harness.publisher,
        harness.session,
      );

  setUp(() => harness = ViewModelHarness());

  group('grupos', () {
    test('con un solo grupo lo deja elegido', () async {
      final viewModel = await start(build());

      expect(viewModel.myGroups.map((group) => group.id), ['group_1']);
      expect(viewModel.selectedGroup.value?.id, 'group_1');
      expect(viewModel.hasNoGroups, isFalse);
      expect(viewModel.isLoadingGroups.value, isFalse);
    });

    test('con varios grupos no elige ninguno', () async {
      await harness.groups.createGroup(
        Group.draft(
          name: 'Segundo',
          description: 'Otro grupo',
          ownerId: 'user_1',
          ownerName: 'Leonel Triana',
        ),
      );

      final viewModel = await start(build());

      expect(viewModel.myGroups, hasLength(2));
      expect(viewModel.selectedGroup.value, isNull);

      viewModel.selectGroup(viewModel.myGroups.last);

      expect(viewModel.selectedGroup.value?.id, viewModel.myGroups.last.id);
    });

    test('sin grupos lo indica', () async {
      harness.session.signInAs(TestUsers.mariana);

      final viewModel = await start(build());

      expect(viewModel.hasNoGroups, isTrue);
      expect(viewModel.selectedGroup.value, isNull);
    });

    test('mientras carga no dice que no hay grupos', () {
      final viewModel = build();

      final loading = viewModel.loadGroups();

      expect(viewModel.isLoadingGroups.value, isTrue);
      expect(viewModel.hasNoGroups, isFalse);

      return loading;
    });

    test('un fallo al cargar los grupos se informa', () async {
      harness = ViewModelHarness(groupSource: _FailingGroupSource());

      final viewModel = await start(build());

      expect(viewModel.error.value, 'No se pudieron cargar tus grupos');
      expect(viewModel.isLoadingGroups.value, isFalse);
    });
  });

  group('formulario', () {
    late CreateListingViewModel viewModel;

    setUp(() => viewModel = build());

    test('empieza en la primera categoría y con 4 integrantes', () {
      expect(viewModel.category.value, 'Tecnología');
      expect(viewModel.maxMembers.value, 4);
      expect(viewModel.requiredSkills, isEmpty);

      viewModel.selectCategory('Emprendimiento');
      expect(viewModel.category.value, 'Emprendimiento');
    });

    test('agrega habilidades sin espacios y sin repetir', () {
      viewModel.addSkill('  Flutter  ');
      viewModel.addSkill('Flutter');
      viewModel.addSkill('Diseño UI');

      expect(viewModel.requiredSkills, ['Flutter', 'Diseño UI']);
    });

    test('ignora una habilidad en blanco', () {
      viewModel.addSkill('   ');
      viewModel.addSkill('');

      expect(viewModel.requiredSkills, isEmpty);
    });

    test('quita una habilidad', () {
      viewModel.addSkill('Flutter');
      viewModel.addSkill('Python');

      viewModel.removeSkill('Flutter');

      expect(viewModel.requiredSkills, ['Python']);
    });

    test('el cupo se limita entre 2 y 12', () {
      viewModel.setMaxMembers(1);
      expect(viewModel.maxMembers.value, 2);

      viewModel.setMaxMembers(40);
      expect(viewModel.maxMembers.value, 12);

      viewModel.setMaxMembers(7);
      expect(viewModel.maxMembers.value, 7);
    });
  });

  group('submit', () {
    test('sin grupo elegido no publica', () async {
      harness.session.signInAs(TestUsers.mariana);
      final viewModel = await start(build());

      final saved = await viewModel.submit(
        title: 'Sin grupo',
        description: 'No debería guardarse',
      );

      expect(saved, isNull);
      expect(
        viewModel.error.value,
        'Elige el grupo que publica este proyecto.',
      );
      expect(viewModel.isSaving.value, isFalse);
      expect(await harness.listings.getListings(), hasLength(3));
    });

    test('guarda el proyecto bajo el grupo, con quien lo crea dentro',
        () async {
      final viewModel = await start(build());
      viewModel.selectCategory('Investigación');
      viewModel.setMaxMembers(6);
      viewModel.addSkill('Python');

      final saved = await viewModel.submit(
        title: '  Drones  ',
        description: '  Vuelo autónomo  ',
      );

      expect(saved, isNotNull);
      expect(saved!.id, isNotEmpty);
      expect(saved.title, 'Drones');
      expect(saved.description, 'Vuelo autónomo');
      expect(saved.category, 'Investigación');
      expect(saved.maxMembers, 6);
      expect(saved.requiredSkills, ['Python']);
      expect(saved.creatorId, 'user_1');
      expect(saved.memberIds, ['user_1']);
      expect(saved.groupId, 'group_1');
      expect(saved.groupName, 'Innovación UN');
      expect(viewModel.error.value, isNull);
      expect(viewModel.isSaving.value, isFalse);

      expect(await harness.listings.getListingById(saved.id), isNotNull);
    });

    test('avisa al resto del grupo y no a quien publica', () async {
      await harness.groupSource.addMember(
        const GroupMember(
          groupId: 'group_1',
          userId: 'user_2',
          userName: 'Mariana Ospina',
        ),
      );
      final viewModel = await start(build());

      final saved = await viewModel.submit(
        title: 'Drones',
        description: 'Vuelo autónomo',
      );

      final sent = harness.notificationSource.all;
      expect(sent, hasLength(1));
      expect(sent.single.recipientId, 'user_2');
      expect(sent.single.type, NotificationType.ideaPublished);
      expect(sent.single.targetId, saved!.id);
      expect(sent.single.title, 'Nueva idea en Innovación UN');
    });

    test('un grupo de una sola persona no genera avisos', () async {
      final viewModel = await start(build());

      await viewModel.submit(title: 'Solo', description: 'Nadie más');

      expect(harness.notificationSource.all, isEmpty);
    });

    test('un error genérico muestra el mensaje de respaldo', () async {
      harness = ViewModelHarness(
        listingSource: _FailingListingSource(StateError('red')),
      );
      final viewModel = await start(build());

      final saved = await viewModel.submit(title: 'X', description: 'Y');

      expect(saved, isNull);
      expect(viewModel.error.value, 'No se pudo crear el proyecto');
      expect(viewModel.isSaving.value, isFalse);
      expect(harness.notificationSource.all, isEmpty);
    });

    test('un error para el usuario se muestra tal cual', () async {
      harness = ViewModelHarness(
        listingSource: _FailingListingSource(
          const ListingException('Espera 40 segundos.'),
        ),
      );
      final viewModel = await start(build());

      await viewModel.submit(title: 'X', description: 'Y');

      expect(viewModel.error.value, 'Espera 40 segundos.');
    });
  });
}
