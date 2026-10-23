import '../../features/sharing/connections_screen.dart';

import 'package:lifelink/features/legal/policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lifelink/features/auth/auth_wrapper.dart';
import 'package:lifelink/features/auth/auth_screen.dart';

/// Provider for the GoRouter instance.
/// Uses declarative widget routing via [AuthWrapper] instead of redirects.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (_, state) =>
        state.uri.scheme == 'lifelink' && state.uri.host == 'connect'
        ? Uri(
            path: '/connect',
            queryParameters: {'code': state.uri.queryParameters['code'] ?? ''},
          ).toString()
        : null,
    routes: <RouteBase>[
      GoRoute(
        path: '/connect',
        builder: (_, state) =>
            ConnectionLanding(code: state.uri.queryParameters['code'] ?? ''),
      ),
      GoRoute(
        path: '/terms',
        builder: (_, _) => const PolicyScreen(page: 'terms'),
      ),
      GoRoute(
        path: '/copyright',
        builder: (_, _) => const PolicyScreen(page: 'copyright'),
      ),
      GoRoute(path: '/privacy', builder: (_, _) => const PolicyScreen()),
      GoRoute(
        path: '/cookies',
        builder: (_, _) => const PolicyScreen(cookies: true),
      ),
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const AuthWrapper();
        },
      ),
      GoRoute(
        path: '/auth',
        builder: (BuildContext context, GoRouterState state) {
          return const AuthScreen();
        },
      ),
      // We can define other explicit routes here if manual deep linking
      // is ever required, but AuthWrapper handles the main root dynamically.
    ],
  );
});
