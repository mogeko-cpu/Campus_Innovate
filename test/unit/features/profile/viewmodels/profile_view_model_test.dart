import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:campus_innovate/features/profile/ui/viewmodels/profile_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_group_source.dart';
import '../../../../support/test_bindings.dart';
import '../../view_model_harness.dart';

class _FailingGroupSource extends InMemoryGroupSource {
  @override
  Future<List<Group>> getGroups() async => throw StateError('groups');
}

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  ProfileViewModel build() => ProfileViewModel(
        harness.session,
        harness.listings,
        harness.groups,
        harness.engagement,
      );

  setUp(() => harness = ViewModelHarness());

  Future<Listing> publishOwn() => harness.listingSource.createListing(
        Listing.draft(
          title: 'Mi proyecto',
          description: 'Lo publiqué yo',
          category: 'Tecnología',
          creatorId: 'user_1',
          creatorName: 'Leonel Triana',
          maxMembers: 4,
          requiredSkills: const [],
          groupId: 'group_1',
          groupName: 'Innovación UN',
        ),
      );

  Future<JoinRequest> apply(String listingId) =>
      harness.listingSource.createJoinRequest(
        JoinRequest.draft(
          listingId: listingId,
          applicantId: 'user_1',
          applicantName: 'Leonel Triana',
          motivation: 'Me interesa',
          skills: 'Flutter',
          availability: 'Tardes',
        ),
      );

  Future<void> react(String listingId, String userId, ReactionType reaction) =>
      harness.engagementSource.setReaction(
        listingId: listingId,
        groupId: '',
        userId: userId,
        reaction: reaction,
      );

  group('iniciales', () {
    String initialsOf(String name) => ProfileViewModel(
          FakeSessionService(currentUserName: name),
          harness.listings,
          harness.groups,
          harness.engagement,
        ).initials;

    test('toma la primera letra del primer y del último nombre', () {
      expect(initialsOf('Leonel Triana'), 'LT');
      expect(initialsOf('ana maría pérez'), 'AP');
    });

    test('ignora los espacios de sobra', () {
      expect(initialsOf('  Mariana    Ospina  '), 'MO');
    });

    test('con un solo nombre muestra una letra', () {
      expect(initialsOf('madonna'), 'M');
    });

    test('sin nombre muestra un signo de interrogación', () {
      expect(initialsOf('   '), '?');
    });
  });

  test('expone los datos de la sesión', () {
    final viewModel = build();

    expect(viewModel.userId, 'user_1');
    expect(viewModel.userName, 'Leonel Triana');
    expect(viewModel.userEmail, 'leonel@uninorte.edu.co');
  });

  group('carga', () {
    test('separa lo propio de las participaciones', () async {
      final own = await publishOwn();
      await harness.listingSource.addMember(
        listingId: 'listing_1',
        userId: 'user_1',
      );

      final viewModel = await start(build());

      expect(viewModel.myListings.map((listing) => listing.id), [own.id]);
      expect(viewModel.joinedListings, hasLength(2));
      expect(
        viewModel.participations.map((listing) => listing.id),
        ['listing_1'],
      );
      expect(viewModel.isLoading.value, isFalse);
      expect(viewModel.error.value, isNull);
    });

    test('lista los grupos de la persona', () async {
      final viewModel = await start(build());

      expect(viewModel.myGroups.map((group) => group.id), ['group_1']);
    });

    test('las solicitudes pendientes excluyen las ya respondidas', () async {
      final waiting = await apply('listing_2');
      final answered = await apply('listing_3');
      await harness.listingSource.updateRequestStatus(
        answered.id,
        JoinRequestStatus.accepted,
      );

      final viewModel = await start(build());

      expect(viewModel.myRequests, hasLength(2));
      expect(
        viewModel.pendingRequests.map((request) => request.id),
        [waiting.id],
      );
    });

    test('suma likes y vistas solo de los proyectos propios', () async {
      final own = await publishOwn();
      await harness.listingSource.addMember(
        listingId: 'listing_1',
        userId: 'user_1',
      );

      await react(own.id, 'user_2', ReactionType.like);
      await react(own.id, 'user_3', ReactionType.like);
      await react(own.id, 'user_4', ReactionType.dislike);
      for (final viewer in ['user_2', 'user_3']) {
        await harness.engagementSource.registerView(
          listingId: own.id,
          groupId: 'group_1',
          userId: viewer,
        );
      }

      // Activity on a project the user only joined is not theirs to count.
      await react('listing_1', 'user_5', ReactionType.like);
      await harness.engagementSource.registerView(
        listingId: 'listing_1',
        groupId: '',
        userId: 'user_5',
      );

      final viewModel = await start(build());

      expect(viewModel.likesReceived.value, 2);
      expect(viewModel.viewsReceived.value, 2);
    });

    test('sin proyectos propios los contadores quedan en cero', () async {
      await react('listing_1', 'user_5', ReactionType.like);

      final viewModel = await start(build());

      expect(viewModel.likesReceived.value, 0);
      expect(viewModel.viewsReceived.value, 0);
    });

    test('un fallo muestra el mensaje de respaldo', () async {
      harness = ViewModelHarness(groupSource: _FailingGroupSource());

      final viewModel = await start(build());

      expect(viewModel.error.value, 'No se pudo cargar tu perfil');
      expect(viewModel.isLoading.value, isFalse);
    });
  });
}
