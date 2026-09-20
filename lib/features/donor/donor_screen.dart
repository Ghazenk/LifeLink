import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lifelink/features/auth/data/auth_repository.dart';
import 'package:lifelink/features/donor/data/donor_repository.dart';

class DonorScreen extends StatefulWidget {
  const DonorScreen({super.key});

  @override
  State<DonorScreen> createState() => _DonorScreenState();
}

class _DonorScreenState extends State<DonorScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check screen width for responsive layout
    final isWideScreen = MediaQuery.of(context).size.width >= 600;

    final destinations = <_Destination>[
      _Destination('Tracker', Icons.data_usage_outlined, Icons.data_usage),
      _Destination('History', Icons.history_outlined, Icons.history),
      _Destination('Patients', Icons.family_restroom_outlined, Icons.family_restroom),
    ];

    final bodyContent = IndexedStack(
      index: _selectedIndex,
      children: const [
        _CycleTrackerTab(),
        _DonationHistoryTab(),
        _PatientGuardianshipTab(),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Donor Portal'),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              return IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign Out',
                onPressed: () {
                  ref.read(authRepositoryProvider).signOut();
                },
              );
            },
          ),
        ],
      ),
      body: isWideScreen
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  destinations: destinations.map((d) {
                    return NavigationRailDestination(
                      icon: Icon(d.outlinedIcon),
                      selectedIcon: Icon(d.solidIcon),
                      label: Text(d.label),
                    );
                  }).toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: bodyContent),
              ],
            )
          : bodyContent,
      bottomNavigationBar: isWideScreen
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              items: destinations.map((d) {
                return BottomNavigationBarItem(
                  icon: Icon(d.outlinedIcon),
                  activeIcon: Icon(d.solidIcon),
                  label: d.label,
                );
              }).toList(),
            ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.outlinedIcon, this.solidIcon);
  final String label;
  final IconData outlinedIcon;
  final IconData solidIcon;
}

// ---------------------------------------------------------------------------
// Tab 1: Home / Cycle Tracker
// ---------------------------------------------------------------------------
class _CycleTrackerTab extends ConsumerWidget {
  const _CycleTrackerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibilityAsync = ref.watch(eligibilityStatusProvider);

    return Center(
      child: eligibilityAsync.when(
        loading: () => const CircularProgressIndicator(),
        error: (err, stack) => Text('Error: $err'),
        data: (status) {
          final theme = Theme.of(context);
          
          if (status.isEligible) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 16,
                        color: Colors.green,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    const Icon(Icons.check_circle, size: 80, color: Colors.green),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Eligible to Donate',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Thank you for saving lives! Visit the clinic to donate.'),
              ],
            );
          } else {
            // Not eligible
            final double progress = (90 - status.daysRemaining) / 90.0;
            
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 16,
                        color: Colors.orange,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${status.daysRemaining}',
                          style: theme.textTheme.displayLarge?.copyWith(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Days Left',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Recovery Cycle Active',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Next eligible date: ${DateFormat.yMMMd().format(status.nextEligibleDate)}',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            );
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Donation History
// ---------------------------------------------------------------------------
class _DonationHistoryTab extends ConsumerWidget {
  const _DonationHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(donationHistoryProvider);

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (visits) {
        if (visits.isEmpty) {
          return const Center(child: Text('No donation history found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index];
            final dateStr = DateFormat.yMMMd().add_jm().format(visit.createdAt);
            final isCompleted = visit.status == 'completed';

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCompleted ? Colors.green.shade100 : Colors.grey.shade200,
                  child: Icon(
                    Icons.bloodtype,
                    color: isCompleted ? Colors.green : Colors.grey,
                  ),
                ),
                title: Text('Token: ${visit.tokenNumber}'),
                subtitle: Text(dateStr),
                trailing: Chip(
                  label: Text(visit.status.toUpperCase()),
                  backgroundColor: isCompleted ? Colors.green.shade50 : Colors.grey.shade100,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Patient Guardianship
// ---------------------------------------------------------------------------
class _PatientGuardianshipTab extends ConsumerStatefulWidget {
  const _PatientGuardianshipTab();

  @override
  ConsumerState<_PatientGuardianshipTab> createState() => _PatientGuardianshipTabState();
}

class _PatientGuardianshipTabState extends ConsumerState<_PatientGuardianshipTab> {
  final _patientIdController = TextEditingController();
  bool _isRequesting = false;

  @override
  void dispose() {
    _patientIdController.dispose();
    super.dispose();
  }

  Future<void> _requestAccess() async {
    final id = _patientIdController.text.trim();
    if (id.isEmpty) return;

    setState(() => _isRequesting = true);

    try {
      await ref.read(donorRepositoryProvider).requestGuardianship(id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access requested! Waiting for admin approval.')),
        );
        _patientIdController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(linkedPatientsProvider);

    return Column(
      children: [
        // Top Section: Request Access
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Link a Thalassemia Patient',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Enter the Patient ID to request viewing access to their transfusion records.'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _patientIdController,
                      decoration: const InputDecoration(
                        labelText: 'Patient ID (UUID)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _isRequesting ? null : _requestAccess,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    ),
                    child: _isRequesting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Request Access'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(),
        // Bottom Section: Linked Patients
        Expanded(
          child: patientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (patients) {
              if (patients.isEmpty) {
                return const Center(
                  child: Text('You have no approved linked patients.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final record = patients[index];
                  // The patient alias comes from the foreign key join
                  final patientProfile = record['patient'] as Map<String, dynamic>?;
                  
                  if (patientProfile == null) return const SizedBox.shrink();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12.0),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.personal_injury),
                      ),
                      title: Text(patientProfile['full_name'] ?? 'Unknown Patient'),
                      subtitle: Text('Blood Group: ${patientProfile['blood_group'] ?? 'Unknown'}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.arrow_forward_ios),
                        onPressed: () {
                          // Placeholder for future navigation to patient detail view
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Patient records view coming soon.')),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
