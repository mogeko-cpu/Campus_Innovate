import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/domain/models/group_member.dart';
import 'package:campus_innovate/features/groups/ui/widgets/group_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../../support/app_tester.dart';

const _group = Group(
  id: 'group_1',
  name: 'Innovación UN',
  description: 'Grupo que arma equipos para concursos y semilleros.',
  ownerId: 'user_1',
  ownerName: 'Leonel Triana',
  members: [
    GroupMember(groupId: 'group_1', userId: 'user_1', userName: 'Leonel'),
    GroupMember(groupId: 'group_1', userId: 'user_2', userName: 'Mariana'),
    GroupMember(groupId: 'group_1', userId: 'user_3', userName: 'Andrés'),
  ],
);

void main() {
  tearDown(Get.reset);

  testWidgets('muestra nombre, creador, descripción, integrantes y proyectos',
      (tester) async {
    await tester.pumpWidget(
      wrapWidget(GroupCard(group: _group, projectCount: 7, onTap: () {})),
    );

    expect(find.text('Innovación UN'), findsOneWidget);
    expect(find.text('Leonel Triana'), findsOneWidget);
    expect(
      find.text('Grupo que arma equipos para concursos y semilleros.'),
      findsOneWidget,
    );
    // Three members and seven projects, each next to its own icon.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('sin insignia no muestra ninguna etiqueta de relación',
      (tester) async {
    await tester.pumpWidget(
      wrapWidget(GroupCard(group: _group, projectCount: 0, onTap: () {})),
    );

    expect(find.text('Creador'), findsNothing);
    expect(find.text('Integrante'), findsNothing);
    expect(find.text('Solicitud pendiente'), findsNothing);
  });

  testWidgets('con insignia la muestra junto al nombre', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        GroupCard(
          group: _group,
          projectCount: 0,
          badge: 'Solicitud pendiente',
          onTap: () {},
        ),
      ),
    );

    expect(find.text('Solicitud pendiente'), findsOneWidget);
  });

  testWidgets('sin descripción no deja un texto vacío', (tester) async {
    await tester.pumpWidget(
      wrapWidget(
        GroupCard(
          group: _group.copyWith(description: ''),
          projectCount: 2,
          onTap: () {},
        ),
      ),
    );

    // Name, owner, member count and project count: nothing else.
    expect(find.text(''), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('tocar la tarjeta llama a onTap', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      wrapWidget(
        GroupCard(group: _group, projectCount: 0, onTap: () => taps++),
      ),
    );

    await tester.tap(find.text('Innovación UN'));
    await tester.pump();

    expect(taps, 1);
  });
}
