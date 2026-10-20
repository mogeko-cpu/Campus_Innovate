import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/requests_view_model.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_listing_source.dart';
import '../../../../support/test_session.dart';
import '../../view_model_harness.dart';

class _FailingListingSource extends InMemoryListingSource {
  @override
  Future<List<JoinRequest>> getRequestsForListing(String listingId) async =>
      throw StateError('join_requests');
}

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;
  late RequestsViewModel viewModel;

  Future<JoinRequest> apply(String listingId, String applicantId) =>
      harness.listings.createJoinRequest(
        JoinRequest.draft(
          listingId: listingId,
          applicantId: applicantId,
          applicantName: 'Persona $applicantId',
          motivation: 'Quiero',
          skills: 'Flutter',
          availability: 'Tardes',
        ),
      );

  Future<Listing> listing(String id) async =>
      (await harness.listings.getListingById(id))!;

  // Mariana (user_2) created `listing_1`, so she is the one deciding.
  setUp(() {
    harness = ViewModelHarness(user: TestUsers.mariana);
    viewModel = RequestsViewModel(
      harness.listings,
      harness.publisher,
      harness.session,
    );
  });

  test('carga las solicitudes del proyecto', () async {
    await apply('listing_1', 'user_1');
    await apply('listing_2', 'user_6');

    await viewModel.load('listing_1', listingTitle: 'Campus App');

    expect(viewModel.requests.map((request) => request.applicantId), [
      'user_1',
    ]);
    expect(viewModel.isLoading.value, isFalse);
    expect(viewModel.error.value, isNull);
  });

  test('aceptar suma a la persona al equipo y le avisa', () async {
    final request = await apply('listing_1', 'user_1');
    await viewModel.load('listing_1', listingTitle: 'Campus App');

    await viewModel.accept(request.id);

    expect(viewModel.requests.single.status, JoinRequestStatus.accepted);
    expect((await listing('listing_1')).memberIds, contains('user_1'));

    final sent = harness.notificationSource.all;
    expect(sent, hasLength(1));
    expect(sent.single.recipientId, 'user_1');
    expect(sent.single.type, NotificationType.requestAccepted);
    expect(sent.single.target, NotificationTarget.listing);
    expect(sent.single.targetId, 'listing_1');
    expect(sent.single.body, contains('Campus App'));
  });

  test('rechazar no suma a nadie y le avisa', () async {
    final request = await apply('listing_1', 'user_1');
    await viewModel.load('listing_1', listingTitle: 'Campus App');

    await viewModel.reject(request.id);

    expect(viewModel.requests.single.status, JoinRequestStatus.rejected);
    expect((await listing('listing_1')).memberIds, isNot(contains('user_1')));

    final sent = harness.notificationSource.all;
    expect(sent.single.recipientId, 'user_1');
    expect(sent.single.type, NotificationType.requestRejected);
  });

  test('aceptar en un proyecto lleno muestra la regla y no avisa', () async {
    final full = await harness.listingSource.createListing(
      const Listing(
        id: '',
        title: 'Pareja',
        description: 'Dos personas',
        category: 'Tecnología',
        creatorId: 'user_2',
        creatorName: 'Mariana Ospina',
        maxMembers: 2,
        requiredSkills: [],
        memberIds: ['user_2', 'user_3'],
      ),
    );
    final request = await apply(full.id, 'user_1');
    await viewModel.load(full.id);

    await viewModel.accept(request.id);

    expect(
      viewModel.error.value,
      'El proyecto ya alcanzó su número máximo de integrantes.',
    );
    expect(viewModel.requests.single.status, JoinRequestStatus.pending);
    expect(harness.notificationSource.all, isEmpty);
  });

  test('una solicitud que ya no existe da el mensaje de respaldo', () async {
    await viewModel.load('listing_1');

    await viewModel.accept('request_missing');

    expect(viewModel.error.value, 'No se pudo actualizar la solicitud');
    expect(harness.notificationSource.all, isEmpty);
  });

  test('un fallo al cargar muestra el mensaje de respaldo', () async {
    harness = ViewModelHarness(
      user: TestUsers.mariana,
      listingSource: _FailingListingSource(),
    );
    final broken = RequestsViewModel(
      harness.listings,
      harness.publisher,
      harness.session,
    );

    await broken.load('listing_1');

    expect(broken.error.value, 'No se pudieron cargar las solicitudes');
    expect(broken.isLoading.value, isFalse);
  });
}
