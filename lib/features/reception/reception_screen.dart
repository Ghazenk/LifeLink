import '../sharing/checkin_screen.dart';

import 'package:lifelink/features/legal/policy_screen.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lifelink/features/auth/session_actions.dart';
import 'package:lifelink/core/theme/portal_shell.dart';
import 'package:lifelink/core/theme/adaptive_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';

import 'data/workbook_validation.dart';

import 'dart:async';

import 'package:lifelink/core/network/backend_configuration.dart';

import 'package:lifelink/features/reception/data/reception_repository.dart';

class ReceptionScreen extends StatefulWidget {
  const ReceptionScreen({super.key});

  @override
  State<ReceptionScreen> createState() => _ReceptionScreenState();
}

class _ReceptionScreenState extends State<ReceptionScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, _) => PortalShell(
      title: 'Reception',
      subtitle: 'LifeLink / Patient & donor services',
      selectedIndex: _selectedIndex,
      onSelected: (index) => setState(() => _selectedIndex = index),
      onSignOut: () => signOutWithFeedback(context, ref),
      destinations: const [
        PortalDestination(
          'Approvals',
          Icons.how_to_reg_outlined,
          Icons.how_to_reg,
        ),
        PortalDestination(
          'Donation',
          Icons.volunteer_activism_outlined,
          Icons.volunteer_activism,
        ),
        PortalDestination('Transfusion', Icons.healing_outlined, Icons.healing),
        PortalDestination(
          'Inventory',
          Icons.inventory_2_outlined,
          Icons.inventory_2,
        ),
      ],
      child: IndexedStack(
        index: _selectedIndex,
        children: const [
          _UserApprovalsTab(),
          _TokenGenerationTab(roleFilter: 'donor', type: 'donation'),
          _TokenGenerationTab(roleFilter: 'patient', type: 'transfusion'),
          _LiveInventoryTab(),
        ],
      ),
    ),
  );
}

Future<void> _importBulkData(BuildContext context, WidgetRef ref) async {
  final allowed = await showAdaptiveSheet<bool>(
    context: context,
    builder: (ctx) => AppSheet(
      title: const Text('Before importing personal information'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Import only people whose age you have verified as 13 or older and whose information you are authorized to provide. Do not select a file containing children under 13. Each row requires a sixth column, age_13_or_older, with TRUE. Files stay on this device; validated account fields are sent to Supabase.',
          ),
          SizedBox(height: 16),
          CopyrightReportLink(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('I verified ages and have permission'),
        ),
      ],
    ),
  );
  if (allowed != true || !context.mounted) return;
  bool dialogOpen = false;
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    if (await file.length() > 5 * 1024 * 1024) {
      throw StateError('Use a workbook smaller than 5 MB.');
    }
    final bytes = await file.readAsBytes();
    validateImportWorkbook(bytes);
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.length != 1) {
      throw const FormatException('Import one worksheet at a time.');
    }
    final sheet = excel.tables[excel.tables.keys.first]!;
    if (sheet.maxRows > 101 || sheet.maxColumns > 6) {
      throw const FormatException('Use at most 100 rows and six columns.');
    }

    List<Map<String, dynamic>> parsedUsers = [];

    // Skip header row
    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty || row[0]?.value == null) continue;
      if (row.any((cell) => cell?.value is FormulaCellValue)) {
        throw FormatException(
          'Row ${i + 1} contains a formula. Use plain values.',
        );
      }

      if (row.length < 6) {
        throw StateError(
          'Row ${i + 1} needs name, phone, role, blood group, real email and age_13_or_older TRUE.',
        );
      }
      if (row[5]?.value.toString().trim().toLowerCase() != 'true') {
        throw StateError(
          'Every person must be verified as 13 or older. Nothing was imported.',
        );
      }
      // Expecting: Full Name (0), Phone (1), Role (2), Blood Group (3), Email (4)
      parsedUsers.add({
        'age_13_or_older': true,
        'full_name': row[0]?.value.toString(),
        'phone': row[1]?.value.toString(),
        'role': row[2]?.value.toString().trim().toLowerCase(),
        'blood_group': row[3]?.value.toString(),
        'email': row[4]?.value.toString().trim(),
      });
    }

    if (parsedUsers.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No valid rows found.')));
      }
      return;
    }

    if (!context.mounted) return;
    dialogOpen = true;
    showAdaptiveSheet<void>(
      context: context,
      dismissible: false,
      builder: (c) => const AppSheet(
        title: Text('Importing users'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Importing users...'),
          ],
        ),
      ),
    );

    await ref
        .read(receptionRepositoryProvider)
        .importUsersFromExcel(parsedUsers);

    if (context.mounted) {
      Navigator.pop(context); // close dialog
      dialogOpen = false;
      ref.invalidate(pendingUsersProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${parsedUsers.length} accounts. Email verification and password recovery are required before first use.',
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      // try pop dialog if open
      if (dialogOpen) Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Middle Tab: View Users Approvals
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
          return const PortalEmptyState(
            icon: Icons.how_to_reg_outlined,
            title: 'All caught up',
            message: 'New donor and patient registrations will appear here for review.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24.0),
          itemCount: users.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final user = users[index];
            return PortalRecordTile(
              leading: CircleAvatar(
                child: Text(
                  user['role']?.toString().substring(0, 1).toUpperCase() ?? '?',
                ),
              ),
              title: Text(user['full_name'] ?? 'Unknown Name'),
              subtitle: Text(
                'Phone: ${user['phone'] ?? '-'}  •  Role: ${user['role']}'
                '${user['blood_group'] != null ? '  •  Blood: ${user['blood_group']}' : ''}',
              ),
              trailing: FilledButton.icon(
                onPressed: () async {
                  try {
                    await ref
                        .read(receptionRepositoryProvider)
                        .approveUser(user['id']);
                    ref.invalidate(pendingUsersProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${user['full_name']} approved successfully.',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Approval failed: $e'),
                          backgroundColor: Colors.red,
                        ),
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
  const _TokenGenerationTab({required this.roleFilter, required this.type});
  final String roleFilter;
  final String type;

  @override
  ConsumerState<_TokenGenerationTab> createState() =>
      _TokenGenerationTabState();
}

class _TokenGenerationTabState extends ConsumerState<_TokenGenerationTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _issuingToken = false;
  int _searchRevision = 0;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
    _searchRevision++;
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
    final revision = ++_searchRevision;
    setState(() => _isLoading = true);
    try {
      final results = await ref
          .read(receptionRepositoryProvider)
          .searchActiveUsers(query);
      if (mounted && revision == _searchRevision) {
        setState(() {
          _searchResults = results
              .where((u) => u['role'] == widget.roleFilter)
              .toList();
          _isLoading = false;
          _searchError = null;
        });
      }
    } catch (_) {
      if (mounted && revision == _searchRevision) {
        setState(() {
          _isLoading = false;
          _searchResults = [];
          _searchError = BackendConfiguration.isClinic
              ? 'Patient and donor lookup needs the clinic server. Check the LAN connection; do not use an old search result.'
              : 'Patient and donor lookup needs an internet connection. Do not use an old search result to create a visit.';
        });
      }
    }
  }

  Future<void> _issueToken(String userId, String type) async {
    if (_issuingToken) return;
    setState(() => _issuingToken = true);
    try {
      final visit = await ref
          .read(receptionRepositoryProvider)
          .issueToken(userId: userId, type: type);

      if (mounted) {
        showAdaptiveSheet<void>(
          context: context,
          builder: (ctx) => AppSheet(
            title: Center(
              child: Text(
                BackendConfiguration.isClinic
                    ? 'Token issued at clinic server'
                    : 'Token saved on this device',
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  BackendConfiguration.isClinic
                      ? 'The shared clinic server accepted this token. Lab can refresh its queue over the LAN.'
                      : 'Check sync is up to date before sending this token to another workstation.',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    visit.tokenNumber,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
          SnackBar(
            content: Text('Failed to issue token: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _issuingToken = false);
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
            decoration: InputDecoration(
              labelText:
                  'Search Active ${widget.roleFilter == 'donor' ? 'Donors' : 'Patients'}',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              hintText: 'Enter name or phone number...',
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan / enter check-in code'),
          onPressed: () async {
            final person = await Navigator.of(context)
                .push<Map<String, dynamic>>(
                  MaterialPageRoute(builder: (_) => const CheckInScreen()),
                );
            if (person == null || !mounted || !context.mounted) return;
            if (person['role'] != widget.roleFilter) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Use the Donation tab for donors and the Transfusion tab for patients.',
                  ),
                ),
              );
              return;
            }
            _debounce?.cancel();
            _searchRevision++;
            setState(() {
              _searchResults = [person];
              _isLoading = false;
              _searchError = null;
            });
          },
        ),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_searchError!, textAlign: TextAlign.center),
          ),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_searchResults.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No active users found matching search.'),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              itemCount: _searchResults.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final role = user['role']?.toString() ?? 'unknown';
                return PortalRecordTile(
                  leading: CircleAvatar(
                    backgroundColor: role == 'donor'
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    child: Icon(
                      role == 'donor'
                          ? Icons.volunteer_activism
                          : Icons.personal_injury,
                      color: role == 'donor' ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(user['full_name'] ?? 'Unknown Name'),
                  subtitle: Text(
                    'Role: ${role.toUpperCase()}  •  Phone: ${user['phone'] ?? '-'}',
                  ),
                  trailing: OutlinedButton.icon(
                    onPressed: _issuingToken
                        ? null
                        : () => _issueToken(user['id'], widget.type),
                    icon: Icon(
                      widget.type == 'donation'
                          ? Icons.bloodtype
                          : Icons.healing,
                    ),
                    label: Text(
                      widget.type == 'donation'
                          ? 'Issue Donation'
                          : 'Issue Transfusion',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.type == 'donation'
                          ? Colors.green
                          : Colors.orange,
                    ),
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
      error: (err, stack) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Live inventory is unavailable. Stock cannot be verified or adjusted in this app while offline. Follow the clinic\'s approved downtime procedure.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (inventory) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  Text(
                    'Blood bank inventory',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _showManualStockDialog(context, ref),
                        icon: const Icon(Icons.add),
                        label: const Text('Manual Stock Entry'),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _importBulkData(context, ref),
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Import Bulk Users (XLSX)'),
                      ),
                      const CopyrightReportLink(),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                BackendConfiguration.isClinic
                    ? 'Stock is read from the clinic server. Verify physical units and compatibility before use; changes require the LAN server.'
                    : 'Live online stock only. Verify availability before use; manual stock entries require an internet connection.',
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
                  mainAxisExtent: 140,
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
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
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

  Future<void> _showManualStockDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final formKey = GlobalKey<FormState>();
    final volumeCtrl = TextEditingController();
    String selectedBg = 'A+';
    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    bool isSaving = false;

    await showAdaptiveSheet<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AppSheet(
            title: const Text('Add Stock Manually'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedBg,
                    decoration: const InputDecoration(labelText: 'Blood Group'),
                    items: bloodGroups
                        .map(
                          (bg) => DropdownMenuItem(value: bg, child: Text(bg)),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedBg = val);
                    },
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: volumeCtrl,
                    decoration: const InputDecoration(labelText: 'Volume (ml)'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final volume = int.tryParse(v?.trim() ?? '');
                      return volume == null || volume <= 0
                          ? 'Enter a volume greater than zero'
                          : null;
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
                              .read(receptionRepositoryProvider)
                              .addManualStock(
                                selectedBg,
                                int.parse(volumeCtrl.text.trim()),
                              );
                          ref.invalidate(liveInventoryProvider);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Stock added successfully.'),
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Add Stock'),
              ),
            ],
          );
        },
      ),
    );
  }
}
