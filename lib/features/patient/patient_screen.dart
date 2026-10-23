import 'package:lifelink/features/diet/diet_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:lifelink/features/auth/session_actions.dart';
import 'package:lifelink/core/theme/portal_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../sharing/share_code_card.dart';

import 'package:lifelink/features/patient/data/patient_repository.dart';

class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) => PortalShell(
      title: 'Patient portal',
      subtitle: 'Your care, in one place.',
      selectedIndex: _selectedIndex,
      onSelected: (index) => setState(() => _selectedIndex = index),
      onSignOut: () => signOutWithFeedback(context, ref),
      destinations: const [
        PortalDestination('Home', Icons.home_outlined, Icons.home),
        PortalDestination(
          'Records',
          Icons.medical_information_outlined,
          Icons.medical_information,
        ),
        PortalDestination(
          'Guardians',
          Icons.family_restroom_outlined,
          Icons.family_restroom,
        ),
      ],
      child: IndexedStack(
        index: _selectedIndex,
        children: const [
          _DashboardTab(),
          _MedicalRecordsTab(),
          _GuardianshipApprovalsTab(),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tab 1: Dashboard (Digital ID & Next Appointment)
// ---------------------------------------------------------------------------
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            'Your care overview',
            'Your records and digital check-in, together.',
          ),
          const DietPlanLink(),
          const SizedBox(height: 16),
          // A fixed interval cannot determine a person's transfusion schedule.
          Card(
            color: theme.colorScheme.primaryContainer,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Next transfusion',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confirm the date with your care team.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'LifeLink does not schedule or prescribe transfusions.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const ShareCodeCard(purpose: 'checkin'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Medical Records
// ---------------------------------------------------------------------------
class _MedicalRecordsTab extends ConsumerWidget {
  const _MedicalRecordsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(medicalHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (records) {
        if (records.isEmpty) {
          return const PortalEmptyState(
            icon: Icons.medical_information_outlined,
            title: 'Your records, together',
            message: 'Transfusion history and lab results will appear after your first recorded visit.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            final visit = record.visit;
            final lab = record.labResult;
            final isCompleted = visit.status == 'completed';

            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          DateFormat.yMMMd().add_jm().format(visit.createdAt),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Chip(
                          label: Text(visit.status.toUpperCase()),
                          backgroundColor: isCompleted
                              ? Colors.green.shade50
                              : Colors.orange.shade50,
                          labelStyle: TextStyle(
                            color: isCompleted
                                ? Colors.green.shade900
                                : Colors.orange.shade900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Token: ${visit.tokenNumber}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),

                    if (lab != null) ...[
                      const Divider(height: 24),
                      Text(
                        'Lab Results & Procedure',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        children: [
                          _StatDisplay('HGB', '${lab.hemoglobin} g/dL'),
                          _StatDisplay('WBC', '${lab.wbc}'),
                          _StatDisplay(
                            'Ferritin',
                            '${lab.ferritin ?? '-'} ng/mL',
                            highlight: true,
                          ),
                          _StatDisplay(
                            'Vol',
                            '${lab.prescribedVolumeMl ?? 0} ml',
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatDisplay extends StatelessWidget {
  const _StatDisplay(this.label, this.value, {this.highlight = false});
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: highlight ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Guardianship Approvals
// ---------------------------------------------------------------------------
class _GuardianshipApprovalsTab extends ConsumerWidget {
  const _GuardianshipApprovalsTab();

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    String id,
    String status,
  ) async {
    try {
      await ref
          .read(patientRepositoryProvider)
          .respondToGuardianship(id, status);
      ref.invalidate(pendingGuardianshipsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingGuardianshipsProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const ShareCodeCard(purpose: 'guardian'),
        const SizedBox(height: 24),
        const Text(
          'Approve only people you trust. Approval shares your visits and laboratory records. You can revoke access here.',
        ),
        pendingAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(pendingGuardianshipsProvider),
            child: const Text('Could not load connections. Retry'),
          ),
          data: (requests) => Column(
            children: [
              if (requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No connection requests yet.'),
                ),
              for (final req in requests)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(req['donor_name'] as String? ?? 'Care partner'),
                        Text(
                          req['status'] == 'approved'
                              ? 'Can view your care records'
                              : 'Requests access to your care records',
                        ),
                        Wrap(
                          spacing: 12,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _respond(context, ref, req['id'], 'rejected'),
                              child: Text(
                                req['status'] == 'approved'
                                    ? 'Revoke access'
                                    : 'Reject',
                              ),
                            ),
                            if (req['status'] != 'approved')
                              FilledButton(
                                onPressed: () => _respond(
                                  context,
                                  ref,
                                  req['id'],
                                  'approved',
                                ),
                                child: const Text('Approve access'),
                              ),
                          ],
                        ),
                      ],
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
