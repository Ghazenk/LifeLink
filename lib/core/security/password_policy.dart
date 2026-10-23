/// Password rules enforced by both the client and Supabase Auth.
///
/// Passwords are sent only to Supabase Auth over TLS. They must never be
/// written to the clinical database, local cache, analytics, or logs.
abstract final class PasswordPolicy {
  static const int minimumLength = 12;
  static const int maximumLength = 128;

  static String? validate(String? value) {
    final password = value ?? '';
    if (password.length < minimumLength || password.length > maximumLength) {
      return 'Use 12 to 128 characters';
    }
    if (!RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password) ||
        !RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Include uppercase, lowercase, a number, and a symbol';
    }
    return null;
  }

  static bool isValid(String value) => validate(value) == null;
}
