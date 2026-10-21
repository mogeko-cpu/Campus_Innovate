import 'dart:typed_data';

import 'package:campus_innovate/core/i_file_picker.dart';
import 'package:campus_innovate/features/listings/data/repositories/listing_repository.dart';
import 'package:campus_innovate/features/listings/data/repositories/project_file_repository.dart';
import 'package:campus_innovate/features/listings/domain/listing_exception.dart';
import 'package:campus_innovate/features/listings/domain/models/listing_role.dart';
import 'package:campus_innovate/features/listings/domain/models/project_file.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/in_memory_file_storage.dart';
import '../../../../support/in_memory_listing_source.dart';
import '../../../../support/in_memory_project_file_source.dart';

/// A row store whose insert fails, to check the bytes are taken back out.
class _FailingRows extends InMemoryProjectFileSource {
  @override
  Future<ProjectFile> createFile(ProjectFile file) async =>
      throw StateError('project_files');
}

Matcher _refusedWith(String message) => throwsA(
      isA<ListingException>().having((e) => e.message, 'message', message),
    );

void main() {
  // `listing_1` (Campus App) is led by user_2; the tests add user_1 as a member
  // and user_9 as its mentor. user_3 leads another project.
  const project = 'listing_1';
  const leader = 'user_2';
  const member = 'user_1';
  const mentor = 'user_9';
  const outsider = 'user_3';

  late InMemoryListingSource listings;
  late InMemoryProjectFileSource rows;
  late InMemoryFileStorage storage;
  late ProjectFileRepository repository;

  ProjectFileRepository build(InMemoryProjectFileSource source) =>
      ProjectFileRepository(source, storage, ListingRepository(listings));

  setUp(() async {
    listings = InMemoryListingSource();
    await listings.addMember(listingId: project, userId: member);
    await listings.addMember(
      listingId: project,
      userId: mentor,
      userName: 'Profesora Díaz',
      role: ListingRole.mentor,
    );

    rows = InMemoryProjectFileSource();
    storage = InMemoryFileStorage();
    repository = build(rows);
  });

  PickedFile pdf({int size = 2048, String name = 'Informe.pdf'}) =>
      PickedFile(name: name, bytes: Uint8List(size));

  Future<ProjectFile> upload({String by = member, PickedFile? file}) =>
      repository.uploadFile(
        listingId: project,
        uploaderId: by,
        uploaderName: 'Quien sube',
        file: file ?? pdf(),
      );

  group('subir', () {
    test('guarda los bytes en la carpeta del proyecto y la ficha en la tabla',
        () async {
      final file = await upload();

      final object = storage.objects[file.storageId]!;
      expect(object.fileName, 'Informe.pdf');
      expect(object.folder, 'proyectos/$project');
      expect(object.mimeType, 'application/pdf');

      expect(file.kind, ProjectFileKind.file);
      expect(file.sizeBytes, 2048);
      expect(await repository.getFiles(project), hasLength(1));
    });

    test('el mentor también comparte', () async {
      expect((await upload(by: mentor)).uploaderId, mentor);
    });

    test('alguien de afuera no sube nada', () async {
      await expectLater(
        upload(by: outsider),
        _refusedWith('Solo el equipo del proyecto puede subir archivos.'),
      );
      expect(storage.objects, isEmpty);
    });

    test('más de 10 MB no sale del teléfono', () async {
      await expectLater(
        upload(file: pdf(size: 12 * 1024 * 1024)),
        _refusedWith(
          'El archivo pesa 12 MB y el máximo es 10 MB. Para algo más grande, '
          'comparte un enlace.',
        ),
      );
      expect(storage.objects, isEmpty);
    });

    test('un archivo vacío no se sube', () async {
      await expectLater(
        upload(file: pdf(size: 0)),
        _refusedWith('El archivo está vacío.'),
      );
    });

    test('si la ficha no se guarda, los bytes se borran del bucket', () async {
      await expectLater(
        build(_FailingRows()).uploadFile(
          listingId: project,
          uploaderId: member,
          uploaderName: 'Leonel',
          file: pdf(),
        ),
        throwsA(isA<StateError>()),
      );
      expect(storage.objects, isEmpty);
    });

    test('en un proyecto que ya no existe lo dice', () async {
      await expectLater(
        repository.uploadFile(
          listingId: 'listing_borrado',
          uploaderId: member,
          uploaderName: 'Leonel',
          file: pdf(),
        ),
        _refusedWith('Este proyecto ya no existe.'),
      );
    });
  });

  group('enlaces', () {
    test('un enlace sin esquema se completa con https', () async {
      final link = await repository.addLink(
        listingId: project,
        uploaderId: leader,
        uploaderName: 'Sebastián',
        name: '  Carpeta  ',
        url: ' drive.google.com/drive/folders/abc ',
      );

      expect(link.name, 'Carpeta');
      expect(link.url, 'https://drive.google.com/drive/folders/abc');
      expect(await repository.urlToOpen(link), link.url);
    });

    test('lo que no es una dirección web se rechaza', () async {
      for (final bad in ['hola', 'ftp://archivos.com/x', 'https://', 'a b.com']) {
        await expectLater(
          repository.addLink(
            listingId: project,
            uploaderId: member,
            uploaderName: 'Leonel',
            name: 'Malo',
            url: bad,
          ),
          _refusedWith(
            'Escribe un enlace válido, por ejemplo https://drive.google.com/…',
          ),
          reason: bad,
        );
      }
    });

    test('sin nombre no se guarda', () async {
      await expectLater(
        repository.addLink(
          listingId: project,
          uploaderId: member,
          uploaderName: 'Leonel',
          name: '  ',
          url: 'https://github.com/equipo',
        ),
        _refusedWith('Ponle un nombre al enlace.'),
      );
    });
  });

  test('abrir un archivo subido pide un enlace firmado al almacenamiento',
      () async {
    final file = await upload();

    expect(
      await repository.urlToOpen(file),
      InMemoryFileStorage.linkOf(file.storageId),
    );
  });

  test('solo quien lo compartió lo elimina, bytes y ficha', () async {
    final file = await upload();

    await expectLater(
      repository.deleteFile(fileId: file.id, actorId: leader),
      _refusedWith('Solo quien compartió el archivo puede eliminarlo.'),
    );
    expect(storage.objects, hasLength(1));

    await repository.deleteFile(fileId: file.id, actorId: member);

    expect(storage.objects, isEmpty);
    expect(rows.all, isEmpty);
  });

  test('purgeListing borra las fichas y solo los bytes de quien elimina',
      () async {
    final mine = await upload(by: leader, file: pdf(name: 'mio.pdf'));
    final theirs = await upload(by: member, file: pdf(name: 'suyo.pdf'));

    await repository.purgeListing(project, actorId: leader);

    expect(rows.all, isEmpty);
    // ROBLE only lets each person delete what they uploaded.
    expect(storage.objects.keys, [theirs.storageId]);
    expect(storage.objects.containsKey(mine.storageId), isFalse);
  });

  group('normalizeUrl', () {
    test('acepta http y https, y completa el esquema que falte', () {
      expect(
        ProjectFileRepository.normalizeUrl('figma.com/file/abc'),
        'https://figma.com/file/abc',
      );
      expect(
        ProjectFileRepository.normalizeUrl('http://sitio.test:8080/x'),
        'http://sitio.test:8080/x',
      );
    });

    test('rechaza lo que no es una dirección web', () {
      for (final bad in [
        '',
        'hola',
        'mailto:a@b.com',
        'ftp://a.com',
        'https://usuario:clave@sitio.com',
      ]) {
        expect(ProjectFileRepository.normalizeUrl(bad), isNull, reason: bad);
      }
    });
  });
}
