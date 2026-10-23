import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_client.dart';
import '../../core/network/sync_manager.dart';

String normalizeLifeLinkCode(String input, String purpose) {
  var value = input.trim();
  if (value.length > 200) throw const FormatException('Enter a LifeLink code.');
  if (value.toLowerCase().startsWith('lifelink:')) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'lifelink' ||
        uri.host != 'connect' ||
        uri.path.isNotEmpty ||
        uri.queryParametersAll['code']?.length != 1) {
      throw const FormatException('This is not a LifeLink sharing link.');
    }
    value = uri.queryParameters['code'] ?? '';
  }
  final clean = value.toUpperCase().replaceAll(RegExp(r'[-\s]'), '');
  final prefix = purpose == 'guardian' ? 'LLG' : 'LLC';
  if (!RegExp('^$prefix[0-9A-F]{12}\$').hasMatch(clean)) {
    throw FormatException(
      purpose == 'guardian'
          ? 'Use a patient connection code beginning LL-G.'
          : 'Use a check-in code beginning LL-C.',
    );
  }
  return 'LL-${prefix[2]}-${clean.substring(3, 7)}-${clean.substring(7, 11)}-${clean.substring(11)}';
}

abstract class SharingApi {
  Future<Map<String, dynamic>> createCode(String purpose);
  Future<Map<String, dynamic>> redeem(String code, String purpose);
  Future<void> revoke(String purpose);
}

class SupabaseSharingApi implements SharingApi {
  @override
  Future<Map<String, dynamic>> createCode(String purpose) async =>
      Map<String, dynamic>.from(
        await SupabaseClientManager.client
            .rpc('create_share_code', params: {'purpose': purpose})
            .timeout(const Duration(seconds: 20)),
      );
  @override
  Future<void> revoke(String purpose) async {
    await SupabaseClientManager.client
        .rpc('revoke_share_code', params: {'purpose': purpose})
        .timeout(const Duration(seconds: 20));
  }

  @override
  Future<Map<String, dynamic>> redeem(String code, String purpose) async {
    final result = Map<String, dynamic>.from(
      await SupabaseClientManager.client
          .rpc(
            'redeem_share_code',
            params: {
              'code': normalizeLifeLinkCode(code, purpose),
              'purpose': purpose,
            },
          )
          .timeout(const Duration(seconds: 20)),
    );
    if (result['ok'] != true) {
      throw StateError(
        result['message'] as String? ?? 'Code unavailable. Ask for a new code.',
      );
    }
    SyncManager().syncNow();
    return result;
  }
}

final sharingApiProvider = Provider<SharingApi>((_) => SupabaseSharingApi());
