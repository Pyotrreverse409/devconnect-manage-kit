import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import '../../components/layout/sidebar.dart';
import '../theme/theme_provider.dart';
import '../../features/last_connected/provider/last_connected_providers.dart';

/// Breakpoint below which sidebar auto-collapses
const _collapseBreakpoint = 920.0;

class AppShell extends ConsumerStatefulWidget {
  final String currentPath;
  final Widget child;

  const AppShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int get _selectedIndex {
    for (int i = 0; i < sidebarItems.length; i++) {
      if (sidebarItems[i].routePath == widget.currentPath) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Initialize the last connected provider so disconnect listeners are active
    ref.watch(lastConnectedProvider);
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Auto-collapse sidebar at narrow widths
          if (constraints.maxWidth < _collapseBreakpoint && !isCollapsed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ref.read(sidebarCollapsedProvider.notifier).state = true;
              }
            });
          }

          return Stack(
            children: [
              Row(
                children: [
                  Sidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: (index) {
                      context.go(sidebarItems[index].routePath);
                    },
                  ),
                  Expanded(child: widget.child),
                ],
              ),
              // Draggable title bar (macOS)
              if (Platform.isMacOS)
                Positioned(
                  top: 0,
                  left: isCollapsed ? 16 : 68,
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
          );
        },
      ),
    );
  }
}
