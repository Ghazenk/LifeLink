import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:lifelink/features/auth/data/auth_repository.dart';
import 'package:lifelink/features/reception/data/reception_repository.dart';

class ReceptionScreen extends StatefulWidget {
  const ReceptionScreen({super.key});

  @override
  State<ReceptionScreen> createState() => _ReceptionScreenState();
}

class _ReceptionScreenState extends State<ReceptionScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reception Dashboard'),
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
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.how_to_reg_outlined),
                selectedIcon: Icon(Icons.how_to_reg),
                label: Text('Approvals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.confirmation_number_outlined),
                selectedIcon: Icon(Icons.confirmation_number),
                label: Text('Issue Token'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Inventory'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                _UserApprovalsTab(),
                _TokenGenerationTab(),
                _LiveInventoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: User Approvals
// ---------------------------------------------------------------------------
class _UserApprovalsTab extends ConsumerWidget {
  const _UserApprovalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingUsersAsync = ref.watch(pendingUsersProvider);

    return pendingUsersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (users) {
        if (users.isEmpty) {
          return const Center(child: Text('No pending user approvals.'));
        }
        
        return ListView.separated(
          padding: const EdgeInsets.all(24.0),
          itemCount: users.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(user['role']?.toString().substring(0, 1).toUpperCase() ?? '?'),
              ),
              title: Text(user['full_name'] ?? 'Unknown Name'),
              subtitle: Text(
                'Phone: ${user['phone'] ?? '-'}  •  Role: ${user['role']}'
                '${user['blood_group'] != null ? '  •  Blood: ${user['blood_group']}' : ''}'
              ),
              trailing: FilledButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(receptionRepositoryProvider).approveUser(user['id']);
                    ref.invalidate(pendingUsersProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${user['full_name']} approved successfully.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Approval failed: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Token Generation
// ---------------------------------------------------------------------------
class _TokenGenerationTab extends ConsumerStatefulWidget {
  const _TokenGenerationTab();

  @override
  ConsumerState<_TokenGenerationTab> createState() => _TokenGenerationTabState();
}

class _TokenGenerationTabState extends ConsumerState<_TokenGenerationTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await ref.read(receptionRepositoryProvider).searchActiveUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _issueToken(String userId, String type) async {
    try {
      final visit = await ref.read(receptionRepositoryProvider).issueToken(
        userId: userId,
        type: type,
      );
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Center(child: Text('Token Issued Successfully')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Please direct the user to the Lab with token:'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    visit.tokenNumber,
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Type: ${visit.type.toUpperCase()}'),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to issue token: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search Active Donors & Patients',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              hintText: 'Enter name or phone number...',
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_searchResults.isEmpty)
          const Expanded(child: Center(child: Text('No active users found matching search.')))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              itemCount: _searchResults.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final role = user['role']?.toString() ?? 'unknown';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: role == 'donor' ? Colors.green.shade100 : Colors.orange.shade100,
                    child: Icon(
                      role == 'donor' ? Icons.volunteer_activism : Icons.personal_injury,
                      color: role == 'donor' ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(user['full_name'] ?? 'Unknown Name'),
                  subtitle: Text('Role: ${role.toUpperCase()}  •  Phone: ${user['phone'] ?? '-'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _issueToken(user['id'], 'donation'),
                        icon: const Icon(Icons.bloodtype),
                        label: const Text('Issue Donation'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _issueToken(user['id'], 'transfusion'),
                        icon: const Icon(Icons.healing),
                        label: const Text('Issue Transfusion'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Live Inventory
// ---------------------------------------------------------------------------
class _LiveInventoryTab extends ConsumerWidget {
  const _LiveInventoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(liveInventoryProvider);

    return inventoryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (inventory) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Blood Bank Inventory',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Read-only view for reception staff to check availability before issuing transfusion tokens.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                itemCount: inventory.length,
                itemBuilder: (context, index) {
                  final row = inventory[index];
                  final bg = row['blood_group']?.toString() ?? '?';
                  final ml = row['volume_ml']?.toString() ?? '0';
                  
                  return Card(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          bg,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$ml ml',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
