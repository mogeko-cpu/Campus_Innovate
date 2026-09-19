import '../user_facing_exception.dart';

/// Failures that come back from ROBLE, sorted by what the caller can do.
///
/// The types exist because ROBLE's own messages mislead in ways that cost real
/// debugging time, and each status code means something specific here:
///
/// * **400** on a write is almost always a field the table does not have. ROBLE
///   rejects the *whole* record and says only "Bad Request".
/// * **401** means the access token expired; [RobleClient] already tried to
///   refresh once before this reaches you, so seeing it means the session is
///   really over.
/// * **429** is a per-**IP** limit with three separate buckets, and the body
///   (`ThrottlerException`) does not say which one ran out. On a shared campus
///   network it is spent between several people, so "it works for me" proves
///   nothing.
/// * **500** on a read is frequently *our* fault: filtering an `_id` column
///   with something that is not a UUID makes PostgreSQL fail, and ROBLE
///   forwards that as a server error indistinguishable from an outage.
///
/// [toString] returns the plain message because `errorMessage()` feeds it
/// straight to the UI.
sealed class RobleException implements UserFacingException {
  const RobleException(this.message);

  @override
  final String message;

  @override
  String toString() => message;
}

/// The device could not reach ROBLE at all.
class RobleNetworkException extends RobleException {
  const RobleNetworkException([
    super.message = 'No hay conexión con ROBLE. Revisa tu internet.',
  ]);
}

/// ROBLE did not answer in time.
class RobleTimeoutException extends RobleException {
  const RobleTimeoutException([
    super.message = 'ROBLE tardó demasiado en responder. Intenta de nuevo.',
  ]);
}

/// No valid session: either the credentials were wrong or the token expired and
/// could not be refreshed.
class RobleUnauthorizedException extends RobleException {
  const RobleUnauthorizedException([
    super.message = 'Tu sesión expiró. Vuelve a iniciar sesión.',
  ]);
}

/// Authenticated, but the ROBLE role of this account lacks the permission.
///
/// Note that a *missing* table permission usually surfaces as a 500, not as
/// this; see `docs/roble.md`.
class RobleForbiddenException extends RobleException {
  const RobleForbiddenException([
    super.message = 'Tu cuenta no tiene permiso para esta operación.',
  ]);
}

/// ROBLE rejected the request body. On a write this means a column mismatch
/// between the app and the table, which is a bug here and not user error.
class RobleBadRequestException extends RobleException {
  const RobleBadRequestException(super.message);
}

/// The row addressed by `_id` does not exist.
class RobleNotFoundException extends RobleException {
  const RobleNotFoundException(super.message);
}

/// Rate limited. Waiting is the only fix — retrying does not shorten the
/// window, which is fixed and shared by everyone behind the same IP.
class RobleRateLimitException extends RobleException {
  const RobleRateLimitException(super.message, {this.retryAfter});

  /// Seconds left in the window, from `X-Ratelimit-Reset`, when ROBLE said.
  final int? retryAfter;
}

/// ROBLE answered 5xx. Carries its body, because that is the only thing that
/// separates a genuine outage from a malformed value we sent.
class RobleServerException extends RobleException {
  const RobleServerException(super.message, this.statusCode);

  final int statusCode;
}
