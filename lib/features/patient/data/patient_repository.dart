import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_lab_result.dart';
import 'package:lifelink/core/local_db/models/local_guardianship.dart';
import 'package:lifelink/core/network/supabase_client.dart';

class MedicalRecord {
  MedicalRecord({
    required this.visit,
    this.labResult,
  });

  final LocalVisit visit;
  final LocalLabResult? labResult;
}

class PatientRepository {
  PatientRepository(this.supabase, this.isar);

  final SupabaseClient supabase;
  final Isar isar;

  String get currentUserId => supabase.auth.currentUser?.id ?? '';

  /// Stream of patient's transfusion history, joined locally with lab results.
  Stream<List<MedicalRecord>> getMedicalHistory() async* {
    final visitStream = isar.localVisits
        .filter()
        .userIdEqualTo(currentUserId)
        .and()
        .typeEqualTo('transfusion')
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);

    await for (final visits in visitStream) {
      final List<MedicalRecord> records = [];
      for (final visit in visits) {
        // Fetch matching lab result
        final labResult = await isar.localLabResults
            .filter()
            .visitIdEqualTo(visit.id)
            .findFirst();
        
        records.add(MedicalRecord(visit: visit, labResult: labResult));
      }
      yield records;
    }
  }

  /// Calculates estimated next transfusion (21 days from last completed).
  Future<DateTime?> getNextTransfusionEstimate() async {
    final latestTransfusion = await isar.localVisits
        .filter()
        .userIdEqualTo(currentUserId)
        .and()
        .typeEqualTo('transfusion')
        .and()
        .statusEqualTo('completed')
        .sortByCreatedAtDesc()
        .findFirst();

    if (latestTransfusion == null) return null;
    return latestTransfusion.createdAt.add(const Duration(days: 21));
  }

  /// Fetches pending guardianships joined with donor profiles via Supabase.
  /// (Using Supabase directly here since we need the donor's `profiles` data).
  Future<List<Map<String, dynamic>>> getPendingGuardianships() async {
    final response = await supabase
        .from('guardianships')
        .select('*, donor:profiles!guardianships_donor_id_fkey(*)')
        .eq('patient_id', currentUserId)
        .eq('status', 'pending');
        
    return response;
  }

  /// Responds to a guardianship request (Approve/Reject)
  Future<void> respondToGuardianship(String guardianshipId, String newStatus) async {
    // Attempt local update if record exists locally
    final localRecord = await isar.localGuardianships
        .filter()
        .idEqualTo(guardianshipId)
        .findFirst();

    if (localRecord != null) {
      await isar.writeTxn(() async {
        localRecord.status = newStatus;
        localRecord.syncStatus = GuardianshipSyncStatus.pendingUpdate;
        await isar.localGuardianships.put(localRecord);
      });
    }

    // Cloud push
    try {
      await supabase
          .from('guardianships')
          .update({'status': newStatus})
          .eq('id', guardianshipId);

      if (localRecord != null) {
        await isar.writeTxn(() async {
          localRecord.syncStatus = GuardianshipSyncStatus.synced;
          await isar.localGuardianships.put(localRecord);
        });
      }
    } catch (e) {
      // Offline fallback handling
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepository(
    SupabaseClientManager.client,
    LocalDatabase.instance,
  );
});

final medicalHistoryProvider = StreamProvider.autoDispose<List<MedicalRecord>>((ref) {
  return ref.watch(patientRepositoryProvider).getMedicalHistory();
});

final nextTransfusionProvider = FutureProvider.autoDispose<DateTime?>((ref) {
  return ref.watch(patientRepositoryProvider).getNextTransfusionEstimate();
});

final pendingGuardianshipsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(patientRepositoryProvider).getPendingGuardianships();
});
