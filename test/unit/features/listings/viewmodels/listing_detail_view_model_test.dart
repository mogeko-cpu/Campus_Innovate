import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_comment.dart';
import 'package:campus_innovate/features/listings/domain/models/reaction_type.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/listing_detail_view_model.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_engagement_source.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

/// Counts the visits written, and can refuse them, to check that a visit is
/// counted once per screen and never gets in the way.
class _ViewCountingSource extends InMemoryEngagementSource {
  _ViewCountingSource({this.failViews = false});

  final bool failViews;
  int viewWrites = 0;

  @override
  Future<void> registerView({
    required String listingId,
    required String groupId,
    required String userId,
  }) async {
    viewWrites++;
    if (failViews) throw StateError('listing_views');

    return super.registerView(
      listingId: listingId,
      groupId: groupId,
      userId: userId,
    );
  }
}

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  ListingDetailViewModel build() => ListingDetailViewModel(
        harness.listings,
        harness.engagement,
        harness.groups,
        harness.publisher,
        harness.session,
        harness.tasks,
      );

  Future<ListingDetailViewModel> open(String id) =>
      start(build(), routeId: id);

  setUp(() => harness = ViewModelHarness());

  /// A project of `group_1` created by user_3, with user_4 on the team.
  Future<Listing> groupProject({int maxMembers = 5}) =>
      harness.listingSource.createListing(
        Listing(
          id: '',
          title: 'Drones',
          description: 'Vuelo autónomo',
          category: 'Investigación',
          creatorId: 'user_3',
          creatorName: 'Carlos Ruiz',
          maxMembers: maxMembers,
          requiredSkills: const [],
          memberIds: const ['user_3', 'user_4'],
          groupId: 'group_1',
          groupName: 'Innovación UN',
        ),
      );

  group('carga', () {
    test('un id inexistente dice que no se encontró', () async {
      final viewModel = await open('ghost');

      expect(viewModel.error.value, 'Proyecto no encontrado');
      expect(viewModel.listing.value, isNull);
      expect(viewModel.canRequestToJoin, isFalse);
      expect(viewModel.isLoading.value, isFalse);
    });

    test('carga el proyecto, sus contadores y sus comentarios', () async {
      await harness.engagementSource.addComment(
        ListingComment.draft(
          listingId: 'listing_1',
          groupId: '',
          authorId: 'user_3',
          authorName: 'Carlos Ruiz',
          body: 'Me encanta',
        ),
      );

      final viewModel = await open('listing_1');

      expect(viewModel.listing.value?.title, 'Campus App');
      expect(viewModel.comments.map((item) => item.body), ['Me encanta']);
      expect(viewModel.stats.value.comments, 1);
      expect(viewModel.error.value, isNull);
    });

    test('la visita cuenta antes de leer los contadores', () async {
      final viewModel = await open('listing_1');

      expect(viewModel.stats.value.views, 1);
    });

    test('registra la visita una sola vez aunque recargue', () async {
      final source = _ViewCountingSource();
      harness = ViewModelHarness(engagementSource: source);

      final viewModel = await open('listing_1');
      await viewModel.load();
      await viewModel.load();

      expect(source.viewWrites, 1);
    });

    test('si la visita falla el proyecto carga igual', () async {
      harness = ViewModelHarness(
        engagementSource: _ViewCountingSource(failViews: true),
      );

      final viewModel = await open('listing_1');

      expect(viewModel.error.value, isNull);
      expect(viewModel.listing.value, isNotNull);
      expect(viewModel.stats.value.views, 0);
    });
  });

  group('quién es quién', () {
    test('quien lo creó es creador e integrante y no puede postularse',
        () async {
      harness.session.signInAs(TestUsers.mariana);

      final viewModel = await open('listing_1');

      expect(viewModel.isCreator, isTrue);
      expect(viewModel.isMember, isTrue);
      expect(viewModel.canRequestToJoin, isFalse);
    });

    test('un integrante que no lo creó no puede postularse', () async {
      final project = await groupProject();
      harness.session.signInAs(
        const TestUser(id: 'user_4', name: 'Sofía', email: 's@u.co'),
      );

      final viewModel = await open(project.id);

      expect(viewModel.isCreator, isFalse);
      expect(viewModel.isMember, isTrue);
      expect(viewModel.canRequestToJoin, isFalse);
    });

    test('alguien de afuera puede postularse', () async {
      final viewModel = await open('listing_1');

      expect(viewModel.isCreator, isFalse);
      expect(viewModel.isMember, isFalse);
      expect(viewModel.canRequestToJoin, isTrue);
      expect(viewModel.myRequest.value, isNull);
    });

    test('con una solicitud ya enviada no puede postularse otra vez', () async {
      await harness.listings.createJoinRequest(
        const JoinRequest.draft(
          listingId: 'listing_1',
          applicantId: 'user_1',
          applicantName: 'Leonel Triana',
          motivation: 'Quiero',
          skills: 'Flutter',
          availability: 'Tardes',
        ),
      );

      final viewModel = await open('listing_1');

      expect(viewModel.myRequest.value, isNotNull);
      expect(viewModel.canRequestToJoin, isFalse);
    });

    test('un proyecto lleno no admite postulaciones', () async {
      final project = await groupProject(maxMembers: 2);

      final viewModel = await open(project.id);

      expect(viewModel.canRequestToJoin, isFalse);
    });
  });

  group('react', () {
    test('like, otra vez like lo retira, y dislike lo cambia', () async {
      final viewModel = await open('listing_1');

      await viewModel.react(ReactionType.like);
      expect(viewModel.stats.value.likes, 1);
      expect(viewModel.stats.value.myReaction, ReactionType.like);

      await viewModel.react(ReactionType.like);
      expect(viewModel.stats.value.likes, 0);
      expect(viewModel.stats.value.myReaction, isNull);

      await viewModel.react(ReactionType.dislike);
      await viewModel.react(ReactionType.like);
      expect(viewModel.stats.value.likes, 1);
      expect(viewModel.stats.value.dislikes, 0);
      expect(viewModel.stats.value.myReaction, ReactionType.like);
      expect(viewModel.isWorking.value, isFalse);
    });

    test('sin proyecto cargado no hace nada', () async {
      final viewModel = await open('ghost');

      await viewModel.react(ReactionType.like);

      expect(viewModel.stats.value.likes, 0);
    });
  });

  group('comentarios', () {
    test('publicar lo pone primero y sube el contador', () async {
      final viewModel = await open('listing_1');

      final done = await viewModel.comment('Buen proyecto');

      expect(done, isTrue);
      expect(viewModel.comments.first.body, 'Buen proyecto');
      expect(viewModel.comments.first.id, isNotEmpty);
      expect(viewModel.comments.first.authorId, 'user_1');
      expect(viewModel.stats.value.comments, 1);
      expect(viewModel.isWorking.value, isFalse);
    });

    test('un comentario en blanco se rechaza sin tocar la lista', () async {
      final viewModel = await open('listing_1');

      final done = await viewModel.comment('   ');

      expect(done, isFalse);
      expect(viewModel.error.value, 'Escribe algo antes de comentar.');
      expect(viewModel.comments, isEmpty);
      expect(viewModel.stats.value.comments, 0);
    });

    test('avisa al creador, al equipo y al grupo, pero no a quien comenta',
        () async {
      final project = await groupProject();
      await harness.groupSource.addMember(
        const GroupMember(
          groupId: 'group_1',
          userId: 'user_2',
          userName: 'Mariana Ospina',
        ),
      );
      final viewModel = await open(project.id);

      await viewModel.comment('¿Cuándo nos vemos?');

      final sent = harness.notificationSource.all;
      expect(
        sent.map((item) => item.recipientId).toSet(),
        {'user_3', 'user_4', 'user_2'},
      );
      expect(sent, hasLength(3));
      expect(
        sent.every((item) => item.type == NotificationType.comment),
        isTrue,
      );
    });

    test('solo quien escribió un comentario puede borrarlo', () async {
      await harness.engagementSource.addComment(
        ListingComment.draft(
          listingId: 'listing_1',
          groupId: '',
          authorId: 'user_3',
          authorName: 'Carlos Ruiz',
          body: 'Ajeno',
        ),
      );
      final viewModel = await open('listing_1');
      await viewModel.comment('Propio');

      final mine = viewModel.comments.firstWhere((c) => c.body == 'Propio');
      final theirs = viewModel.comments.firstWhere((c) => c.body == 'Ajeno');

      expect(viewModel.canDeleteComment(mine), isTrue);
      expect(viewModel.canDeleteComment(theirs), isFalse);
    });

    test('borrar quita el comentario y baja el contador', () async {
      final viewModel = await open('listing_1');
      await viewModel.comment('Me equivoqué');
      final id = viewModel.comments.first.id;

      await viewModel.deleteComment(id);

      expect(viewModel.comments, isEmpty);
      expect(viewModel.stats.value.comments, 0);
      expect(await harness.engagement.getComments('listing_1'), isEmpty);
    });
  });

  group('deleteListing', () {
    test('solo el líder puede eliminarlo', () async {
      final viewModel = await open('listing_1');

      final deleted = await viewModel.deleteListing();

      expect(deleted, isFalse);
      expect(
        viewModel.error.value,
        'Solo el líder del proyecto puede eliminarlo.',
      );
      expect(await harness.listings.getListingById('listing_1'), isNotNull);
    });

    test('quien lo creó lo elimina junto con likes, vistas y comentarios',
        () async {
      harness.session.signInAs(TestUsers.mariana);
      final viewModel = await open('listing_1');
      await viewModel.react(ReactionType.like);
      await viewModel.comment('Último comentario');

      final deleted = await viewModel.deleteListing();

      expect(deleted, isTrue);
      expect(await harness.listings.getListingById('listing_1'), isNull);

      final stats = await harness.engagement.getStatsFor(
        listingId: 'listing_1',
        userId: 'user_2',
      );
      expect(stats.likes, 0);
      expect(stats.views, 0);
      expect(stats.comments, 0);
    });
  });
}
