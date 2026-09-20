import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lifelink/core/constants/app_constants.dart';
import 'package:lifelink/core/network/supabase_client.dart';
import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_user_profile.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_lab_result.dart';
import 'package:lifelink/core/local_db/models/local_guardianship.dart';
import 'package:lifelink/core/network/sync_manager.dart';
import 'package:lifelink/core/routing/app_router.dart';

/// LifeLink — Multi-role Blood Bank & Thalassemia Management App
///
/// Entry point initializes:
/// 1. Flutter binding
/// 2. Supabase client (cloud backend)
/// 3. Isar database (local offline storage) — initialized when schemas are ready
/// 4. Riverpod for state management
/// 5. GoRouter for declarative navigation
/// 6. SyncManager for background offline-to-cloud syncing
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await SupabaseClientManager.initialize();

  // Initialize Isar local database
  await LocalDatabase.initialize(schemas: [
    LocalUserProfileSchema,
    LocalVisitSchema,
    LocalLabResultSchema,
    LocalGuardianshipSchema,
  ]);

  // Start background sync engine
  SyncManager().initialize();

  runApp(
    const ProviderScope(
      child: LifeLinkApp(),
    ),
  );
}

/// Root application widget.
class LifeLinkApp extends ConsumerWidget {
  const LifeLinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935), // Blood-red accent
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
