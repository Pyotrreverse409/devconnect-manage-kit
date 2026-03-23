import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/layout/sidebar.dart';

class AppShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
