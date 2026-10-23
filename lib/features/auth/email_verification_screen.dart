import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/auth_repository.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  Timer? _timer;
  int _cooldown = 60;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    _cooldown = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .verifySignupCode(email: widget.email, code: _code.text);
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException {
      if (mounted) {
        setState(() => _message = 'That code is invalid or expired.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Verification is unavailable. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).resendSignupCode(widget.email);
      _startCooldown();
      if (mounted) setState(() => _message = 'A new code was sent.');
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'A new code could not be sent yet.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      'Enter the eight-digit code sent to ${widget.email}. It expires after 15 minutes.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Verification code',
                      ),
                      validator: (value) =>
                          value == null || !RegExp(r'^\d{8}$').hasMatch(value)
                          ? 'Enter the eight-digit code'
                          : null,
                      onFieldSubmitted: (_) => _busy ? null : _verify(),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(_message!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _verify,
                      child: Text(_busy ? 'Verifying...' : 'Verify email'),
                    ),
                    TextButton(
                      onPressed: _busy || _cooldown > 0 ? null : _resend,
                      child: Text(
                        _cooldown > 0
                            ? 'Resend in ${_cooldown}s'
                            : 'Resend code',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
