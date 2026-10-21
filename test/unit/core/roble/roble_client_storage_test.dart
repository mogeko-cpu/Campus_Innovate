import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_innovate/core/roble/roble_client.dart';
import 'package:campus_innovate/core/roble/roble_exception.dart';
import 'package:campus_innovate/core/roble/roble_session.dart';
import 'package:campus_innovate/core/roble/roble_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../support/memory_preferences.dart';

/// The storage half of the transport: the three-step upload, the signed links,
/// and the one request that must *not* carry the session token.
void main() {
  const host = 'https://roble-api.test';
  const contract = 'contrato_test';
  const objects = '/database/$contract/storage/objects';
  const bucket = 'https://bucket.test/proyectos/firmada?firma=abc';

  final bytes = Uint8List.fromList(utf8.encode('informe final'));

  late RobleSession session;

  setUp(() async {
    session = RobleSession(MemoryPreferences());
    await session.save(
      accessToken: 'access-1',
      refreshToken: null,
      user: const RobleUser(
        id: 'user-1',
        email: 'ana@uninorte.edu.co',
        name: 'Ana Pérez',
      ),
    );
  });

  RobleClient clientWith(MockClient http) => RobleClient(
        session: session,
        httpClient: http,
        baseUrl: host,
        contractId: contract,
      );

  group('uploadFile', () {
    test('registra, sube al bucket y confirma, en ese orden', () async {
      final calls = <String>[];

      final client = clientWith(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.toString()}');

          if (request.method == 'POST' && request.url.path == objects) {
            expect(request.headers['Authorization'], 'Bearer access-1');
            expect(jsonDecode(request.body), {
              'fileName': 'informe.pdf',
              'mimeType': 'application/pdf',
              'sizeBytes': bytes.length,
              'folder': 'proyectos/p-1',
            });

            return http.Response(
              jsonEncode({'fileId': 'f-1', 'uploadUrl': bucket}),
              201,
            );
          }

          if (request.method == 'PUT') {
            // The signed URL authenticates by itself; a second credential makes
            // the bucket refuse the request.
            expect(request.headers.containsKey('Authorization'), isFalse);
            expect(request.headers['Content-Type'], 'application/pdf');
            expect(request.bodyBytes, bytes);

            return http.Response('', 200);
          }

          if (request.url.path == '$objects/f-1/complete') {
            expect(request.headers['Authorization'], 'Bearer access-1');
            return http.Response(jsonEncode({'status': 'READY'}), 201);
          }

          return http.Response('no esperado: ${request.url}', 404);
        }),
      );

      final id = await client.uploadFile(
        fileName: 'informe.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
        folder: 'proyectos/p-1',
      );

      expect(id, 'f-1');
      expect(calls, [
        'POST $host$objects',
        'PUT $bucket',
        'POST $host$objects/f-1/complete',
      ]);
    });

    test('sin tipo ni carpeta no los manda', () async {
      final client = clientWith(
        MockClient((request) async {
          if (request.url.path == objects) {
            expect(jsonDecode(request.body), {
              'fileName': 'notas',
              'sizeBytes': bytes.length,
            });

            return http.Response(
              jsonEncode({'fileId': 'f-2', 'uploadUrl': bucket}),
              201,
            );
          }

          if (request.method == 'PUT') {
            expect(request.headers.containsKey('Content-Type'), isFalse);
          }

          return http.Response('{}', 200);
        }),
      );

      expect(await client.uploadFile(fileName: 'notas', bytes: bytes), 'f-2');
    });

    test('si el bucket rechaza los bytes no se confirma nada', () async {
      var confirmed = false;

      final client = clientWith(
        MockClient((request) async {
          if (request.method == 'POST' && request.url.path == objects) {
            return http.Response(
              jsonEncode({'fileId': 'f-1', 'uploadUrl': bucket}),
              201,
            );
          }

          if (request.method == 'PUT') return http.Response('denied', 403);

          confirmed = true;
          return http.Response('{}', 201);
        }),
      );

      await expectLater(
        client.uploadFile(fileName: 'a.pdf', bytes: bytes),
        throwsA(
          isA<RobleServerException>()
              .having((e) => e.statusCode, 'statusCode', 403)
              .having(
                (e) => e.message,
                'message',
                contains('rechazó el archivo'),
              ),
        ),
      );
      expect(confirmed, isFalse);
    });

    test('sin bucket conectado el mensaje de ROBLE llega tal cual', () async {
      const reason = 'El proyecto no tiene un bucket conectado. Configúralo en '
          'Configuración → Almacenamiento.';

      final client = clientWith(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'message': reason}),
            400,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await expectLater(
        client.uploadFile(fileName: 'a.pdf', bytes: bytes),
        throwsA(
          isA<RobleBadRequestException>().having(
            (e) => e.message,
            'message',
            reason,
          ),
        ),
      );
    });

    test('una respuesta sin URL de subida es un error del servidor', () async {
      final client = clientWith(
        MockClient(
          (request) async => http.Response(jsonEncode({'fileId': 'f-1'}), 201),
        ),
      );

      await expectLater(
        client.uploadFile(fileName: 'a.pdf', bytes: bytes),
        throwsA(isA<RobleServerException>()),
      );
    });

    test('sin red hacia el bucket lo dice en palabras del usuario', () async {
      final client = clientWith(
        MockClient((request) async {
          if (request.method == 'PUT') {
            throw http.ClientException('XMLHttpRequest error.');
          }

          return http.Response(
            jsonEncode({'fileId': 'f-1', 'uploadUrl': bucket}),
            201,
          );
        }),
      );

      await expectLater(
        client.uploadFile(fileName: 'a.pdf', bytes: bytes),
        throwsA(
          isA<RobleNetworkException>().having(
            (e) => e.message,
            'message',
            contains('almacenamiento del proyecto'),
          ),
        ),
      );
    });
  });

  group('fileDownloadUrl', () {
    test('devuelve el enlace firmado', () async {
      final client = clientWith(
        MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '$objects/f-1');
          expect(request.headers['Authorization'], 'Bearer access-1');

          return http.Response(
            jsonEncode({'downloadUrl': 'https://bucket.test/f-1?firma=x'}),
            200,
          );
        }),
      );

      expect(
        await client.fileDownloadUrl('f-1'),
        'https://bucket.test/f-1?firma=x',
      );
    });

    test('sin enlace en la respuesta falla en vez de abrir nada', () async {
      final client = clientWith(
        MockClient((request) async => http.Response('{}', 200)),
      );

      await expectLater(
        client.fileDownloadUrl('f-1'),
        throwsA(isA<RobleServerException>()),
      );
    });
  });

  test('deleteFile manda un DELETE al objeto', () async {
    String? seen;

    final client = clientWith(
      MockClient((request) async {
        seen = '${request.method} ${request.url.path}';
        return http.Response('{}', 200);
      }),
    );

    await client.deleteFile('f-1');

    expect(seen, 'DELETE $objects/f-1');
  });

  test('deleteFile de algo ajeno es un 403 de ROBLE', () async {
    final client = clientWith(
      MockClient(
        (request) async => http.Response(
          jsonEncode({'message': 'Solo quien subió el archivo puede borrarlo'}),
          403,
        ),
      ),
    );

    await expectLater(
      client.deleteFile('f-1'),
      throwsA(isA<RobleForbiddenException>()),
    );
  });
}
