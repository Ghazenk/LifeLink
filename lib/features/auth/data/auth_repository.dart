import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_user_profile.dart';
import 'package:lifelink/core/network/supabase_client.dart';
import 'package:lifelink/core/network/sync_manager.dart';
import 'package:lifelink/core/security/password_policy.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_lab_result.dart';
import 'package:lifelink/core/local_db/models/local_guardianship.dart';

// ---------------------------------------------------------------------------
// Auth Repository — bridges Supabase Auth + Isar local cache
// ---------------------------------------------------------------------------

class AuthRepository {
  AuthRepository({required this.supabase, required this.isar});

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
    Map<String, dynamic>? medicalHistory,
    required bool age13OrOlder,
    required bool termsAccepted,
  }) async {
    if (!age13OrOlder || !termsAccepted) {
      throw const AuthException(
        'Age eligibility and Terms acceptance are required.',
      );
    }
    if (!['patient', 'donor', 'caregiver'].contains(role)) {
      throw const AuthException(
        'Staff accounts must be created by an administrator.',
      );
    }
    if (email.length > 254 ||
        !RegExp(r'^[^\s@<>]{1,64}@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$')
            .hasMatch(email.trim()) ||
        fullName.trim().length < 2 ||
        fullName.length > 150 ||
        RegExp(r'[<>\x00-\x1f\x7f]').hasMatch(fullName) ||
        !RegExp(r'^\d{11}$').hasMatch(phone)) {
      throw const AuthException(
        'Enter a valid email, name and 11-digit phone number.',
      );
    }
    if (bloodGroup != null &&
        ![
          'A+',
          'A-',
          'B+',
          'B-',
          'AB+',
          'AB-',
          'O+',
          'O-',
        ].contains(bloodGroup)) {
      throw const AuthException('Choose a valid blood group.');
    }
    final passwordError = PasswordPolicy.validate(password);
    if (passwordError != null) {
      throw AuthException(passwordError);
    }
    final metadata = <String, dynamic>{
      'full_name': fullName.trim(),
      'phone': phone,
      'role': role,
      'age_13_or_older': true,
      'terms_version': '2026-09-28',
    };
    // Omit absent optional fields. JSON null is not SQL NULL in the profile
    // validation trigger and would reject an otherwise valid signup.
    if (bloodGroup != null) metadata['blood_group'] = bloodGroup;
    if (medicalHistory != null) metadata['medical_history'] = medicalHistory;
    // TRANSACTIONAL ONLY: Supabase confirmation email must contain no marketing.
    final response = await supabase.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: metadata,
    );

    // After signup, sync the profile to Isar.
    if (response.session != null && response.user != null) {
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
    late final AuthResponse response;
    try {
      response = await supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on AuthException catch (error) {
      if (error.statusCode == '429' ||
          error.message.toLowerCase().contains('too many')) {
        throw const AuthException(
          'Too many sign-in attempts. Wait a few minutes and try again.',
          statusCode: '429',
        );
      }
      // Avoid revealing whether an email address exists or is confirmed.
      throw const AuthException(
        'Email or password is incorrect, or the email is not verified.',
      );
    }

    if (response.session == null) {
      throw const AuthException(
        'Your email is unverified. Please check your inbox or create a new account.',
      );
    }

    try {
      if (response.user != null) await _syncProfileToIsar(response.user!.id);
      unawaited(SyncManager().syncNow());
    } catch (_) {
      await supabase.auth.signOut(scope: SignOutScope.local);
      throw const AuthException(
        'Your account could not be verified. Check your connection and sign in again.',
      );
    }

    return response;
  }

  /// Verifies ownership of a newly registered email address and then loads the
  /// server-authorized profile. The eight-digit code expires in Supabase.
  Future<AuthResponse> verifySignupCode({
    required String email,
    required String code,
  }) async {
    final response = await supabase.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: code.trim(),
      type: OtpType.signup,
    );
    if (response.session == null || response.user == null) {
      throw const AuthException('Email verification failed.');
    }
    await _syncProfileToIsar(response.user!.id);
    return response;
  }

  Future<void> resendSignupCode(String email) => supabase.auth.resend(
    type: OtpType.signup,
    email: email.trim().toLowerCase(),
  );

  // ── Sign Out ─────────────────────────────────────────────────────────────

  /// Sign-out is always available. Keep only the account-owned unsynced outbox.
  Future<void> signOut() async {
    try {
      // The SDK clears its local session before attempting server revocation.
      await supabase.auth
          .signOut(scope: SignOutScope.global)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Always remove the local credential even when server revocation cannot
      // be confirmed. The short-lived access token still expires server-side.
      try {
        await supabase.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Supabase clears persisted local auth state before its network call.
      }
    } finally {
      // Network revocation failure must not leave a signed-out user's cache visible.
      await isar.writeTxn(() async {
        await isar.localUserProfiles.clear();
        await isar.localVisits
            .filter()
            .syncStatusEqualTo(VisitSyncStatus.synced)
            .deleteAll();
        await isar.localLabResults
            .filter()
            .syncStatusEqualTo(LabResultSyncStatus.synced)
            .deleteAll();
        await isar.localGuardianships
            .filter()
            .syncStatusEqualTo(GuardianshipSyncStatus.synced)
            .deleteAll();
      });
    }
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
      } else {
        throw Exception(
          'Profile not found in database. The creation trigger may have failed.',
        );
      }
    } catch (e) {
      // If we can't sync the profile on initial login, throw an error
      // so the UI can display it instead of silently failing.
      throw const AuthException(
        'Unable to verify your account profile. Please reconnect and try again.',
      );
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
final currentUserProfileProvider = StreamProvider<LocalUserProfile?>((
  ref,
) async* {
  // Watch the auth state so this provider rebuilds when the user logs in or out.
  final authState = await ref.watch(authStateProvider.future);
  final user = authState.session?.user;

  if (user == null) {
    yield null;
    return;
  }

  final repo = ref.watch(authRepositoryProvider);
  yield* repo.watchLocalProfile(user.id);
});
