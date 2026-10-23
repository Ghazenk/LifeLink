import 'dart:async';

import 'package:lifelink/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/network/supabase_client.dart';
import 'package:lifelink/core/network/backend_configuration.dart';
import 'package:lifelink/core/network/sync_manager.dart';

/// PostgREST's `or` filter is a small expression language, not a SQL bind
/// parameter. Permit only characters that cannot change its grammar.
String sanitizedReceptionSearch(String query) {
  if (query.length > 80) throw ArgumentError('Search is too long.');
  final value = query.trim();
  if (RegExp(r'[^a-zA-Z0-9 +\-]').hasMatch(value)) {
    throw const FormatException(
      'Search uses letters, numbers, spaces or hyphens.',
    );
  }
  return value;
}

class ReceptionRepository {
  ReceptionRepository(this.supabase, this.isar);

  final SupabaseClient supabase;
  final Isar isar;

  /// Fetches users whose status is 'pending' for approval.
  Future<List<Map<String, dynamic>>> getPendingUsers() async {
    return await supabase
        .from('profiles')
        .select('id, full_name, phone, role, blood_group')
        .eq('status', 'pending')
        .inFilter('role', ['donor', 'patient', 'caregiver'])
        .order('created_at', ascending: false);
  }

  /// Approves a user by setting their status to 'active'.
  Future<void> approveUser(String userId) async {
    await supabase
        .from('profiles')
        .update({'status': 'active'})
        .eq('id', userId)
        .select('id')
        .single();
  }

  /// In clinic mode the shared LAN server is authoritative. Never show a
  /// token to a patient until its server transaction has committed.
  Future<LocalVisit> issueToken({
    required String userId,
    required String type, // 'donation' or 'transfusion'
  }) async {
    final owner = supabase.auth.currentUser?.id;
    if (owner == null) {
      throw const AuthException('Sign in before creating a visit.');
    }
    if (!['donation', 'transfusion'].contains(type)) {
      throw ArgumentError('Invalid visit type');
    }
    final now = DateTime.now();
    final uuid = const Uuid().v4();
    final prefix = type == 'donation' ? 'D' : 'T';
    final localVisit = LocalVisit()
      ..id = uuid
      ..ownerUserId = owner
      ..userId = userId
      ..tokenNumber = '$prefix-${uuid.substring(0, 8).toUpperCase()}'
      ..type = type
      ..status = 'waiting_for_lab'
      ..createdAt = now
      ..syncStatus = VisitSyncStatus.pendingInsert;
    if (BackendConfiguration.isClinic) {
      await supabase.rpc('queue_visit', params: {'payload': {
        'id': localVisit.id,
        'user_id': localVisit.userId,
        'token_number': localVisit.tokenNumber,
        'type': localVisit.type,
        'created_at': localVisit.createdAt.toUtc().toIso8601String(),
      }}).timeout(const Duration(seconds: 15));
      localVisit.syncStatus = VisitSyncStatus.synced;
      return localVisit;
    }
    await isar.writeTxn(() => isar.localVisits.put(localVisit));
    unawaited(SyncManager().syncNow());

    return localVisit;
  }

  /// Fetches users who are active (Donors and Patients) for token issuance.
  Future<List<Map<String, dynamic>>> getActivePatientsAndDonors() async {
    return await supabase
        .from('profiles')
        .select('id, full_name, phone, role')
        .eq('status', 'active')
        .inFilter('role', ['patient', 'donor'])
        .order('full_name', ascending: true)
        .limit(100);
  }

  /// Searches active users by name or phone
  Future<List<Map<String, dynamic>>> searchActiveUsers(String query) async {
    final safeQuery = sanitizedReceptionSearch(query);
    if (safeQuery.isEmpty) return getActivePatientsAndDonors();

    return await supabase
        .from('profiles')
        .select('id, full_name, phone, role')
        .eq('status', 'active')
        .inFilter('role', ['patient', 'donor'])
        .or('full_name.ilike.%$safeQuery%,phone.ilike.%$safeQuery%')
        .order('full_name', ascending: true)
        .limit(100);
  }

  /// Fetches live inventory stock levels
  Future<List<Map<String, dynamic>>> getInventory() async {
    return await supabase
        .from('inventory')
        .select('blood_group, volume_ml, last_updated')
        .order('blood_group', ascending: true);
  }

  /// Manually adjusts inventory levels
  Future<void> addManualStock(String bloodGroup, int volumeMl) async {
    await supabase.rpc(
      'add_stock',
      params: {
        'operation_id': const Uuid().v4(),
        'blood_group': bloodGroup,
        'volume_ml': volumeMl,
      },
    );
  }

  /// Bulk imports users from an Excel list
  Future<void> importUsersFromExcel(List<Map<String, dynamic>> users) async {
    if (users.isEmpty || users.length > 100) {
      throw ArgumentError('Import between 1 and 100 users at a time.');
    }
    final result = await supabase.functions.invoke(
      'manage-users',
      body: {'action': 'import', 'users': users},
    );
    if (result.status != 200) throw StateError('Import was not completed.');
    final data = result.data as Map<String, dynamic>;
    final failures = data['failed_rows'] as List? ?? [];
    if (failures.isNotEmpty) {
      throw StateError(
        '${data['created']} accounts created; failed rows: $failures. Review these rows before retrying.',
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final receptionRepositoryProvider = Provider<ReceptionRepository>((ref) {
  ref.watch(
    authStateProvider.select((state) => state.valueOrNull?.session?.user.id),
  );
  return ReceptionRepository(
    SupabaseClientManager.client,
    LocalDatabase.instance,
  );
});

final pendingUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(syncRevisionProvider);
      return ref.watch(receptionRepositoryProvider).getPendingUsers();
    });

final liveInventoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(syncRevisionProvider);
      return ref.watch(receptionRepositoryProvider).getInventory();
    });
