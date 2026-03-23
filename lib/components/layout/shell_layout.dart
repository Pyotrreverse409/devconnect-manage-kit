import 'package:flutter/material.dart';

import 'sidebar.dart';

class ShellLayout extends StatefulWidget {
  final Widget child;
  final int selectedIndex;

  const ShellLayout({
    super.key,
    required this.child,
    required this.selectedIndex,
  });

  @override
  State<ShellLayout> createState() => _ShellLayoutState();
}

class _ShellLayoutState extends State<ShellLayout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            selectedIndex: widget.selectedIndex,
            onItemSelected: (index) {
              final item = sidebarItems[index];
              _navigateTo(item.routePath);
            },
          ),
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }

  void _navigateTo(String path) {
    // Using GoRouter context extension
    // GoRouter.of(context).go(path);
    // We'll use the callback approach through the router
    final router =
        ModalRoute.of(context)?.settings.arguments as Function(String)?;
    if (router != null) {
      router(path);
    }
  }
}
