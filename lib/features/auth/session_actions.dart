import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/auth_repository.dart';

Future<void> signOutWithFeedback(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(authRepositoryProvider).signOut();
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Signed out. Any pending work stays on this device for this account. Sign back in to sync it.',
        ),
      ),
    );
  } on AuthException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign-out could not finish. Please try again.'),
        ),
      );
    }
  }
}
