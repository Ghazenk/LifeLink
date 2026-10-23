import 'dart:io';

import 'package:flutter/material.dart';

import 'backend_configuration.dart';

/// Shown only in a clinic staff build before any account or clinical data is read.
class ClinicSetupScreen extends StatefulWidget {
  const ClinicSetupScreen({required this.onConfigured, super.key});
  final Future<void> Function() onConfigured;

  @override
  State<ClinicSetupScreen> createState() => _ClinicSetupScreenState();
}

class _ClinicSetupScreenState extends State<ClinicSetupScreen> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() { _busy = true; _error = null; });
    try {
      final config = BackendConfiguration.parseClinic(_url.text, _key.text);
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      try {
        final request = await client.getUrl(Uri.parse('${config.url}/auth/v1/health'))
            .timeout(const Duration(seconds: 10));
        request.headers.set('apikey', config.publishableKey);
        final response = await request.close().timeout(const Duration(seconds: 10));
        await response.drain<void>();
        if (response.statusCode != 200) throw StateError('Clinic authentication service returned ${response.statusCode}.');
      } finally {
        client.close(force: true);
      }
      await BackendConfiguration.saveClinic(config);
      await widget.onConfigured();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is HandshakeException
            ? 'The clinic server certificate is not trusted. Ask the clinic administrator to install a valid certificate.'
            : 'Could not connect securely: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'LifeLink clinic setup',
    home: Scaffold(
      appBar: AppBar(title: const Text('Connect to clinic server')),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
          const Text('Enter the HTTPS address and publishable key supplied by your clinic administrator. All staff computers must use the same clinic server. The server must remain powered on.'),
          const SizedBox(height: 24),
          TextField(controller: _url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Clinic server URL', hintText: 'https://clinic.example.pk')),
          const SizedBox(height: 16),
          TextField(controller: _key, decoration: const InputDecoration(labelText: 'Publishable key')),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _connect, child: Text(_busy ? 'Checking server…' : 'Connect securely')),
        ]),
      )),
    ),
  );
}
