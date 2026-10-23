import 'package:lifelink/core/network/sync_manager.dart';
import 'package:lifelink/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/core/network/supabase_client.dart';

/// Repository for Admin-specific operations.
class AdminRepository {
  AdminRepository(this.supabase);

  final SupabaseClient supabase;

  /// Fetches dashboard statistics: Total Blood (ml), Active Patients, Active Donors.
  Future<Map<String, dynamic>> getDashboardStats() async {
    // 1. Inventory stats
    final inventoryResponse = await supabase
        .from('inventory')
        .select('blood_group, volume_ml');
    int totalBloodMl = 0;
    final Map<String, int> stockLevels = {};
    for (final row in inventoryResponse) {
      final volume = ((row['volume_ml'] as num?) ?? 0).toInt();
      totalBloodMl += volume;
      final bg = row['blood_group'] as String?;
      if (bg != null) {
        stockLevels[bg] = volume;
      }
    }

    // 2. Total Active Patients
    final patientsResponse = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'patient')
        .eq('status', 'active')
        .limit(1)
        .count(CountOption.exact);
    final activePatientsCount = patientsResponse.count;

    // 3. Total Active Donors
    final donorsResponse = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'donor')
        .eq('status', 'active')
        .limit(1)
        .count(CountOption.exact);
    final activeDonorsCount = donorsResponse.count;

    return {
      'total_blood_ml': totalBloodMl,
      'stock_levels': stockLevels,
      'active_patients': activePatientsCount,
      'active_donors': activeDonorsCount,
    };
  }

  /// Securely registers a new staff account without logging out the current admin.
  Future<void> createStaffAccount({
    required bool age13OrOlder,
    required String fullName,
    required String phone,
    required String email,
    required String role,
  }) async {
    if (!['reception', 'lab'].contains(role)) {
      throw ArgumentError('Invalid staff role');
    }
    final response = await supabase.functions.invoke(
      'manage-users',
      body: {
        'action': 'create_staff',
        'age_13_or_older': age13OrOlder,
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'role': role,
      },
    );
    if (response.status != 200 ||
        response.data is! Map ||
        response.data['created'] != 1) {
      final data = response.data;
      final message = data is Map && data['error'] is String
          ? data['error'] as String
          : 'Staff account could not be created. Check whether the email is already registered, then try again.';
      throw StateError(message);
    }
  }

  /// Fetches a list of all active reception and lab staff members.
  Future<List<Map<String, dynamic>>> getStaffMembers() async {
    return await supabase
        .from('profiles')
        .select('id, full_name, phone, role, status')
        .inFilter('role', ['reception', 'lab'])
        .order('full_name', ascending: true);
  }

  /// Deactivates a staff account (revokes their access without deleting the user).
  Future<void> deactivateStaffAccount(String profileId) async {
    await supabase
        .from('profiles')
        .update({'status': 'rejected'})
        .eq('id', profileId)
        .inFilter('role', ['reception', 'lab'])
        .select('id')
        .single();
  }

  Future<void> reactivateStaffAccount(String profileId) async {
    await supabase
        .from('profiles')
        .update({'status': 'active'})
        .eq('id', profileId)
        .inFilter('role', ['reception', 'lab'])
        .select('id')
        .single();
  }

  /// Updates staff member details.
  Future<void> updateStaffMember({
    required String profileId,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    if (!['reception', 'lab'].contains(role)) {
      throw ArgumentError('Invalid staff role');
    }
    await supabase
        .from('profiles')
        .update({'full_name': fullName, 'phone': phone, 'role': role})
        .eq('id', profileId)
        .inFilter('role', ['reception', 'lab'])
        .select('id')
        .single();
  }

  /// Fetches a paginated list of recent visits for the system override view.
  Future<List<Map<String, dynamic>>> getSystemRecords({
    int limit = 50,
    int offset = 0,
  }) async {
    return await supabase
        .from('visits')
        .select(
          'id, created_at, token_number, type, status, profiles(full_name)',
        )
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
  }

  /// Deletes a visit record (emergency data correction).
  Future<void> deleteVisitRecord(String visitId) async {
    await supabase.rpc(
      'delete_uncompleted_visit',
      params: {'visit_id': visitId},
    );
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  ref.watch(
    authStateProvider.select((state) => state.valueOrNull?.session?.user.id),
  );
  return AdminRepository(SupabaseClientManager.client);
});

final adminDashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      ref.watch(syncRevisionProvider);
      return ref.watch(adminRepositoryProvider).getDashboardStats();
    });

final staffListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(syncRevisionProvider);
      return ref.watch(adminRepositoryProvider).getStaffMembers();
    });

final systemRecordsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      ref.watch(syncRevisionProvider);
      return ref.watch(adminRepositoryProvider).getSystemRecords();
    });
