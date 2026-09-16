# Codebase Index

## Overview

`campus_innovate` is a Flutter application for publishing university projects and
joining other students' teams. It follows the feature-first Clean Architecture /
MVVM layout of `f_clean_template`: every feature splits into `domain`, `data`,
and `ui`, with GetX providing dependency injection, named routing, and reactive
state.

Layer chain, top to bottom:

```text
View (GetView)
  -> ViewModel (GetxController)
    -> IListingRepository
      -> ListingRepository
        -> IListingSource
          -> LocalListingSource (active, in-memory)
```

Views never reach past the repository interface, and view models receive both
the repository and `ISessionService` through constructor injection.

## Runtime entry and composition

- [`lib/main.dart`](lib/main.dart) — Entry point. Builds `GetMaterialApp` with `AppBindings`, the route table, and the light/dark themes.
- [`lib/di/app_bindings.dart`](lib/di/app_bindings.dart) — Global binding. Registers the session service, listing source, and listing repository as permanent singletons so in-memory data survives navigation.
- [`lib/routes/app_routes.dart`](lib/routes/app_routes.dart) — Route name constants plus `detailOf(id)` / `joinOf(id)` builders for parameterized routes.
- [`lib/routes/app_pages.dart`](lib/routes/app_pages.dart) — Maps each route to its page and per-route binding.
- [`lib/core/app_theme.dart`](lib/core/app_theme.dart) — Campus Innovate palette: academic crimson primary, navy secondary, muted gold tertiary, built with FlexColorScheme.
- [`lib/core/i_session_service.dart`](lib/core/i_session_service.dart) — Identity of the current user, implemented by [`MockSessionService`](lib/core/mock_session_service.dart) until authentication is wired to the shell.
- [`lib/core/i_local_preferences.dart`](lib/core/i_local_preferences.dart) — Storage contract with shared and encrypted adapters.

## Listings feature

The core feature: publish a project, browse open projects, request to join one.

### Domain

- [`domain/models/listing.dart`](lib/features/listings/domain/models/listing.dart) — `Listing` entity. `availableSlots` and `isFull` derive team capacity.
- [`domain/models/join_request.dart`](lib/features/listings/domain/models/join_request.dart) — A student's application to a listing.
- [`domain/models/join_request_status.dart`](lib/features/listings/domain/models/join_request_status.dart) — `pending` / `accepted` / `rejected` with Spanish labels.
- [`domain/models/listing_category.dart`](lib/features/listings/domain/models/listing_category.dart) — The categories a project can be published under.
- [`domain/repositories/i_listing_repository.dart`](lib/features/listings/domain/repositories/i_listing_repository.dart) — Everything the UI is allowed to ask for.

### Data

- [`data/datasources/i_listing_source.dart`](lib/features/listings/data/datasources/i_listing_source.dart) — Storage contract, shared by the in-memory source and the future HTTP one.
- [`data/datasources/local/local_listing_source.dart`](lib/features/listings/data/datasources/local/local_listing_source.dart) — In-memory store seeded with three demo projects. State resets on restart.
- [`data/repositories/listing_repository.dart`](lib/features/listings/data/repositories/listing_repository.dart) — Delegates to the source and owns the rules the source does not: what counts as featured, and that accepting a request also adds the applicant as a member.

### UI

- [`ui/viewmodels/listings_view_model.dart`](lib/features/listings/ui/viewmodels/listings_view_model.dart) — Listing catalog plus category and free-text filtering.
- [`ui/viewmodels/create_listing_view_model.dart`](lib/features/listings/ui/viewmodels/create_listing_view_model.dart) — Category, team size, and skill-tag state for the publish form.
- [`ui/viewmodels/listing_detail_view_model.dart`](lib/features/listings/ui/viewmodels/listing_detail_view_model.dart) — Loads one listing by route parameter and decides whether the viewer may apply.
- [`ui/viewmodels/join_request_view_model.dart`](lib/features/listings/ui/viewmodels/join_request_view_model.dart) — Submits the application form.
- [`ui/viewmodels/requests_view_model.dart`](lib/features/listings/ui/viewmodels/requests_view_model.dart) — Creator-facing request inbox. Written but not routed yet.
- [`ui/views/`](lib/features/listings/ui/views) — `listings_page`, `create_listing_page`, `listing_detail_page`, `join_request_page`.
- [`ui/widgets/listing_card.dart`](lib/features/listings/ui/widgets/listing_card.dart) — Shared project card, also used by home.
- [`listings_dependencies.dart`](lib/features/listings/listings_dependencies.dart) — One binding per listings route.

## Home feature

- [`ui/viewmodels/home_view_model.dart`](lib/features/home/ui/viewmodels/home_view_model.dart) — Featured listings and the projects the current user belongs to.
- [`ui/views/home_page.dart`](lib/features/home/ui/views/home_page.dart) — Greeting header, the two primary actions, featured projects, and my projects. Reloads whenever the user returns from a pushed route.
- [`ui/widgets/action_card.dart`](lib/features/home/ui/widgets/action_card.dart) — The filled/outlined primary action tile.
- [`home_dependencies.dart`](lib/features/home/home_dependencies.dart) — `HomeBinding`.

## Authentication feature

Carried over from the template and kept for later. Login and signup pages,
controller, repository, and a local multi-user source all work, but no route
points at them yet, so the app opens straight onto home.

## Tests

- [`test/features/listings/listing_flows_test.dart`](test/features/listings/listing_flows_test.dart) — Drives the real app through home, publishing a project, and requesting to join one.
- [`test/features/auth/authentication_source_service_test.dart`](test/features/auth/authentication_source_service_test.dart) — Account storage and credential checks.

## Current implementation boundaries

- No backend. `LocalListingSource` holds everything in memory and resets on restart.
- The session is a fixed mock user; authentication exists but is not wired into the app shell.
- Accepting and rejecting join requests works at the repository level, but no screen exposes it yet.
- The "Proyectos" and "Perfil" tabs of the bottom navigation bar are inert.
- `_template_removed/` holds the template's product feature and the old mock files, kept until the team confirms they are no longer needed.
