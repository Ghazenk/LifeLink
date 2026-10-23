import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lifelink/features/auth/data/auth_repository.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_lab_result.dart';
import 'package:lifelink/core/local_db/models/local_guardianship.dart';
import 'package:lifelink/core/local_db/models/local_user_profile.dart';
import 'package:lifelink/core/network/sync_engine.dart';

class MockClient extends Mock implements SupabaseClient {}

class MockAuth extends Mock implements GoTrueClient {}

class FakeTransport implements SyncTransport {
  @override
  String? userId = 'staff';
  String status = 'active';
  bool fail = false;
  Completer<void>? gate;
  final calls = <Map<String, dynamic>>[];
  final cloud = <String, List<Map<String, dynamic>>>{
    'visits': [],
    'lab_results': [],
    'guardianships': [],
  };
  @override
  Future<Map<String, dynamic>?> profile(String id) async {
    if (gate != null) await gate!.future;
    return {
      'id': id,
      'role': 'lab',
      'status': status,
      'full_name': 'Test Staff',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> rows(String table) async => cloud[table]!;
  @override
  Future<void> invoke(String name, Map<String, dynamic> parameters) async {
    calls.add({'name': name, ...parameters});
    if (fail) {
      throw StateError('Duplicate or unauthorized; must not acknowledge');
    }
    if (name == 'queue_visit') {
      cloud['visits']!.add({
        ...parameters['payload'] as Map<String, dynamic>,
        'status': 'waiting_for_lab',
      });
    }
    if (name == 'complete_lab_visit') {
      cloud['lab_results']!.add(parameters['payload'] as Map<String, dynamic>);
      for (final visit in cloud['visits']!) {
        if (visit['id'] == parameters['payload']['visit_id']) {
          visit['status'] = 'completed';
        }
      }
    }
  }
}

LocalVisit visit(String id, {String? owner = 'staff'}) => LocalVisit()
  ..id = id
  ..ownerUserId = owner
  ..userId = 'patient'
  ..tokenNumber = 'T-$id'
  ..type = 'transfusion'
  ..status = 'waiting_for_lab'
  ..createdAt = DateTime.utc(2026, 1, 1)
  ..syncStatus = VisitSyncStatus.pendingInsert;

void main() {
  late Isar isar;
  late Directory directory;
  late FakeTransport transport;
  late SyncEngine engine;
  setUpAll(() async {
    HttpOverrides.global = null;
    await Isar.initializeIsarCore(download: true);
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lifelink_sync_');
    isar = await Isar.open(
      [
        LocalVisitSchema,
        LocalLabResultSchema,
        LocalGuardianshipSchema,
        LocalUserProfileSchema,
      ],
      directory: directory.path,
      name: 'sync',
      inspector: false,
    );
    transport = FakeTransport();
    engine = SyncEngine(isar, transport);
  });
  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    for (final entry in directory.listSync()) {
      if (entry is File) await entry.delete();
    }
    await directory.delete();
  });
  test(
    'Only the active account outbox is pushed; legacy rows stay quarantined',
    () async {
      await isar.writeTxn(
        () => isar.localVisits.putAll([
          visit('own'),
          visit('other', owner: 'other'),
          visit('legacy', owner: null),
        ]),
      );
      final report = await engine.sync();
      expect(report.failed, 0);
      expect(transport.calls.length, 1);
      expect(
        transport.calls.single['payload']['created_at'],
        '2026-01-01T00:00:00.000Z',
      );
      expect(
        (await isar.localVisits.filter().idEqualTo('own').findFirst())!
            .syncStatus,
        VisitSyncStatus.synced,
      );
      expect(
        (await isar.localVisits.filter().idEqualTo('other').findFirst())!
            .syncStatus,
        VisitSyncStatus.pendingInsert,
      );
    },
  );
  test(
    'Failed write retains outbox and cloud pulls cannot overwrite it',
    () async {
      await isar.writeTxn(() => isar.localVisits.put(visit('own')));
      transport.fail = true;
      transport.cloud['visits'] = [
        {
          'id': 'own',
          'user_id': 'patient',
          'token_number': 'wrong',
          'type': 'transfusion',
          'status': 'completed',
          'created_at': '2026-01-02T00:00:00Z',
        },
      ];
      final report = await engine.sync();
      expect(report.failed, 1);
      expect(report.pending, 1);
      expect(
        (await isar.localVisits.filter().idEqualTo('own').findFirst())!
            .tokenNumber,
        'T-own',
      );
    },
  );
  test(
    'Full lab result and completion are acknowledged together after RPC',
    () async {
      final pending = visit('v')..status = 'completed';
      final lab = LocalLabResult()
        ..id = 'lab'
        ..ownerUserId = 'staff'
        ..visitId = 'v'
        ..conductedBy = 'staff'
        ..hemoglobin = 11
        ..wbc = 6
        ..platelets = 250
        ..rbc = 4
        ..hematocrit = 36
        ..mcv = 80
        ..mch = 29
        ..mchc = 33
        ..ferritin = 180
        ..prescribedVolumeMl = 350
        ..syncStatus = LabResultSyncStatus.pendingInsert;
      await isar.writeTxn(() async {
        await isar.localVisits.put(pending);
        await isar.localLabResults.put(lab);
      });
      expect((await engine.sync()).failed, 0);
      expect(transport.calls.map((x) => x['name']), [
        'queue_visit',
        'complete_lab_visit',
      ]);
      expect(transport.calls.last['payload']['ferritin'], 180);
      expect(transport.calls.last['payload']['prescribed_volume_ml'], 350);
      expect(
        (await isar.localLabResults.get(lab.isarId))!.syncStatus,
        LabResultSyncStatus.synced,
      );
      expect((await isar.localVisits.get(pending.isarId))!.status, 'completed');
    },
  );
  test(
    'Pull creates account-owned cache and removes revoked synced rows',
    () async {
      final old = visit('old')..syncStatus = VisitSyncStatus.synced;
      await isar.writeTxn(() => isar.localVisits.put(old));
      transport.cloud['visits'] = [
        {
          'id': 'new',
          'user_id': 'patient',
          'token_number': 'T-new',
          'type': 'transfusion',
          'status': 'waiting_for_lab',
          'created_at': '2026-01-02T00:00:00Z',
        },
      ];
      await engine.sync();
      expect(await isar.localVisits.get(old.isarId), isNull);
      expect(
        (await isar.localVisits.where().findAll()).single.ownerUserId,
        'staff',
      );
    },
  );
  test(
    'Inactive accounts cannot push and lose synced cached records',
    () async {
      transport.status = 'rejected';
      await isar.writeTxn(
        () => isar.localVisits.putAll([
          visit('pending'),
          visit('cached')..syncStatus = VisitSyncStatus.synced,
        ]),
      );
      final report = await engine.sync();
      expect(report.authenticated, false);
      expect(transport.calls, isEmpty);
      expect((await isar.localVisits.where().findAll()).single.id, 'pending');
    },
  );
  test(
    'Concurrent triggers share one run and account switch aborts it',
    () async {
      transport.gate = Completer<void>();
      await isar.writeTxn(() => isar.localVisits.put(visit('pending')));
      final first = engine.sync();
      final second = engine.sync();
      expect(identical(first, second), true);
      transport.userId = 'other';
      transport.gate!.complete();
      expect((await first).failed, 1);
      expect(transport.calls, isEmpty);
    },
  );
  test('Signed-out session performs no cloud writes', () async {
    transport.userId = null;
    expect((await engine.sync()).authenticated, false);
    expect(transport.calls, isEmpty);
  });
  test(
    'Session expiry removes synced snapshots but retains isolated outbox',
    () async {
      await isar.writeTxn(
        () => isar.localVisits.putAll([
          visit('cached', owner: 'another')
            ..syncStatus = VisitSyncStatus.synced,
          visit('pending', owner: 'staff'),
        ]),
      );
      transport.userId = null;
      expect((await engine.sync()).authenticated, false);
      final remaining = await isar.localVisits.where().findAll();
      expect(remaining.map((row) => row.id), ['pending']);
      expect(remaining.single.ownerUserId, 'staff');
    },
  );
  test(
    'Sign-out clears synced cache and preserves only isolated pending work',
    () async {
      final client = MockClient();
      final auth = MockAuth();
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(
        User(
          id: 'staff',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );
      when(() => auth.signOut(scope: SignOutScope.global))
          .thenAnswer((_) async {});
      await isar.writeTxn(
        () => isar.localVisits.putAll([
          visit('pending'),
          visit('cached')..syncStatus = VisitSyncStatus.synced,
        ]),
      );
      await AuthRepository(supabase: client, isar: isar).signOut();
      final remaining = await isar.localVisits.where().findAll();
      expect(remaining.single.id, 'pending');
      expect(remaining.single.ownerUserId, 'staff');
      verify(() => auth.signOut(scope: SignOutScope.global)).called(1);
    },
  );
  test(
    'Offline server revocation cannot prevent local cache cleanup',
    () async {
      final client = MockClient();
      final auth = MockAuth();
      when(() => client.auth).thenReturn(auth);
      when(() => auth.currentUser).thenReturn(
        User(
          id: 'staff',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01T00:00:00Z',
        ),
      );
      when(() => auth.currentSession).thenReturn(null);
      when(() => auth.signOut(scope: SignOutScope.global))
          .thenThrow(const AuthException('Network unavailable'));
      when(() => auth.signOut(scope: SignOutScope.local))
          .thenAnswer((_) async {});
      await isar.writeTxn(
        () => isar.localVisits.putAll([
          visit('pending'),
          visit('cached')..syncStatus = VisitSyncStatus.synced,
        ]),
      );
      await AuthRepository(supabase: client, isar: isar).signOut();
      expect((await isar.localVisits.where().findAll()).single.id, 'pending');
    },
  );
}
