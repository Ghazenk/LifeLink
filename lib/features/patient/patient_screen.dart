import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:lifelink/features/auth/data/auth_repository.dart';
import 'package:lifelink/features/patient/data/patient_repository.dart';

class PatientScreen extends StatefulWidget {
  const PatientScreen({super.key});

  @override
  State<PatientScreen> createState() => _PatientScreenState();
}

class _PatientScreenState extends State<PatientScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width >= 600;

    final destinations = <_Destination>[
      _Destination('Dashboard', Icons.dashboard_outlined, Icons.dashboard),
      _Destination('Records', Icons.medical_information_outlined, Icons.medical_information),
      _Destination('Guardianship', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings),
    ];

    final bodyContent = IndexedStack(
      index: _selectedIndex,
      children: const [
        _DashboardTab(),
        _MedicalRecordsTab(),
        _GuardianshipApprovalsTab(),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Portal'),
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
// Tab 1: Dashboard (Digital ID & Next Appointment)
// ---------------------------------------------------------------------------
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextTransfusionAsync = ref.watch(nextTransfusionProvider);
    final userId = ref.read(patientRepositoryProvider).currentUserId;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Next Estimate Card
          Card(
            color: theme.colorScheme.primaryContainer,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(Icons.calendar_month, size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Next Estimated Transfusion',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  nextTransfusionAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Text('Error: $err'),
                    data: (date) {
                      if (date == null) {
                        return Text(
                          'No completed visits yet.',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        );
                      }
                      return Text(
                        DateFormat.yMMMMd().format(date),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48),
          
          // Digital ID QR Code
          Text(
            'Digital Check-In ID',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Present this code at Reception to quickly pull up your records and issue a token.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: userId,
                version: QrVersions.auto,
                size: 250.0,
                backgroundColor: Colors.white,
              ),
            ),
          ),
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
          return const Center(child: Text('No transfusion records found.'));
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat.yMMMd().add_jm().format(visit.createdAt),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Chip(
                          label: Text(visit.status.toUpperCase()),
                          backgroundColor: isCompleted ? Colors.green.shade50 : Colors.orange.shade50,
                          labelStyle: TextStyle(
                            color: isCompleted ? Colors.green.shade900 : Colors.orange.shade900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Token: ${visit.tokenNumber}', style: TextStyle(color: Colors.grey.shade700)),
                    
                    if (lab != null) ...[
                      const Divider(height: 24),
                      Text('Lab Results & Procedure', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatDisplay('HGB', '${lab.hemoglobin} g/dL'),
                          _StatDisplay('WBC', '${lab.wbc}'),
                          _StatDisplay('PLT', '${lab.platelets}'),
                          _StatDisplay('Volume', '${lab.prescribedVolumeMl ?? 0} ml', highlight: true),
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

  Future<void> _respond(BuildContext context, WidgetRef ref, String id, String status) async {
    try {
      await ref.read(patientRepositoryProvider).respondToGuardianship(id, status);
      ref.invalidate(pendingGuardianshipsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingGuardianshipsProvider);

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (requests) {
        if (requests.isEmpty) {
          return const Center(child: Text('No pending guardianship requests.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            final donor = req['donor'] as Map<String, dynamic>?;

            return Card(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.volunteer_activism),
                ),
                title: Text(donor?['full_name'] ?? 'Unknown Donor'),
                subtitle: const Text('Requested access to your medical history.'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _respond(context, ref, req['id'], 'rejected'),
                      child: const Text('REJECT', style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _respond(context, ref, req['id'], 'approved'),
                      child: const Text('APPROVE'),
                    ),
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
