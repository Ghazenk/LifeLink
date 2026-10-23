import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client.dart';
import '../network/backend_configuration.dart';

/// Adds an app-side session lifetime on plans where Supabase time-boxed and
/// inactivity session controls are unavailable.
///
/// Supabase still enforces its one-hour access-token lifetime and refresh-token
/// replay detection. This gate additionally revokes the user's server sessions
/// after 12 hours or 30 minutes without local activity.
class SessionSecurityGate extends StatefulWidget {
  const SessionSecurityGate({required this.child, super.key});

  static const maximumLifetime = Duration(hours: 12);
  static const inactivityTimeout = Duration(minutes: 30);

  final Widget child;

  @override
  State<SessionSecurityGate> createState() => _SessionSecurityGateState();
}

class _SessionSecurityGateState extends State<SessionSecurityGate>
    with WidgetsBindingObserver {
  static const _storage = FlutterSecureStorage();
  String get _suffix => BackendConfiguration.isClinic
      ? '.${BackendConfiguration.current.namespace}' : '';
  String get _userKey => 'lifelink.session.user.v1$_suffix';
  String get _startedKey => 'lifelink.session.started.v1$_suffix';
  String get _activityKey => 'lifelink.session.activity.v1$_suffix';

  StreamSubscription<AuthState>? _authSubscription;
  Timer? _expiryTimer;
  String? _userId;
  DateTime? _startedAt;
  DateTime? _lastActivity;
  DateTime? _lastPersistedActivity;
  bool _expiring = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = SupabaseClientManager.client.auth;
    _authSubscription = auth.onAuthStateChange.listen((state) {
      if (state.session == null) {
        unawaited(_clearSessionMetadata());
      } else {
        unawaited(_activate(state.session!));
      }
    });
    final current = auth.currentSession;
    if (current != null) unawaited(_activate(current));
  }

  DateTime? _parse(String? value) =>
      value == null ? null : DateTime.tryParse(value)?.toUtc();

  Future<void> _activate(Session session) async {
    final now = DateTime.now().toUtc();
    final storedUser = await _storage.read(key: _userKey);
    final sameUser = storedUser == session.user.id;
    final storedStarted = sameUser
        ? _parse(await _storage.read(key: _startedKey))
        : null;
    final storedActivity = sameUser
        ? _parse(await _storage.read(key: _activityKey))
        : null;
    final serverSignIn = _parse(session.user.lastSignInAt);

    _userId = session.user.id;
    _startedAt = storedStarted ?? serverSignIn ?? now;
    _lastActivity = storedActivity ?? now;
    _lastPersistedActivity = _lastActivity;
    await _storage.write(key: _userKey, value: _userId);
    await _storage.write(
      key: _startedKey,
      value: _startedAt!.toIso8601String(),
    );
    await _storage.write(
      key: _activityKey,
      value: _lastActivity!.toIso8601String(),
    );
    await _checkExpiry();
  }

  void _recordActivity() {
    if (_userId == null || _expiring) return;
    final now = DateTime.now().toUtc();
    _lastActivity = now;
    if (_lastPersistedActivity == null ||
        now.difference(_lastPersistedActivity!) >= const Duration(minutes: 1)) {
      _lastPersistedActivity = now;
      unawaited(
        _storage.write(key: _activityKey, value: now.toIso8601String()),
      );
    }
    _scheduleExpiry();
  }

  Future<void> _checkExpiry() async {
    if (_userId == null || _startedAt == null || _lastActivity == null) return;
    final now = DateTime.now().toUtc();
    final absoluteExpired =
        now.difference(_startedAt!) >= SessionSecurityGate.maximumLifetime;
    final idleExpired =
        now.difference(_lastActivity!) >= SessionSecurityGate.inactivityTimeout;
    if (absoluteExpired || idleExpired) {
      await _expireSession();
    } else {
      _scheduleExpiry();
    }
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    if (_startedAt == null || _lastActivity == null) return;
    final absoluteAt = _startedAt!.add(SessionSecurityGate.maximumLifetime);
    final idleAt = _lastActivity!.add(SessionSecurityGate.inactivityTimeout);
    final expiryAt = absoluteAt.isBefore(idleAt) ? absoluteAt : idleAt;
    final delay = expiryAt.difference(DateTime.now().toUtc());
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      unawaited(_checkExpiry());
    });
  }

  Future<void> _expireSession() async {
    if (_expiring) return;
    _expiring = true;
    _expiryTimer?.cancel();
    final auth = SupabaseClientManager.client.auth;
    try {
      await auth
          .signOut(scope: SignOutScope.global)
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      try {
        await auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // Secure storage is cleared below even if the network is unavailable.
      }
    } finally {
      await _clearSessionMetadata();
      _expiring = false;
    }
  }

  Future<void> _clearSessionMetadata() async {
    _expiryTimer?.cancel();
    _userId = null;
    _startedAt = null;
    _lastActivity = null;
    _lastPersistedActivity = null;
    await Future.wait([
      _storage.delete(key: _userKey),
      _storage.delete(key: _startedKey),
      _storage.delete(key: _activityKey),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkExpiry());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordActivity(),
      child: Focus(
        onKeyEvent: (_, event) {
          _recordActivity();
          return KeyEventResult.ignored;
        },
        child: widget.child,
      ),
    );
  }
}
