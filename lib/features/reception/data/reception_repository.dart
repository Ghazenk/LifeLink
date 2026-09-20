import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/network/supabase_client.dart';

class ReceptionRepository {
  ReceptionRepository(this.supabase, this.isar);

  final SupabaseClient supabase;
  final Isar isar;

  /// Fetches users whose status is 'pending' for approval.
  Future<List<Map<String, dynamic>>> getPendingUsers() async {
    return await supabase
        .from('profiles')
        .select('*')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
  }

  /// Approves a user by setting their status to 'active'.
  Future<void> approveUser(String userId) async {
    await supabase
        .from('profiles')
        .update({'status': 'active'})
        .eq('id', userId);
  }

  /// Issues a token, saves it locally first (offline-first), then syncs.
  Future<LocalVisit> issueToken({
    required String userId,
    required String type, // 'donation' or 'transfusion'
  }) async {
    final now = DateTime.now();
    // Simple token generation: Prefix + Timestamp-based suffix
    final prefix = type == 'donation' ? 'D' : 'T';
    final suffix = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    final tokenNumber = '$prefix-$suffix';
    final uuid = const Uuid().v4();

    // 1. Create local visit object
    final localVisit = LocalVisit()
      ..id = uuid
      ..userId = userId
      ..tokenNumber = tokenNumber
      ..type = type
      ..status = 'waiting_for_lab'
      ..createdAt = now
      ..syncStatus = VisitSyncStatus.pendingInsert;

    // 2. Save locally immediately (UI updates instantly if watching stream)
    await isar.writeTxn(() async {
      await isar.localVisits.put(localVisit);
    });

    // 3. Attempt network sync
    try {
      await supabase.from('visits').insert({
        'id': uuid,
        'user_id': userId,
        'token_number': tokenNumber,
        'type': type,
        'status': 'waiting_for_lab',
        // Supabase trigger sets created_at
      });

      // 4. Update sync status on success
      await isar.writeTxn(() async {
        localVisit.syncStatus = VisitSyncStatus.synced;
        await isar.localVisits.put(localVisit);
      });
    } catch (e) {
      // Network failed - swallow the error so the app continues offline.
      // The SyncManager (when implemented) will pick this up later.
    }

    return localVisit;
  }

  /// Fetches users who are active (Donors and Patients) for token issuance.
  Future<List<Map<String, dynamic>>> getActivePatientsAndDonors() async {
    return await supabase
        .from('profiles')
        .select('*')
        .eq('status', 'active')
        .inFilter('role', ['patient', 'donor'])
        .order('full_name', ascending: true);
  }

  /// Searches active users by name or phone
  Future<List<Map<String, dynamic>>> searchActiveUsers(String query) async {
    if (query.trim().isEmpty) return getActivePatientsAndDonors();
    
    return await supabase
        .from('profiles')
        .select('*')
        .eq('status', 'active')
        .inFilter('role', ['patient', 'donor'])
        .or('full_name.ilike.%$query%,phone.ilike.%$query%')
        .order('full_name', ascending: true);
  }

  /// Fetches live inventory stock levels
  Future<List<Map<String, dynamic>>> getInventory() async {
    return await supabase
        .from('inventory')
        .select('*')
        .order('blood_group', ascending: true);
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final receptionRepositoryProvider = Provider<ReceptionRepository>((ref) {
  return ReceptionRepository(
    SupabaseClientManager.client,
    LocalDatabase.instance,
  );
});

final pendingUsersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(receptionRepositoryProvider).getPendingUsers();
});

final liveInventoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(receptionRepositoryProvider).getInventory();
});
