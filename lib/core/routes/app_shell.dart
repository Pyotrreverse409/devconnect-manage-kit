import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/sidebar.dart';
import '../../features/last_connected/provider/last_connected_providers.dart';

class AppShell extends ConsumerWidget {
  final String currentPath;
  final Widget child;

  const AppShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  int get _selectedIndex {
    for (int i = 0; i < sidebarItems.length; i++) {
      if (sidebarItems[i].routePath == currentPath) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize the last connected provider so disconnect listeners are active
    ref.watch(lastConnectedProvider);

    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedIndex: _selectedIndex,
            onItemSelected: (index) {
              context.go(sidebarItems[index].routePath);
            },
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
