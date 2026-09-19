// Siembra los proyectos de demostración en ROBLE.
//
//   dart run tool/seed_roble.dart
//
// Pide el correo y la contraseña de ROBLE por consola, o los toma de las
// variables de entorno ROBLE_EMAIL y ROBLE_PASSWORD. La contraseña no se
// escribe en ningún archivo ni queda en el historial del shell si se usa el
// modo interactivo.
//
// Es idempotente: antes de insertar consulta si ya existe un proyecto con el
// mismo título, así que correrlo dos veces no duplica nada.
//
// Otro contrato:
//
//   dart run --define=ROBLE_CONTRACT_ID=otro_contrato_ab12cd34 tool/seed_roble.dart
import 'dart:io';

import 'package:campus_innovate/core/i_local_preferences.dart';
import 'package:campus_innovate/core/roble/roble_client.dart';
import 'package:campus_innovate/core/roble/roble_config.dart';
import 'package:campus_innovate/core/roble/roble_exception.dart';
import 'package:campus_innovate/core/roble/roble_session.dart';

/// Los tres proyectos con los que arranca la aplicación.
///
/// El dueño de cada uno es un estudiante ficticio y **no** la cuenta que corre
/// el script: las columnas `creator_id` y `user_id` son `text` y no hay llaves
/// foráneas, así que el id no tiene que existir en ROBLE. Es a propósito —
/// sembrarlos a nombre propio dejaría a quien prueba la app como integrante de
/// los tres y sin ningún proyecto al que pueda solicitar unirse.
const _demoListings = [
  {
    'title': 'Campus App',
    'description':
        'Aplicación para mejorar la experiencia de los estudiantes dentro del '
            'campus: horarios, mapas y notificaciones en un solo lugar.',
    'category': 'Tecnología',
    'creator_id': 'demo_sebastian',
    'creator_name': 'Sebastián González',
    'max_members': 4,
    'required_skills': ['Flutter', 'Diseño UI'],
  },
  {
    'title': 'Huerta Universitaria',
    'description':
        'Proyecto de sostenibilidad para cultivar alimentos en zonas verdes '
            'del campus y abastecer la cafetería con producto local.',
    'category': 'Sostenibilidad',
    'creator_id': 'demo_mariana',
    'creator_name': 'Mariana Ospina',
    'max_members': 6,
    'required_skills': ['Biología', 'Gestión de proyectos'],
    // Un integrante además del creador, para que la tarjeta no muestre siempre
    // "1 de N".
    'extra_members': ['demo_julian'],
  },
  {
    'title': 'Semillero de Robótica',
    'description':
        'Construcción de un robot autónomo para competir en el torneo '
            'interuniversitario del próximo semestre.',
    'category': 'Investigación',
    'creator_id': 'demo_andres',
    'creator_name': 'Andrés Betancur',
    'max_members': 5,
    'required_skills': ['Electrónica', 'Python', 'Impresión 3D'],
  },
];

Future<void> main() async {
  stdout.writeln('ROBLE: ${RobleConfig.baseUrl}');
  stdout.writeln('Contrato: ${RobleConfig.contractId}');
  stdout.writeln('');

  final client = RobleClient(session: RobleSession(_MemoryPreferences()));

  try {
    final email = _ask('Correo de ROBLE', variable: 'ROBLE_EMAIL');
    final password = _askSecret('Contraseña', variable: 'ROBLE_PASSWORD');

    final user = await client.login(email: email, password: password);
    stdout.writeln('\nSesión iniciada como ${user.name} <${user.email}>.\n');

    var created = 0;

    for (final listing in _demoListings) {
      final title = listing['title'] as String;

      // Sin UNIQUE en `title` la única defensa contra duplicar es preguntar.
      final existing = await client.read(
        RobleConfig.listingsTable,
        filters: {'title': title},
      );

      if (existing.isNotEmpty) {
        stdout.writeln('· $title ya estaba en ROBLE, se omite.');
        continue;
      }

      final row = await client.insertOne(RobleConfig.listingsTable, {
        'title': title,
        'description': listing['description'],
        'category': listing['category'],
        'creator_id': listing['creator_id'],
        'creator_name': listing['creator_name'],
        'max_members': listing['max_members'],
        'required_skills': listing['required_skills'],
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      final id = row['_id']?.toString();

      if (id == null || id.isEmpty) {
        stderr.writeln(
          '· $title se insertó pero ROBLE no devolvió su _id: revisa la tabla '
          'en la consola antes de volver a correr el script.',
        );
        continue;
      }

      final members = [
        listing['creator_id'] as String,
        ...(listing['extra_members'] as List? ?? const []).cast<String>(),
      ];

      for (final member in members) {
        await client.insertOne(RobleConfig.listingMembersTable, {
          'listing_id': id,
          'user_id': member,
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      created++;
      stdout.writeln('· $title creado con ${members.length} integrante(s).');
    }

    stdout.writeln(
      '\nListo: $created proyecto(s) nuevo(s) de ${_demoListings.length}.',
    );
  } on RobleException catch (error) {
    // El mensaje de RobleException ya está escrito para leerse; el stack no
    // aporta nada a quien corre un script de siembra.
    stderr.writeln('\nERROR: ${error.message}');
    exitCode = 1;
  } finally {
    client.close();
  }
}

/// Lee un valor de [variable] o, si no está, lo pregunta por consola.
String _ask(String label, {required String variable}) {
  final fromEnvironment = Platform.environment[variable];

  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    stdout.writeln('$label: $fromEnvironment (de $variable)');
    return fromEnvironment;
  }

  stdout.write('$label: ');
  final value = stdin.readLineSync() ?? '';

  if (value.isEmpty) {
    stderr.writeln('$label es obligatorio.');
    exit(2);
  }

  return value;
}

/// Igual que [_ask] pero sin mostrar lo que se escribe.
///
/// La contraseña nunca se guarda: ni en un archivo del repositorio (que está en
/// OneDrive y se sincroniza) ni en `RobleSession`, cuyo respaldo aquí vive solo
/// en memoria y muere con el proceso.
String _askSecret(String label, {required String variable}) {
  final fromEnvironment = Platform.environment[variable];

  if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
    stdout.writeln('$label: (de $variable)');
    return fromEnvironment;
  }

  final echoWasOn = stdin.echoMode;

  try {
    stdin.echoMode = false;
    stdout.write('$label: ');
    final value = stdin.readLineSync() ?? '';
    stdout.writeln('');

    if (value.isEmpty) {
      stderr.writeln('$label es obligatoria.');
      exit(2);
    }

    return value;
  } on StdinException {
    // Sin terminal (una tubería, un runner de CI) no se puede apagar el eco:
    // mejor exigir la variable de entorno que mostrar la contraseña.
    stderr.writeln(
      'No hay terminal para pedir la contraseña sin mostrarla. '
      'Exporta $variable y vuelve a correr el script.',
    );
    exit(2);
  } finally {
    stdin.echoMode = echoWasOn;
  }
}

/// [ILocalPreferences] en memoria: el script no necesita — ni debe — dejar el
/// token en el disco.
class _MemoryPreferences implements ILocalPreferences {
  final Map<String, Object> _values = {};

  T? _read<T>(String key) {
    final value = _values[key];

    return value is T ? value : null;
  }

  @override
  Future<String?> getString(String key) async => _read<String>(key);

  @override
  Future<void> setString(String key, String value) async => _values[key] = value;

  @override
  Future<int?> getInt(String key) async => _read<int>(key);

  @override
  Future<void> setInt(String key, int value) async => _values[key] = value;

  @override
  Future<double?> getDouble(String key) async => _read<double>(key);

  @override
  Future<void> setDouble(String key, double value) async => _values[key] = value;

  @override
  Future<bool?> getBool(String key) async => _read<bool>(key);

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;

  @override
  Future<List<String>?> getStringList(String key) async =>
      _read<List<String>>(key);

  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}
