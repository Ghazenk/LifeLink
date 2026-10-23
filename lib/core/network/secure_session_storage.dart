import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// OS-backed session storage. Never write access/refresh tokens to Isar.
class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage([this.namespace]);
  final String? namespace;
  static const _storage = FlutterSecureStorage();
  static const _key = 'lifelink.auth.session.v1';
  String get key => namespace == null ? _key : '$_key.$namespace';
  @override
  Future<void> initialize() async {
    // Retire the old plain-preferences session. A one-time sign-in is required.
    final legacy = SharedPreferencesLocalStorage(
      persistSessionKey: 'sb-osqirvdgczhvnacwxfgg-auth-token',
    );
    await legacy.initialize();
    await legacy.removePersistedSession();
  }

  @override
  Future<bool> hasAccessToken() async => await _storage.containsKey(key: key);
  @override
  Future<String?> accessToken() => _storage.read(key: key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => _storage.delete(key: key);
}
