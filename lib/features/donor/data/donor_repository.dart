import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_guardianship.dart';
import 'package:lifelink/core/network/supabase_client.dart';

class EligibilityStatus {
  EligibilityStatus({
    required this.isEligible,
    required this.daysRemaining,
    required this.nextEligibleDate,
  });

  final bool isEligible;
  final int daysRemaining;
  final DateTime nextEligibleDate;
}

class DonorRepository {
  DonorRepository(this.supabase, this.isar);

  final SupabaseClient supabase;
  final Isar isar;

  /// Retrieves the current user's ID safely.
  String get currentUserId => supabase.auth.currentUser?.id ?? '';

  /// Stream of past donations sorted by newest first (Offline-First).
  Stream<List<LocalVisit>> getDonationHistory() {
    return isar.localVisits
        .filter()
        .userIdEqualTo(currentUserId)
        .and()
        .typeEqualTo('donation')
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
  }

  /// Calculates donation eligibility based on the 90-day cycle.
  Future<EligibilityStatus> getEligibilityStatus() async {
    // Look for the most recent completed donation locally.
    final latestDonation = await isar.localVisits
        .filter()
        .userIdEqualTo(currentUserId)
        .and()
        .typeEqualTo('donation')
        .and()
        .statusEqualTo('completed')
        .sortByCreatedAtDesc()
        .findFirst();

    if (latestDonation == null) {
      return EligibilityStatus(
        isEligible: true,
        daysRemaining: 0,
        nextEligibleDate: DateTime.now(),
      );
    }

    // A standard whole blood donation cooldown is 90 days.
    final nextEligibleDate = latestDonation.createdAt.add(const Duration(days: 90));
    final now = DateTime.now();
    final diff = nextEligibleDate.difference(now);

    if (diff.isNegative) {
      return EligibilityStatus(
        isEligible: true,
        daysRemaining: 0,
        nextEligibleDate: now,
      );
    } else {
      return EligibilityStatus(
        isEligible: false,
        daysRemaining: diff.inDays,
        nextEligibleDate: nextEligibleDate,
      );
    }
  }

  /// Requests access to a Thalassemia patient's records.
  Future<void> requestGuardianship(String patientId) async {
    final uuid = const Uuid().v4();

    final guardianship = LocalGuardianship()
      ..id = uuid
      ..donorId = currentUserId
      ..patientId = patientId
      ..status = 'pending'
      ..syncStatus = GuardianshipSyncStatus.pendingInsert;

    // 1. Offline-First Local Write
    await isar.writeTxn(() async {
      await isar.localGuardianships.put(guardianship);
    });

    // 2. Cloud Sync
    try {
      await supabase.from('guardianships').insert({
        'id': uuid,
        'donor_id': currentUserId,
        'patient_id': patientId,
        'status': 'pending',
      });

      await isar.writeTxn(() async {
        guardianship.syncStatus = GuardianshipSyncStatus.synced;
        await isar.localGuardianships.put(guardianship);
      });
    } catch (e) {
      // Network failure, handled gracefully for offline sync later.
    }
  }

  /// Fetches approved patients linked to this donor from Supabase.
  Future<List<Map<String, dynamic>>> getLinkedPatients() async {
    final response = await supabase
        .from('guardianships')
        .select('*, patient:profiles!guardianships_patient_id_fkey(*)')
        .eq('donor_id', currentUserId)
        .eq('status', 'approved');
        
    return response;
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final donorRepositoryProvider = Provider<DonorRepository>((ref) {
  return DonorRepository(
    SupabaseClientManager.client,
    LocalDatabase.instance,
  );
});

final donationHistoryProvider = StreamProvider.autoDispose<List<LocalVisit>>((ref) {
  return ref.watch(donorRepositoryProvider).getDonationHistory();
});

final eligibilityStatusProvider = FutureProvider.autoDispose<EligibilityStatus>((ref) {
  return ref.watch(donorRepositoryProvider).getEligibilityStatus();
});

final linkedPatientsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(donorRepositoryProvider).getLinkedPatients();
});
