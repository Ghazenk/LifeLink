import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/core/local_db/models/local_lab_result.dart';
import 'package:lifelink/core/local_db/models/local_guardianship.dart';
import 'package:lifelink/core/network/sync_manager.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final directory = Directory.systemTemp.createTempSync('isar_test_dir_sync');
    return directory.path;
  }
}

class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class FakePostgrestFilterBuilder extends Fake implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {
  @override
  Future<R> then<R>(FutureOr<R> Function(List<Map<String, dynamic>> value) onValue, {Function? onError}) async {
    return onValue([]);
  }
  
  @override
  PostgrestFilterBuilder<List<Map<String, dynamic>>> eq(String column, Object value) {
    return this;
  }
}

void main() {
  late Isar isar;
  late MockSupabaseClient mockSupabase;
  late SyncManager syncManager;

  setUpAll(() async {
    PathProviderPlatform.instance = MockPathProviderPlatform();
    HttpOverrides.global = null;
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    final dir = await PathProviderPlatform.instance.getApplicationDocumentsPath();
    isar = await Isar.open(
      [LocalVisitSchema, LocalLabResultSchema, LocalGuardianshipSchema],
      directory: dir!,
      name: 'test_db_sync_${DateTime.now().millisecondsSinceEpoch}',
    );

    mockSupabase = MockSupabaseClient();
    syncManager = SyncManager()
      ..debugIsar = isar
      ..debugSupabase = mockSupabase;
  });

  tearDown(() async {
    if (isar.isOpen) {
      await isar.close(deleteFromDisk: true);
    }
  });

  group('SyncManager Tests', () {
    test('Should sync pending LocalVisits and update their status', () async {
      // 1. Arrange: Create 2 pending visits
      final visit1 = LocalVisit()
        ..id = 'uuid-1'
        ..userId = 'user-1'
        ..tokenNumber = 'T-1'
        ..type = 'donation'
        ..status = 'waiting_for_lab'
        ..createdAt = DateTime.now()
        ..syncStatus = VisitSyncStatus.pendingInsert;

      final visit2 = LocalVisit()
        ..id = 'uuid-2'
        ..userId = 'user-2'
        ..tokenNumber = 'T-2'
        ..type = 'transfusion'
        ..status = 'waiting_for_lab'
        ..createdAt = DateTime.now()
        ..syncStatus = VisitSyncStatus.pendingInsert;

      await isar.writeTxn(() async {
        await isar.localVisits.putAll([visit1, visit2]);
      });

      // Mock Supabase chain: .from('visits').insert(...)
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = FakePostgrestFilterBuilder();
      
      when(() => mockSupabase.from(any())).thenAnswer((_) => mockQueryBuilder);
      when(() => mockQueryBuilder.insert(any())).thenAnswer((_) => mockFilterBuilder);

      // We also need to mock from('lab_results') and from('guardianships') because the sync loop checks them
      when(() => mockQueryBuilder.update(any())).thenAnswer((_) => mockFilterBuilder);

      // 2. Act: Trigger sync loop
      await syncManager.forceSync();

      // 3. Assert
      // Verify Supabase insert was called (we don't strictly assert the exact map payload here for simplicity,
      // just that .insert was called).
      verify(() => mockQueryBuilder.insert(any())).called(greaterThanOrEqualTo(2));

      // Verify Isar status was updated to synced
      final visitsAfterSync = await isar.localVisits.where().findAll();
      expect(visitsAfterSync.length, 2);
      expect(visitsAfterSync[0].syncStatus, VisitSyncStatus.synced);
      expect(visitsAfterSync[1].syncStatus, VisitSyncStatus.synced);
    });
  });
}
