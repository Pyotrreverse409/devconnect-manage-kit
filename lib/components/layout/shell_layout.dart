import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

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
      body: Stack(
        children: [
          Row(
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
          // Draggable title bar area (macOS traffic lights clearance)
          if (Platform.isMacOS)
            Positioned(
              top: 0,
              left: 68, // sidebar width
              right: 0,
              height: 38,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
              ),
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
