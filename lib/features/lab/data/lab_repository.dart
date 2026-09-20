import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_lab_result.dart';
import 'package:lifelink/core/network/supabase_client.dart';

class LabRepository {
  LabRepository(this.supabase, this.isar);

  final SupabaseClient supabase;
  final Isar isar;

  /// A watch query fetching LocalVisit records where status == 'waiting_for_lab'.
  /// Ordered by createdAt ascending for strict FIFO.
  Stream<List<LocalVisit>> getLiveQueue() {
    return isar.localVisits
        .filter()
        .statusEqualTo('waiting_for_lab')
        .sortByCreatedAt()
        .watch(fireImmediately: true);
  }

  /// Processes the lab visit: writes to Isar locally first, then attempts Supabase sync.
  Future<void> completeLabProcessing({
    required LocalVisit visit,
    required double hemoglobin,
    required double wbc,
    required double platelets,
    required int prescribedVolumeMl,
  }) async {
    final uuid = const Uuid().v4();
    final technicianId = supabase.auth.currentUser?.id ?? '';

    // 1. Create LocalLabResult
    final localResult = LocalLabResult()
      ..id = uuid
      ..visitId = visit.id
      ..hemoglobin = hemoglobin
      ..wbc = wbc
      ..platelets = platelets
      ..prescribedVolumeMl = prescribedVolumeMl
      ..conductedBy = technicianId
      ..syncStatus = LabResultSyncStatus.pendingInsert;

    // 2. Local Write First (Offline-First)
    await isar.writeTxn(() async {
      // Save result
      await isar.localLabResults.put(localResult);
      // Update visit status
      visit.status = 'completed';
      visit.syncStatus = VisitSyncStatus.pendingUpdate;
      await isar.localVisits.put(visit);
    });

    // 3. Cloud Push
    try {
      // Insert lab result to Supabase
      await supabase.from('lab_results').insert({
        'id': uuid,
        'visit_id': visit.id,
        'hemoglobin': hemoglobin,
        'wbc': wbc,
        'platelets': platelets,
        'prescribed_volume_ml': prescribedVolumeMl,
        'conducted_by': technicianId,
      });

      // Update visit status on Supabase
      await supabase.from('visits').update({
        'status': 'completed'
      }).eq('id', visit.id);

      // 4. Inventory Trigger RPC
      // Fetch the user's blood group first to pass to RPC.
      final profile = await supabase
          .from('profiles')
          .select('blood_group')
          .eq('id', visit.userId)
          .maybeSingle();
      
      final bloodGroup = profile?['blood_group'] as String?;
      
      if (bloodGroup != null) {
        final deltaMl = visit.type == 'donation' ? 500 : -prescribedVolumeMl;
        await supabase.rpc('adjust_inventory', params: {
          'p_blood_group': bloodGroup,
          'p_delta_ml': deltaMl,
        });
      }

      // 5. Update local sync status on complete network success
      await isar.writeTxn(() async {
        localResult.syncStatus = LabResultSyncStatus.synced;
        await isar.localLabResults.put(localResult);
        
        visit.syncStatus = VisitSyncStatus.synced;
        await isar.localVisits.put(visit);
      });
      
    } catch (e) {
      // Catch all network exceptions gracefully to preserve the offline queue flow.
      // SyncManager will retry later.
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final labRepositoryProvider = Provider<LabRepository>((ref) {
  return LabRepository(
    SupabaseClientManager.client,
    LocalDatabase.instance,
  );
});

final liveQueueProvider = StreamProvider.autoDispose<List<LocalVisit>>((ref) {
  return ref.watch(labRepositoryProvider).getLiveQueue();
});
