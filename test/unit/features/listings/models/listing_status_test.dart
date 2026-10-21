import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('los estados van de la idea al proyecto terminado, en ese orden', () {
    expect(ListingStatus.values, [
      ListingStatus.idea,
      ListingStatus.inProgress,
      ListingStatus.paused,
      ListingStatus.done,
    ]);
  });

  test('cada estado tiene su etiqueta en español', () {
    expect(ListingStatus.idea.label, 'Idea');
    expect(ListingStatus.inProgress.label, 'En curso');
    expect(ListingStatus.paused.label, 'Pausado');
    expect(ListingStatus.done.label, 'Terminado');
  });

  group('acceptsRequests', () {
    test('una idea y un proyecto en curso reciben solicitudes', () {
      expect(ListingStatus.idea.acceptsRequests, isTrue);
      expect(ListingStatus.inProgress.acceptsRequests, isTrue);
    });

    test('uno pausado o terminado no las recibe', () {
      expect(ListingStatus.paused.acceptsRequests, isFalse);
      expect(ListingStatus.done.acceptsRequests, isFalse);
    });
  });

  group('fromName', () {
    test('lee de vuelta el nombre que se guarda en la columna', () {
      for (final status in ListingStatus.values) {
        expect(ListingStatus.fromName(status.name), status);
      }
    });

    test('una fila sin estado es una idea, como lo era todo antes', () {
      expect(ListingStatus.fromName(null), ListingStatus.idea);
      expect(ListingStatus.fromName(''), ListingStatus.idea);
    });

    test('un valor desconocido se lee como idea y no oculta el proyecto', () {
      expect(ListingStatus.fromName('archived'), ListingStatus.idea);
      // Names are compared exactly, as they are stored.
      expect(ListingStatus.fromName('DONE'), ListingStatus.idea);
    });
  });
}
