import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_status.dart';
import 'package:campus_innovate/features/listings/ui/widgets/listing_card.dart';
import 'package:campus_innovate/features/listings/ui/widgets/status_chip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';

const _base = Listing(
  id: 'listing_9',
  title: 'Laboratorio de Prototipos',
  description: 'Un espacio para construir prototipos rápidos con estudiantes '
      'de varias carreras.',
  category: 'Emprendimiento',
  creatorId: 'user_7',
  creatorName: 'Camila Rojas',
  maxMembers: 4,
  requiredSkills: ['Arduino'],
  memberIds: ['user_7'],
);

const _fullTeam = ['user_7', 'user_8', 'user_9', 'user_10'];

void main() {
  tearDown(Get.reset);

  Future<void> pump(WidgetTester tester, Listing listing) async {
    tester.useTallSurface();
    await tester.pumpWidget(wrapWidget(ListingCard(listing: listing, onTap: () {})));
  }

  testWidgets('una idea no lleva pastilla de estado y muestra los cupos',
      (tester) async {
    await pump(tester, _base);

    expect(find.byType(StatusChip), findsNothing);
    expect(find.text('Idea'), findsNothing);
    expect(find.text('3 cupos libres'), findsOneWidget);
  });

  testWidgets('un proyecto en curso muestra su estado y sigue con cupos',
      (tester) async {
    await pump(tester, _base.copyWith(status: ListingStatus.inProgress));

    expect(find.byType(StatusChip), findsOneWidget);
    expect(find.text('En curso'), findsOneWidget);
    expect(find.text('3 cupos libres'), findsOneWidget);
  });

  testWidgets('con un solo cupo lo dice en singular', (tester) async {
    await pump(
      tester,
      _base.copyWith(
        status: ListingStatus.inProgress,
        memberIds: const ['user_7', 'user_8', 'user_9'],
      ),
    );

    expect(find.text('1 cupo libre'), findsOneWidget);
  });

  testWidgets('en curso y lleno dice "Equipo completo"', (tester) async {
    await pump(
      tester,
      _base.copyWith(status: ListingStatus.inProgress, memberIds: _fullTeam),
    );

    expect(find.text('Equipo completo'), findsOneWidget);
    expect(find.text('4/4'), findsOneWidget);
  });

  for (final status in [ListingStatus.paused, ListingStatus.done]) {
    testWidgets('"${status.label}" muestra su estado y ya no ofrece cupos',
        (tester) async {
      await pump(tester, _base.copyWith(status: status));

      expect(find.byType(StatusChip), findsOneWidget);
      expect(find.text(status.label), findsOneWidget);
      expect(find.textContaining('cupo'), findsNothing);
      expect(find.text('Equipo completo'), findsNothing);
      // The headcount is still there; only the recruiting badge goes.
      expect(find.text('1/4'), findsOneWidget);
    });
  }

  testWidgets('pausado y lleno tampoco dice "Equipo completo"', (tester) async {
    await pump(
      tester,
      _base.copyWith(status: ListingStatus.paused, memberIds: _fullTeam),
    );

    expect(find.text('Equipo completo'), findsNothing);
  });
}
