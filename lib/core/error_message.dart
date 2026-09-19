import 'user_facing_exception.dart';

/// Turns an error into something worth putting on screen.
///
/// The ROBLE and domain exceptions carry messages meant for the user — "espera
/// 40 segundos", "el proyecto ya está completo", "tu sesión expiró" — and those
/// go through untouched: they say what to do next, which no generic line can.
///
/// Anything else is a bug rather than a situation, and its `toString()` ("Bad
/// state: …", "Null check operator used on a null value") tells the user nothing,
/// so [fallback] replaces it.
String errorMessage(Object error, {String? fallback}) {
  if (error is UserFacingException) return error.message;

  return fallback ?? error.toString();
}
