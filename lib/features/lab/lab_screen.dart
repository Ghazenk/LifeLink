import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lifelink/core/local_db/models/local_visit.dart';
import 'package:lifelink/features/auth/data/auth_repository.dart';
import 'package:lifelink/features/lab/data/lab_repository.dart';
import 'package:lifelink/features/lab/data/cbc_serial_reader.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  LocalVisit? _selectedVisit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab Workstation'),
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
          // Left Pane: The Queue
          Expanded(
            flex: 1,
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: _QueuePane(
                selectedVisitId: _selectedVisit?.id,
                onSelectVisit: (visit) {
                  setState(() => _selectedVisit = visit);
                },
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // Right Pane: Processing Workstation
          Expanded(
            flex: 2,
            child: _selectedVisit == null
                ? const Center(child: Text('Select a token from the queue to begin processing.'))
                : _WorkstationPane(
                    visit: _selectedVisit!,
                    onComplete: () {
                      setState(() => _selectedVisit = null);
                    },
                  ),
          ),
        ],
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
          return const Center(child: Text('Queue is empty.'));
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
                backgroundColor: isDonation ? Colors.green.shade100 : Colors.orange.shade100,
                child: Text(
                  visit.type.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: isDonation ? Colors.green : Colors.orange),
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
  const _WorkstationPane({
    required this.visit,
    required this.onComplete,
  });

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
  final _volumeController = TextEditingController();

  final _serialReader = CbcSerialReader();
  String? _selectedPort;
  bool _isReadingHardware = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-select first available port if any
    final ports = _serialReader.getAvailablePorts();
    if (ports.isNotEmpty) {
      _selectedPort = ports.first;
    }
  }

  @override
  void didUpdateWidget(covariant _WorkstationPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visit.id != widget.visit.id) {
      // Visit changed, clear fields
      _formKey.currentState?.reset();
      _hgbController.clear();
      _wbcController.clear();
      _pltController.clear();
      _volumeController.clear();
    }
  }

  @override
  void dispose() {
    _hgbController.dispose();
    _wbcController.dispose();
    _pltController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  Future<void> _fetchFromMachine() async {
    setState(() => _isReadingHardware = true);
    try {
      final results = await _serialReader.mockFetch();
      if (mounted) {
        _hgbController.text = results['hemoglobin'].toString();
        _wbcController.text = results['wbc'].toString();
        _pltController.text = results['platelets'].toString();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CBC values auto-filled from machine.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hardware read failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isReadingHardware = false);
    }
  }

  Future<void> _completeVisit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final isDonation = widget.visit.type == 'donation';
      final prescribedVolume = isDonation 
          ? 500 
          : int.parse(_volumeController.text.trim());

      await ref.read(labRepositoryProvider).completeLabProcessing(
        visit: widget.visit,
        hemoglobin: double.parse(_hgbController.text.trim()),
        wbc: double.parse(_wbcController.text.trim()),
        platelets: double.parse(_pltController.text.trim()),
        prescribedVolumeMl: prescribedVolume,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Visit ${widget.visit.tokenNumber} completed and inventory updated.')),
        );
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving result: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ports = _serialReader.getAvailablePorts();
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
                      style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
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

            // Hardware Row
            Text('Hardware Integration', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedPort,
                    decoration: const InputDecoration(
                      labelText: 'CBC Machine COM Port',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.usb),
                    ),
                    items: ports.isEmpty 
                        ? [const DropdownMenuItem(value: null, child: Text('No ports found'))]
                        : ports.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPort = val);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _isReadingHardware ? null : _fetchFromMachine,
                  icon: _isReadingHardware 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download),
                  label: const Text('Auto-Fill from Machine'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20)),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // CBC Inputs
            Text('Lab Results', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hgbController,
                    decoration: const InputDecoration(
                      labelText: 'Hemoglobin (g/dL)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _wbcController,
                    decoration: const InputDecoration(
                      labelText: 'WBC (10^9/L)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _pltController,
                    decoration: const InputDecoration(
                      labelText: 'Platelets (10^9/L)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),

            // Prescription Input
            Text('Procedure Details', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (isDonation)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.green),
                    const SizedBox(width: 16),
                    Text(
                      'Standard 500ml Donation',
                      style: theme.textTheme.titleMedium?.copyWith(color: Colors.green.shade900),
                    ),
                  ],
                ),
              )
            else
              TextFormField(
                controller: _volumeController,
                decoration: const InputDecoration(
                  labelText: 'Prescribed Transfusion Volume (ml)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.water_drop),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            
            const SizedBox(height: 48),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _completeVisit,
                icon: _isSubmitting 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSubmitting ? 'Processing...' : 'Complete Visit & Update Inventory'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
