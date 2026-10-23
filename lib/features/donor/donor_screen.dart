import 'package:lifelink/features/diet/diet_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:lifelink/features/auth/session_actions.dart';
import 'package:lifelink/core/theme/portal_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:lifelink/features/donor/data/donor_repository.dart';

import '../sharing/share_code_card.dart';
import '../sharing/connections_screen.dart';

import 'package:flutter_animate/flutter_animate.dart';

class DonorScreen extends StatefulWidget {
  const DonorScreen({super.key});

  @override
  State<DonorScreen> createState() => _DonorScreenState();
}

class _DonorScreenState extends State<DonorScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) => PortalShell(
      title: 'Donor portal',
      subtitle: 'Every donation makes a difference.',
      selectedIndex: _selectedIndex,
      onSelected: (index) => setState(() => _selectedIndex = index),
      onSignOut: () => signOutWithFeedback(context, ref),
      destinations: const [
        PortalDestination('Home', Icons.home_outlined, Icons.home),
        PortalDestination('History', Icons.history_outlined, Icons.history),
        PortalDestination(
          'Family',
          Icons.family_restroom_outlined,
          Icons.family_restroom,
        ),
        PortalDestination(
          'Impact',
          Icons.leaderboard_outlined,
          Icons.leaderboard,
        ),
        PortalDestination('Profile', Icons.person_outline, Icons.person),
      ],
      child: IndexedStack(
        index: _selectedIndex,
        children: const [
          _CycleTrackerTab(),
          _DonationHistoryTab(),
          CareConnections(),
          _LeaderboardTab(),
          _ProfileTab(),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tab 1: Home / Cycle Tracker
// ---------------------------------------------------------------------------
class _CycleTrackerTab extends ConsumerWidget {
  const _CycleTrackerTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final impactScoreAsync = ref.watch(impactScoreProvider);

    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeading(
            'Your donation journey',
            'See your impact and check in with your clinic.',
          ),
          const DietPlanLink(),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.bloodtype_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Donation status',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Clinic screening required',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'LifeLink cannot determine donation eligibility from a fixed date. A qualified clinic must review your health, donation history and current screening.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          impactScoreAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, stack) => const SizedBox.shrink(),
            data: (volume) {
              final badge = volume > 2000
                  ? 'Gold'
                  : volume > 1000
                  ? 'Silver'
                  : 'Bronze';
              return Card(
                child: PortalRecordTile(
                  leading: Icon(
                    Icons.volunteer_activism_outlined,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(
                    '$volume mL donated',
                    style: theme.textTheme.titleLarge,
                  ),
                  subtitle: const Text('Your contribution so far'),
                  trailing: Chip(label: Text('$badge donor')),
                ),
              );
            },
          ),
        ],
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
          return const PortalEmptyState(
            icon: Icons.history,
            title: 'Your journey starts here',
            message: 'Completed donations and visit updates will appear here.',
          );
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
              child: PortalRecordTile(
                leading: CircleAvatar(
                  backgroundColor: isCompleted
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
                  child: Icon(
                    Icons.bloodtype,
                    color: isCompleted ? Colors.green : Colors.grey,
                  ),
                ),
                title: Text('Token: ${visit.tokenNumber}'),
                subtitle: Text(dateStr),
                trailing: Chip(
                  label: Text(visit.status.toUpperCase()),
                  backgroundColor: isCompleted
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
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
// Tab 4: Leaderboard
// ---------------------------------------------------------------------------
class _LeaderboardTab extends ConsumerWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return leaderboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (donors) {
        if (donors.isEmpty) {
          return const PortalEmptyState(
            icon: Icons.volunteer_activism_outlined,
            title: 'Every donor matters',
            message: 'Community contributions will appear after donations are recorded.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: donors.length,
          itemBuilder: (context, index) {
            final donor = donors[index];
            final rank = index + 1;

            Color rankColor = Colors.grey;
            if (rank == 1) rankColor = Colors.amber;
            if (rank == 2) rankColor = Colors.grey.shade400;
            if (rank == 3) rankColor = Colors.brown.shade300;

            return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: PortalRecordTile(
                    leading: CircleAvatar(
                      backgroundColor: rank <= 3
                          ? rankColor
                          : Colors.blueGrey.shade100,
                      child: Text(
                        '#$rank',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    title: Text(
                      donor['full_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      '${donor['total_volume']} ml',
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                  ),
                )
                .animate()
                .slideX(delay: (index * 50).ms, begin: 0.1, end: 0)
                .fadeIn();
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 5: Profile (QR & Request Blood)
// ---------------------------------------------------------------------------
class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  Future<void> _requestBlood(BuildContext context) async {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Request Blood Transfusion'),
        content: const Text(
          'Please contact reception to arrange a transfusion for yourself or a dependent. Your care team will review the request and next steps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Your profile',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          const ShareCodeCard(purpose: 'checkin'),
          const SizedBox(height: 48),
          const Divider(),
          const SizedBox(height: 32),
          Text('Need Blood?', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _requestBlood(context),
            icon: const Icon(Icons.water_drop),
            label: const Text('How to arrange a transfusion'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
