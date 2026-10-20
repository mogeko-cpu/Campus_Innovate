import 'package:campus_innovate/features/listings/domain/models/listing.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_stats.dart';
import 'package:campus_innovate/features/listings/ui/widgets/listing_card.dart';
import 'package:campus_innovate/features/listings/ui/widgets/listing_stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

void main() {
  tearDown(Get.reset);

  const base = Listing(
    id: 'listing_9',
    title: 'Laboratorio de Prototipos',
    description: 'Un espacio para construir prototipos rápidos con estudiantes '
        'de varias carreras y presentarlos en la feria del semestre.',
    category: 'Emprendimiento',
    creatorId: 'user_7',
    creatorName: 'Camila Rojas',
    maxMembers: 4,
    requiredSkills: ['Arduino', 'Pitch'],
    memberIds: ['user_7'],
  );

  Future<void> pump(
    WidgetTester tester,
    Listing listing, {
    ListingStats? stats,
    Widget? leading,
    VoidCallback? onTap,
  }) async {
    tester.useTallSurface();
    await tester.pumpWidget(
      wrapWidget(
        ListingCard(
          listing: listing,
          stats: stats,
          leading: leading,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  testWidgets('muestra título, categoría, creador, habilidades y ocupación',
      (tester) async {
    await pump(tester, base);

    expect(find.text('Laboratorio de Prototipos'), findsOneWidget);
    expect(find.text('Emprendimiento'), findsOneWidget);
    expect(find.text('Camila Rojas'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Arduino'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Pitch'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('3 cupos libres'), findsOneWidget);
  });

  testWidgets('la descripción larga se corta en dos líneas', (tester) async {
    await pump(tester, base);

    final description = tester.widget<Text>(find.text(base.description));
    expect(description.maxLines, 2);
    expect(description.overflow, TextOverflow.ellipsis);
  });

  testWidgets('con un solo cupo lo dice en singular', (tester) async {
    await pump(
      tester,
      base.copyWith(memberIds: ['user_7', 'user_8', 'user_9']),
    );

    expect(find.text('1 cupo libre'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
  });

  testWidgets('un equipo lleno muestra "Equipo completo" en vez de cupos',
      (tester) async {
    await pump(tester, base.copyWith(maxMembers: 2, memberIds: ['a', 'b']));

    expect(find.text('Equipo completo'), findsOneWidget);
    expect(find.textContaining('cupo'), findsNothing);
  });

  testWidgets('sin habilidades no dibuja chips', (tester) async {
    await pump(tester, base.copyWith(requiredSkills: const []));

    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('muestra el grupo que publica, o un genérico si no tiene nombre',
      (tester) async {
    await pump(
      tester,
      base.copyWith(groupId: 'group_1', groupName: 'Innovación UN'),
    );
    expect(find.text('Innovación UN'), findsOneWidget);

    await pump(tester, base.copyWith(groupId: 'group_1'));
    expect(find.text('Grupo del campus'), findsOneWidget);
  });

  testWidgets('un proyecto sin grupo no muestra la fila del grupo',
      (tester) async {
    await pump(tester, base);

    expect(find.byIcon(Icons.groups_outlined), findsNothing);
    expect(find.text('Grupo del campus'), findsNothing);
  });

  testWidgets('los contadores aparecen solo cuando se pasan',
      (tester) async {
    await pump(tester, base);
    expect(find.byType(ListingStatsRow), findsNothing);

    await pump(
      tester,
      base,
      stats: const ListingStats(likes: 7, dislikes: 1, views: 12, comments: 3),
    );
    expect(find.byType(ListingStatsRow), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('el widget inicial va antes de la categoría', (tester) async {
    await pump(tester, base, leading: const Text('#1'));

    expect(find.text('#1'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('#1')).dx,
      lessThan(tester.getTopLeft(find.text('Emprendimiento')).dx),
    );
  });

  testWidgets('tocar la tarjeta llama a onTap', (tester) async {
    var taps = 0;

    await pump(tester, base, onTap: () => taps++);
    await tester.tap(find.text('Laboratorio de Prototipos'));
    await tester.pump();

    expect(taps, 1);
  });
}
