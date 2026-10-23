import 'dart:async';

import 'package:lifelink/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_lab_result.dart';
import 'package:lifelink/core/network/supabase_client.dart';
import 'package:lifelink/core/network/backend_configuration.dart';
import 'package:lifelink/core/network/sync_manager.dart';

class LabRepository {
  LabRepository(this.supabase, this.isar);

  final SupabaseClient supabase;
  final Isar isar;

  /// A watch query fetching LocalVisit records where status == 'waiting_for_lab'.
  /// Ordered by createdAt ascending for strict FIFO.
  Stream<List<LocalVisit>> getLiveQueue() {
    if (BackendConfiguration.isClinic) {
      return Stream.fromFuture(fetchClinicQueue());
    }
    return isar.localVisits
        .filter()
        .ownerUserIdEqualTo(supabase.auth.currentUser?.id ?? '')
        .statusEqualTo('waiting_for_lab')
        .sortByCreatedAt()
        .watch(fireImmediately: true);
  }

  Future<List<LocalVisit>> fetchClinicQueue() async {
    if (supabase.auth.currentUser == null) {
      throw const AuthException('Sign in to view the clinic queue.');
    }
    final rows = await supabase.from('visits')
        .select('id,user_id,token_number,type,status,created_at')
        .eq('status', 'waiting_for_lab')
        .order('created_at', ascending: true)
        .limit(200)
        .timeout(const Duration(seconds: 15));
    return rows.map((row) => LocalVisit()
      ..id = row['id'] as String
      ..ownerUserId = supabase.auth.currentUser!.id
      ..userId = row['user_id'] as String
      ..tokenNumber = row['token_number'] as String
      ..type = row['type'] as String
      ..status = row['status'] as String
      ..createdAt = DateTime.parse(row['created_at'] as String)
      ..syncStatus = VisitSyncStatus.synced).toList();
  }

  /// Processes the lab visit: writes to Isar locally first, then attempts Supabase sync.
  Future<void> completeLabProcessing({
    required LocalVisit visit,
    required double hemoglobin,
    required double wbc,
    required double platelets,
    required double rbc,
    required double hematocrit,
    required double mcv,
    required double mch,
    required double mchc,
    required double ferritin,
    required int prescribedVolumeMl,
  }) async {
    final technicianId = supabase.auth.currentUser?.id;
    if (technicianId == null || visit.ownerUserId != technicianId) {
      throw const AuthException('Sign in to your own workstation session.');
    }
    final values = [
      hemoglobin,
      wbc,
      platelets,
      rbc,
      hematocrit,
      mcv,
      mch,
      mchc,
      ferritin,
    ];
    if (values.any((v) => !v.isFinite || v < 0 || v > 100000) ||
        prescribedVolumeMl <= 0 ||
        prescribedVolumeMl > 2000) {
      throw ArgumentError(
        'Enter valid lab measurements and a recorded volume between 1 and 2000 mL.',
      );
    }
    if (BackendConfiguration.isClinic) {
      await supabase.rpc('complete_lab_visit', params: {'payload': {
        'id': const Uuid().v4(),
        'visit_id': visit.id,
        'conducted_by': technicianId,
        'hemoglobin': hemoglobin,
        'wbc': wbc,
        'platelets': platelets,
        'rbc': rbc,
        'hematocrit': hematocrit,
        'mcv': mcv,
        'mch': mch,
        'mchc': mchc,
        'ferritin': ferritin,
        'prescribed_volume_ml': prescribedVolumeMl,
      }}).timeout(const Duration(seconds: 15));
      return;
    }
    await isar.writeTxn(() async {
      final current = await isar.localVisits.get(visit.isarId);
      if (current == null || current.status == 'completed') {
        throw StateError('This visit has already been processed.');
      }
      final existing = await isar.localLabResults
          .filter()
          .ownerUserIdEqualTo(supabase.auth.currentUser!.id)
          .visitIdEqualTo(visit.id)
          .findFirst();
      if (existing != null) {
        throw StateError('This visit already has a lab result.');
      }
      await isar.localLabResults.put(
        LocalLabResult()
          ..id = const Uuid().v4()
          ..ownerUserId = technicianId
          ..visitId = visit.id
          ..hemoglobin = hemoglobin
          ..wbc = wbc
          ..platelets = platelets
          ..rbc = rbc
          ..hematocrit = hematocrit
          ..mcv = mcv
          ..mch = mch
          ..mchc = mchc
          ..ferritin = ferritin
          ..prescribedVolumeMl = prescribedVolumeMl
          ..conductedBy = technicianId
          ..syncStatus = LabResultSyncStatus.pendingInsert,
      );
      current.status = 'completed';
      // Never lose the pending parent INSERT when processing an offline visit.
      if (current.syncStatus != VisitSyncStatus.pendingInsert) {
        current.syncStatus = VisitSyncStatus.pendingUpdate;
      }
      await isar.localVisits.put(current);
    });
    unawaited(SyncManager().syncNow());
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final labRepositoryProvider = Provider<LabRepository>((ref) {
  ref.watch(
    authStateProvider.select((state) => state.valueOrNull?.session?.user.id),
  );
  return LabRepository(SupabaseClientManager.client, LocalDatabase.instance);
});

final liveQueueProvider = StreamProvider.autoDispose<List<LocalVisit>>((ref) {
  if (BackendConfiguration.isClinic) ref.watch(syncRevisionProvider);
  return ref.watch(labRepositoryProvider).getLiveQueue();
});
