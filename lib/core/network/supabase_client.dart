import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lifelink/core/constants/app_constants.dart';

/// Supabase client initialization and accessor.
class SupabaseClientManager {
  SupabaseClientManager._();

  /// Initialize Supabase. Call once in main() before runApp().
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      publishableKey: AppConstants.supabaseAnonKey,
    );
  }

  /// Accessor for the global Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}
