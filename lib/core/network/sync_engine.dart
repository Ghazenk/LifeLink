import 'package:isar_community/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../local_db/models/local_visit.dart';
import '../local_db/models/local_lab_result.dart';
import '../local_db/models/local_guardianship.dart';
import '../local_db/models/local_user_profile.dart';

abstract interface class SyncTransport {
  String? get userId;
  Future<Map<String, dynamic>?> profile(String userId);
  Future<List<Map<String, dynamic>>> rows(String table);
  Future<void> invoke(String name, Map<String, dynamic> parameters);
}

class SupabaseSyncTransport implements SyncTransport {
  SupabaseSyncTransport(this.client);
  final SupabaseClient client;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Future<Map<String, dynamic>?> profile(String userId) => client
      .from('profiles')
      .select()
      .eq('id', userId)
      .maybeSingle()
      .timeout(const Duration(seconds: 25));
  @override
  Future<void> invoke(String name, Map<String, dynamic> parameters) async {
    if (name != 'queue_visit' && name != 'complete_lab_visit') {
      throw ArgumentError.value(name, 'name', 'Unsupported sync operation');
    }
    await client
        .rpc(name, params: parameters)
        .timeout(const Duration(seconds: 25));
  }

  @override
  Future<List<Map<String, dynamic>>> rows(String table) async {
    if (table != 'visits' &&
        table != 'lab_results' &&
        table != 'guardianships') {
      throw ArgumentError.value(table, 'table', 'Unsupported cache table');
    }
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; offset < 100000; offset += 500) {
      final page = await client
          .from(table)
          .select()
          .order('id')
          .range(offset, offset + 499)
          .timeout(const Duration(seconds: 25));
      result.addAll(page);
      if (page.length < 500) return result;
    }
    throw StateError(
      'Sync snapshot exceeds the supported size; no cache reconciliation performed.',
    );
  }
}

class SyncReport {
  const SyncReport({
    this.pending = 0,
    this.failed = 0,
    this.authenticated = true,
  });
  final int pending;
  final int failed;
  final bool authenticated;
}

/// A single writer owns cloud synchronization. Repositories only write the outbox.
class SyncEngine {
  SyncEngine(this.isar, this.transport);
  final Isar isar;
  final SyncTransport transport;
  Future<SyncReport>? _running;
  Future<SyncReport> sync() =>
      _running ??= _run().whenComplete(() => _running = null);
  void _checkAccount(String owner) {
    if (transport.userId != owner) {
      throw StateError('Account changed during sync');
    }
  }

  Future<int> pendingCount(String owner) async =>
      await isar.localVisits
          .filter()
          .ownerUserIdEqualTo(owner)
          .not()
          .syncStatusEqualTo(VisitSyncStatus.synced)
          .count() +
      await isar.localLabResults
          .filter()
          .ownerUserIdEqualTo(owner)
          .not()
          .syncStatusEqualTo(LabResultSyncStatus.synced)
          .count() +
      await isar.localGuardianships
          .filter()
          .ownerUserIdEqualTo(owner)
          .not()
          .syncStatusEqualTo(GuardianshipSyncStatus.synced)
          .count();

  Future<SyncReport> _run() async {
    final owner = transport.userId;
    if (owner == null) {
      // Session expiry can sign out without going through AuthRepository.
      // Remove readable snapshots for every previous account; keep only the
      // account-owned pending outbox so offline clinical work is not lost.
      await isar.writeTxn(() async {
        await isar.localUserProfiles.clear();
        await isar.localVisits
            .filter()
            .syncStatusEqualTo(VisitSyncStatus.synced)
            .deleteAll();
        await isar.localLabResults
            .filter()
            .syncStatusEqualTo(LabResultSyncStatus.synced)
            .deleteAll();
        await isar.localGuardianships
            .filter()
            .syncStatusEqualTo(GuardianshipSyncStatus.synced)
            .deleteAll();
      });
      return const SyncReport(authenticated: false);
    }
    var failed = 0;
    try {
      final profile = await transport.profile(owner);
      _checkAccount(owner);
      await isar.writeTxn(() async {
        if (profile == null) {
          await isar.localUserProfiles.filter().idEqualTo(owner).deleteAll();
        } else {
          await isar.localUserProfiles.put(
            LocalUserProfile.fromSupabaseMap(profile),
          );
        }
      });
      if (profile == null || profile['status'] != 'active') {
        await _clearSynced(owner);
        return SyncReport(
          pending: await pendingCount(owner),
          authenticated: false,
        );
      }
      final visits = await isar.localVisits
          .filter()
          .ownerUserIdEqualTo(owner)
          .syncStatusEqualTo(VisitSyncStatus.pendingInsert)
          .findAll();
      for (final visit in visits) {
        _checkAccount(owner);
        try {
          await transport.invoke('queue_visit', {
            'payload': {
              'id': visit.id,
              'user_id': visit.userId,
              'token_number': visit.tokenNumber,
              'type': visit.type,
              'created_at': visit.createdAt.toUtc().toIso8601String(),
            },
          });
          _checkAccount(owner);
          await isar.writeTxn(() async {
            final current = await isar.localVisits.get(visit.isarId);
            if (current == null || current.ownerUserId != owner) return;
            current.syncStatus = current.status == 'completed'
                ? VisitSyncStatus.pendingUpdate
                : VisitSyncStatus.synced;
            await isar.localVisits.put(current);
          });
        } catch (_) {
          failed++;
        }
      }
      final results = await isar.localLabResults
          .filter()
          .ownerUserIdEqualTo(owner)
          .syncStatusEqualTo(LabResultSyncStatus.pendingInsert)
          .findAll();
      for (final result in results) {
        _checkAccount(owner);
        try {
          await transport.invoke('complete_lab_visit', {
            'payload': {
              'id': result.id,
              'visit_id': result.visitId,
              'conducted_by': result.conductedBy,
              'hemoglobin': result.hemoglobin,
              'wbc': result.wbc,
              'platelets': result.platelets,
              'rbc': result.rbc,
              'hematocrit': result.hematocrit,
              'mcv': result.mcv,
              'mch': result.mch,
              'mchc': result.mchc,
              'ferritin': result.ferritin,
              'prescribed_volume_ml': result.prescribedVolumeMl,
            },
          });
          _checkAccount(owner);
          await isar.writeTxn(() async {
            final current = await isar.localLabResults.get(result.isarId);
            if (current == null || current.ownerUserId != owner) return;
            current.syncStatus = LabResultSyncStatus.synced;
            await isar.localLabResults.put(current);
            final visit = await isar.localVisits
                .filter()
                .idEqualTo(result.visitId)
                .ownerUserIdEqualTo(owner)
                .findFirst();
            if (visit != null) {
              visit.status = 'completed';
              visit.syncStatus = VisitSyncStatus.synced;
              await isar.localVisits.put(visit);
            }
          });
        } catch (_) {
          failed++;
        }
      }
      // Legacy UUID/offline sharing actions cannot establish consent. Discard only
      // these obsolete sharing drafts; visits and clinical outboxes are preserved.
      await isar.writeTxn(() async {
        _checkAccount(owner);
        await isar.localGuardianships
            .filter()
            .ownerUserIdEqualTo(owner)
            .not()
            .syncStatusEqualTo(GuardianshipSyncStatus.synced)
            .deleteAll();
      });
      // Pull only data permitted by current server RLS. Fetch all pages before reconciling.
      final cloudVisits = await transport.rows('visits');
      _checkAccount(owner);
      final cloudLabs = await transport.rows('lab_results');
      _checkAccount(owner);
      final cloudGuards = await transport.rows('guardianships');
      _checkAccount(owner);
      await isar.writeTxn(() async {
        _checkAccount(owner);
        final visitIds = cloudVisits.map((r) => r['id'] as String).toSet();
        final labIds = cloudLabs.map((r) => r['id'] as String).toSet();
        final guardIds = cloudGuards.map((r) => r['id'] as String).toSet();
        for (final old
            in await isar.localVisits
                .filter()
                .ownerUserIdEqualTo(owner)
                .syncStatusEqualTo(VisitSyncStatus.synced)
                .findAll()) {
          if (!visitIds.contains(old.id)) {
            await isar.localVisits.delete(old.isarId);
          }
        }
        for (final old
            in await isar.localLabResults
                .filter()
                .ownerUserIdEqualTo(owner)
                .syncStatusEqualTo(LabResultSyncStatus.synced)
                .findAll()) {
          if (!labIds.contains(old.id)) {
            await isar.localLabResults.delete(old.isarId);
          }
        }
        for (final old
            in await isar.localGuardianships
                .filter()
                .ownerUserIdEqualTo(owner)
                .syncStatusEqualTo(GuardianshipSyncStatus.synced)
                .findAll()) {
          if (!guardIds.contains(old.id)) {
            await isar.localGuardianships.delete(old.isarId);
          }
        }
        for (final row in cloudVisits) {
          final old = await isar.localVisits
              .filter()
              .idEqualTo(row['id'] as String)
              .findFirst();
          if (old != null && old.syncStatus != VisitSyncStatus.synced) continue;
          await isar.localVisits.put(
            LocalVisit()
              ..isarId = old?.isarId ?? Isar.autoIncrement
              ..ownerUserId = owner
              ..id = row['id'] as String
              ..userId = row['user_id'] as String
              ..tokenNumber = row['token_number'] as String
              ..type = row['type'] as String
              ..status = row['status'] as String
              ..createdAt = DateTime.parse(row['created_at'] as String),
          );
        }
        for (final row in cloudLabs) {
          final old = await isar.localLabResults
              .filter()
              .idEqualTo(row['id'] as String)
              .findFirst();
          if (old != null && old.syncStatus != LabResultSyncStatus.synced) {
            continue;
          }
          double? number(String key) => (row[key] as num?)?.toDouble();
          await isar.localLabResults.put(
            LocalLabResult()
              ..isarId = old?.isarId ?? Isar.autoIncrement
              ..ownerUserId = owner
              ..id = row['id'] as String
              ..visitId = row['visit_id'] as String
              ..hemoglobin = number('hemoglobin') ?? 0
              ..wbc = number('wbc') ?? 0
              ..platelets = number('platelets') ?? 0
              ..rbc = number('rbc')
              ..hematocrit = number('hematocrit')
              ..mcv = number('mcv')
              ..mch = number('mch')
              ..mchc = number('mchc')
              ..ferritin = number('ferritin')
              ..prescribedVolumeMl = (row['prescribed_volume_ml'] as num?)
                  ?.toInt()
              ..conductedBy = row['conducted_by'] as String? ?? '',
          );
        }
        for (final row in cloudGuards) {
          final old = await isar.localGuardianships
              .filter()
              .idEqualTo(row['id'] as String)
              .findFirst();
          if (old != null && old.syncStatus != GuardianshipSyncStatus.synced) {
            continue;
          }
          await isar.localGuardianships.put(
            LocalGuardianship()
              ..isarId = old?.isarId ?? Isar.autoIncrement
              ..ownerUserId = owner
              ..id = row['id'] as String
              ..donorId = row['donor_id'] as String
              ..patientId = row['patient_id'] as String
              ..status = row['status'] as String,
          );
        }
      });
    } catch (_) {
      failed++;
    }
    return SyncReport(pending: await pendingCount(owner), failed: failed);
  }

  Future<void> _clearSynced(String owner) => isar.writeTxn(() async {
    await isar.localVisits
        .filter()
        .ownerUserIdEqualTo(owner)
        .syncStatusEqualTo(VisitSyncStatus.synced)
        .deleteAll();
    await isar.localLabResults
        .filter()
        .ownerUserIdEqualTo(owner)
        .syncStatusEqualTo(LabResultSyncStatus.synced)
        .deleteAll();
    await isar.localGuardianships
        .filter()
        .ownerUserIdEqualTo(owner)
        .syncStatusEqualTo(GuardianshipSyncStatus.synced)
        .deleteAll();
  });
}
