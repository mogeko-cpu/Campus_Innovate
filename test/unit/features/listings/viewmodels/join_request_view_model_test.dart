import 'package:campus_innovate/features/listings/domain/models/join_request.dart';
import 'package:campus_innovate/features/listings/domain/models/join_request_status.dart';
import 'package:campus_innovate/features/listings/ui/viewmodels/join_request_view_model.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_target.dart';
import 'package:campus_innovate/features/notifications/domain/models/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_listing_source.dart';
import '../../view_model_harness.dart';

class _FailingListingSource extends InMemoryListingSource {
  @override
  Future<JoinRequest> createJoinRequest(JoinRequest request) async =>
      throw StateError('join_requests');
}

void main() {
  setUpViewModelTests();

  late ViewModelHarness harness;

  Future<JoinRequestViewModel> open(String id) => start(
        JoinRequestViewModel(
          harness.listings,
          harness.publisher,
          harness.session,
        ),
        routeId: id,
      );

  Future<bool> send(JoinRequestViewModel viewModel) => viewModel.submit(
        motivation: '  Me interesa el proyecto  ',
        skills: '  Flutter, Firebase ',
        availability: ' Tardes ',
      );

  setUp(() => harness = ViewModelHarness());

  test('toma el proyecto de la ruta', () async {
    final viewModel = await open('listing_1');

    expect(viewModel.listingId, 'listing_1');
  });

  test('guarda la solicitud pendiente con los campos sin espacios', () async {
    final viewModel = await open('listing_1');

    final sent = await send(viewModel);

    expect(sent, isTrue);
    expect(viewModel.error.value, isNull);
    expect(viewModel.isSending.value, isFalse);

    final stored = await harness.listings.getRequestsForListing('listing_1');
    expect(stored, hasLength(1));
    expect(stored.single.applicantId, 'user_1');
    expect(stored.single.applicantName, 'Leonel Triana');
    expect(stored.single.motivation, 'Me interesa el proyecto');
    expect(stored.single.skills, 'Flutter, Firebase');
    expect(stored.single.availability, 'Tardes');
    expect(stored.single.status, JoinRequestStatus.pending);
  });

  test('avisa a quien creó el proyecto', () async {
    final viewModel = await open('listing_1');

    await send(viewModel);

    final sent = harness.notificationSource.all;
    expect(sent, hasLength(1));
    expect(sent.single.recipientId, 'user_2');
    expect(sent.single.type, NotificationType.requestReceived);
    expect(sent.single.target, NotificationTarget.listing);
    expect(sent.single.targetId, 'listing_1');
    expect(sent.single.body, contains('Campus App'));
  });

  test('una segunda solicitud al mismo proyecto se rechaza', () async {
    final viewModel = await open('listing_1');
    await send(viewModel);

    final again = await send(viewModel);

    expect(again, isFalse);
    expect(
      viewModel.error.value,
      'Ya enviaste una solicitud a este proyecto.',
    );
    expect(harness.notificationSource.all, hasLength(1));
  });

  test('si el proyecto no aparece para avisar, la solicitud cuenta igual',
      () async {
    final viewModel = await open('ghost');

    final sent = await send(viewModel);

    expect(sent, isTrue);
    expect(harness.notificationSource.all, isEmpty);
  });

  test('un fallo al guardar muestra el mensaje de respaldo', () async {
    harness = ViewModelHarness(listingSource: _FailingListingSource());
    final viewModel = await open('listing_1');

    final sent = await send(viewModel);

    expect(sent, isFalse);
    expect(viewModel.error.value, 'No se pudo enviar la solicitud');
    expect(viewModel.isSending.value, isFalse);
    expect(harness.notificationSource.all, isEmpty);
  });
}
