/// An exception whose [message] was written to be read by the person using the
/// app, not by a developer.
///
/// `errorMessage()` shows these verbatim. Everything else — a `TypeError`, a
/// `StateError`, whatever a plugin throws — is replaced by the caller's fallback,
/// because its text would only confuse.
abstract interface class UserFacingException implements Exception {
  String get message;
}
