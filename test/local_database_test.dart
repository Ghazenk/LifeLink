import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:lifelink/core/local_db/models/local_visit.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    final directory = Directory.systemTemp.createTempSync('isar_test_dir');
    return directory.path;
  }
}

void main() {
  late Isar isar;

  setUpAll(() async {
    PathProviderPlatform.instance = MockPathProviderPlatform();

    // Allow HTTP requests to download Isar binaries
    HttpOverrides.global = null;
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    final dir = await PathProviderPlatform.instance.getApplicationDocumentsPath();
    isar = await Isar.open(
      [LocalVisitSchema],
      directory: dir!,
      name: 'test_db_${DateTime.now().millisecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    if (isar.isOpen) {
      await isar.close(deleteFromDisk: true);
    }
  });

  group('LocalDatabase (Isar) Tests', () {
    test('Should create and read a LocalVisit successfully', () async {
      // 1. Arrange
      final visit = LocalVisit()
        ..id = 'test-uuid-123'
        ..userId = 'user-1'
        ..tokenNumber = 'D-100'
        ..type = 'donation'
        ..status = 'waiting_for_lab'
        ..createdAt = DateTime.now()
        ..syncStatus = VisitSyncStatus.pendingInsert;

      // 2. Act (Write)
      await isar.writeTxn(() async {
        await isar.localVisits.put(visit);
      });

      // 3. Assert (Read)
      final retrieved = await isar.localVisits.filter().idEqualTo('test-uuid-123').findFirst();

      expect(retrieved, isNotNull);
      expect(retrieved!.tokenNumber, 'D-100');
      expect(retrieved.syncStatus, VisitSyncStatus.pendingInsert);
    });
  });
}
