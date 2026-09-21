# ROBLE

Campus Innovate guarda sus datos en **ROBLE**, el servicio de OPENLAB de la
Universidad del Norte: autenticación con JWT y una base PostgreSQL administrada
que se consume por REST. No hay servidor propio ni datos en memoria.

| | |
|---|---|
| API | `https://roble-api.openlab.uninorte.edu.co` |
| Consola | `https://roble.openlab.uninorte.edu.co` |
| Contrato | `campus_innov_0ee3af93b1` |

Los dos primeros valores y el contrato están en
[`lib/core/roble/roble_config.dart`](../lib/core/roble/roble_config.dart). El
`contractId` **no es un secreto**: aparece en el encabezado de la consola y viaja
en la ruta de cada petición, por eso está compilado en el código. Las
contraseñas y los tokens no aparecen nunca ahí — los escribe la persona que usa
la app y viven en `RobleSession`.

Para apuntar a otro contrato sin tocar el código:

```bash
flutter run --dart-define=ROBLE_CONTRACT_ID=otro_contrato_ab12cd34
```

---

## Esquema

Nueve tablas, creadas desde la Consola SQL de ROBLE. La columna `_id` la agrega
ROBLE si falta, y siempre es `uuid`.

Las tres primeras son las originales; las seis restantes se agregaron con
[`sql/2026_grupos_y_valoraciones.sql`](sql/2026_grupos_y_valoraciones.sql), que
es el archivo que hay que correr en la consola antes de abrir la app con estas
funciones.

```sql
CREATE TABLE listings (
  _id UUID PRIMARY KEY NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  title text NOT NULL,
  description text NOT NULL,
  category text NOT NULL,
  creator_id text NOT NULL,
  creator_name text NOT NULL,
  max_members int4 NOT NULL,
  required_skills jsonb,
  created_at timestamp NOT NULL
);

CREATE TABLE listing_members (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL,
  user_id text NOT NULL,
  joined_at timestamp NOT NULL,
  UNIQUE (listing_id, user_id)
);

CREATE TABLE join_requests (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL,
  applicant_id text NOT NULL,
  applicant_name text NOT NULL,
  motivation text NOT NULL,
  skills text NOT NULL,
  availability text NOT NULL,
  status text NOT NULL,
  created_at timestamp NOT NULL,
  UNIQUE (listing_id, applicant_id)
);
```

Tres decisiones que conviene entender antes de cambiar algo:

- **Los integrantes son filas, no un arreglo.** Guardar los ids dentro de
  `listings` como `jsonb` obligaría a leer-modificar-escribir, y dos personas
  entrando el mismo segundo se sobrescribirían. Una fila por integrante hace que
  unirse sea un solo `INSERT` que nadie puede perder.
- **Los dos `UNIQUE` compuestos son la única defensa real** contra unirse dos
  veces o postularse dos veces. La app también revisa antes, pero esa revisión
  puede quedar obsoleta entre la lectura y la escritura; la restricción no.
- **No hay llaves foráneas** (ROBLE no las ofrece), así que `listing_id` puede
  sobrevivir al proyecto que apuntaba. Las pantallas tratan una fila huérfana
  como inexistente en lugar de fallar.

`status` es `text` y guarda el nombre del enum (`pending`, `accepted`,
`rejected`). Un valor desconocido se lee como `pending`, el estado que deja la
solicitud visible y accionable.

### Grupos

```sql
CREATE TABLE groups (
  _id UUID PRIMARY KEY NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text NOT NULL,
  owner_id text NOT NULL,
  owner_name text NOT NULL,
  created_at timestamp NOT NULL
);

CREATE TABLE group_members (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  group_id text NOT NULL,
  user_id text NOT NULL,
  user_name text NOT NULL,
  joined_at timestamp NOT NULL,
  UNIQUE (group_id, user_id)
);

CREATE TABLE group_requests (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  group_id text NOT NULL,
  applicant_id text NOT NULL,
  applicant_name text NOT NULL,
  message text NOT NULL,
  status text NOT NULL,
  created_at timestamp NOT NULL,
  UNIQUE (group_id, applicant_id)
);

ALTER TABLE listings ADD COLUMN group_id text;
ALTER TABLE listings ADD COLUMN group_name text;
```

Los integrantes de un grupo son filas por la misma razón que los de un proyecto:
sin transacciones, un arreglo `jsonb` obligaría a leer-modificar-escribir y dos
aceptaciones simultáneas se pisarían.

`group_id` en `listings` puede quedar nulo: las filas publicadas antes de que
existieran los grupos siguen siendo proyectos reales, y las pantallas las
muestran como "Publicado sin grupo" en lugar de esconderlas. `group_name` viaja
copiado porque ROBLE no hace `JOIN`, así que una tarjeta que mostrara el nombre
del grupo necesitaría una lectura por proyecto.

**Eliminar un grupo no elimina sus proyectos.** La app se niega mientras el grupo
tenga alguno: otras personas se postularon a esos proyectos y pueden estar en sus
equipos, así que borrarlos como efecto secundario de ordenar un grupo sería una
sorpresa. El dueño elimina primero cada proyecto, desde la pantalla del proyecto.

### Valoraciones, vistas y comentarios

```sql
CREATE TABLE listing_reactions (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL,
  group_id text NOT NULL,
  user_id text NOT NULL,
  value int4 NOT NULL,
  created_at timestamp NOT NULL,
  UNIQUE (listing_id, user_id)
);

CREATE TABLE listing_views (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL,
  group_id text NOT NULL,
  user_id text NOT NULL,
  viewed_at timestamp NOT NULL,
  UNIQUE (listing_id, user_id)
);

CREATE TABLE listing_comments (
  _id UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  listing_id text NOT NULL,
  group_id text NOT NULL,
  author_id text NOT NULL,
  author_name text NOT NULL,
  body text NOT NULL,
  created_at timestamp NOT NULL
);
```

Tres decisiones que conviene entender antes de cambiar algo aquí:

- **Los contadores son filas, no columnas.** Un `likes int4` en `listings`
  obligaría a `likes = likes + 1`, que sin escrituras condicionales es
  leer-modificar-escribir: dos personas votando en el mismo segundo perderían un
  voto. Contar filas no se puede desincronizar.
- **`value` es `1` o `-1`**, así el puntaje del ranking es una suma y nunca una
  segunda consulta. El `UNIQUE (listing_id, user_id)` es lo que impide votar dos
  veces; cambiar de opinión es un `UPDATE` de la fila que ya es tuya, y quitar el
  voto es borrarla.
- **Las vistas son únicas por persona.** Volver a abrir un proyecto no suma: la
  fila ya existe y el `UNIQUE` la rechaza. Eso también evita que la tabla crezca
  sin límite, que es lo que pasaría guardando cada visita.

`group_id` se repite en las tres tablas a propósito. Es redundante con
`listings.group_id`, pero `read` solo filtra por igualdad: con esa columna, una
pantalla de grupo puede leer todos los comentarios de sus proyectos en una sola
petición, y la actividad de un grupo nunca se puede contar para otro.

---

## Lo que ROBLE no hace

Esto es lo que explica la forma del código, y no es negociable desde la app:

| Limitación | Consecuencia en el código |
|---|---|
| `read` filtra **solo por igualdad** — sin `LIKE`, sin rangos, sin orden, sin paginación | Buscar y ordenar ocurre en Dart, sobre la tabla completa. `getListings()` hace dos lecturas completas y agrupa los integrantes en memoria. |
| **Sin transacciones** | Dos filas relacionadas son dos peticiones que pueden fallar a medias. El orden de escritura se elige para dejar un estado recuperable. |
| **Sin escrituras condicionales** | El tope de `max_members` es orientativo: entre la revisión y el `INSERT` otro dispositivo puede tomar el último puesto, así que un proyecto puede quedar con un integrante de más. Aceptado a propósito — la alternativa es un `INSERT … SELECT` con bloqueo, demasiada maquinaria para un grupo que puede sacar a alguien a mano. |
| `_id` es `uuid` | Comparar esa columna con algo que no sea un UUID falla **dentro** de PostgreSQL y ROBLE responde **500**. `RobleClient.isRowId` filtra antes: un id mal formado se trata como "no existe" y no llega a salir una petición. |

### Fallas parciales y cómo quedan

- **Publicar un proyecto** son dos escrituras: la fila en `listings` y la
  membresía del creador. Si la segunda falla, la primera se borra: un proyecto
  sin nadie adentro no tiene pantalla que lo arregle. El usuario ve el error
  original y puede volver a publicar.
- **Aceptar una solicitud** también son dos: agregar al integrante y marcar la
  solicitud como aceptada. Se hace en ese orden a propósito. Si falla la
  segunda, la persona ya está en el equipo y la solicitud sigue pendiente —
  visible y se puede reintentar. Al revés quedaría una solicitud aceptada sin
  integrante, invisible para todos.
- **Unirse dos veces** no es un error: si el `UNIQUE` rechaza el `INSERT`, ser
  integrante es justo lo que quería quien llamó, así que cuenta como éxito.
  Detectarlo exige leer el mensaje de PostgreSQL, porque ROBLE lo reenvía sin
  código propio y el estado puede ser 400 o 500 — si cambia la redacción se
  pierde el mensaje amable, nunca la integridad de los datos.

---

## Límites de tasa

Por IP, y una IP es toda la red del campus o del salón:

| Endpoint | Límite |
|---|---|
| `signup` | **5 por hora** |
| `login` | **10 cada 15 minutos** |
| Todo lo demás | 100 por minuto |

Dos consecuencias en el código:

1. **La sesión se persiste** en almacenamiento cifrado
   (`flutter_secure_storage`) y se restaura al arrancar. Una app que iniciara
   sesión en cada lanzamiento dejaría a un salón entero sin poder entrar.
2. **La contraseña se valida antes de pedir la cuenta**
   ([`roble_password_policy.dart`](../lib/core/roble/roble_password_policy.dart)):
   una contraseña que ROBLE rechace gasta uno de los 5 intentos igual. La regla
   es 8 caracteres o más, una mayúscula, una minúscula, un número y uno de
   `! @ # $ _ - .` — `%` o `*` no sirven aunque parezcan más fuertes.

Cuando ROBLE responde **429** envía el encabezado `X-Ratelimit-Reset` con los
segundos que faltan; `RobleRateLimitException.retryAfter` lo conserva y el
mensaje que ve el usuario los menciona.

---

## Las clases

En [`lib/core/roble/`](../lib/core/roble):

| Archivo | Qué hace |
|---|---|
| `roble_config.dart` | Host, contrato y nombres de las nueve tablas. Un `--dart-define` los cambia. |
| `roble_duplicate.dart` | `isDuplicateRow()`: si el error de ROBLE es una violación de `UNIQUE`. Tres fuentes dependen de la misma lectura del mensaje de PostgreSQL. |
| `roble_client.dart` | Transporte: arma la petición, pone el `Bearer`, traduce cada código de estado y **renueva el token una sola vez** ante un 401 antes de reintentar. Sin imports de Flutter, para que `tool/seed_roble.dart` lo pueda usar. |
| `roble_session.dart` | Tokens y usuario en memoria, espejados en almacenamiento cifrado. Borra de paso las llaves que dejó la plantilla, que guardaba contraseñas en texto plano. |
| `roble_user.dart` | La cuenta según `GET /me`. `userId` gana sobre `id`: es el valor que va en `creator_id`. |
| `roble_exception.dart` | Una excepción por falla, con mensaje en español listo para mostrar. |
| `roble_password_policy.dart` | La política de contraseñas, verificada antes de la petición. |
| `roble_session_service.dart` | `ISessionService` sobre la sesión de ROBLE: quién es el usuario actual para el resto de la app. |

Las fuentes de datos que hablan con ROBLE:

- [`features/auth/data/datasources/remote/roble_authentication_source.dart`](../lib/features/auth/data/datasources/remote/roble_authentication_source.dart)
- [`features/listings/data/datasources/remote/roble_listing_source.dart`](../lib/features/listings/data/datasources/remote/roble_listing_source.dart)
- [`features/listings/data/datasources/remote/roble_engagement_source.dart`](../lib/features/listings/data/datasources/remote/roble_engagement_source.dart)
- [`features/groups/data/datasources/remote/roble_group_source.dart`](../lib/features/groups/data/datasources/remote/roble_group_source.dart)

Todo se arma en [`lib/di/app_bindings.dart`](../lib/di/app_bindings.dart), que
además decide la pantalla inicial: `home` si hay sesión guardada, `login` si no.
Estar sin red al arrancar **no** cierra la sesión: no poder preguntar no es lo
mismo que estar expulsado.

---

## Sembrar los datos de demostración

```bash
dart run tool/seed_roble.dart
```

Pide el correo y la contraseña de ROBLE por consola (o los toma de
`ROBLE_EMAIL` / `ROBLE_PASSWORD`) e inserta los tres proyectos de muestra. Es
idempotente: consulta por título antes de insertar, así que correrlo dos veces no
duplica nada.

Los tres quedan a nombre de estudiantes ficticios y no de la cuenta que corre el
script. `creator_id` es `text` y no hay llaves foráneas, así que el id no tiene
que existir en ROBLE — y de esa forma quien prueba la app puede solicitar unirse
a los tres en lugar de aparecer ya como integrante.

---

## Trampas de la Consola SQL

- La consola **elimina los comentarios SQL** antes de ejecutar.
- Un `CREATE TABLE` recibe la columna `_id` automáticamente si falta, y un
  `INSERT` recibe el `_id` si no se lo dan.
- Las sentencias van en **PostgreSQL**, y se pueden ejecutar varias juntas.
- La documentación de ROBLE es una SPA: no se puede leer con un `curl` ni con una
  herramienta que solo baje HTML.

---

## Pruebas

No hay pruebas que hablen con ROBLE de verdad: necesitarían credenciales y red, y
dejarían filas para que la siguiente corrida se tropiece con ellas.

- [`test/support/fake_roble_api.dart`](../test/support/fake_roble_api.dart) imita
  los endpoints de base de datos sobre un mapa de tablas, **con los mismos
  `UNIQUE` compuestos**, que es la razón de existir del doble: así se puede
  probar qué pasa en el segundo `INSERT`.
- [`test/core/roble/roble_client_test.dart`](../test/core/roble/roble_client_test.dart)
  usa `MockClient` para lo que es fácil equivocar y difícil de notar: el refresh
  único, las dos formas en que llega una lista de filas, el 429 y el guardia del
  UUID.
- [`test/features/listings/roble_listing_source_test.dart`](../test/features/listings/roble_listing_source_test.dart)
  cubre lo que la fuente hace y ROBLE no: agrupar integrantes, ordenar, deshacer
  un proyecto a medio escribir y tratar un duplicado como éxito.
