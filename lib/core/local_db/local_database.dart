import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

/// Isar local database initialization and accessor.
class LocalDatabase {
  LocalDatabase._();

  static Isar? _instance;

  /// Initialize Isar. Call once in main() before runApp().
  ///
  /// Pass all Isar collection schemas here when they are defined.
  static Future<Isar> initialize({
    List<CollectionSchema<dynamic>> schemas = const [],
  }) async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      schemas,
      directory: dir.path,
      name: 'lifelink_db',
    );
    return _instance!;
  }

  /// Accessor for the Isar database instance.
  static Isar get instance {
    assert(_instance != null, 'LocalDatabase.initialize() must be called first');
    return _instance!;
  }
}
