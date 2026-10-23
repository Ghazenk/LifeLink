import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'sharing_repository.dart';

class ShareCodeCard extends ConsumerStatefulWidget {
  const ShareCodeCard({super.key, required this.purpose});
  final String purpose;
  @override
  ConsumerState<ShareCodeCard> createState() => _ShareCodeCardState();
}

class _ShareCodeCardState extends ConsumerState<ShareCodeCard> {
  Map<String, dynamic>? _code;
  bool _busy = false;
  String? _error;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _expired =>
      _code != null &&
      !DateTime.parse(_code!['expires_at'] as String).isAfter(DateTime.now());
  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await ref
          .read(sharingApiProvider)
          .createCode(widget.purpose);
      if (mounted) {
        setState(() => _code = value);
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not create a code. Check your connection and active account, then retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    setState(() => _busy = true);
    try {
      await ref.read(sharingApiProvider).revoke(widget.purpose);
      if (mounted) setState(() => _code = null);
      _timer?.cancel();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not revoke. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardian = widget.purpose == 'guardian';
    final seconds = _code == null
        ? 0
        : DateTime.parse(_code!['expires_at'] as String)
              .difference(DateTime.now())
              .inSeconds
              .clamp(0, 900);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              guardian ? 'Invite a caregiver or donor' : 'Your clinic check-in',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              guardian
                  ? 'Share a one-use code with someone you trust. They request access; you approve before they can view your visits and lab records. This is record-sharing permission, not legal guardianship.'
                  : 'Generate a code when you reach reception. Staff scan it in LifeLink to find your account, then confirm the visit with you.',
            ),
            if (_code != null && !_expired) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: 'lifelink://connect?code=${_code!['code']}',
                    size: 190,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              SelectableText(
                _code!['code'] as String,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Expires in ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} · one recipient',
                textAlign: TextAlign.center,
              ),
              TextButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(text: _code!['code'] as String),
                ),
                icon: const Icon(Icons.copy),
                label: const Text('Copy code'),
              ),
              TextButton(
                onPressed: _busy ? null : _revoke,
                child: const Text('Revoke this code'),
              ),
            ],
            if (_expired) const Text('This code expired. Generate a new one.'),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.qr_code),
              label: Text(
                _busy
                    ? 'Please wait…'
                    : _code == null
                    ? 'Generate code'
                    : 'Generate replacement code',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use LifeLink’s scanner or enter the short code. Internet access is required. A replacement invalidates the previous code.',
            ),
          ],
        ),
      ),
    );
  }
}
