import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/color_tokens.dart';
import '../../core/theme/theme_provider.dart';
import '../../server/providers/server_providers.dart';

class SidebarItem {
  final String label;
  final IconData icon;
  final String routePath;

  const SidebarItem({
    required this.label,
    required this.icon,
    required this.routePath,
  });
}

final sidebarItems = [
  const SidebarItem(
    label: 'Console',
    icon: LucideIcons.terminal,
    routePath: '/console',
  ),
  const SidebarItem(
    label: 'Network',
    icon: LucideIcons.globe,
    routePath: '/network',
  ),
  const SidebarItem(
    label: 'State',
    icon: LucideIcons.layers,
    routePath: '/state',
  ),
  const SidebarItem(
    label: 'Storage',
    icon: LucideIcons.database,
    routePath: '/storage',
  ),
  const SidebarItem(
    label: 'Database',
    icon: LucideIcons.hardDrive,
    routePath: '/database',
  ),
  const SidebarItem(
    label: 'Settings',
    icon: LucideIcons.settings,
    routePath: '/settings',
  ),
];

class Sidebar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final devices = ref.watch(connectedDevicesProvider);

    return Container(
      width: 68,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF),
        border: Border(
          right: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [ColorTokens.primary, ColorTokens.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'DC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Connection indicator
          _ConnectionBadge(deviceCount: devices.length),
          const SizedBox(height: 16),
          const Divider(height: 1, indent: 12, endIndent: 12),
          const SizedBox(height: 8),
          // Navigation items
          Expanded(
            child: ListView.builder(
              itemCount: sidebarItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final item = sidebarItems[index];
                final isSelected = index == selectedIndex;
                return _SidebarButton(
                  icon: item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  onTap: () => onItemSelected(index),
                );
              },
            ),
          ),
          // Theme toggle
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _SidebarButton(
              icon: isDark ? LucideIcons.sun : LucideIcons.moon,
              label: isDark ? 'Light' : 'Dark',
              isSelected: false,
              onTap: () => ref.read(themeModeProvider.notifier).toggle(),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarButton> createState() => _SidebarButtonState();
}

class _SidebarButtonState extends State<_SidebarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bgColor;
    if (widget.isSelected) {
      bgColor = ColorTokens.primary.withValues(alpha: 0.15);
    } else if (_isHovered) {
      bgColor = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.04);
    } else {
      bgColor = Colors.transparent;
    }

    final iconColor = widget.isSelected
        ? ColorTokens.primary
        : isDark
            ? const Color(0xFF8B949E)
            : const Color(0xFF656D76);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52,
            height: 46,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: widget.isSelected
                  ? Border.all(
                      color: ColorTokens.primary.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 20, color: iconColor),
                const SizedBox(height: 2),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final int deviceCount;

  const _ConnectionBadge({required this.deviceCount});

  @override
  Widget build(BuildContext context) {
    final isConnected = deviceCount > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isConnected
            ? ColorTokens.success.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isConnected ? ColorTokens.success : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            '$deviceCount',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isConnected ? ColorTokens.success : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
