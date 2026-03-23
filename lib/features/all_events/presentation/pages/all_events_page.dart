import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../components/feedback/empty_state.dart';
import '../../../../components/inputs/search_field.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../server/providers/server_providers.dart';
import '../../provider/all_events_provider.dart';

class AllEventsPage extends ConsumerStatefulWidget {
  const AllEventsPage({super.key});

  @override
  ConsumerState<AllEventsPage> createState() => _AllEventsPageState();
}

class _AllEventsPageState extends ConsumerState<AllEventsPage> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(filteredAllEventsProvider);
    final devices = ref.watch(connectedDevicesProvider);
    final server = ref.watch(wsServerProvider);
    return Column(
      children: [
        // Toolbar
        _Toolbar(
          eventCount: events.length,
          deviceCount: devices.length,
          serverRunning: server.isRunning,
          port: server.isRunning ? server.port : 9090,
        ),
        const Divider(height: 1),
        // Stats bar
        _StatsBar(events: ref.watch(allEventsProvider)),
        const Divider(height: 1),
        // Event list
        Expanded(
          child: events.isEmpty
              ? EmptyState(
                  icon: LucideIcons.layoutDashboard,
                  title: devices.isEmpty
                      ? 'No devices connected'
                      : 'No events yet',
                  subtitle: devices.isEmpty
                      ? 'Open DevConnect desktop, then init SDK in your app'
                      : 'Events will appear here in real-time',
                )
              : ListView.builder(
                  controller: _scrollController,
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return _EventTile(event: event);
                  },
                ),
        ),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  final int eventCount;
  final int deviceCount;
  final bool serverRunning;
  final int port;

  const _Toolbar({
    required this.eventCount,
    required this.deviceCount,
    required this.serverRunning,
    required this.port,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeFilters = ref.watch(allEventsFilterProvider);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.layoutDashboard,
              size: 16, color: ColorTokens.primary),
          const SizedBox(width: 8),
          Text('All Events', style: theme.textTheme.titleMedium),
          const SizedBox(width: 8),
          Text('$eventCount total', style: theme.textTheme.bodySmall),
          const SizedBox(width: 12),
          // Server status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: serverRunning
                  ? ColorTokens.success.withValues(alpha: 0.1)
                  : ColorTokens.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color:
                        serverRunning ? ColorTokens.success : ColorTokens.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  serverRunning ? 'Port $port' : 'Stopped',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: serverRunning
                        ? ColorTokens.success
                        : ColorTokens.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Device count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ColorTokens.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$deviceCount device${deviceCount != 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: ColorTokens.info,
              ),
            ),
          ),
          const Spacer(),
          // Type filters
          _TypeFilterChip(
            label: 'LOG',
            icon: LucideIcons.terminal,
            color: ColorTokens.logInfo,
            isActive: activeFilters.contains(EventType.log),
            onTap: () => _toggleFilter(ref, EventType.log),
          ),
          const SizedBox(width: 4),
          _TypeFilterChip(
            label: 'API',
            icon: LucideIcons.globe,
            color: ColorTokens.success,
            isActive: activeFilters.contains(EventType.network),
            onTap: () => _toggleFilter(ref, EventType.network),
          ),
          const SizedBox(width: 4),
          _TypeFilterChip(
            label: 'STATE',
            icon: LucideIcons.layers,
            color: ColorTokens.secondary,
            isActive: activeFilters.contains(EventType.state),
            onTap: () => _toggleFilter(ref, EventType.state),
          ),
          const SizedBox(width: 4),
          _TypeFilterChip(
            label: 'STORE',
            icon: LucideIcons.database,
            color: ColorTokens.warning,
            isActive: activeFilters.contains(EventType.storage),
            onTap: () => _toggleFilter(ref, EventType.storage),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: SearchField(
              hintText: 'Search all...',
              onChanged: (v) =>
                  ref.read(allEventsSearchProvider.notifier).state = v,
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFilter(WidgetRef ref, EventType type) {
    final current = ref.read(allEventsFilterProvider);
    if (current.contains(type)) {
      ref.read(allEventsFilterProvider.notifier).state =
          current.difference({type});
    } else {
      ref.read(allEventsFilterProvider.notifier).state = {...current, type};
    }
  }
}

class _TypeFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _TypeFilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.4)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 10, color: isActive ? color : Colors.grey),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: isActive ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final List<UnifiedEvent> events;

  const _StatsBar({required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final logCount = events.where((e) => e.type == EventType.log).length;
    final netCount = events.where((e) => e.type == EventType.network).length;
    final stateCount = events.where((e) => e.type == EventType.state).length;
    final storeCount = events.where((e) => e.type == EventType.storage).length;
    final errorCount = events.where((e) => e.level == 'error').length;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      child: Row(
        children: [
          _StatItem('Logs', logCount, ColorTokens.logInfo),
          const SizedBox(width: 16),
          _StatItem('API', netCount, ColorTokens.success),
          const SizedBox(width: 16),
          _StatItem('State', stateCount, ColorTokens.secondary),
          const SizedBox(width: 16),
          _StatItem('Storage', storeCount, ColorTokens.warning),
          const SizedBox(width: 16),
          if (errorCount > 0)
            _StatItem('Errors', errorCount, ColorTokens.error),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatItem(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $count',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final UnifiedEvent event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final time = DateFormat('HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(event.timestamp),
    );

    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    switch (event.type) {
      case EventType.log:
        typeColor = _logLevelColor(event.level);
        typeIcon = LucideIcons.terminal;
        typeLabel = event.level.toUpperCase();
        break;
      case EventType.network:
        typeColor = ColorTokens.success;
        typeIcon = LucideIcons.globe;
        typeLabel = 'API';
        break;
      case EventType.state:
        typeColor = ColorTokens.secondary;
        typeIcon = LucideIcons.layers;
        typeLabel = 'STATE';
        break;
      case EventType.storage:
        typeColor = ColorTokens.warning;
        typeIcon = LucideIcons.database;
        typeLabel = 'STORE';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
          left: BorderSide(
            color: typeColor,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          // Timestamp
          Text(
            time,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(width: 8),
          // Type badge
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(typeIcon, size: 9, color: typeColor),
                const SizedBox(width: 2),
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: typeColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Platform badge (from deviceId -> lookup device)
          _PlatformTag(deviceId: event.deviceId),
          const SizedBox(width: 8),
          // Title
          Expanded(
            child: Text(
              event.title,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                color: event.level == 'error'
                    ? ColorTokens.error
                    : isDark
                        ? const Color(0xFFE6EDF3)
                        : const Color(0xFF1F2328),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Subtitle
          Text(
            event.subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Color _logLevelColor(String level) {
    switch (level) {
      case 'debug':
        return ColorTokens.logDebug;
      case 'info':
        return ColorTokens.logInfo;
      case 'warn':
        return ColorTokens.logWarn;
      case 'error':
        return ColorTokens.logError;
      default:
        return ColorTokens.logInfo;
    }
  }
}

class _PlatformTag extends ConsumerWidget {
  final String deviceId;

  const _PlatformTag({required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(connectedDevicesProvider);
    final device = devices.where((d) => d.deviceId == deviceId).firstOrNull;

    if (device == null) return const SizedBox.shrink();

    Color color;
    String label;
    switch (device.platform.toLowerCase()) {
      case 'flutter':
        color = const Color(0xFF02569B);
        label = 'Flutter';
        break;
      case 'react_native':
      case 'reactnative':
        color = const Color(0xFF61DAFB);
        label = 'RN';
        break;
      case 'android':
        color = const Color(0xFF3DDC84);
        label = 'Android';
        break;
      default:
        color = Colors.grey;
        label = device.platform;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
