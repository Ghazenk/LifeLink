import 'package:isar_community/isar.dart';

part 'local_user_profile.g.dart';

/// Sync status for offline-first operations.
enum SyncStatus { synced, pendingInsert, pendingUpdate }

/// Local Isar collection mirroring the Supabase `profiles` table.
///
/// This enables offline-first reads — the UI always reads from Isar,
/// and sync logic keeps it in sync with Supabase.
@collection
class LocalUserProfile {
  Id isarId = Isar.autoIncrement;

  /// Supabase UUID — unique index for fast lookups.
  @Index(unique: true, replace: true)
  late String id;

  late String fullName;

  String? phone;

  /// One of: 'admin', 'reception', 'lab', 'donor', 'patient'.
  late String role;

  /// One of: 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'.
  String? bloodGroup;

  /// One of: 'pending', 'active', 'rejected'.
  late String status;

  /// Tracks whether this record needs to be synced to Supabase.
  @enumerated
  SyncStatus syncStatus = SyncStatus.synced;

  /// Creates a [LocalUserProfile] from a Supabase profiles row map.
  static LocalUserProfile fromSupabaseMap(Map<String, dynamic> map) {
    return LocalUserProfile()
      ..id = map['id'] as String
      ..fullName = (map['full_name'] as String?) ?? 'Unknown'
      ..phone = map['phone'] as String?
      ..role = (map['role'] as String?) ?? 'patient'
      ..bloodGroup = map['blood_group'] as String?
      ..status = (map['status'] as String?) ?? 'pending'
      ..syncStatus = SyncStatus.synced;
  }
}
