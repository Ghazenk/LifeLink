import 'dart:async';

import 'package:lifelink/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_lab_result.dart';
import 'package:lifelink/core/network/supabase_client.dart';
import 'package:lifelink/core/network/sync_manager.dart';

class MedicalRecord {
  MedicalRecord({required this.visit, this.labResult});

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
        .ownerUserIdEqualTo(currentUserId)
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
            .ownerUserIdEqualTo(currentUserId)
            .visitIdEqualTo(visit.id)
            .findFirst();

        records.add(MedicalRecord(visit: visit, labResult: labResult));
      }
      yield records;
    }
  }

  /// The server returns only this patient's requests and each requester's name.
  /// A request must not grant access to the requester's full profile.
  Future<List<Map<String, dynamic>>> getPendingGuardianships() async {
    final response = await supabase.rpc('list_guardianship_requests');
    return List<Map<String, dynamic>>.from(response);
  }

  /// Responds to a guardianship request (Approve/Reject)
  Future<void> respondToGuardianship(
    String guardianshipId,
    String newStatus,
  ) async {
    if (!['approved', 'rejected'].contains(newStatus)) {
      throw ArgumentError('Invalid decision');
    }
    await supabase
        .rpc(
          'respond_guardianship',
          params: {'request_id': guardianshipId, 'decision': newStatus},
        )
        .timeout(const Duration(seconds: 20));
    unawaited(SyncManager().syncNow());
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  ref.watch(
    authStateProvider.select((state) => state.valueOrNull?.session?.user.id),
  );
  return PatientRepository(
    SupabaseClientManager.client,
    LocalDatabase.instance,
  );
});

final medicalHistoryProvider = StreamProvider.autoDispose<List<MedicalRecord>>((
  ref,
) {
  return ref.watch(patientRepositoryProvider).getMedicalHistory();
});

final pendingGuardianshipsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(syncRevisionProvider);
      return ref.watch(patientRepositoryProvider).getPendingGuardianships();
    });
