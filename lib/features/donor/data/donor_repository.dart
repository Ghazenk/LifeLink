import 'package:lifelink/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_lab_result.dart';

import 'package:lifelink/core/network/supabase_client.dart';
import 'package:lifelink/core/network/sync_manager.dart';

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
        .ownerUserIdEqualTo(currentUserId)
        .userIdEqualTo(currentUserId)
        .and()
        .typeEqualTo('donation')
        .sortByCreatedAtDesc()
        .watch(fireImmediately: true);
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

  /// Calculates total ml of blood donated by this user
  Future<int> getImpactScore() async {
    final visits = await isar.localVisits
        .filter()
        .ownerUserIdEqualTo(currentUserId)
        .userIdEqualTo(currentUserId)
        .and()
        .typeEqualTo('donation')
        .and()
        .statusEqualTo('completed')
        .findAll();

    int totalVolume = 0;
    for (var v in visits) {
      final lab = await isar.localLabResults
          .filter()
          .ownerUserIdEqualTo(currentUserId)
          .visitIdEqualTo(v.id)
          .findFirst();
      if (lab != null && lab.prescribedVolumeMl != null) {
        totalVolume += lab.prescribedVolumeMl!.toInt();
      }
    }
    return totalVolume;
  }

  /// Fetches top donors leaderboard securely via RPC
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    final response = await supabase.rpc('get_donor_leaderboard');
    return List<Map<String, dynamic>>.from(response);
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final donorRepositoryProvider = Provider<DonorRepository>((ref) {
  ref.watch(
    authStateProvider.select((state) => state.valueOrNull?.session?.user.id),
  );
  return DonorRepository(SupabaseClientManager.client, LocalDatabase.instance);
});

final donationHistoryProvider = StreamProvider.autoDispose<List<LocalVisit>>((
  ref,
) {
  return ref.watch(donorRepositoryProvider).getDonationHistory();
});

final linkedPatientsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(syncRevisionProvider);
      return ref.watch(donorRepositoryProvider).getLinkedPatients();
    });

final impactScoreProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(syncRevisionProvider);
  return ref.watch(donorRepositoryProvider).getImpactScore();
});

final leaderboardProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(syncRevisionProvider);
      return ref.watch(donorRepositoryProvider).getLeaderboard();
    });
