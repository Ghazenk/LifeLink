import 'package:isar_community/isar.dart';

part 'local_visit.g.dart';

/// Sync status for offline-first operations.
enum VisitSyncStatus { synced, pendingInsert, pendingUpdate }

/// Local Isar collection mirroring the Supabase `visits` table.
///
/// Supports offline token generation for Reception, allowing tokens
/// to be issued even when network connectivity is lost.
@collection
class LocalVisit {
  Id isarId = Isar.autoIncrement;

  /// Account that owns this local cache/outbox entry. Null legacy rows are quarantined.
  @Index()
  String? ownerUserId;

  /// Supabase UUID.
  @Index(unique: true, replace: true)
  late String id;

  /// Supabase UUID of the associated user (donor or patient).
  @Index()
  late String userId;

  /// E.g., 'D-123' or 'T-124'.
  late String tokenNumber;

  /// One of: 'donation', 'transfusion'.
  late String type;

  /// One of: 'waiting_for_lab', 'in_lab', 'completed'.
  late String status;

  late DateTime createdAt;

  /// Tracks whether this record needs to be synced to Supabase.
  @enumerated
  VisitSyncStatus syncStatus = VisitSyncStatus.synced;
}
