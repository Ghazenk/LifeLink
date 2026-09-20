import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lifelink/features/auth/data/auth_repository.dart';

/// Provider for the GoRouter instance.
/// Listens to auth state and local user profile to handle redirects.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  return GoRouter(
    initialLocation: '/auth',
    redirect: (context, state) {
      final isAuthRoute = state.matchedLocation == '/auth';

      // We only have a user if authState has data and session is not null
      final isAuthenticated = authState.valueOrNull?.session != null;

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/auth';
      }

      // If authenticated, we need the user profile to determine the next route.
      // While it's loading, we might show a splash or stay on auth.
      if (userProfileAsync.isLoading) return null;

      final profile = userProfileAsync.valueOrNull;

      if (profile == null) {
        // Profile hasn't synced yet, stay on auth (or a loading screen).
        return isAuthRoute ? null : '/auth';
      }

      if (profile.status == 'pending') {
        if (state.matchedLocation != '/pending_approval') {
          return '/pending_approval';
        }
        return null;
      }

      if (profile.status == 'active') {
        // If they are active and on the auth route (or pending), redirect to their home
        if (isAuthRoute || state.matchedLocation == '/pending_approval') {
          switch (profile.role) {
            case 'admin':
              return '/admin';
            case 'reception':
              return '/reception';
            case 'lab':
              return '/lab';
            case 'donor':
              return '/donor';
            case 'patient':
              return '/patient';
            default:
              return '/auth';
          }
        }
      }

      return null; // No redirect needed
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/auth',
        builder: (BuildContext context, GoRouterState state) {
          // TODO: Replace with AuthScreen once UI is built
          // We will build AuthScreen in the next step.
          return const Scaffold(
            body: Center(child: Text('Auth Screen')),
          );
        },
      ),
      GoRoute(
        path: '/pending_approval',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(
            body: Center(
              child: Text(
                  'Your account is pending approval by an administrator.'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(
            body: Center(child: Text('Admin Dashboard')),
          );
        },
      ),
      GoRoute(
        path: '/reception',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(
            body: Center(child: Text('Reception Queue')),
          );
        },
      ),
      GoRoute(
        path: '/lab',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(
            body: Center(child: Text('Lab Results')),
          );
        },
      ),
      GoRoute(
        path: '/donor',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(
            body: Center(child: Text('Donor Portal')),
          );
        },
      ),
      GoRoute(
        path: '/patient',
        builder: (BuildContext context, GoRouterState state) {
          return const Scaffold(
            body: Center(child: Text('Patient Portal')),
          );
        },
      ),
    ],
  );
});
