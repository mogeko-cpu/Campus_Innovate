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
          -> RobleListingSource (active)
            -> RobleClient -> ROBLE REST API
```

Views never reach past the repository interface, and view models receive both
the repository and `ISessionService` through constructor injection.

## Runtime entry and composition

- [`lib/main.dart`](lib/main.dart) — Entry point. Async: sets up Loggy, awaits `AppBindings.boot()`, then builds `GetMaterialApp`. `initialBinding` and `initialRoute` are parameters, so the tests install their own doubles.
- [`lib/di/app_bindings.dart`](lib/di/app_bindings.dart) — Composition root. `boot()` builds preferences → session → client → auth source and restores the stored session, which decides `initialRoute`: home with a session, login without. `dependencies()` registers everything as permanent singletons.
- [`lib/routes/app_routes.dart`](lib/routes/app_routes.dart) — Route name constants plus `detailOf(id)` / `joinOf(id)` builders for parameterized routes.
- [`lib/routes/app_pages.dart`](lib/routes/app_pages.dart) — Maps each route to its page and per-route binding.
- [`lib/core/app_theme.dart`](lib/core/app_theme.dart) — Campus Innovate palette: academic crimson primary, navy secondary, muted gold tertiary, built with FlexColorScheme.
- [`lib/core/i_session_service.dart`](lib/core/i_session_service.dart) — Identity of the current user, implemented by [`RobleSessionService`](lib/core/roble/roble_session_service.dart) over the signed-in ROBLE account.
- [`lib/core/i_local_preferences.dart`](lib/core/i_local_preferences.dart) — Storage contract with shared and encrypted adapters. The session uses the encrypted one.
- [`lib/core/user_facing_exception.dart`](lib/core/user_facing_exception.dart) — Marks an exception whose `message` may be shown as is. [`error_message.dart`](lib/core/error_message.dart) passes those through and gives everything else a fallback.

## ROBLE

The backend. [`docs/roble.md`](docs/roble.md) holds the schema, the rate limits and
the failure modes; this is where the code lives.

- [`lib/core/roble/roble_config.dart`](lib/core/roble/roble_config.dart) — Host, contract id and table names, overridable with `--dart-define`.
- [`lib/core/roble/roble_client.dart`](lib/core/roble/roble_client.dart) — REST transport: Bearer header, status-code translation, and one refresh-and-retry on a 401. No Flutter imports, so `tool/seed_roble.dart` reuses it.
- [`lib/core/roble/roble_session.dart`](lib/core/roble/roble_session.dart) — Tokens and user, in memory and mirrored to encrypted storage. Persisted because `login` allows only 10 attempts per 15 minutes per IP.
- [`lib/core/roble/roble_user.dart`](lib/core/roble/roble_user.dart) — The account as `GET /me` describes it.
- [`lib/core/roble/roble_exception.dart`](lib/core/roble/roble_exception.dart) — One sealed family, each with a Spanish message ready to display.
- [`lib/core/roble/roble_password_policy.dart`](lib/core/roble/roble_password_policy.dart) — Checked before `signup`, whose 5-per-hour budget a rejected password would spend anyway.
- [`lib/core/roble/roble_session_service.dart`](lib/core/roble/roble_session_service.dart) — `ISessionService` over the ROBLE session.
- [`lib/core/roble/roble_duplicate.dart`](lib/core/roble/roble_duplicate.dart) — `isDuplicateRow()`, shared by the three sources that rely on a composite `UNIQUE` to make a second write impossible.
- [`tool/seed_roble.dart`](tool/seed_roble.dart) — Inserts the three demo projects. Idempotent; asks for credentials on the console or reads `ROBLE_EMAIL` / `ROBLE_PASSWORD`.

## Listings feature

The core feature: publish a project, browse open projects, request to join one.

### Domain

- [`domain/models/listing.dart`](lib/features/listings/domain/models/listing.dart) — `Listing` entity. `availableSlots` and `isFull` derive team capacity.
- [`domain/models/join_request.dart`](lib/features/listings/domain/models/join_request.dart) — A student's application to a listing.
- [`domain/models/join_request_status.dart`](lib/features/listings/domain/models/join_request_status.dart) — `pending` / `accepted` / `rejected` with Spanish labels.
- [`domain/models/listing_category.dart`](lib/features/listings/domain/models/listing_category.dart) — The categories a project can be published under.
- [`domain/models/reaction_type.dart`](lib/features/listings/domain/models/reaction_type.dart) — Like or dislike, stored as `1` / `-1` so the ranking score is a sum.
- [`domain/models/listing_stats.dart`](lib/features/listings/domain/models/listing_stats.dart) — Likes, dislikes, unique views, comments and the viewer's own vote. Built by counting rows, never stored as columns.
- [`domain/models/listing_comment.dart`](lib/features/listings/domain/models/listing_comment.dart) — A comment under a project, filed under the project's group.
- [`domain/models/ranked_listing.dart`](lib/features/listings/domain/models/ranked_listing.dart) — A project plus its place, and the comparison the ranking sorts by.
- [`domain/repositories/i_listing_repository.dart`](lib/features/listings/domain/repositories/i_listing_repository.dart) — Everything the UI is allowed to ask for.
- [`domain/repositories/i_engagement_repository.dart`](lib/features/listings/domain/repositories/i_engagement_repository.dart) — Votes, visits and comments, kept apart from the project itself.

### Data

- [`data/datasources/i_listing_source.dart`](lib/features/listings/data/datasources/i_listing_source.dart) — Storage contract. Ids are the `_id` UUIDs the database assigns; the app never invents one.
- [`data/datasources/remote/roble_listing_source.dart`](lib/features/listings/data/datasources/remote/roble_listing_source.dart) — The active store, over three ROBLE tables. Does what ROBLE cannot: group members across tables, sort, undo a half-written project, and treat a duplicate membership as success.
- [`data/repositories/listing_repository.dart`](lib/features/listings/data/repositories/listing_repository.dart) — Delegates to the source and owns the rules the source does not: what counts as featured, and that accepting a request also adds the applicant as a member — membership first, since there are no transactions.
- [`data/datasources/i_engagement_source.dart`](lib/features/listings/data/datasources/i_engagement_source.dart) — Storage contract for reactions, views and comments.
- [`data/datasources/remote/roble_engagement_source.dart`](lib/features/listings/data/datasources/remote/roble_engagement_source.dart) — Three tables, counted in Dart because ROBLE cannot count or group. A duplicate view or vote is a success, not an error.
- [`data/repositories/engagement_repository.dart`](lib/features/listings/data/repositories/engagement_repository.dart) — Owns what a tap means: pressing the button you already pressed takes the vote back.
- [`domain/listing_exception.dart`](lib/features/listings/domain/listing_exception.dart) — A listings rule the user ran into, with a message meant to be read.

### UI

- [`ui/viewmodels/listings_view_model.dart`](lib/features/listings/ui/viewmodels/listings_view_model.dart) — Listing catalog plus category and free-text filtering.
- [`ui/viewmodels/create_listing_view_model.dart`](lib/features/listings/ui/viewmodels/create_listing_view_model.dart) — Category, team size, and skill-tag state for the publish form.
- [`ui/viewmodels/listing_detail_view_model.dart`](lib/features/listings/ui/viewmodels/listing_detail_view_model.dart) — Loads one listing by route parameter and decides whether the viewer may apply.
- [`ui/viewmodels/join_request_view_model.dart`](lib/features/listings/ui/viewmodels/join_request_view_model.dart) — Submits the application form.
- [`ui/viewmodels/requests_view_model.dart`](lib/features/listings/ui/viewmodels/requests_view_model.dart) — Creator-facing request inbox, mounted inside the project's detail screen.
- [`ui/viewmodels/ranking_view_model.dart`](lib/features/listings/ui/viewmodels/ranking_view_model.dart) — Assembles the leaderboard: projects plus counters, ordered in Dart.
- [`ui/views/`](lib/features/listings/ui/views) — `listings_page`, `create_listing_page`, `listing_detail_page`, `join_request_page`, `ranking_page`.
- [`ui/widgets/listing_card.dart`](lib/features/listings/ui/widgets/listing_card.dart) — Shared project card, also used by home, the ranking and the groups screen. Counters and the position badge are optional.
- [`ui/widgets/listing_stats_row.dart`](lib/features/listings/ui/widgets/listing_stats_row.dart) — The read-only counters under a card.
- [`ui/widgets/reaction_bar.dart`](lib/features/listings/ui/widgets/reaction_bar.dart) — Like and dislike with their counts, plus views and comments.
- [`listings_dependencies.dart`](lib/features/listings/listings_dependencies.dart) — One binding per listings route, ranking included.

The detail screen is where a project is lived in: it counts the visit, carries the
vote buttons and the comments, shows the creator their pending requests, and lets
the creator delete the project — reactions, views and comments first, then the
project, so a half-finished delete leaves something that can be retried.

## Groups feature

Standing teams. A project is published **by** a group, which is what ties its
likes, views and comments to one owner.

### Domain

- [`domain/models/group.dart`](lib/features/groups/domain/models/group.dart) — `Group` entity, owner included as its first member.
- [`domain/models/group_member.dart`](lib/features/groups/domain/models/group_member.dart) — One row of `group_members`, name copied in because ROBLE has no join.
- [`domain/models/group_request.dart`](lib/features/groups/domain/models/group_request.dart) — Someone asking to be let in.
- [`domain/models/group_request_status.dart`](lib/features/groups/domain/models/group_request_status.dart) — `pending` / `accepted` / `rejected` with Spanish labels.
- [`domain/group_exception.dart`](lib/features/groups/domain/group_exception.dart) — A groups rule the user ran into.
- [`domain/repositories/i_group_repository.dart`](lib/features/groups/domain/repositories/i_group_repository.dart) — Everything the UI is allowed to ask for.

### Data

- [`data/datasources/i_group_source.dart`](lib/features/groups/data/datasources/i_group_source.dart) — Storage contract.
- [`data/datasources/remote/roble_group_source.dart`](lib/features/groups/data/datasources/remote/roble_group_source.dart) — Three ROBLE tables. Deleting a group removes its members and requests first, so a failure halfway leaves the group still listed and still deletable.
- [`data/repositories/group_repository.dart`](lib/features/groups/data/repositories/group_repository.dart) — Owns the rules: the owner cannot leave, accepting adds the member before marking the request.

### UI

- [`ui/viewmodels/groups_view_model.dart`](lib/features/groups/ui/viewmodels/groups_view_model.dart) — My groups, the rest of the campus, and how many projects each has published.
- [`ui/viewmodels/group_detail_view_model.dart`](lib/features/groups/ui/viewmodels/group_detail_view_model.dart) — One group: members, requests, projects, and every write that acts on them.
- [`ui/viewmodels/create_group_view_model.dart`](lib/features/groups/ui/viewmodels/create_group_view_model.dart) — The creation form.
- [`ui/views/`](lib/features/groups/ui/views) — `groups_page`, `group_detail_page`, `create_group_page`.
- [`ui/widgets/group_card.dart`](lib/features/groups/ui/widgets/group_card.dart) — Group card with owner, member count and project count.
- [`groups_dependencies.dart`](lib/features/groups/groups_dependencies.dart) — One binding per groups route.

Asking to join, accepting, rejecting, removing someone and deleting the group all
happen on the detail screen, so nobody has to remember where the other half of the
job lives. Deleting a group is refused while it still has projects: other people
applied to those and may be on their teams.

## Profile feature

- [`ui/viewmodels/profile_view_model.dart`](lib/features/profile/ui/viewmodels/profile_view_model.dart) — A view across features: the account, the groups, what the user published, what they joined, the requests they sent, and how the campus received their projects.
- [`ui/views/profile_page.dart`](lib/features/profile/ui/views/profile_page.dart) — Identity header, counters, and the four lists. Carries the logout button.
- [`profile_dependencies.dart`](lib/features/profile/profile_dependencies.dart) — `ProfileBinding`.

## Shell

- [`lib/features/shell/ui/widgets/app_bottom_nav.dart`](lib/features/shell/ui/widgets/app_bottom_nav.dart) — `AppTab` and the navigation bar the five root screens share: Inicio, Explorar, Ranking, Grupos, Perfil. Switching tabs uses `offAllNamed`, since a tab is a root and not a step in a journey.

## Home feature

- [`ui/viewmodels/home_view_model.dart`](lib/features/home/ui/viewmodels/home_view_model.dart) — Featured listings, the projects the current user belongs to, and their counters.
- [`ui/views/home_page.dart`](lib/features/home/ui/views/home_page.dart) — Greeting header, the publish action, featured projects, and my projects. Exploring lives in the bar at the bottom, so the screen no longer offers the same trip twice. Reloads whenever the user returns from a pushed route.
- [`ui/widgets/action_card.dart`](lib/features/home/ui/widgets/action_card.dart) — The filled/outlined primary action tile.
- [`home_dependencies.dart`](lib/features/home/home_dependencies.dart) — `HomeBinding`.

## Authentication feature

Real accounts, in ROBLE. The template's local store — which kept passwords in
cleartext — is gone, and `RobleSession` wipes the keys it left behind.

- [`data/datasources/remote/i_authentication_source.dart`](lib/features/auth/data/datasources/remote/i_authentication_source.dart) — What the repository may ask for.
- [`data/datasources/remote/roble_authentication_source.dart`](lib/features/auth/data/datasources/remote/roble_authentication_source.dart) — ROBLE's implementation. Remaps a 401 on login to "wrong credentials", and keeps the session when the network — not ROBLE — is what failed.
- [`ui/viewmodels/authentication_controller.dart`](lib/features/auth/ui/viewmodels/authentication_controller.dart) — Login, signup and logout state, with the password policy checked before the request.
- [`ui/views/`](lib/features/auth/ui/views) — `login_page` and `signup_page`, routed at `/login` and `/signup`.

The app opens on login when there is no stored session, and the home header
carries the logout button.

## Tests

Nothing in the suite talks to the real ROBLE: that would need credentials and a
network, and would leave rows behind for the next run to trip over.

- [`test/features/listings/listing_flows_test.dart`](test/features/listings/listing_flows_test.dart) — Drives the real app through home, publishing a project, and requesting to join one, on the doubles in `test/support/`.
- [`test/features/listings/roble_listing_source_test.dart`](test/features/listings/roble_listing_source_test.dart) — The source against a fake ROBLE: ordering, member grouping, rollback, duplicates, full projects.
- [`test/core/roble/roble_client_test.dart`](test/core/roble/roble_client_test.dart) — Transport over `MockClient`: the single refresh-and-retry, both row shapes, 429, and the UUID guard.
- [`test/core/roble/roble_password_policy_test.dart`](test/core/roble/roble_password_policy_test.dart) — Every rule, and every symbol ROBLE accepts.
- [`test/support/`](test/support) — `fake_roble_api.dart` (ROBLE's database endpoints over a map of tables, composite `UNIQUE` included), `in_memory_listing_source.dart`, `in_memory_group_source.dart` (seeded with one group the test user owns, since publishing needs one), `in_memory_engagement_source.dart`, `test_bindings.dart`, `memory_preferences.dart`.

## Current implementation boundaries

- Every listing read is a full table read, sorted and filtered in Dart, because ROBLE filters by equality only. Fine at course scale, and the first thing to revisit if the data grows.
- `max_members` is advisory: with no conditional writes a project can end up one member over the ceiling. See [`docs/roble.md`](docs/roble.md).
- Counters are read as three full table reads (`getStats`), which is why they arrive once per screen and not once per card.
- Views are unique per person: reopening a project does not raise the number.
- A project published before groups existed keeps `group_id` empty and shows as "Publicado sin grupo".
- Deleting a group is refused while it still owns projects; the owner deletes each project first.
- Password reset and e-mail verification exist in the client; no screen calls them.
