# Campus Innovate

Aplicación móvil para que estudiantes universitarios publiquen proyectos
colaborativos y se postulen a los equipos de otros.

Construida con **Flutter + Dart**, siguiendo **Clean Architecture** por feature con
**GetX** para inyección de dependencias, navegación por rutas y estado reactivo.

> Estado actual: etapa inicial. No hay backend — los datos viven en memoria y se
> reinician al cerrar la app.

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
│   ├── datasources/     # De dónde salen los datos (memoria, HTTP, local)
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
                          └─> LocalListingSource   (activo, en memoria)
```

Dos reglas que sostienen todo esto:

1. **Ninguna vista salta capas.** Un `View` habla con su `ViewModel` y nada más.
   Un `ViewModel` depende de la *interfaz* del repositorio, nunca de la clase
   concreta ni del datasource.
2. **Nada se instancia a sí mismo.** Las dependencias entran por constructor y se
   registran en los *bindings*. Esto permite cambiar `LocalListingSource` por una
   fuente HTTP sin tocar una sola vista.

### Estructura general

```
lib/
├── main.dart                  # Entrada: GetMaterialApp, tema y rutas
├── core/                      # Transversal a todos los features
│   ├── app_theme.dart         # Paleta e identidad visual
│   ├── i_session_service.dart # Contrato del usuario en sesión
│   └── i_local_preferences.dart
├── di/
│   └── app_bindings.dart      # Dependencias globales (singletons permanentes)
├── routes/
│   ├── app_routes.dart        # Constantes de ruta
│   └── app_pages.dart         # Ruta → página + binding
└── features/
    ├── home/                  # Menú principal
    ├── listings/              # Publicar, explorar y unirse a proyectos
    └── auth/                  # Login y registro (aún sin enrutar)
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

**`auth`** — login, registro y almacenamiento local de cuentas. Funciona, pero
todavía ninguna ruta apunta ahí: la app abre directo en `home`.

### Navegación

Rutas nombradas de GetX, declaradas en `app_routes.dart` y mapeadas en
`app_pages.dart`. Cada ruta trae su propio *binding*, así que un ViewModel se
construye solo cuando su pantalla se abre.

| Ruta | Pantalla |
|---|---|
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

`test/features/listings/listing_flows_test.dart` maneja la app real de punta a
punta: carga el menú principal, publica un proyecto y envía una solicitud para
unirse a otro. Son pruebas de flujo, no de widgets aislados — si un binding falta
o una ruta está mal declarada, fallan.

```bash
flutter test
```

---

## Límites conocidos

- **Sin backend.** `LocalListingSource` mantiene todo en memoria; los datos se
  pierden al reiniciar.
- **Sesión simulada.** `MockSessionService` devuelve un usuario fijo. El feature
  `auth` existe pero no está conectado al arranque de la app.
- **Solicitudes sin bandeja.** Aceptar y rechazar postulaciones funciona a nivel
  de repositorio, pero todavía no hay pantalla para el creador del proyecto.
- Las pestañas **Proyectos** y **Perfil** de la barra inferior aún no navegan.
