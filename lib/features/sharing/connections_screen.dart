import 'checkin_screen.dart';

import 'package:go_router/go_router.dart';

import '../../core/network/sync_manager.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/supabase_client.dart';
import '../../core/theme/portal_shell.dart';
import '../auth/data/auth_repository.dart';
import '../auth/auth_screen.dart';
import '../auth/session_actions.dart';
import '../donor/data/donor_repository.dart';
import 'sharing_repository.dart';
import 'qr_scan_screen.dart';

class CaregiverScreen extends StatefulWidget {
  const CaregiverScreen({super.key});
  @override
  State<CaregiverScreen> createState() => _CaregiverScreenState();
}

class _CaregiverScreenState extends State<CaregiverScreen> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) => PortalShell(
      title: 'Caregiver portal',
      subtitle: 'Support the people you care for.',
      selectedIndex: _index,
      onSelected: (i) => setState(() => _index = i),
      onSignOut: () => signOutWithFeedback(context, ref),
      destinations: const [
        PortalDestination(
          'Connections',
          Icons.family_restroom_outlined,
          Icons.family_restroom,
        ),
        PortalDestination('About access', Icons.info_outline, Icons.info),
      ],
      child: _index == 0
          ? const CareConnections()
          : const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Ask a patient to generate a connection code. Only the patient or an administrator can approve access. A connection lets you view shared visits and laboratory records; it does not make you a donor, a clinician or a legally appointed guardian. The patient can revoke access at any time.',
              ),
            ),
    ),
  );
}

class CareConnections extends ConsumerStatefulWidget {
  const CareConnections({super.key, this.initialCode});
  final String? initialCode;
  @override
  ConsumerState<CareConnections> createState() => _CareConnectionsState();
}

class _CareConnectionsState extends ConsumerState<CareConnections> {
  late final TextEditingController _code = TextEditingController(
    text: widget.initialCode,
  );
  bool _busy = false;
  String? _message;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(sharingApiProvider)
          .redeem(_code.text, 'guardian');
      if (mounted) {
        setState(
          () => _message = result['status'] == 'approved'
              ? 'You are already connected.'
              : 'Request sent. The patient must approve access.',
        );
        _code.clear();
        ref.invalidate(linkedPatientsProvider);
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } on StateError catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not send the request. Check your connection and active account.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final value = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const QrScanScreen(purpose: 'guardian'),
      ),
    );
    if (value != null && mounted) setState(() => _code.text = value);
  }

  @override
  Widget build(BuildContext context) {
    final linked = ref.watch(linkedPatientsProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SectionHeading(
          'Connect with a patient',
          'Ask the patient for a new connection code from their Guardians screen.',
        ),
        TextField(
          controller: _code,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Patient connection code',
            hintText: 'LL-G-ABCD-1234-EF56',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _busy ? null : _scan,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan patient QR'),
        ),
        FilledButton(
          onPressed: _busy ? null : _request,
          child: Text(_busy ? 'Sending…' : 'Request connection'),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_message!),
          ),
        const SizedBox(height: 24),
        Text(
          'Approved connections',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        linked.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(linkedPatientsProvider),
            child: const Text('Could not load connections. Retry'),
          ),
          data: (rows) => Column(
            children: [
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No approved connections yet.'),
                ),
              for (final row in rows)
                if (row['patient'] is Map)
                  Card(
                    child: ListTile(
                      title: Text(
                        row['patient']['full_name'] as String? ?? 'Patient',
                      ),
                      subtitle: const Text('View shared care records'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LinkedRecordsScreen(
                            patientId: row['patient_id'] as String,
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

final linkedRecordsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, id) async {
      ref.watch(
        authStateProvider.select((s) => s.valueOrNull?.session?.user.id),
      );
      ref.watch(syncRevisionProvider);
      final client = SupabaseClientManager.client;
      // Verify approval afresh; never render another account's cached record list.
      final link = await client
          .from('guardianships')
          .select('id')
          .eq('donor_id', client.auth.currentUser?.id ?? '')
          .eq('patient_id', id)
          .eq('status', 'approved')
          .maybeSingle();
      if (link == null) throw StateError('Connection no longer approved.');
      return List<Map<String, dynamic>>.from(
        await client
            .from('visits')
            .select(
              'type,status,created_at,lab_results(hemoglobin,wbc,platelets,prescribed_volume_ml)',
            )
            .eq('user_id', id)
            .order('created_at', ascending: false)
            .limit(100),
      );
    });

class LinkedRecordsScreen extends ConsumerWidget {
  const LinkedRecordsScreen({super.key, required this.patientId});
  final String patientId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Shared care records'),
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(linkedRecordsProvider(patientId)),
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh access',
        ),
      ],
    ),
    body: ref
        .watch(linkedRecordsProvider(patientId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(
            child: Text(
              'Records unavailable. Check your connection and ask the patient to confirm access.',
            ),
          ),
          data: (rows) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Most recent 100 visits. For reference only; discuss results with the care team.',
              ),
              if (rows.isEmpty) const Text('No shared visits yet.'),
              for (final row in rows)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${row['type']} · ${row['status']}'),
                        Text('${row['created_at']}'),
                        for (final lab
                            in (row['lab_results'] is Map
                                ? [row['lab_results']]
                                : row['lab_results'] as List? ?? []))
                          Text(
                            'Hemoglobin: ${lab['hemoglobin']} g/dL\nWBC: ${lab['wbc']}\nPlatelets: ${lab['platelets']}\nRecorded volume: ${lab['prescribed_volume_ml']} mL',
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
  );
}

/// Mobile deep link: do not redeem automatically or expose data before login.
class ConnectionLanding extends ConsumerWidget {
  const ConnectionLanding({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const AuthScreen(),
      data: (p) {
        if (p == null) return const AuthScreen();
        if (p.status == 'active' && ['admin', 'reception'].contains(p.role)) {
          return CheckInScreen(initialCode: code, issueVisit: true);
        }
        if (p.status != 'active' || !['donor', 'caregiver'].contains(p.role)) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('LifeLink code'),
              leading: IconButton(
                icon: const Icon(Icons.home_outlined),
                onPressed: () => context.go('/'),
              ),
            ),
            body: const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Use an active donor or caregiver account to request a patient connection. Reception uses clinic check-in codes from its Donation or Transfusion screen.',
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Patient connection'),
            leading: IconButton(
              icon: const Icon(Icons.home_outlined),
              onPressed: () => context.go('/'),
            ),
          ),
          body: CareConnections(initialCode: code),
        );
      },
    );
  }
}
