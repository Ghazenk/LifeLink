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
    routes: <RouteBase>[
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
