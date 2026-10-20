import 'package:campus_innovate/features/groups/domain/group_exception.dart';
import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/ui/views/create_group_page.dart';
import 'package:campus_innovate/features/groups/ui/views/groups_page.dart';
import 'package:campus_innovate/features/groups/ui/widgets/group_card.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_group_source.dart';
import '../../../support/test_bindings.dart';

/// A source that refuses every new group, the way ROBLE does past its limit.
class _RefusingGroupSource extends InMemoryGroupSource {
  @override
  Future<Group> createGroup(Group group) async =>
      throw const GroupException('Espera 40 segundos antes de intentar de nuevo.');
}

Finder get _submit => find.widgetWithText(FilledButton, 'Crear grupo');

void main() {
  tearDown(Get.reset);

  /// Opens the form from the groups screen, so that leaving it has somewhere
  /// to go back to.
  Future<InMemoryGroupSource> openForm(
    WidgetTester tester, {
    InMemoryGroupSource? groups,
  }) async {
    final source = groups ?? InMemoryGroupSource();

    await tester.pumpApp(
      route: AppRoutes.groups,
      bindings: TestBindings(groupSource: source),
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    return source;
  }

  testWidgets('muestra el formulario con sus dos campos', (tester) async {
    await openForm(tester);

    expect(find.byType(CreateGroupPage), findsOneWidget);
    expect(find.text('Arma tu equipo'), findsOneWidget);
    expect(find.text('Nombre del grupo'), findsOneWidget);
    expect(find.text('Descripción'), findsOneWidget);
    expect(_submit, findsOneWidget);
  });

  testWidgets('vacío no se envía y explica los dos campos', (tester) async {
    final groups = await openForm(tester);

    await tester.tapVisible(_submit);

    expect(
      find.text('Escribe un nombre de al menos 3 caracteres'),
      findsOneWidget,
    );
    expect(
      find.text('Describe el grupo en al menos 15 caracteres'),
      findsOneWidget,
    );
    expect(find.byType(CreateGroupPage), findsOneWidget);
    expect(await groups.getGroups(), hasLength(1));
  });

  testWidgets('un nombre corto y una descripción corta no pasan',
      (tester) async {
    await openForm(tester);

    // Spaces do not count: the validators trim.
    await tester.enterField('Nombre del grupo', '  ab  ');
    await tester.enterField('Descripción', 'Muy corta     ');
    await tester.tapVisible(_submit);

    expect(
      find.text('Escribe un nombre de al menos 3 caracteres'),
      findsOneWidget,
    );
    expect(
      find.text('Describe el grupo en al menos 15 caracteres'),
      findsOneWidget,
    );
  });

  testWidgets('con datos válidos crea el grupo, vuelve y lo lista como mío',
      (tester) async {
    final groups = await openForm(tester);

    await tester.enterField('Nombre del grupo', '  Semillero de Robótica ');
    await tester.enterField(
      'Descripción',
      'Construimos robots para el torneo interuniversitario.',
    );
    await tester.tapVisible(_submit);

    expect(find.byType(CreateGroupPage), findsNothing);
    expect(find.byType(GroupsPage), findsOneWidget);
    expect(find.text('Grupo creado'), findsOneWidget);
    expect(
      find.text('"Semillero de Robótica" ya puede publicar proyectos'),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(GroupCard, 'Semillero de Robótica'),
        matching: find.text('Creador'),
      ),
      findsOneWidget,
    );

    // Stored trimmed, owned by whoever is signed in.
    final created = (await groups.getGroups()).first;
    expect(created.name, 'Semillero de Robótica');
    expect(created.ownerId, 'user_1');
    expect(created.memberIds, ['user_1']);

    await tester.settleSnackbars();
  });

  testWidgets('si el servidor lo rechaza se queda y muestra su mensaje',
      (tester) async {
    await openForm(tester, groups: _RefusingGroupSource());

    await tester.enterField('Nombre del grupo', 'Semillero de Robótica');
    await tester.enterField(
      'Descripción',
      'Construimos robots para el torneo interuniversitario.',
    );
    await tester.tapVisible(_submit);

    expect(find.byType(CreateGroupPage), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
    expect(
      find.text('Espera 40 segundos antes de intentar de nuevo.'),
      findsOneWidget,
    );
    // The button is usable again for a retry.
    expect(tester.widget<FilledButton>(_submit).onPressed, isNotNull);

    await tester.settleSnackbars();
  });
}
