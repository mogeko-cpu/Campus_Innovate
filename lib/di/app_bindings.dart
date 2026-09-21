import 'package:get/get.dart';

import '../core/i_local_preferences.dart';
import '../core/i_session_service.dart';
import '../core/local_preferences_secured.dart';
import '../core/roble/roble_client.dart';
import '../core/roble/roble_session.dart';
import '../core/roble/roble_session_service.dart';
import '../features/auth/data/datasources/remote/i_authentication_source.dart';
import '../features/auth/data/datasources/remote/roble_authentication_source.dart';
import '../features/auth/data/repositories/auth_repository.dart';
import '../features/auth/domain/repositories/i_auth_repository.dart';
import '../features/auth/ui/viewmodels/authentication_controller.dart';
import '../features/groups/data/datasources/i_group_source.dart';
import '../features/groups/data/datasources/remote/roble_group_source.dart';
import '../features/groups/data/repositories/group_repository.dart';
import '../features/groups/domain/repositories/i_group_repository.dart';
import '../features/listings/data/datasources/i_engagement_source.dart';
import '../features/listings/data/datasources/i_listing_source.dart';
import '../features/listings/data/datasources/remote/roble_engagement_source.dart';
import '../features/listings/data/datasources/remote/roble_listing_source.dart';
import '../features/listings/data/repositories/engagement_repository.dart';
import '../features/listings/data/repositories/listing_repository.dart';
import '../features/listings/domain/repositories/i_engagement_repository.dart';
import '../features/listings/domain/repositories/i_listing_repository.dart';
import '../routes/app_routes.dart';

/// Composition root: builds the object graph once and hands it to GetX.
///
/// Assembled by [boot] before `runApp`, because the first route depends on
/// whether there is a session — and that answer requires reading encrypted
/// storage and asking ROBLE, neither of which can happen inside a build method.
class AppBindings extends Bindings {
  AppBindings._({
    required this.preferences,
    required this.session,
    required this.client,
    required this.authenticationSource,
    required this.initialRoute,
  });

  /// Wires everything up and works out where the app should open.
  ///
  /// Only an outright "this token is not valid" sends the user to login. Being
  /// offline does not: the session survives, the app opens, and the screens show
  /// the connection error — signing someone out for a dropped wifi would cost
  /// them a login against a limit of 10 per 15 minutes per IP.
  static Future<AppBindings> boot() async {
    final preferences = LocalPreferencesSecured();
    final session = RobleSession(preferences);
    final client = RobleClient(session: session);
    final authenticationSource = RobleAuthenticationSource(client, session);

    var hasSession = false;
    try {
      hasSession = await authenticationSource.restoreSession();
    } catch (_) {
      // Unreadable storage or an unexpected failure: treat it as "no session"
      // rather than blocking startup. The user logs in again.
      hasSession = false;
    }

    return AppBindings._(
      preferences: preferences,
      session: session,
      client: client,
      authenticationSource: authenticationSource,
      initialRoute: hasSession ? AppRoutes.home : AppRoutes.login,
    );
  }

  final ILocalPreferences preferences;
  final RobleSession session;
  final RobleClient client;
  final IAuthenticationSource authenticationSource;

  /// Home when the session is good, login when it is not.
  final String initialRoute;

  @override
  void dependencies() {
    Get.put<ILocalPreferences>(preferences, permanent: true);
    Get.put<RobleSession>(session, permanent: true);
    Get.put<RobleClient>(client, permanent: true);

    // Everything below is permanent: one HTTP client and one session for the
    // whole run, so navigating does not rebuild the graph or re-read the token.
    Get.put<ISessionService>(RobleSessionService(session), permanent: true);
    Get.put<IListingSource>(RobleListingSource(client), permanent: true);
    Get.put<IListingRepository>(
      ListingRepository(Get.find<IListingSource>()),
      permanent: true,
    );

    Get.put<IEngagementSource>(RobleEngagementSource(client), permanent: true);
    Get.put<IEngagementRepository>(
      EngagementRepository(Get.find<IEngagementSource>()),
      permanent: true,
    );

    Get.put<IGroupSource>(RobleGroupSource(client), permanent: true);
    Get.put<IGroupRepository>(
      GroupRepository(Get.find<IGroupSource>()),
      permanent: true,
    );

    Get.put<IAuthenticationSource>(authenticationSource, permanent: true);
    Get.put<IAuthRepository>(
      AuthRepository(Get.find<IAuthenticationSource>()),
      permanent: true,
    );
    Get.put(
      AuthenticationController(Get.find<IAuthRepository>()),
      permanent: true,
    );
  }
}
