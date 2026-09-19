/// ROBLE's password rules, checked here before the account is requested.
///
/// Not a nicety: `signup` allows **5 attempts per hour per IP**, and a password
/// ROBLE rejects still spends one. Three typos from one classroom and nobody
/// else can register for an hour.
abstract final class RoblePasswordPolicy {
  static const int minLength = 8;

  /// The only symbols ROBLE accepts. A password with `%` or `*` is refused even
  /// though it looks stronger, which is the kind of rejection worth explaining
  /// before the request rather than after.
  static const String symbols = '!@#\$_-.';

  /// Returns the reason the password is unacceptable, or null when it passes.
  static String? validate(String password) {
    if (password.length < minLength) {
      return 'La contraseña debe tener al menos $minLength caracteres.';
    }
    if (!password.contains(RegExp('[A-Z]'))) {
      return 'La contraseña debe incluir una letra mayúscula.';
    }
    if (!password.contains(RegExp('[a-z]'))) {
      return 'La contraseña debe incluir una letra minúscula.';
    }
    if (!password.contains(RegExp('[0-9]'))) {
      return 'La contraseña debe incluir un número.';
    }
    if (!password.contains(RegExp(r'[!@#$_\-.]'))) {
      return 'La contraseña debe incluir uno de estos símbolos: $symbols';
    }

    return null;
  }
}
