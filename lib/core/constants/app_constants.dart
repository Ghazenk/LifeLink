// App-wide constants for LifeLink.

class AppConstants {
  AppConstants._();

  /// Public API endpoint selected when the app is built. A clinic build can
  /// target a separately deployed LAN server without changing source code.
  /// Do not use localhost: on a staff PC that would mean the staff PC itself.
  static const String supabaseUrl = String.fromEnvironment(
    'LIFELINK_BACKEND_URL',
    defaultValue: 'https://osqirvdgczhvnacwxfgg.supabase.co',
  );

  /// Supabase publishable key. This identifies the public client and is not an
  /// authorization secret; access is enforced by Auth, RLS, and Edge Functions.
  /// Service-role and third-party provider secrets must remain server-side.
  static const String supabasePublishableKey = String.fromEnvironment(
    'LIFELINK_BACKEND_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_QfLonRyXu56UAYTFRFdTow_S57_c_Zf',
  );

  static const bool hasBackendUrlOverride = bool.hasEnvironment(
    'LIFELINK_BACKEND_URL',
  );
  static const bool hasBackendKeyOverride = bool.hasEnvironment(
    'LIFELINK_BACKEND_PUBLISHABLE_KEY',
  );

  /// App name displayed across the UI.
  static const String appName = 'LifeLink';
}
