import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lifelink/core/constants/app_constants.dart';

import 'secure_session_storage.dart';
import 'backend_configuration.dart';

/// Supabase client initialization and accessor.
class SupabaseClientManager {
  SupabaseClientManager._();

  /// Initialize Supabase. Call once in main() before runApp().
  static Future<void> initialize() async {
    if (!BackendConfiguration.clinicBuild && AppConstants.hasBackendUrlOverride !=
        AppConstants.hasBackendKeyOverride) {
      throw StateError(
        'Set both LIFELINK_BACKEND_URL and LIFELINK_BACKEND_PUBLISHABLE_KEY for a clinic build.',
      );
    }
    final configuration = BackendConfiguration.current;
    final endpoint = Uri.tryParse(configuration.url);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment ||
        configuration.publishableKey.trim().isEmpty) {
      throw StateError(
        'The configured backend URL or publishable key is invalid.',
      );
    }
    await Supabase.initialize(
      debug: false,
      url: configuration.url,
      publishableKey: configuration.publishableKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(
          configuration.clinicMode ? configuration.namespace : null,
        ),
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Accessor for the global Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}
