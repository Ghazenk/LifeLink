import 'package:isar_community/isar.dart';

part 'local_lab_result.g.dart';

/// Sync status for offline-first operations.
enum LabResultSyncStatus {
  synced,
  pendingInsert,
  pendingUpdate,
}

/// Local Isar collection mirroring the Supabase `lab_results` table.
@collection
class LocalLabResult {
  Id isarId = Isar.autoIncrement;

  /// Supabase UUID.
  @Index(unique: true, replace: true)
  late String id;

  /// Supabase UUID of the associated visit.
  @Index()
  late String visitId;

  late double hemoglobin;
  
  late double wbc;
  
  late double platelets;

  /// Volume prescribed for transfusion. Null/0 for donation.
  int? prescribedVolumeMl;

  /// Supabase UUID of the lab technician who conducted the test.
  late String conductedBy;

  /// Tracks whether this record needs to be synced to Supabase.
  @enumerated
  LabResultSyncStatus syncStatus = LabResultSyncStatus.synced;
}
