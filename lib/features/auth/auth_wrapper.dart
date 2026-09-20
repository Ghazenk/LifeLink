import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lifelink/features/auth/auth_screen.dart';
import 'package:lifelink/features/auth/data/auth_repository.dart';
import 'package:lifelink/features/admin/admin_screen.dart';
import 'package:lifelink/features/reception/reception_screen.dart';
import 'package:lifelink/features/lab/lab_screen.dart';
import 'package:lifelink/features/donor/donor_screen.dart';
import 'package:lifelink/features/patient/patient_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Auth Error: $error')),
      ),
      data: (profile) {
        if (profile == null) {
          return const AuthScreen();
        }

        if (profile.status == 'pending') {
          return const PendingApprovalScreen();
        }

        if (profile.status == 'active') {
          switch (profile.role) {
            case 'admin':
              return const AdminScreen();
            case 'reception':
              return const ReceptionScreen();
            case 'lab':
              return const LabScreen();
            case 'donor':
              return const DonorScreen();
            case 'patient':
              return const PatientScreen();
            default:
              return const Scaffold(
                body: Center(child: Text('Unknown role or unauthorized access.')),
              );
          }
        }

        return const Scaffold(
          body: Center(child: Text('Account status invalid.')),
        );
      },
    );
  }
}

class PendingApprovalScreen extends ConsumerWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Pending')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Your account is waiting for Reception approval.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(authRepositoryProvider).signOut();
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
