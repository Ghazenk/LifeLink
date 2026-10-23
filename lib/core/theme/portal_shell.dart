import '../../features/legal/settings_screen.dart';
import '../network/sync_manager.dart';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'adaptive_sheet.dart';

class PortalDestination {
  const PortalDestination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Shared navigation for phones and wide workstations.
class PortalShell extends StatelessWidget {
  const PortalShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.onSignOut,
    required this.child,
  });
  final String title;
  final String subtitle;
  final List<PortalDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onSignOut;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final content = SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.bloodtype, size: 30),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFFC4D3E4),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Sync status',
            icon: const Icon(Icons.cloud_sync_outlined),
            onPressed: () => showAdaptiveSheet<void>(
              context: context,
              builder: (context) => AppSheet(
                title: const Text('Sync status'),
                content: ValueListenableBuilder<String>(
                  valueListenable: SyncManager().status,
                  builder: (_, value, _) => Text(value),
                ),
                actions: [
                  FilledButton.icon(
                    onPressed: () => SyncManager().syncNow(),
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync now'),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onSignOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 12),
        ],
        shape: wide
            ? null
            : const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
      ),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  extended: MediaQuery.sizeOf(context).width >= 1100,
                  minExtendedWidth: 216,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onSelected,
                  labelType: MediaQuery.sizeOf(context).width >= 1100
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  groupAlignment: -0.85,
                  destinations: destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelected,
              destinations: destinations
                  .map(
                    (d) => NavigationDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: d.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.47,
          ),
        ),
      ],
    ),
  );
}

class PortalEmptyState extends StatelessWidget {
  const PortalEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Moves record actions below the text when horizontal room is limited.
class PortalRecordTile extends StatelessWidget {
  const PortalRecordTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 540;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DefaultTextStyle.merge(
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        child: title,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        DefaultTextStyle.merge(
                          style: Theme.of(context).textTheme.bodySmall!,
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!compact && trailing != null) ...[
                  const SizedBox(width: 16),
                  trailing!,
                ],
              ],
            ),
            if (compact && trailing != null) ...[
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          ],
        ),
      );
    },
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    decoration: const BoxDecoration(
      color: AppTheme.navy,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
    ),
    child: const Column(
      children: [
        Icon(Icons.bloodtype, size: 56, color: Colors.white),
        SizedBox(height: 12),
        Text(
          'LifeLink',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.7,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Blood donation. Connected care.',
          style: TextStyle(color: Color(0xFFC4D3E4), fontSize: 15),
        ),
      ],
    ),
  );
}
