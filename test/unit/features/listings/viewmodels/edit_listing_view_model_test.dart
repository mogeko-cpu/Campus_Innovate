import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_member.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/edit_listing_view_model.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  EditListingViewModel build() => EditListingViewModel(
        harness.listings,
        harness.publisher,
        harness.session,
      );

  Future<EditListingViewModel> open(String id) => start(build(), routeId: id);

  setUp(() => harness = ViewModelHarness());

  /// A project led by Leonel (user_1), with as many extra people as
  /// [others] says.
  Future<Listing> leonelsProject({
    List<String> others = const [],
    ListingStatus status = ListingStatus.idea,
    int maxMembers = 5,
  }) =>
      harness.listingSource.createListing(
        Listing(
          id: '',
          title: 'Bicicletas compartidas',
          description: 'Préstamo de bicicletas entre edificios del campus.',
          category: 'Tecnología',
          creatorId: 'user_1',
          creatorName: 'Leonel Triana',
          maxMembers: maxMembers,
          requiredSkills: const ['Flutter'],
          memberIds: ['user_1', ...others],
          status: status,
        ),
      );

  Future<JoinRequest> apply(String listingId, String applicantId) =>
      // Straight to the source: the repository refuses requests to a project
      // that is no longer recruiting, and some tests need one anyway.
      harness.listingSource.createJoinRequest(
        JoinRequest.draft(
          listingId: listingId,
          applicantId: applicantId,
          applicantName: 'Persona $applicantId',
          motivation: 'Quiero ayudar',
          skills: 'Dart',
          availability: 'Tardes',
        ),
      );

  Future<Listing?> submitValid(EditListingViewModel viewModel) =>
      viewModel.submit(
        title: 'Bicicletas compartidas',
        description: 'Préstamo de bicicletas entre edificios del campus.',
      );

  group('carga', () {
    test('un id inexistente dice que no se encontró', () async {
      final viewModel = await open('ghost');

      expect(viewModel.error.value, 'Proyecto no encontrado');
      expect(viewModel.listing.value, isNull);
      expect(viewModel.isLoading.value, isFalse);
    });

    test('alguien que no es el líder no puede editar', () async {
      // listing_1 is Mariana's.
      final viewModel = await open('listing_1');

      expect(
        viewModel.error.value,
        'Solo el líder del proyecto puede editarlo.',
      );
      expect(viewModel.listing.value, isNull);
    });

    test('un integrante que no lidera tampoco puede editar', () async {
      final project = await leonelsProject(others: ['user_2']);
      harness.session.signInAs(TestUsers.mariana);

      final viewModel = await open(project.id);

      expect(
        viewModel.error.value,
        'Solo el líder del proyecto puede editarlo.',
      );
    });

    test('el líder ve el formulario lleno con lo guardado', () async {
      final project = await leonelsProject(
        status: ListingStatus.inProgress,
        maxMembers: 6,
      );

      final viewModel = await open(project.id);

      expect(viewModel.error.value, isNull);
      expect(viewModel.listing.value?.id, project.id);
      expect(viewModel.category.value, 'Tecnología');
      expect(viewModel.maxMembers.value, 6);
      expect(viewModel.requiredSkills, ['Flutter']);
      expect(viewModel.status.value, ListingStatus.inProgress);
      expect(viewModel.isLoading.value, isFalse);
    });

    test('quien recibió el liderazgo puede editar aunque no lo creó', () async {
      final project = await harness.listingSource.createListing(
        const Listing(
          id: '',
          title: 'Radio universitaria',
          description: 'Una emisora hecha por estudiantes del campus.',
          category: 'Arte y Cultura',
          creatorId: 'user_2',
          creatorName: 'Mariana Ospina',
          maxMembers: 4,
          requiredSkills: [],
          memberIds: ['user_2', 'user_1'],
          members: [
            ListingMember(
              userId: 'user_2',
              userName: 'Mariana Ospina',
              role: ListingRole.member,
            ),
            ListingMember(
              userId: 'user_1',
              userName: 'Leonel Triana',
              role: ListingRole.leader,
            ),
          ],
        ),
      );

      final viewModel = await open(project.id);

      expect(viewModel.error.value, isNull);
      expect(viewModel.listing.value, isNotNull);
    });
  });

  group('tamaño del equipo', () {
    test('el mínimo es 2 mientras el equipo sea más chico', () async {
      final viewModel = await open((await leonelsProject()).id);

      expect(viewModel.minMembers, 2);
    });

    test('el mínimo es el tamaño del equipo cuando ya lo supera', () async {
      final project = await leonelsProject(others: ['user_2', 'user_3']);

      final viewModel = await open(project.id);

      expect(viewModel.minMembers, 3);
    });

    test('setMaxMembers no baja del mínimo ni pasa de 12', () async {
      final project = await leonelsProject(others: ['user_2', 'user_3']);
      final viewModel = await open(project.id);

      viewModel.setMaxMembers(1);
      expect(viewModel.maxMembers.value, 3);

      viewModel.setMaxMembers(40);
      expect(viewModel.maxMembers.value, 12);

      viewModel.setMaxMembers(7);
      expect(viewModel.maxMembers.value, 7);
    });
  });

  group('habilidades', () {
    test('agrega sin espacios y no repite ni acepta vacías', () async {
      final viewModel = await open((await leonelsProject()).id);

      viewModel.addSkill('  Python  ');
      viewModel.addSkill('Python');
      viewModel.addSkill('Flutter');
      viewModel.addSkill('   ');

      expect(viewModel.requiredSkills, ['Flutter', 'Python']);
    });

    test('quitar elimina solo esa habilidad', () async {
      final viewModel = await open((await leonelsProject()).id);
      viewModel.addSkill('Python');

      viewModel.removeSkill('Flutter');

      expect(viewModel.requiredSkills, ['Python']);
    });
  });

  group('closesRequests', () {
    test('avisa al elegir Terminado en un proyecto que no lo estaba',
        () async {
      final viewModel = await open((await leonelsProject()).id);

      expect(viewModel.closesRequests, isFalse);

      viewModel.selectStatus(ListingStatus.done);
      expect(viewModel.closesRequests, isTrue);

      viewModel.selectStatus(ListingStatus.paused);
      expect(viewModel.closesRequests, isFalse);
    });

    test('no avisa si el proyecto ya estaba terminado', () async {
      final project = await leonelsProject(status: ListingStatus.done);

      final viewModel = await open(project.id);

      expect(viewModel.status.value, ListingStatus.done);
      expect(viewModel.closesRequests, isFalse);
    });
  });

  group('submit', () {
    test('guarda los cambios y deja el proyecto guardado en pantalla',
        () async {
      final viewModel = await open((await leonelsProject()).id);
      viewModel.selectCategory('Sostenibilidad');
      viewModel.setMaxMembers(8);
      viewModel.addSkill('Logística');
      viewModel.selectStatus(ListingStatus.inProgress);

      final saved = await viewModel.submit(
        title: '  Bicis del campus  ',
        description: 'Préstamo de bicicletas entre los edificios.',
      );

      expect(saved, isNotNull);
      expect(saved!.title, 'Bicis del campus');
      expect(viewModel.listing.value?.title, 'Bicis del campus');
      expect(viewModel.error.value, isNull);
      expect(viewModel.isSaving.value, isFalse);

      final stored = await harness.listings.getListingById(saved.id);
      expect(stored?.category, 'Sostenibilidad');
      expect(stored?.maxMembers, 8);
      expect(stored?.requiredSkills, ['Flutter', 'Logística']);
      expect(stored?.status, ListingStatus.inProgress);
    });

    test('un título corto muestra el error del repositorio', () async {
      final project = await leonelsProject();
      final viewModel = await open(project.id);

      final saved = await viewModel.submit(
        title: 'Bici',
        description: 'Préstamo de bicicletas entre edificios del campus.',
      );

      expect(saved, isNull);
      expect(
        viewModel.error.value,
        'El título debe tener al menos 5 caracteres.',
      );
      expect(viewModel.isSaving.value, isFalse);
      expect(
        (await harness.listings.getListingById(project.id))?.title,
        'Bicicletas compartidas',
      );
    });

    test('una descripción corta muestra el error del repositorio', () async {
      final viewModel = await open((await leonelsProject()).id);

      final saved = await viewModel.submit(
        title: 'Bicicletas compartidas',
        description: 'Muy corta',
      );

      expect(saved, isNull);
      expect(
        viewModel.error.value,
        'La descripción debe tener al menos 20 caracteres.',
      );
    });

    test('sin proyecto cargado no hace nada', () async {
      final viewModel = await open('ghost');

      expect(await submitValid(viewModel), isNull);
    });
  });

  group('marcar como terminado', () {
    test('rechaza las solicitudes pendientes y avisa a cada postulante',
        () async {
      final project = await leonelsProject();
      final first = await apply(project.id, 'user_2');
      final second = await apply(project.id, 'user_3');
      final answered = await apply(project.id, 'user_4');
      await harness.listings.rejectJoinRequest(answered.id);

      final viewModel = await open(project.id);
      viewModel.selectStatus(ListingStatus.done);

      final saved = await submitValid(viewModel);

      expect(saved?.status, ListingStatus.done);

      final requests = await harness.listings.getRequestsForListing(project.id);
      expect(
        requests.every((r) => r.status == JoinRequestStatus.rejected),
        isTrue,
      );

      final sent = harness.notificationSource.all;
      expect(
        sent.map((item) => item.recipientId).toSet(),
        {first.applicantId, second.applicantId},
      );
      expect(sent, hasLength(2));
      expect(
        sent.every((item) => item.type == NotificationType.requestRejected),
        isTrue,
      );
      expect(sent.every((item) => item.targetId == project.id), isTrue);
    });

    test('guardar otra vez un proyecto ya terminado no vuelve a avisar',
        () async {
      final project = await leonelsProject(status: ListingStatus.done);
      final pending = await apply(project.id, 'user_2');

      final viewModel = await open(project.id);
      final saved = await submitValid(viewModel);

      expect(saved, isNotNull);
      expect(harness.notificationSource.all, isEmpty);
      expect(
        (await harness.listingSource.getRequestById(pending.id))?.status,
        JoinRequestStatus.pending,
      );
    });

    test('cambiar a otro estado no toca las solicitudes', () async {
      final project = await leonelsProject();
      final pending = await apply(project.id, 'user_2');

      final viewModel = await open(project.id);
      viewModel.selectStatus(ListingStatus.paused);
      await submitValid(viewModel);

      expect(harness.notificationSource.all, isEmpty);
      expect(
        (await harness.listingSource.getRequestById(pending.id))?.status,
        JoinRequestStatus.pending,
      );
    });
  });
}
