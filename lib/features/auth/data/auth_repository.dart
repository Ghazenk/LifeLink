import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_user_profile.dart';
import 'package:lifelink/core/network/supabase_client.dart';

// ---------------------------------------------------------------------------
// Auth Repository — bridges Supabase Auth + Isar local cache
// ---------------------------------------------------------------------------

class AuthRepository {
  AuthRepository({
    required this.supabase,
    required this.isar,
  });

  final SupabaseClient supabase;
  final Isar isar;

  // ── Sign Up ──────────────────────────────────────────────────────────────

  /// Creates a new account. The Supabase `handle_new_user()` trigger
  /// auto-creates a `profiles` row from the metadata we pass here.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
    String? bloodGroup,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
        'role': role,
        'blood_group': ?bloodGroup,
      },
    );

    // After signup, sync the profile to Isar.
    if (response.user != null) {
      await _syncProfileToIsar(response.user!.id);
    }

    return response;
  }

  // ── Sign In ──────────────────────────────────────────────────────────────

  /// Signs in with email + password, then immediately syncs the remote
  /// profile into the local Isar database.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    // Critical sync: pull remote profile → Isar on every login.
    if (response.user != null) {
      await _syncProfileToIsar(response.user!.id);
    }

    return response;
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────

  /// Signs out and clears the local profile cache.
  Future<void> signOut() async {
    await supabase.auth.signOut();
    // Clear local profile data on logout.
    await isar.writeTxn(() => isar.localUserProfiles.clear());
  }

  // ── Profile Sync ────────────────────────────────────────────────────────

  /// Fetches the user's profile from Supabase `profiles` and upserts it
  /// into the local Isar `LocalUserProfile` collection.
  Future<void> _syncProfileToIsar(String userId) async {
    try {
      final row = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (row != null) {
        final profile = LocalUserProfile.fromSupabaseMap(row);
        await isar.writeTxn(() => isar.localUserProfiles.put(profile));
      }
    } catch (e) {
      // Sync failure is non-fatal — user can still use cached data.
      // In production, queue a retry via SyncManager.
    }
  }

  // ── Local Profile Stream ────────────────────────────────────────────────

  /// Watches the current user's profile *from Isar* (offline-first).
  /// Returns `null` if no local profile exists yet.
  Stream<LocalUserProfile?> watchLocalProfile(String userId) {
    return isar.localUserProfiles
        .where()
        .idEqualTo(userId)
        .watch(fireImmediately: true)
        .map((profiles) => profiles.isEmpty ? null : profiles.first);
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

/// Provides the singleton [AuthRepository] instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    supabase: SupabaseClientManager.client,
    isar: LocalDatabase.instance,
  );
});

/// Streams the Supabase auth state changes (login, logout, token refresh).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseClientManager.client.auth.onAuthStateChange;
});

/// Streams the current user's [LocalUserProfile] from Isar.
///
/// This is the primary source of truth for the UI — always reads local.
/// Returns `null` when not authenticated or profile not yet synced.
final currentUserProfileProvider =
    StreamProvider<LocalUserProfile?>((ref) {
  final user = SupabaseClientManager.client.auth.currentUser;
  if (user == null) return Stream.value(null);

  final repo = ref.watch(authRepositoryProvider);
  return repo.watchLocalProfile(user.id);
});
