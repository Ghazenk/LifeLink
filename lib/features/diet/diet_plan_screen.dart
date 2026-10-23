import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/supabase_client.dart';
import '../legal/policy_screen.dart';

const doctorNotice =
    'Please confirm this draft with your doctor or registered dietitian before following it. AI can be wrong. This is general meal inspiration, not a medical diet or treatment plan.';

abstract interface class MealDraftApi {
  Future<Map<String, dynamic>> availability();
  Future<Map<String, dynamic>> generate(Map<String, dynamic> preferences);
}

class SupabaseMealDraftApi implements MealDraftApi {
  const SupabaseMealDraftApi();
  @override
  Future<Map<String, dynamic>> availability() async =>
      Map<String, dynamic>.from(
        (await SupabaseClientManager.client.functions.invoke(
              'meal-plan',
              method: HttpMethod.get,
            )).data
            as Map,
      );
  @override
  Future<Map<String, dynamic>> generate(
    Map<String, dynamic> preferences,
  ) async => Map<String, dynamic>.from(
    (await SupabaseClientManager.client.functions.invoke(
          'meal-plan',
          body: preferences,
        )).data
        as Map,
  );
}

class DietPlanScreen extends StatefulWidget {
  const DietPlanScreen({super.key, this.api = const SupabaseMealDraftApi()});
  final MealDraftApi api;
  @override
  State<DietPlanScreen> createState() => _DietPlanScreenState();
}

class _DietPlanScreenState extends State<DietPlanScreen> {
  String _cuisine = 'Pakistani', _preference = 'No preference', _provider = '';
  bool _consent = false,
      _suitable = false,
      _loading = false,
      _checking = true,
      _configured = false;
  String? _error;
  Map<String, dynamic>? _draft;
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final data = await widget.api.availability();
      if (mounted) {
        setState(() {
          _configured = data['configured'] == true;
          _provider = data['provider'] as String? ?? '';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'AI availability could not be checked. Please reconnect and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _generate() async {
    if (!_consent || !_suitable || !_configured) return;
    setState(() {
      _loading = true;
      _error = null;
      _draft = null;
    });
    try {
      final data = await widget.api.generate({
        'consent': true,
        'adult_and_clinician_confirmed': true,
        'cuisine': _cuisine,
        'preference': _preference,
      });
      if (data['plan'] is! Map) throw const FormatException('Invalid draft');
      if (mounted) {
        setState(() => _draft = Map<String, dynamic>.from(data['plan'] as Map));
      }
    } on FunctionException catch (error) {
      final details = error.details;
      if (mounted) {
        setState(
          () => _error = details is Map && details['error'] is String
              ? details['error'] as String
              : 'The AI service could not produce a draft. Try again later.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not generate a draft. Please try again later.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _consent = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI meal draft')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Meal ideas to review with your doctor.',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(doctorNotice),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This tool does not use your medical record. If you have allergies, are pregnant, are under 18, or need a therapeutic diet, ask your clinician for a tailored plan instead. Do not change medicines, supplements, iron intake, or transfusion schedules based on AI.',
              ),
              const SizedBox(height: 24),
              if (_checking)
                const Center(child: CircularProgressIndicator())
              else if (!_configured) ...[
                const Text(
                  'AI meal drafts are not enabled yet. Your administrator needs to configure a provider and API key on the server.',
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _checking = true);
                    _check();
                  },
                  child: const Text('Check availability'),
                ),
              ] else ...[
                Text(
                  'Provider: $_provider',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _cuisine,
                  decoration: const InputDecoration(labelText: 'Cuisine'),
                  items: ['Pakistani', 'Mediterranean', 'Mixed']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _cuisine = v!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _preference,
                  decoration: const InputDecoration(
                    labelText: 'Food preference',
                  ),
                  items: ['No preference', 'Vegetarian']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _preference = v!),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _suitable,
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _suitable = v ?? false),
                  title: const Text(
                    'I am 18 or older, and my clinician has confirmed that general meal ideas are appropriate for me.',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: _loading
                      ? null
                      : (v) => setState(() => _consent = v ?? false),
                  title: Text(
                    'I agree to send only these two preferences to $_provider for this request. I understand the draft may be wrong and needs doctor review.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loading || !_consent || !_suitable
                      ? null
                      : _generate,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    _loading ? 'Preparing draft…' : 'Generate a draft',
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_draft != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Draft · not yet reviewed by a doctor',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                for (final meal in (_draft!['meals'] as List))
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal['label'] as String,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(meal['idea'] as String),
                          const SizedBox(height: 8),
                          Text((meal['ingredients'] as List).join(', ')),
                        ],
                      ),
                    ),
                  ),
                Text(
                  'Discuss with your clinician',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                for (final question in (_draft!['questions'] as List))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('• $question'),
                  ),
                const SizedBox(height: 16),
                const Text(doctorNotice),
                const CopyrightReportLink(),
              ],
              const SizedBox(height: 24),

            ],
          ),
        ),
      ),
    ),
  );
}

class DietPlanLink extends StatelessWidget {
  const DietPlanLink({super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () =>
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const DietPlanScreen())),
    icon: const Icon(Icons.restaurant_outlined),
    label: const Text('AI meal draft · doctor review required'),
  );
}
