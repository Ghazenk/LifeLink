import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import '../local_db/local_database.dart';
import 'supabase_client.dart';
import 'backend_configuration.dart';
import 'sync_engine.dart';

class SyncManager with WidgetsBindingObserver {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();
  StreamSubscription? _connectivity;
  StreamSubscription? _auth;
  Timer? _timer;
  SyncEngine? _engine;
  Future<void>? _cloudSyncTask;
  bool _cloudSyncAgain = false;
  bool _initialized = false;
  final _changes = StreamController<int>.broadcast();
  int _revision = 0;
  bool _foreground = true;
  Stream<int> get changes => _changes.stream;
  final status = ValueNotifier<String>('Not connected');
  bool get initialized => _initialized;

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    if (BackendConfiguration.isClinic) {
      _connectivity = Connectivity().onConnectivityChanged.listen((_) => unawaited(syncNow()));
      _auth = SupabaseClientManager.client.auth.onAuthStateChange.listen((_) => unawaited(syncNow()));
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_foreground) unawaited(syncNow());
      });
      unawaited(syncNow());
      return;
    }
    _engine = SyncEngine(
      LocalDatabase.instance,
      SupabaseSyncTransport(SupabaseClientManager.client),
    );
    _connectivity = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) unawaited(syncNow());
    });
    _auth = SupabaseClientManager.client.auth.onAuthStateChange.listen(
      (_) => unawaited(syncNow()),
      onError: (_) => status.value = 'Sign in again to sync',
    );
    // The local Isar snapshot supplies immediate reads. Cloud revalidation is
    // event-driven plus a modest periodic refresh. The lab screen requests
    // more frequent pulls while visible so new reception tokens appear.
    _timer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_foreground) unawaited(syncNow());
    });
    unawaited(syncNow());
  }

  Future<void> syncNow() async {
    if (BackendConfiguration.isClinic) {
      try {
        if (SupabaseClientManager.client.auth.currentUser == null) {
          status.value = 'Sign in to clinic server';
          return;
        }
        await SupabaseClientManager.client.from('profiles').select('id')
            .eq('id', SupabaseClientManager.client.auth.currentUser!.id)
            .single().timeout(const Duration(seconds: 10));
        status.value = 'Clinic server connected';
        _changes.add(++_revision);
      } catch (_) {
        status.value = 'Clinic server unavailable · no changes saved';
      }
      return;
    }
    if (_engine == null) return;
    if (_cloudSyncTask != null) {
      // A write may have arrived after the current pass collected its outbox.
      // Complete that pass, then immediately run another one.
      _cloudSyncAgain = true;
      return _cloudSyncTask;
    }
    final task = _runCloudSyncLoop();
    _cloudSyncTask = task;
    try {
      await task;
    } finally {
      _cloudSyncTask = null;
    }
  }

  Future<void> _runCloudSyncLoop() async {
    do {
      _cloudSyncAgain = false;
      await _syncCloudOnce();
    } while (_cloudSyncAgain);
  }

  Future<void> _syncCloudOnce() async {
    status.value = 'Syncing…';
    try {
      final result = await _engine!.sync();
      _changes.add(++_revision);
      status.value = !result.authenticated
          ? 'Sign in with an active account to sync'
          : result.failed > 0
          ? '${result.pending} pending · sync needs attention'
          : result.pending > 0
          ? '${result.pending} changes pending'
          : 'Up to date';
    } catch (_) {
      status.value = 'Sync unavailable · changes remain on this device';
    }
  }

  Future<int> pendingCount(String owner) async =>
      _engine == null ? 0 : _engine!.pendingCount(owner);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(syncNow());
  }

  Future<void> dispose() async {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _connectivity?.cancel();
    await _auth?.cancel();
    _engine = null;
    _initialized = false;
  }
}

final syncRevisionProvider = StreamProvider<int>((ref) async* {
  yield 0;
  yield* SyncManager().changes;
});
