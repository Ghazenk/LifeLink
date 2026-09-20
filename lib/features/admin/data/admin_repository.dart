import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/core/constants/app_constants.dart';
import 'package:lifelink/core/network/supabase_client.dart';

/// Repository for Admin-specific operations.
class AdminRepository {
  AdminRepository(this.supabase);

  final SupabaseClient supabase;

  /// Fetches dashboard statistics: Total Blood (ml), Active Patients, Active Donors.
  Future<Map<String, dynamic>> getDashboardStats() async {
    // 1. Inventory stats
    final inventoryResponse = await supabase.from('inventory').select('blood_group, volume_ml');
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
        .eq('status', 'active');
    final activePatientsCount = patientsResponse.length;

    // 3. Total Active Donors
    final donorsResponse = await supabase
        .from('profiles')
        .select('id')
        .eq('role', 'donor')
        .eq('status', 'active');
    final activeDonorsCount = donorsResponse.length;

    return {
      'total_blood_ml': totalBloodMl,
      'stock_levels': stockLevels,
      'active_patients': activePatientsCount,
      'active_donors': activeDonorsCount,
    };
  }

  /// Securely registers a new staff account without logging out the current admin.
  Future<void> createStaffAccount({
    required String fullName,
    required String phone,
    required String email,
    required String password,
    required String role,
  }) async {
    // Instantiate a temporary, non-persisted client to avoid overriding the admin's session.
    final tempClient = SupabaseClient(
      AppConstants.supabaseUrl,
      AppConstants.supabaseAnonKey,
    );

    try {
      final res = await tempClient.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': role,
        },
      );

      final newUserId = res.user?.id;
      if (newUserId != null) {
        // The handle_new_user trigger creates the profile. 
        // We now update it to make sure they are active and have the correct role.
        await supabase.from('profiles').update({
          'role': role,
          'status': 'active',
        }).eq('id', newUserId);
      }
    } finally {
      tempClient.dispose();
    }
  }

  /// Fetches a paginated list of recent visits for the system override view.
  Future<List<Map<String, dynamic>>> getSystemRecords({int limit = 50, int offset = 0}) async {
    return await supabase
        .from('visits')
        .select('*, profiles(full_name, role)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
  }
  
  /// Deletes a visit record (emergency data correction).
  Future<void> deleteVisitRecord(String visitId) async {
    await supabase.from('visits').delete().eq('id', visitId);
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(SupabaseClientManager.client);
});

final adminDashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(adminRepositoryProvider).getDashboardStats();
});

final systemRecordsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(adminRepositoryProvider).getSystemRecords();
});
