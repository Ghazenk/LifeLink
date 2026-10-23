import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lifelink/core/network/backend_configuration.dart';
import 'package:lifelink/core/security/password_policy.dart';

abstract class RecoveryApi {
  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<bool> updatePassword(String password);
  Future<void> close();
}

/// A recovery session must never sign the user into the normal patient portal.
/// This client has no persistent storage and is discarded on leaving recovery.
class SupabaseRecoveryApi implements RecoveryApi {
  final SupabaseClient _client = SupabaseClient(
    BackendConfiguration.current.url,
    BackendConfiguration.current.publishableKey,
    authOptions: const AuthClientOptions(
      autoRefreshToken: false,
      authFlowType: AuthFlowType.implicit,
    ),
  );
  String? _verifiedId;

  @override
  Future<void> sendCode(String email) =>
      _client.auth.resetPasswordForEmail(email);

  @override
  Future<void> verifyCode(String email, String code) async {
    _verifiedId = null;
    final result = await _client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.recovery,
    );
    if (result.session == null ||
        result.user == null ||
        result.user!.email?.toLowerCase() != email.toLowerCase()) {
      throw const AuthException('Recovery verification failed');
    }
    _verifiedId = result.user!.id;
  }

  @override
  Future<bool> updatePassword(String password) async {
    if (_verifiedId == null || _client.auth.currentUser?.id != _verifiedId) {
      throw const AuthException('Verify a recovery code first');
    }
    final passwordError = PasswordPolicy.validate(password);
    if (passwordError != null) {
      throw ArgumentError(passwordError);
    }
    await _client.auth.updateUser(UserAttributes(password: password));
    _verifiedId = null;
    try {
      await _client.auth.signOut(scope: SignOutScope.global);
      return true;
    } catch (_) {
      // The password changed, but remote session revocation was not confirmed.
      return false;
    }
  }

  @override
  Future<void> close() async {
    _verifiedId = null;
    try {
      await _client.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Always discard the in-memory client, including after network failures.
    } finally {
      await _client.dispose();
    }
  }
}
