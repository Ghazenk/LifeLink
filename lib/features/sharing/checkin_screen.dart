import '../reception/data/reception_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sharing_repository.dart';
import 'qr_scan_screen.dart';

import 'package:go_router/go_router.dart';

/// Lookup only. Reception still confirms identity and issues the visit separately.
class CheckInScreen extends ConsumerStatefulWidget {
  const CheckInScreen({super.key, this.initialCode, this.issueVisit = false});
  final String? initialCode;
  final bool issueVisit;
  @override
  ConsumerState<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<CheckInScreen> {
  late final _code = TextEditingController(text: widget.initialCode);
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _person;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() {
      _busy = true;
      _error = null;
      _person = null;
    });
    try {
      final result = await ref
          .read(sharingApiProvider)
          .redeem(_code.text, 'checkin');
      if (mounted) {
        setState(() => _person = Map<String, dynamic>.from(result['profile']));
      }
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not look up this code. Check your connection and staff account.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Clinic check-in'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/');
          }
        },
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Ask the patient or donor for a fresh check-in code. Verify their identity before issuing a visit.',
        ),
        TextField(
          controller: _code,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Check-in code',
            hintText: 'LL-C-ABCD-1234-EF56',
          ),
        ),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  final value = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => const QrScanScreen(purpose: 'checkin'),
                    ),
                  );
                  if (value != null && mounted) {
                    setState(() => _code.text = value);
                  }
                },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan check-in QR'),
        ),
        FilledButton(
          onPressed: _busy ? null : _lookup,
          child: Text(_busy ? 'Looking up…' : 'Look up code'),
        ),
        if (_error != null) Text(_error!),
        if (_person != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(_person!['full_name'] as String? ?? 'Clinic visitor'),
                  Text(
                    '${_person!['role']} · ${_person!['blood_group'] ?? 'Blood group unverified'}',
                  ),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!widget.issueVisit) {
                              Navigator.of(context).pop(_person);
                              return;
                            }
                            setState(() => _busy = true);
                            try {
                              final visit = await ref
                                  .read(receptionRepositoryProvider)
                                  .issueToken(
                                    userId: _person!['id'],
                                    type: _person!['role'] == 'donor'
                                        ? 'donation'
                                        : 'transfusion',
                                  );
                              if (mounted) {
                                setState(() {
                                  _error =
                                      'Visit ${visit.tokenNumber} queued. Check sync status for server confirmation.';
                                  _person = null;
                                  _code.clear();
                                });
                              }
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => _error = 'Could not issue a visit. Retry from Reception.',
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: Text(
                      widget.issueVisit
                          ? 'Confirm identity and issue visit'
                          : 'Use this person',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
