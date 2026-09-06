/// Converts an unexpected error into a message suitable for presentation.
///
/// Replace this with backend-specific mappings when the application introduces
/// typed API exceptions. Until then, preserving the original message makes the
/// template useful while it is being wired to a service.
String errorMessage(Object error, {String? fallback}) =>
    fallback ?? error.toString();
