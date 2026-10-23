import 'package:lifelink/features/legal/age_gate.dart';
import 'package:lifelink/features/legal/policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:lifelink/features/auth/session_actions.dart';
import 'package:lifelink/core/theme/portal_shell.dart';
import 'package:lifelink/core/theme/adaptive_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelink/features/admin/data/admin_repository.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) => PortalShell(
      title: 'Admin workspace',
      subtitle: 'LifeLink / Clinic management',
      selectedIndex: _selectedIndex,
      onSelected: (index) => setState(() => _selectedIndex = index),
      onSignOut: () => signOutWithFeedback(context, ref),
      destinations: const [
        PortalDestination(
          'Overview',
          Icons.dashboard_outlined,
          Icons.dashboard,
        ),
        PortalDestination('Staff', Icons.people_outline, Icons.people),
        PortalDestination('Settings', Icons.settings_outlined, Icons.settings),
        PortalDestination(
          'System',
          Icons.admin_panel_settings_outlined,
          Icons.admin_panel_settings,
        ),
      ],
      child: IndexedStack(
        index: _selectedIndex,
        children: const [
          _DashboardTab(),
          _StaffManagementTab(),
          PolicyAdminScreen(),
          _SystemOverrideTab(),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tab 1: Dashboard
// ---------------------------------------------------------------------------
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (data) {
        final totalBloodMl = data['total_blood_ml'] as int;
        final activePatients = data['active_patients'] as int;
        final activeDonors = data['active_donors'] as int;
        final stockLevels = data['stock_levels'] as Map<String, int>;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeading(
                'Clinic overview',
                'A clear view of your community and blood bank.',
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth < 600 ? 1 : 3;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 16) /
                            columns,
                        child: _SummaryCard(
                          title: 'Blood in stock',
                          value: '${totalBloodMl / 1000} L',
                          icon: Icons.water_drop_outlined,
                        ),
                      ),
                      SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 16) /
                            columns,
                        child: _SummaryCard(
                          title: 'Active patients',
                          value: '$activePatients',
                          icon: Icons.people_outline,
                        ),
                      ),
                      SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 16) /
                            columns,
                        child: _SummaryCard(
                          title: 'Active donors',
                          value: '$activeDonors',
                          icon: Icons.volunteer_activism_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Blood Group Inventory',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 130,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  final bloodGroups = [
                    'A+',
                    'A-',
                    'B+',
                    'B-',
                    'AB+',
                    'AB-',
                    'O+',
                    'O-',
                  ];
                  final bg = bloodGroups[index];
                  final ml = stockLevels[bg] ?? 0;
                  return Card(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          bg,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$ml ml',
                          style: Theme.of(context).textTheme.titleMedium,
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: theme.textTheme.headlineMedium),
                  Text(title, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Staff Management
// ---------------------------------------------------------------------------
class _StaffManagementTab extends ConsumerWidget {
  const _StaffManagementTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: 'Staff Directory'),
              Tab(icon: Icon(Icons.person_add), text: 'Register Staff'),
            ],
          ),
          Expanded(
            child: const TabBarView(
              children: [_StaffDirectoryView(), _StaffRegistrationForm()],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffDirectoryView extends ConsumerWidget {
  const _StaffDirectoryView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);

    return staffAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (staffList) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Clinic staff',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${staffList.length} team member${staffList.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: () => ref.invalidate(staffListProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (staffList.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No staff members yet. Use Register Staff to add your team.',
                          ),
                        ),
                      ),
                    )
                  else
                    ...staffList.map(
                      (row) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StaffActions(ref, context).buildCard(row),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StaffActions {
  _StaffActions(this.ref, this.context);

  final WidgetRef ref;
  final BuildContext context;

  Widget buildCard(Map<String, dynamic> row) {
    final isActive = row['status'] == 'active';
    final scheme = Theme.of(context).colorScheme;
    final role = row['role'] == 'lab' ? 'Lab technician' : 'Reception';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.person_outline),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['full_name']?.toString() ?? 'Unnamed staff',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(role, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: isActive
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              row['phone']?.toString() ?? 'No phone',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showEditDialog(row),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit details'),
                ),
                TextButton.icon(
                  onPressed: () =>
                      isActive ? _deactivateStaff(row) : _reactivateStaff(row),
                  icon: Icon(
                    isActive ? Icons.block_outlined : Icons.restore,
                    size: 18,
                  ),
                  label: Text(isActive ? 'Deactivate' : 'Reactivate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deactivateStaff(Map<String, dynamic> row) async {
    final confirm = await showAdaptiveSheet<bool>(
      context: context,
      builder: (ctx) => AppSheet(
        title: const Text('Deactivate staff member?'),
        content: const Text(
          'This person will lose access until an admin reactivates the account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(adminRepositoryProvider)
            .deactivateStaffAccount(row['id']);
        ref.invalidate(staffListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff account deactivated.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to deactivate: $e')));
        }
      }
    }
  }

  Future<void> _reactivateStaff(Map<String, dynamic> row) async {
    try {
      await ref.read(adminRepositoryProvider).reactivateStaffAccount(row['id']);
      ref.invalidate(staffListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff account reactivated.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reactivate staff. Try again.'),
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> row) async {
    final nameCtrl = TextEditingController(text: row['full_name']);
    final phoneCtrl = TextEditingController(text: row['phone']);
    String selectedRole = row['role'] ?? 'reception';
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showAdaptiveSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AppSheet(
            title: const Text('Edit Staff Details'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: phoneCtrl,
                    maxLength: 11,
                    decoration: const InputDecoration(
                      labelText: 'Phone (11 digits)',
                      counterText: "",
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length != 11 || int.tryParse(v) == null) {
                        return 'Must be exactly 11 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: ['reception', 'lab'].contains(selectedRole)
                        ? selectedRole
                        : 'reception',
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(
                        value: 'reception',
                        child: Text('Reception'),
                      ),
                      DropdownMenuItem(
                        value: 'lab',
                        child: Text('Lab Technician'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => selectedRole = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setState(() => isSaving = true);
                        try {
                          await ref
                              .read(adminRepositoryProvider)
                              .updateStaffMember(
                                profileId: row['id'],
                                fullName: nameCtrl.text.trim(),
                                phone: phoneCtrl.text.trim(),
                                role: selectedRole,
                              );
                          ref.invalidate(staffListProvider);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Staff details updated successfully.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Update failed: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StaffRegistrationForm extends ConsumerStatefulWidget {
  const _StaffRegistrationForm();

  @override
  ConsumerState<_StaffRegistrationForm> createState() =>
      _StaffRegistrationFormState();
}

class _StaffRegistrationFormState
    extends ConsumerState<_StaffRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedRole = 'reception';
  bool _ageVerified = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _registerStaff() async {
    if (!_ageVerified) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref
          .read(adminRepositoryProvider)
          .createStaffAccount(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            role: _selectedRole,
            age13OrOlder: _ageVerified,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Staff account created securely!')),
        );
        _formKey.currentState!.reset();
        setState(() => _ageVerified = false);
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        ref.invalidate(staffListProvider); // Refresh directory
      }
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['error'] is String
          ? details['error'] as String
          : 'Staff registration failed. Check the email and try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ageVerified) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: AgeGate(
                  staff: true,
                  onEligible: () => setState(() => _ageVerified = true),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Register Clinic Staff',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) =>
                      v == null ||
                          v.trim().length < 2 ||
                          RegExp(r'[<>\x00-\x1f\x7f]').hasMatch(v)
                      ? 'Enter a plain-text name of at least two characters'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    labelText: 'Phone (11 digits)',

                    counterText: "",
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (!RegExp(r'^\d{11}$').hasMatch(v)) {
                      return 'Must be exactly 11 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'reception',
                      child: Text('Reception'),
                    ),
                    DropdownMenuItem(
                      value: 'lab',
                      child: Text('Lab Technician'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedRole = val);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  maxLength: 254,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  validator: (v) =>
                      RegExp(
                        r'^[^\s@<>]{1,64}@[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)+$',
                      ).hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Enter a valid email address',
                ),
                const SizedBox(height: 16),
                const Text(
                  'LifeLink will email a one-time recovery code. The staff member must verify that inbox and choose their own strong password.',
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _registerStaff,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label: const Text('Register Staff Account'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: System Override (Visits)
// ---------------------------------------------------------------------------
class _SystemOverrideTab extends ConsumerWidget {
  const _SystemOverrideTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(systemRecordsProvider);

    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (records) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'System Override - Recent Visits',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (records.isEmpty)
                const Center(child: Text('No recent visits found.'))
              else
                PaginatedDataTable(
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Token')),
                    DataColumn(label: Text('User')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Action')),
                  ],
                  source: _VisitsDataSource(records, ref, context),
                  rowsPerPage: 10,
                  showCheckboxColumn: false,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _VisitsDataSource extends DataTableSource {
  _VisitsDataSource(this.records, this.ref, this.context);

  final List<Map<String, dynamic>> records;
  final WidgetRef ref;
  final BuildContext context;

  @override
  DataRow? getRow(int index) {
    if (index >= records.length) return null;
    final row = records[index];

    // Safely extract nested profile data
    final profileData = row['profiles'] as Map<String, dynamic>?;
    final userName = profileData?['full_name'] as String? ?? 'Unknown';

    return DataRow(
      cells: [
        DataCell(Text(row['created_at'].toString().split('T').first)),
        DataCell(Text(row['token_number']?.toString() ?? '-')),
        DataCell(Text(userName)),
        DataCell(Text(row['type']?.toString().toUpperCase() ?? '-')),
        DataCell(Text(row['status']?.toString().toUpperCase() ?? '-')),
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete Record (Override)',
            onPressed: () async {
              final confirm = await showAdaptiveSheet<bool>(
                context: context,
                builder: (ctx) => AppSheet(
                  title: const Text('Delete visit record?'),
                  content: const Text(
                    'Are you sure you want to permanently delete this visit record?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await ref
                      .read(adminRepositoryProvider)
                      .deleteVisitRecord(row['id']);
                  ref.invalidate(systemRecordsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Record deleted successfully.'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e')),
                    );
                  }
                }
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => records.length;
  @override
  int get selectedRowCount => 0;
}
