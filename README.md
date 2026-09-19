# Campus Innovate

Aplicación móvil para que estudiantes universitarios publiquen proyectos
colaborativos y se postulen a los equipos de otros.

Construida con **Flutter + Dart**, siguiendo **Clean Architecture** por feature con
**GetX** para inyección de dependencias, navegación por rutas y estado reactivo.

Los datos y las cuentas viven en **ROBLE** (OPENLAB, Universidad del Norte):
autenticación con JWT y PostgreSQL administrado por REST. Nada se guarda en
memoria — lo que publicas sigue ahí en el siguiente arranque y en otro
dispositivo. Los detalles del esquema, los límites del servicio y por qué el
código está hecho así están en [`docs/roble.md`](docs/roble.md).

---

## Cómo correr el proyecto

### Requisitos

- Flutter **3.47.4** o superior (canal `stable`) — verifica con `flutter --version`
- Dart SDK `^3.12.2` (viene incluido con Flutter)

### Primeros pasos

```bash
git clone https://github.com/mogeko-cpu/Campus_Innovate.git
cd Campus_Innovate
flutter pub get
```

### Ejecutar

Revisa primero qué plataformas tienes configuradas:

```bash
flutter doctor
flutter devices
```

Luego lanza la app en el destino que corresponda:

```bash
# Navegador (no requiere configuración adicional)
flutter run -d chrome

# Android — requiere Android Studio + SDK instalados
flutter run -d <id-del-dispositivo>
```

Con la app corriendo, `r` recarga en caliente, `R` reinicia y `q` cierra.

La app abre en la pantalla de **inicio de sesión**. Necesitas una cuenta de
ROBLE: puedes crearla desde *Crear cuenta* en la app o desde la consola de
ROBLE. La sesión queda guardada cifrada, así que el siguiente arranque entra
directo.

### Sembrar los proyectos de demostración

Una base vacía muestra una pantalla vacía. Para insertar los tres proyectos de
muestra:

```bash
dart run tool/seed_roble.dart
```

Pide tu correo y contraseña de ROBLE por consola (sin mostrar la contraseña y sin
guardarla en ningún archivo); también los toma de `ROBLE_EMAIL` y
`ROBLE_PASSWORD`. Correrlo dos veces no duplica nada.

### Apuntar a otro contrato de ROBLE

```bash
flutter run --dart-define=ROBLE_CONTRACT_ID=otro_contrato_ab12cd34
```

### Configurar otras plataformas

| Destino | Qué falta instalar |
|---|---|
| Android | Android Studio con el SDK. Luego `flutter doctor --android-licenses` |
| Windows escritorio | Visual Studio con el workload *Desktop development with C++* |
| iOS | Xcode (solo en macOS) |

### Verificar el código

```bash
flutter analyze   # análisis estático — debe salir sin issues
flutter test      # suite de pruebas
```

---

## Arquitectura

El proyecto se organiza **por feature**, y cada feature se parte en tres capas.
La dependencia siempre apunta hacia adentro: la UI conoce al dominio, el dominio
no conoce a nadie.

```
lib/features/<feature>/
├── domain/              # Reglas y contratos. Sin Flutter, sin GetX.
│   ├── models/          # Entidades (Listing, JoinRequest)
│   └── repositories/    # Interfaces que la UI puede consumir
├── data/                # Implementaciones concretas
│   ├── datasources/     # De dónde salen los datos (remote/ = ROBLE)
│   └── repositories/    # Adaptan el datasource al contrato de dominio
└── ui/
    ├── viewmodels/      # GetxController: estado reactivo y orquestación
    ├── views/           # Pantallas
    └── widgets/         # Componentes reutilizables del feature
```

### Cadena de dependencias

```
View (GetView)
  └─> ViewModel (GetxController)
        └─> IListingRepository          ← interfaz de dominio
              └─> ListingRepository      ← implementación
                    └─> IListingSource   ← interfaz de datos
                          └─> RobleListingSource   (activo)
                                └─> RobleClient → API REST de ROBLE
```

Dos reglas que sostienen todo esto:

1. **Ninguna vista salta capas.** Un `View` habla con su `ViewModel` y nada más.
   Un `ViewModel` depende de la *interfaz* del repositorio, nunca de la clase
   concreta ni del datasource.
2. **Nada se instancia a sí mismo.** Las dependencias entran por constructor y se
   registran en los *bindings*. Por eso cambiar la fuente en memoria por
   `RobleListingSource` no tocó ni una vista, y por eso las pruebas pueden
   sustituirla por un doble.

### Estructura general

```
lib/
├── main.dart                  # Entrada: arranca los bindings y GetMaterialApp
├── core/                      # Transversal a todos los features
│   ├── app_theme.dart         # Paleta e identidad visual
│   ├── i_session_service.dart # Contrato del usuario en sesión
│   ├── i_local_preferences.dart
│   └── roble/                 # Cliente, sesión y errores de ROBLE
├── di/
│   └── app_bindings.dart      # Raíz de composición (singletons permanentes)
├── routes/
│   ├── app_routes.dart        # Constantes de ruta
│   └── app_pages.dart         # Ruta → página + binding
└── features/
    ├── home/                  # Menú principal
    ├── listings/              # Publicar, explorar y unirse a proyectos
    └── auth/                  # Inicio de sesión y registro contra ROBLE

tool/
└── seed_roble.dart            # Siembra los proyectos de demostración
docs/
└── roble.md                   # Esquema, límites y modos de falla de ROBLE
```

### Features

**`listings`** — el núcleo de la app. Publicar un proyecto, explorar los abiertos
con búsqueda y filtro por categoría, ver el detalle y enviar una solicitud para
unirse. `ListingRepository` concentra las reglas que el datasource no conoce: qué
cuenta como proyecto destacado, y que aceptar una solicitud además incorpora al
postulante como miembro.

**`home`** — el menú principal. Saludo al usuario, las dos acciones primarias
(publicar / explorar), proyectos destacados y los proyectos del usuario. Recarga
su estado cada vez que el usuario vuelve de otra pantalla.

**`auth`** — inicio de sesión y registro con cuentas reales de ROBLE. La app abre
aquí cuando no hay sesión guardada, y el saludo del menú principal trae el botón
para cerrarla. La política de contraseñas de ROBLE se verifica antes de pedir la
cuenta: `signup` permite 5 intentos por hora por IP y una contraseña rechazada
gasta uno igual.

### Navegación

Rutas nombradas de GetX, declaradas en `app_routes.dart` y mapeadas en
`app_pages.dart`. Cada ruta trae su propio *binding*, así que un ViewModel se
construye solo cuando su pantalla se abre.

| Ruta | Pantalla |
|---|---|
| `/login` | Inicio de sesión (pantalla inicial sin sesión) |
| `/signup` | Crear cuenta |
| `/home` | Menú principal |
| `/listings` | Explorar proyectos |
| `/listings/create` | Publicar proyecto |
| `/listings/detail/:id` | Detalle del proyecto |
| `/listings/join/:id` | Solicitud para unirse |

### Identidad visual

Paleta universitaria definida en `lib/core/app_theme.dart` con FlexColorScheme:

| Rol | Color | |
|---|---|---|
| Primario | Carmesí académico | `#9E1B32` |
| Secundario | Azul marino | `#1F2A44` |
| Terciario | Dorado apagado | `#B08D3F` |

---

## Pruebas

```bash
flutter test
```

`test/features/listings/listing_flows_test.dart` maneja la app real de punta a
punta: carga el menú principal, publica un proyecto y envía una solicitud para
unirse a otro. Son pruebas de flujo, no de widgets aislados — si un binding falta
o una ruta está mal declarada, fallan.

Ninguna prueba habla con ROBLE de verdad: necesitaría credenciales y red, y
dejaría filas para que la siguiente corrida se tropiece con ellas. En su lugar,
`test/support/fake_roble_api.dart` imita los endpoints de base de datos sobre un
mapa de tablas, **con los mismos `UNIQUE` compuestos**, y sobre eso se prueban el
cliente (`test/core/roble/`) y la fuente de datos
(`test/features/listings/roble_listing_source_test.dart`).

---

## Límites conocidos

- **Cada lectura trae la tabla completa.** ROBLE filtra solo por igualdad, así que
  buscar y ordenar ocurre en Dart. Alcanza de sobra para un curso; es lo primero
  que habría que revisar si los datos crecen.
- **El tope de integrantes es orientativo.** Sin escrituras condicionales, dos
  dispositivos pueden tomar el último puesto a la vez y un proyecto queda con uno
  de más. El detalle, en [`docs/roble.md`](docs/roble.md).
- **Solicitudes sin bandeja.** Aceptar y rechazar postulaciones funciona a nivel
  de repositorio, pero todavía no hay pantalla para el creador del proyecto.
- **Sin recuperar contraseña.** El cliente de ROBLE lo soporta; ninguna pantalla
  lo llama todavía.
- Las pestañas **Proyectos** y **Perfil** de la barra inferior aún no navegan.
