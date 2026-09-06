# Codebase Index

## Overview

`f_clean_template` is a Flutter application organized by feature using a pragmatic Clean Architecture / MVVM structure. GetX provides dependency injection, navigation, and reactive state. The implemented features are authentication and product CRUD.

## Runtime entry and composition

- [`lib/main.dart`](lib/main.dart) — Application entry point. Initializes logging, delegates feature wiring to `registerAuth` and `registerProduct`, and starts `MyApp`.
- [`lib/central.dart`](lib/central.dart) — Root authentication gate. Reactively displays `LoginPage` or `ListProductPage` based on `AuthenticationController.isLogged`.
- [`lib/core/app_theme.dart`](lib/core/app_theme.dart) — Light and dark Material themes built with FlexColorScheme.
- [`lib/core/error_message.dart`](lib/core/error_message.dart) — Converts authentication exceptions into presentation-safe error messages.
- [`lib/core/i_local_preferences.dart`](lib/core/i_local_preferences.dart) — Storage contract, implemented by shared web and encrypted native adapters; the native adapter falls back to shared preferences only when its plugin is unavailable.

Dependency graph:

```text
AuthenticationController
  -> IAuthRepository
    -> AuthRepository
      -> IAuthenticationSource
        -> AuthenticationSourceService

ProductController
  -> IProductRepository
    -> ProductRepository
      -> IProductSource
        -> LocalProductSource (active)
        -> RemoteProductSource (available stub)
```

## Authentication feature

### Domain

- [`lib/features/auth/domain/models/authentication_user.dart`](lib/features/auth/domain/models/authentication_user.dart) — `AuthenticationUser` entity plus JSON conversion.
- [`lib/features/auth/domain/repositories/i_auth_repository.dart`](lib/features/auth/domain/repositories/i_auth_repository.dart) — Authentication operations exposed to the UI layer.

### Data

- [`lib/features/auth/data/datasources/remote/i_authentication_source.dart`](lib/features/auth/data/datasources/remote/i_authentication_source.dart) — Full authentication data-source contract.
- [`lib/features/auth/data/datasources/remote/authentication_source_service.dart`](lib/features/auth/data/datasources/remote/authentication_source_service.dart) — Local multi-user authentication implementation: persists accounts, verifies credentials, and restores the session for a valid stored account.
- [`lib/features/auth/data/repositories/auth_repository.dart`](lib/features/auth/data/repositories/auth_repository.dart) — Adapter from the domain repository contract to the authentication source.
- [`lib/features/auth/auth_dependencies.dart`](lib/features/auth/auth_dependencies.dart) — Registers the authentication source, repository, and controller with GetX.

### UI

- [`lib/features/auth/ui/viewmodels/authentication_controller.dart`](lib/features/auth/ui/viewmodels/authentication_controller.dart) — Reactive logged/loading state, credential validation, and login/signup/logout orchestration.
- [`lib/features/auth/ui/views/login_page.dart`](lib/features/auth/ui/views/login_page.dart) — Login form and navigation to signup.
- [`lib/features/auth/ui/views/signup_page.dart`](lib/features/auth/ui/views/signup_page.dart) — Account creation form.

Authentication flow:

```text
LoginPage -> AuthenticationController.login()
          -> AuthRepository.login()
          -> AuthenticationSourceService.login()
          -> isLogged = true
          -> Central rebuilds with ListProductPage
```

## Product feature

### Domain

- [`lib/features/product/domain/models/product.dart`](lib/features/product/domain/models/product.dart) — Mutable `Product` entity and JSON conversion.
- [`lib/features/product/domain/repositories/i_product_repository.dart`](lib/features/product/domain/repositories/i_product_repository.dart) — Product CRUD contract.

### Data

- [`lib/features/product/data/datasources/i_remote_product_source.dart`](lib/features/product/data/datasources/i_remote_product_source.dart) — Product data-source contract. Despite its filename, it is shared by local and remote implementations.
- [`lib/features/product/data/datasources/local/local_product_source.dart`](lib/features/product/data/datasources/local/local_product_source.dart) — Active JSON-backed local CRUD store; product data persists across app restarts.
- [`lib/features/product/data/datasources/remote_product_source.dart`](lib/features/product/data/datasources/remote_product_source.dart) — Remote API placeholder; no HTTP requests are implemented yet.
- [`lib/features/product/data/repositories/product_repository.dart`](lib/features/product/data/repositories/product_repository.dart) — Pass-through adapter from domain operations to the selected product source.
- [`lib/features/product/product_dependencies.dart`](lib/features/product/product_dependencies.dart) — Registers the active local product source, repository, and controller with GetX.

### UI

- [`lib/features/product/ui/viewmodels/product_controller.dart`](lib/features/product/ui/viewmodels/product_controller.dart) — Owns the reactive product list/loading state and refreshes after mutations.
- [`lib/features/product/ui/views/list_product_page.dart`](lib/features/product/ui/views/list_product_page.dart) — Product list, pull-to-refresh, swipe deletion, delete-all, logout, and add/edit navigation.
- [`lib/features/product/ui/views/add_product_page.dart`](lib/features/product/ui/views/add_product_page.dart) — Product creation form.
- [`lib/features/product/ui/views/edit_product_page.dart`](lib/features/product/ui/views/edit_product_page.dart) — Product editing form; receives a product through GetX navigation arguments.

CRUD flow:

```text
Product view -> ProductController
             -> ProductRepository
             -> LocalProductSource
             -> ProductController.getProducts()
             -> reactive list rebuild
```

## Platform and project files

- [`pubspec.yaml`](pubspec.yaml) — Dart/Flutter constraints and dependencies (`get`, `http`, `loggy`, `shared_preferences`, `flex_color_scheme`).
- [`analysis_options.yaml`](analysis_options.yaml) — Dart analyzer and lint configuration.
- [`android/`](android/) — Android runner and Gradle configuration.
- [`ios/`](ios/) — iOS runner and Xcode/CocoaPods configuration.
- [`web/`](web/) — Flutter web bootstrap, manifest, and icons.
- [`test/widget_test.dart`](test/widget_test.dart) — Default counter-template test; it does not match the current application behavior.

## Current implementation boundaries

- Authentication and the remote product source do not communicate with a backend. Local authentication is for demos only and must be replaced with a backend before production.
- Authentication and products use local storage; replace the auth session marker with secure backend tokens when a real backend is connected.
- There is no route table; navigation uses widget-based GetX calls.
- There are no use-case classes by design: controllers call repository interfaces directly.
- Automated coverage is effectively absent because the remaining widget test targets the original Flutter counter template.
