import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/backend_configuration.dart';
import '../../core/network/sync_manager.dart';
import '../auth/data/auth_repository.dart';
import 'policy_screen.dart';

class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Your account', style: Theme.of(context).textTheme.titleLarge),
          if (profile != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(profile.fullName),
              subtitle: Text('${profile.role} · ${profile.status}'),
            ),
          const SizedBox(height: 24),
          Text(
            'Privacy & legal',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final item in const {
            'privacy': 'Privacy notice',
            'terms': 'Terms of use',
            'cookies': 'Cookies & storage',
            'copyright': 'Copyright & reports',
          }.entries)
            ListTile(
              title: Text(item.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PolicyScreen(
                    page: item.key,
                    cookies: item.key == 'cookies',
                  ),
                ),
              ),
            ),
          Text('Connection', style: Theme.of(context).textTheme.titleLarge),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_outlined),
            title: Text(
              BackendConfiguration.isClinic || AppConstants.hasBackendUrlOverride
                  ? 'Configured clinic backend'
                  : 'Hosted cloud backend',
            ),
            subtitle: Text(BackendConfiguration.selectedHost),
          ),
          ValueListenableBuilder<String>(
            valueListenable: SyncManager().status,
            builder: (context, status, _) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sync),
              title: const Text('Sync status'),
              subtitle: Text(status),
              trailing: TextButton(
                onPressed: status == 'Syncing…'
                    ? null
                    : () => SyncManager().syncNow(),
                child: const Text('Sync now'),
              ),
            ),
          ),
          if (!BackendConfiguration.isClinic && !AppConstants.hasBackendUrlOverride)
            const Text(
              'This build uses the internet for sharing records between laptops. '
              'The Ethernet test page is not a clinical database. A clinic LAN '
              'server must be installed and configured before internet-off '
              'sharing is available.',
            ),
          if (BackendConfiguration.isClinic)
            const Text(
              'This workstation uses the clinic server on your local network. '
              'Token and lab changes require that server to be reachable. '
              'Cloud publication is not yet enabled.',
            ),
          const SizedBox(height: 24),
          if (profile?.role == 'admin')
            ListTile(
              title: const Text('Edit public operator details'),
              subtitle: const Text(
                'Contact information, retention and copyright settings',
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Operator settings')),
                    body: const PolicyAdminScreen(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
