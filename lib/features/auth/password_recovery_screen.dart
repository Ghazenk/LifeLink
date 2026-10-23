import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/recovery_repository.dart';

import 'package:lifelink/core/security/password_policy.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, this.initialEmail = '', this.api});
  final String initialEmail;
  final RecoveryApi? api;
  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  late final RecoveryApi _api = widget.api ?? SupabaseRecoveryApi();
  late final _email = TextEditingController(text: widget.initialEmail);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _form = GlobalKey<FormState>();
  int _step = 0;
  int _cooldown = 0;
  bool _busy = false;
  bool _hidden = true;
  bool _revoked = true;
  String? _message;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    unawaited(_api.close());
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String error) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _message = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_cooldown > 0 || _busy) return;
    await _run(() async {
      await _api.sendCode(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _step = 1;
        _cooldown = 60;
        _message = 'If an account exists, a recovery email has been requested. Check your inbox and spam folder.';
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || _cooldown <= 1) timer.cancel();
        if (mounted) setState(() => _cooldown = (_cooldown - 1).clamp(0, 60));
      });
    }, 'Could not request a code. Check your connection and try again later.');
  }

  Future<void> _next() async {
    if (!_form.currentState!.validate()) return;
    if (_step == 0) {
      await _send();
      return;
    }
    if (_step == 1) {
      await _run(
        () async {
          await _api.verifyCode(_email.text.trim(), _code.text.trim());
          if (mounted) {
            setState(() {
              _code.clear();
              _step = 2;
            });
          }
        },
        'That code could not be verified. Check the email and code, or request a new code if it expired.',
      );
    } else {
      await _run(
        () async {
          final revoked = await _api.updatePassword(_password.text);
          if (mounted) {
            setState(() {
              _revoked = revoked;
              _password.clear();
              _confirm.clear();
              _code.clear();
              _email.clear();
              _step = 3;
            });
          }
        },
        'Password update failed. Use a different strong password, check your connection, or restart recovery if the session expired.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reset password')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _step == 3 ? Icons.check_circle_outline : Icons.lock_reset,
                    size: 48,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _step == 3
                        ? 'Password changed'
                        : 'Recover your LifeLink account',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (_step < 2) ...[
                    const Text(
                      'Enter the recovery code from your email here. You do not need to open a browser link.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _email,
                      enabled: !_busy && _step == 0,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Enter a valid email address',
                    ),
                  ],
                  if (_step == 1) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      autofillHints: const [AutofillHints.oneTimeCode],
                      decoration: const InputDecoration(
                        labelText: 'Recovery code',
                      ),
                      validator: (v) => RegExp(r'^\d{8}$').hasMatch(v ?? '')
                          ? null
                          : 'Enter the eight-digit code from your email',
                    ),
                    TextButton(
                      onPressed: _busy || _cooldown > 0
                          ? null
                          : () async {
                              // Resending does not require the previous code to be valid.
                              setState(() => _step = 0);
                              await _send();
                            },
                      child: Text(
                        _cooldown > 0
                            ? 'Resend in ${_cooldown}s'
                            : 'Resend code',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _step = 0;
                              _code.clear();
                              _message = null;
                            }),
                      child: const Text('Use another email'),
                    ),
                  ],
                  if (_step == 2) ...[
                    const Text(
                      'Use 12 to 128 characters with uppercase, lowercase, a number, and a symbol.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _hidden,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        suffixIcon: IconButton(
                          tooltip: _hidden ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _hidden = !_hidden),
                          icon: Icon(
                            _hidden ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: PasswordPolicy.validate,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      enabled: !_busy,
                      obscureText: _hidden,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                      ),
                      validator: (v) =>
                          v != _password.text ? 'Passwords must match' : null,
                    ),
                  ],
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(_message!, semanticsLabel: _message),
                    ),
                  const SizedBox(height: 20),
                  if (_step < 3)
                    FilledButton(
                      onPressed: _busy ? null : _next,
                      child: Text(
                        _busy
                            ? 'Please wait...'
                            : [
                                'Send recovery code',
                                'Verify code',
                                'Save new password',
                              ][_step],
                      ),
                    ),
                  if (_step == 0)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              if (_form.currentState!.validate()) {
                                setState(() {
                                  _step = 1;
                                  _message = null;
                                });
                              }
                            },
                      child: const Text('I already have a code'),
                    ),
                  if (_step == 3) ...[
                    Text(
                      _revoked ? 'Sign in with your new password.' : 'Your password changed, but signing out other sessions could not be confirmed. Sign in and contact the operator if you suspect account access.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
