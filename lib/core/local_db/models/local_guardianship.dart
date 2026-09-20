import 'package:isar_community/isar.dart';

part 'local_guardianship.g.dart';

/// Sync status for offline-first operations.
enum GuardianshipSyncStatus {
  synced,
  pendingInsert,
  pendingUpdate,
}

/// Local Isar collection mirroring the Supabase `guardianships` table.
@collection
class LocalGuardianship {
  Id isarId = Isar.autoIncrement;

  /// Supabase UUID.
  @Index(unique: true, replace: true)
  late String id;

  /// Supabase UUID of the donor requesting access.
  @Index()
  late String donorId;

  /// Supabase UUID of the patient being linked.
  @Index()
  late String patientId;

  /// One of: 'pending', 'approved', 'rejected'.
  late String status;

  /// Tracks whether this record needs to be synced to Supabase.
  @enumerated
  GuardianshipSyncStatus syncStatus = GuardianshipSyncStatus.synced;
}
