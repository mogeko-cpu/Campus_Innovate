import 'package:campus_innovate/features/groups/domain/models/group.dart';
import 'package:campus_innovate/features/groups/ui/views/create_group_page.dart';
import 'package:campus_innovate/features/listings/ui/views/create_listing_page.dart';
import 'package:campus_innovate/features/listings/ui/views/listings_page.dart';
import 'package:campus_innovate/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/app_tester.dart';
import '../../../support/in_memory_group_source.dart';
import '../../../support/in_memory_listing_source.dart';
import '../../../support/test_bindings.dart';

void main() {
  tearDown(Get.reset);

  const skillHint = 'Ej. Flutter, Diseño UI, Finanzas';

  /// Somebody who does not belong to any group yet.
  const newcomer = FakeSessionService(
    currentUserId: 'user_9',
    currentUserName: 'Tomás Vélez',
    currentUserEmail: 'tomas@uninorte.edu.co',
  );

  /// Opened from the catalogue, as the app does, so publishing has a screen to
  /// go back to.
  Future<TestBindings> openForm(
    WidgetTester tester, {
    TestBindings? bindings,
  }) async {
    final graph = await tester.pumpApp(
      route: AppRoutes.listings,
      bindings: bindings,
    );
    await tester.tapText('Publicar');
    expect(find.byType(CreateListingPage), findsOneWidget);

    return graph;
  }

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  bool isSelected(WidgetTester tester, String label) =>
      tester.widget<ChoiceChip>(chip(label)).selected;

  Finder publishButton() => find.widgetWithText(FilledButton, 'Publicar proyecto');

  bool canPublish(WidgetTester tester) =>
      tester.widget<FilledButton>(publishButton()).onPressed != null;

  // By its hint in the decoration, which stays there after typing.
  Finder skillField() => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.hintText == skillHint,
      );

  Future<void> addSkill(WidgetTester tester, String skill) async {
    await tester.enterText(skillField(), skill);
    await tester.tapVisible(find.widgetWithIcon(IconButton, Icons.add));
  }

  Finder skillChip(String skill) => find.widgetWithText(InputChip, skill);

  Future<void> fillText(WidgetTester tester) async {
    await tester.enterField('Título del proyecto', 'Tutorías entre pares');
    await tester.enterField(
      'Descripción',
      'Red de estudiantes que dictan refuerzos a compañeros de primer semestre.',
    );
  }

  testWidgets('arranca con Tecnología, cuatro personas y sin habilidades',
      (tester) async {
    await openForm(tester);

    expect(find.text('Cuéntanos tu idea'), findsOneWidget);
    expect(isSelected(tester, 'Tecnología'), isTrue);
    expect(isSelected(tester, 'Impacto Social'), isFalse);
    expect(find.text('4 personas'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
    expect(canPublish(tester), isTrue);
  });

  testWidgets('con un solo grupo, ese queda elegido sin tocar nada',
      (tester) async {
    await openForm(tester);

    expect(find.text('Grupo que publica'), findsOneWidget);
    expect(isSelected(tester, 'Innovación UN'), isTrue);
  });

  testWidgets('enviar vacío muestra los mensajes de título y descripción',
      (tester) async {
    final graph = await openForm(tester);

    await tester.tapVisible(publishButton());

    expect(find.text('Escribe un título de al menos 5 caracteres'), findsOneWidget);
    expect(find.text('Describe la idea en al menos 20 caracteres'), findsOneWidget);
    expect(find.byType(CreateListingPage), findsOneWidget);
    expect(await graph.source.getListings(), hasLength(3));
  });

  testWidgets('los mínimos se cuentan sin los espacios de los bordes',
      (tester) async {
    await openForm(tester);

    await tester.enterField('Título del proyecto', '   Abcd   ');
    await tester.enterField('Descripción', '  Diecinueve letras  ');
    await tester.tapVisible(publishButton());

    expect(find.text('Escribe un título de al menos 5 caracteres'), findsOneWidget);
    expect(find.text('Describe la idea en al menos 20 caracteres'), findsOneWidget);

    await tester.enterField('Título del proyecto', 'Abcde');
    await tester.enterField('Descripción', 'Exactamente veinte c');
    await tester.tapVisible(publishButton());

    expect(find.text('Escribe un título de al menos 5 caracteres'), findsNothing);
    expect(find.text('Describe la idea en al menos 20 caracteres'), findsNothing);

    await tester.settleSnackbars();
  });

  testWidgets('elegir otra categoría deselecciona la anterior',
      (tester) async {
    await openForm(tester);

    await tester.tapVisible(chip('Arte y Cultura'));

    expect(isSelected(tester, 'Arte y Cultura'), isTrue);
    expect(isSelected(tester, 'Tecnología'), isFalse);
  });

  testWidgets('el control deslizante cambia el tamaño entre 2 y 12',
      (tester) async {
    await openForm(tester);

    await tester.drag(find.byType(Slider), const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(find.text('12 personas'), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 personas'), findsOneWidget);
  });

  testWidgets('las habilidades se agregan como chips, sin vacías ni repetidas',
      (tester) async {
    await openForm(tester);

    await addSkill(tester, '  Flutter  ');
    expect(skillChip('Flutter'), findsOneWidget);

    // The field is emptied after adding.
    expect(tester.widget<TextField>(skillField()).controller!.text, isEmpty);

    await addSkill(tester, 'Flutter');
    await addSkill(tester, '   ');
    await addSkill(tester, 'Diseño UI');

    expect(find.byType(InputChip), findsNWidgets(2));
    expect(skillChip('Diseño UI'), findsOneWidget);
  });

  testWidgets('enviar con el teclado también agrega la habilidad',
      (tester) async {
    await openForm(tester);

    await tester.enterText(skillField(), 'Finanzas');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(skillChip('Finanzas'), findsOneWidget);
  });

  testWidgets('el botón de borrar de un chip quita esa habilidad',
      (tester) async {
    await openForm(tester);

    await addSkill(tester, 'Flutter');
    await addSkill(tester, 'Python');

    await tester.tapVisible(
      find.descendant(
        of: skillChip('Flutter'),
        matching: find.byTooltip('Delete'),
      ),
    );

    expect(skillChip('Flutter'), findsNothing);
    expect(skillChip('Python'), findsOneWidget);
  });

  testWidgets('publicar guarda el proyecto con lo elegido y vuelve a la lista',
      (tester) async {
    final source = InMemoryListingSource();
    await openForm(tester, bindings: TestBindings(source: source));

    await fillText(tester);
    await tester.tapVisible(chip('Impacto Social'));
    await tester.drag(find.byType(Slider), const Offset(2000, 0));
    await tester.pumpAndSettle();
    await addSkill(tester, 'Pedagogía');
    await tester.tapVisible(publishButton());

    expect(find.byType(ListingsPage), findsOneWidget);
    expect(find.text('Proyecto publicado'), findsOneWidget);
    expect(
      find.text('"Tutorías entre pares" ya está visible para el campus'),
      findsOneWidget,
    );

    final saved = (await source.getListings()).first;
    expect(saved.title, 'Tutorías entre pares');
    expect(saved.category, 'Impacto Social');
    expect(saved.maxMembers, 12);
    expect(saved.requiredSkills, ['Pedagogía']);
    expect(saved.creatorId, 'user_1');
    expect(saved.memberIds, ['user_1']);
    expect(saved.groupId, 'group_1');
    expect(saved.groupName, 'Innovación UN');

    await tester.settleSnackbars();
  });

  testWidgets('con varios grupos hay que elegir uno antes de publicar',
      (tester) async {
    final groups = InMemoryGroupSource();
    final second = await groups.createGroup(
      Group.draft(
        name: 'Semillero Verde',
        description: 'Proyectos ambientales del campus.',
        ownerId: 'user_1',
        ownerName: 'Leonel Triana',
      ),
    );
    final source = InMemoryListingSource();

    await openForm(
      tester,
      bindings: TestBindings(source: source, groupSource: groups),
    );

    expect(isSelected(tester, 'Innovación UN'), isFalse);
    expect(isSelected(tester, 'Semillero Verde'), isFalse);

    await fillText(tester);
    await tester.tapVisible(publishButton());

    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Elige el grupo que publica este proyecto.'), findsOneWidget);
    expect(find.byType(CreateListingPage), findsOneWidget);
    await tester.settleSnackbars();

    await tester.tapVisible(chip('Semillero Verde'));
    expect(isSelected(tester, 'Semillero Verde'), isTrue);

    await tester.tapVisible(publishButton());

    expect(find.byType(ListingsPage), findsOneWidget);
    expect((await source.getListings()).first.groupId, second.id);

    await tester.settleSnackbars();
  });

  testWidgets('sin grupos lo explica, ofrece "Crear un grupo" y no deja '
      'publicar', (tester) async {
    await openForm(tester, bindings: TestBindings(session: newcomer));

    expect(
      find.text(
        'Los proyectos se publican a nombre de un grupo y todavía no '
        'tienes ninguno.',
      ),
      findsOneWidget,
    );
    expect(find.text('Crear un grupo'), findsOneWidget);
    expect(canPublish(tester), isFalse);
  });

  testWidgets('"Crear un grupo" abre ese formulario y al volver ya se puede '
      'publicar con el grupo nuevo', (tester) async {
    final groups = InMemoryGroupSource();
    await openForm(
      tester,
      bindings: TestBindings(session: newcomer, groupSource: groups),
    );

    await tester.tapText('Crear un grupo');
    expect(find.byType(CreateGroupPage), findsOneWidget);

    // Stored while the group form is open, as if it had been submitted there.
    await groups.createGroup(
      Group.draft(
        name: 'Club de Datos',
        description: 'Análisis de datos abiertos.',
        ownerId: 'user_9',
        ownerName: 'Tomás Vélez',
      ),
    );

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Crear un grupo'), findsNothing);
    expect(isSelected(tester, 'Club de Datos'), isTrue);
    expect(canPublish(tester), isTrue);
  });
}
