# Pruebas

Tres capas, cada una con su job en GitHub Actions
(`.github/workflows/pruebas.yml`), más el análisis estático. Ninguna toca ROBLE:
corren sobre los dobles en memoria de `test/support/`, así que no necesitan
credenciales ni dejan filas en la base de datos.

| Capa | Carpeta | Qué cubre |
|---|---|---|
| Unitarias | `test/unit/` | `core` (sesión, preferencias, poller, tema, errores), todos los modelos, los repositorios y cada view model |
| Widgets | `test/widget/` | cada widget reutilizable y cada una de las 15 pantallas, con sus estados vacío, de error y de carga |
| Integración | `integration_test/` | flujos completos sobre la app real: entrar/registrarse/salir, la vida de un proyecto, una solicitud entre dos personas, un grupo con invitación y chat, y la navegación con el cambio de tema |

## Cómo se corren

```bash
flutter analyze
flutter test test/unit
flutter test test/widget
```

Las de integración necesitan un dispositivo. En CI usan la app de escritorio
de Linux (`linux/`) dentro de un servidor X virtual:

```bash
for f in integration_test/*_test.dart; do xvfb-run -a flutter test "$f" -d linux; done
```

Un archivo por invocación: con varios juntos, el escritorio de Linux solo logra
abrir la app la primera vez.

Sin escritorio Linux también corren en el `flutter-tester`, una por archivo:

```bash
flutter test integration_test/auth_flow_test.dart -d flutter-tester
```

## Piezas de apoyo

- `test/support/test_bindings.dart`: el grafo de la app con ROBLE reemplazado
  por fuentes en memoria. Todo lo de arriba (rutas, bindings, view models,
  repositorios, pantallas) es el código real.
- `test/support/test_session.dart`: una sesión que puede cambiar de persona,
  para los flujos donde una publica o invita y otra responde.
- `test/support/fake_auth_repository.dart`: login, registro y salida sin red,
  con las cuentas de Leonel y Mariana.
- `test/support/app_tester.dart`: abrir la app en una ruta y los gestos que los
  snackbars y las listas largas vuelven incómodos.
- `integration_test/flow_helpers.dart`: `CampusApp`, la app arrancada como la
  encuentra un estudiante, con `logIn`, `logOut`, `goToTab` y `waitFor`.
