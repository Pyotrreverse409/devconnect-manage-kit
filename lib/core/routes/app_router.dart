import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/console/presentation/pages/console_page.dart';
import '../../features/database_viewer/presentation/pages/database_viewer_page.dart';
import '../../features/network_inspector/presentation/pages/network_inspector_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/state_inspector/presentation/pages/state_inspector_page.dart';
import '../../features/storage_viewer/presentation/pages/storage_viewer_page.dart';
import '../routes/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/console',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return AppShell(
          currentPath: state.uri.path,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/console',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ConsolePage(),
          ),
        ),
        GoRoute(
          path: '/network',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: NetworkInspectorPage(),
          ),
        ),
        GoRoute(
          path: '/state',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: StateInspectorPage(),
          ),
        ),
        GoRoute(
          path: '/storage',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: StorageViewerPage(),
          ),
        ),
        GoRoute(
          path: '/database',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DatabaseViewerPage(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsPage(),
          ),
        ),
      ],
    ),
  ],
);
