import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lifelink/features/auth/session_actions.dart';
import 'package:lifelink/core/theme/portal_shell.dart';
import 'package:lifelink/core/network/sync_manager.dart';
import 'package:lifelink/core/network/backend_configuration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/features/lab/data/lab_repository.dart';
import 'package:lifelink/features/legal/settings_screen.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  static const _queueRefreshInterval = Duration(seconds: 30);
  Timer? _queueRefreshTimer;
  LocalVisit? _selectedVisit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(SyncManager().syncNow());
    });
    _queueRefreshTimer = Timer.periodic(_queueRefreshInterval, (_) {
      if (!mounted ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          !(ModalRoute.of(context)?.isCurrent ?? true)) {
        return;
      }
      unawaited(SyncManager().syncNow());
    });
  }

  @override
  void dispose() {
    _queueRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final queue = _QueuePane(
      selectedVisitId: _selectedVisit?.id,
      onSelectVisit: (visit) => setState(() => _selectedVisit = visit),
    );
    final workstation = _selectedVisit == null
        ? const PortalEmptyState(
            icon: Icons.biotech_outlined,
            title: 'Ready for the next visit',
            message:
                'Select a token from the queue to view and record lab results.',
          )
        : _WorkstationPane(
            visit: _selectedVisit!,
            onComplete: () => setState(() => _selectedVisit = null),
          );
    return Scaffold(
      appBar: AppBar(
        leading: !wide && _selectedVisit != null
            ? IconButton(
                tooltip: 'Back to queue',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedVisit = null),
              )
            : const Icon(Icons.bloodtype),
        title: const Text('Lab workstation'),
        actions: [
          IconButton(
            tooltip: 'Settings and connection',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Sync lab queue',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await SyncManager().syncNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(SyncManager().status.value)),
                );
              }
            },
          ),
          Consumer(
            builder: (context, ref, _) => IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => signOutWithFeedback(context, ref),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: wide
            ? Row(
                children: [
                  SizedBox(width: 300, child: queue),
                  const VerticalDivider(width: 1),
                  Expanded(child: workstation),
                ],
              )
            : (_selectedVisit == null ? queue : workstation),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Left Pane: Queue
// ---------------------------------------------------------------------------
class _QueuePane extends ConsumerWidget {
  const _QueuePane({
    required this.selectedVisitId,
    required this.onSelectVisit,
  });

  final String? selectedVisitId;
  final ValueChanged<LocalVisit> onSelectVisit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(liveQueueProvider);

    return queueAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (queue) {
        if (queue.isEmpty) {
          return PortalEmptyState(
            icon: Icons.check_circle_outline,
            title: 'Queue is clear',
            message: BackendConfiguration.isClinic
                ? 'New tokens from Reception appear through the clinic server. This queue checks every 30 seconds; tap refresh to check now.'
                : 'New tokens appear after reception syncs them. This queue checks every 30 seconds while open; tap the sync icon to check now.',
          );
        }

        return ListView.separated(
          itemCount: queue.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final visit = queue[index];
            final isSelected = visit.id == selectedVisitId;
            final isDonation = visit.type == 'donation';

            return ListTile(
              selected: isSelected,
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
              leading: CircleAvatar(
                backgroundColor: isDonation
                    ? Colors.green.shade100
                    : Colors.orange.shade100,
                child: Text(
                  visit.type.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: isDonation ? Colors.green : Colors.orange,
                  ),
                ),
              ),
              title: Text(
                'Token: ${visit.tokenNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Time: ${visit.createdAt.toLocal().toString().split('.')[0]}',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => onSelectVisit(visit),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Right Pane: Workstation
// ---------------------------------------------------------------------------
class _WorkstationPane extends ConsumerStatefulWidget {
  const _WorkstationPane({required this.visit, required this.onComplete});

  final LocalVisit visit;
  final VoidCallback onComplete;

  @override
  ConsumerState<_WorkstationPane> createState() => _WorkstationPaneState();
}

class _WorkstationPaneState extends ConsumerState<_WorkstationPane> {
  final _formKey = GlobalKey<FormState>();
  final _hgbController = TextEditingController();
  final _wbcController = TextEditingController();
  final _pltController = TextEditingController();
  final _rbcController = TextEditingController();
  final _hctController = TextEditingController();
  final _mcvController = TextEditingController();
  final _mchController = TextEditingController();
  final _mchcController = TextEditingController();
  final _ferritinController = TextEditingController();
  final _volumeController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void didUpdateWidget(covariant _WorkstationPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visit.id != widget.visit.id) {
      // Visit changed, clear fields
      _formKey.currentState?.reset();
      _hgbController.clear();
      _wbcController.clear();
      _pltController.clear();
      _rbcController.clear();
      _hctController.clear();
      _mcvController.clear();
      _mchController.clear();
      _mchcController.clear();
      _ferritinController.clear();
      _volumeController.clear();
    }
  }

  @override
  void dispose() {
    _hgbController.dispose();
    _wbcController.dispose();
    _pltController.dispose();
    _rbcController.dispose();
    _hctController.dispose();
    _mcvController.dispose();
    _mchController.dispose();
    _mchcController.dispose();
    _ferritinController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  String? _validateMeasurement(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || !number.isFinite || number < 0 || number > 100000
        ? 'Enter a valid non-negative reading'
        : null;
  }

  Future<void> _completeVisit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final prescribedVolume = int.parse(_volumeController.text.trim());

      await ref
          .read(labRepositoryProvider)
          .completeLabProcessing(
            visit: widget.visit,
            hemoglobin: double.parse(_hgbController.text.trim()),
            wbc: double.parse(_wbcController.text.trim()),
            platelets: double.parse(_pltController.text.trim()),
            rbc: double.parse(_rbcController.text.trim()),
            hematocrit: double.parse(_hctController.text.trim()),
            mcv: double.parse(_mcvController.text.trim()),
            mch: double.parse(_mchController.text.trim()),
            mchc: double.parse(_mchcController.text.trim()),
            ferritin: double.parse(_ferritinController.text.trim()),
            prescribedVolumeMl: prescribedVolume,
          );

      if (BackendConfiguration.isClinic) {
        await SyncManager().syncNow();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              BackendConfiguration.isClinic
                  ? 'Visit ${widget.visit.tokenNumber} committed to the clinic server. Verify stock and clinical details before use.'
                  : 'Visit ${widget.visit.tokenNumber} saved on this device. Check sync before relying on cloud inventory.',
            ),
          ),
        );
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving result: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDonation = widget.visit.type == 'donation';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Token: ${widget.visit.tokenNumber}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Type: ${widget.visit.type.toUpperCase()}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDonation ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isDonation ? Icons.bloodtype : Icons.healing,
                  size: 64,
                  color: isDonation ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const Divider(height: 48),

            const Text(
              'Enter verified laboratory readings. Automatic machine import is not configured.',
            ),
            const SizedBox(height: 24),

            // CBC Inputs
            Text('Lab Results', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            GridView.extent(
              maxCrossAxisExtent: 280,
              mainAxisExtent: 88,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,

              children: [
                TextFormField(
                  controller: _hgbController,
                  decoration: const InputDecoration(
                    labelText: 'HGB (g/dL)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMeasurement,
                ),
                TextFormField(
                  controller: _wbcController,
                  decoration: const InputDecoration(
                    labelText: 'WBC (10^9/L)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMeasurement,
                ),
                TextFormField(
                  controller: _pltController,
                  decoration: const InputDecoration(
                    labelText: 'PLT (10^9/L)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMeasurement,
                ),
                TextFormField(
                  controller: _rbcController,
                  decoration: const InputDecoration(
                    labelText: 'RBC (10^12/L)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMeasurement,
                ),
                TextFormField(
                  controller: _hctController,
                  decoration: const InputDecoration(
                    labelText: 'HCT (%)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMeasurement,
                ),
                TextFormField(
                  controller: _mcvController,
                  decoration: const InputDecoration(
                    labelText: 'MCV (fL)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMeasurement,
                ),
                TextFormField(
                  controller: _mchController,
                  decoration: const InputDecoration(
                    labelText: 'MCH (pg)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMeasurement,
                ),
                TextFormField(
                  controller: _mchcController,
                  decoration: const InputDecoration(
                    labelText: 'MCHC (g/dL)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMeasurement,
                ),
                TextFormField(
                  controller: _ferritinController,
                  decoration: const InputDecoration(
                    labelText: 'Ferritin (ng/mL)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _validateMeasurement,
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Prescription Input
            Text('Procedure Details', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _volumeController,
              decoration: const InputDecoration(
                labelText: 'Actual recorded volume (mL)',
                prefixIcon: Icon(Icons.water_drop),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final volume = int.tryParse(value ?? '');
                return volume == null || volume < 1 || volume > 2000
                    ? 'Enter the recorded volume (1-2000 mL)'
                    : null;
              },
            ),

            const SizedBox(height: 48),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _completeVisit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSubmitting
                      ? 'Processing...'
                      : 'Complete Visit & Update Inventory',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
