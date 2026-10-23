import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

/// A clinic installation is a separate deployment, never a cloud fallback.
/// The publishable key is public; authorization remains on the server.
class BackendConfiguration {
  BackendConfiguration._(this.url, this.publishableKey, this.clinicMode);

  final String url;
  final String publishableKey;
  final bool clinicMode;

  static const clinicBuild = bool.fromEnvironment('LIFELINK_CLINIC_BUILD');
  static const _storage = FlutterSecureStorage();
  static const _urlKey = 'lifelink.clinic.url.v1';
  static const _publishableKey = 'lifelink.clinic.publishable_key.v1';
  static BackendConfiguration? _current;

  static BackendConfiguration get current => _current ??
      (throw StateError('Backend configuration has not been loaded.'));

  static bool get isClinic => _current?.clinicMode ?? false;
  static String get selectedHost => Uri.parse(_current?.url ?? AppConstants.supabaseUrl).host;

  /// A short, deterministic namespace keeps session keys and Isar databases
  /// apart when an installation moves between clinic servers.
  String get namespace => sha256.convert(utf8.encode(url)).toString().substring(0, 16);

  static Future<BackendConfiguration?> load() async {
    if (!clinicBuild) {
      _current = BackendConfiguration._(
        AppConstants.supabaseUrl,
        AppConstants.supabasePublishableKey,
        false,
      );
      return _current;
    }
    final url = await _storage.read(key: _urlKey);
    final key = await _storage.read(key: _publishableKey);
    if (url == null || key == null) return null;
    _current = parseClinic(url, key);
    return _current;
  }

  static BackendConfiguration parseClinic(String rawUrl, String rawKey) {
    final url = rawUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty ||
        uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.host == 'localhost' || uri.host == '127.0.0.1' ||
        rawKey.trim().isEmpty || rawKey.length > 4096 ||
        rawKey.trim().startsWith('sb_secret_') ||
        rawKey.trim().startsWith('sb_service_role_')) {
      throw const FormatException('Enter a trusted HTTPS clinic server address and its publishable key.');
    }
    return BackendConfiguration._(url, rawKey.trim(), true);
  }

  static Future<void> saveClinic(BackendConfiguration config) async {
    if (!clinicBuild || !config.clinicMode) throw StateError('Clinic build required.');
    await _storage.write(key: _urlKey, value: config.url);
    await _storage.write(key: _publishableKey, value: config.publishableKey);
    _current = config;
  }
}
