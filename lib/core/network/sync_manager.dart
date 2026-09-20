import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/core/local_db/local_database.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_lab_result.dart';
import 'package:lifelink/core/local_db/models/local_guardianship.dart';
import 'package:lifelink/core/network/supabase_client.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  @visibleForTesting
  Isar? debugIsar;
  @visibleForTesting
  SupabaseClient? debugSupabase;

  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        // We have an active connection, attempt sync
        _syncPendingData();
      }
    });

    // Also attempt sync immediately on init if we have network
    _syncPendingData();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  @visibleForTesting
  Future<void> forceSync() => _syncPendingData();

  Future<void> _syncPendingData() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final isar = debugIsar ?? LocalDatabase.instance;
      final supabase = debugSupabase ?? SupabaseClientManager.client;

      // 1. Sync Visits
      await _syncVisits(isar, supabase);

      // 2. Sync Lab Results
      await _syncLabResults(isar, supabase);

      // 3. Sync Guardianships
      await _syncGuardianships(isar, supabase);

    } catch (e) {
      debugPrint('SyncManager loop error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncVisits(Isar isar, SupabaseClient supabase) async {
    final pendingInserts = await isar.localVisits
        .filter()
        .syncStatusEqualTo(VisitSyncStatus.pendingInsert)
        .findAll();

    for (final visit in pendingInserts) {
      try {
        await supabase.from('visits').insert({
          'id': visit.id,
          'user_id': visit.userId,
          'token_number': visit.tokenNumber,
          'type': visit.type,
          'status': visit.status,
          // created_at is handled by DB default/trigger or can be passed if strictly needed
        });
        
        await _markVisitSynced(isar, visit);
      } catch (e) {
        _handleSyncError(e, () => _markVisitSynced(isar, visit));
      }
    }

    final pendingUpdates = await isar.localVisits
        .filter()
        .syncStatusEqualTo(VisitSyncStatus.pendingUpdate)
        .findAll();

    for (final visit in pendingUpdates) {
      try {
        await supabase.from('visits').update({
          'status': visit.status,
        }).eq('id', visit.id);
        
        await _markVisitSynced(isar, visit);
      } catch (e) {
        // Updates don't typically throw 23505, but we catch network errors
        debugPrint('Visit update failed: $e');
      }
    }
  }

  Future<void> _syncLabResults(Isar isar, SupabaseClient supabase) async {
    final pendingInserts = await isar.localLabResults
        .filter()
        .syncStatusEqualTo(LabResultSyncStatus.pendingInsert)
        .findAll();

    for (final result in pendingInserts) {
      try {
        await supabase.from('lab_results').insert({
          'id': result.id,
          'visit_id': result.visitId,
          'hemoglobin': result.hemoglobin,
          'wbc': result.wbc,
          'platelets': result.platelets,
          'prescribed_volume_ml': result.prescribedVolumeMl,
          'conducted_by': result.conductedBy,
        });

        await _markLabResultSynced(isar, result);
        
        // Ensure the adjust_inventory RPC also fires if the sync was delayed.
        // Look up the visit type and user to trigger inventory adjustment correctly.
        final visit = await isar.localVisits.filter().idEqualTo(result.visitId).findFirst();
        if (visit != null) {
           final profile = await supabase
              .from('profiles')
              .select('blood_group')
              .eq('id', visit.userId)
              .maybeSingle();
              
           final bloodGroup = profile?['blood_group'] as String?;
           if (bloodGroup != null) {
              final deltaMl = visit.type == 'donation' ? 500 : -(result.prescribedVolumeMl ?? 0);
              // Ignore failure if this specifically errors, as the main insert succeeded
              supabase.rpc('adjust_inventory', params: {
                'p_blood_group': bloodGroup,
                'p_delta_ml': deltaMl,
              }).ignore();
           }
        }
      } catch (e) {
        _handleSyncError(e, () => _markLabResultSynced(isar, result));
      }
    }
  }

  Future<void> _syncGuardianships(Isar isar, SupabaseClient supabase) async {
    final pendingInserts = await isar.localGuardianships
        .filter()
        .syncStatusEqualTo(GuardianshipSyncStatus.pendingInsert)
        .findAll();

    for (final guard in pendingInserts) {
      try {
        await supabase.from('guardianships').insert({
          'id': guard.id,
          'donor_id': guard.donorId,
          'patient_id': guard.patientId,
          'status': guard.status,
        });
        await _markGuardianshipSynced(isar, guard);
      } catch (e) {
        _handleSyncError(e, () => _markGuardianshipSynced(isar, guard));
      }
    }

    final pendingUpdates = await isar.localGuardianships
        .filter()
        .syncStatusEqualTo(GuardianshipSyncStatus.pendingUpdate)
        .findAll();

    for (final guard in pendingUpdates) {
      try {
        await supabase.from('guardianships').update({
          'status': guard.status,
        }).eq('id', guard.id);
        
        await _markGuardianshipSynced(isar, guard);
      } catch (e) {
        debugPrint('Guardianship update failed: $e');
      }
    }
  }

  /// Helper to safely mark a LocalVisit as synced
  Future<void> _markVisitSynced(Isar isar, LocalVisit visit) async {
    await isar.writeTxn(() async {
      visit.syncStatus = VisitSyncStatus.synced;
      await isar.localVisits.put(visit);
    });
  }

  /// Helper to safely mark a LocalLabResult as synced
  Future<void> _markLabResultSynced(Isar isar, LocalLabResult result) async {
    await isar.writeTxn(() async {
      result.syncStatus = LabResultSyncStatus.synced;
      await isar.localLabResults.put(result);
    });
  }

  /// Helper to safely mark a LocalGuardianship as synced
  Future<void> _markGuardianshipSynced(Isar isar, LocalGuardianship guard) async {
    await isar.writeTxn(() async {
      guard.syncStatus = GuardianshipSyncStatus.synced;
      await isar.localGuardianships.put(guard);
    });
  }

  /// Handles Supabase insert errors.
  /// If it's a unique constraint violation (code '23505'), it means the record
  /// was already inserted previously but the app crashed/lost connection before
  /// the local `syncStatus` was updated. We mark it as synced to clear the queue.
  void _handleSyncError(Object error, Future<void> Function() onAlreadyExists) {
    if (error is PostgrestException && error.code == '23505') {
      debugPrint('Sync conflict: Record already exists on cloud. Marking as synced locally.');
      onAlreadyExists();
    } else {
      debugPrint('Sync failed: $error');
    }
  }
}
