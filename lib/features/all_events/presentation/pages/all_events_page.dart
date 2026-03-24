import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../components/feedback/empty_state.dart';
import '../../../../components/inputs/search_field.dart';
import '../../../../components/misc/status_badge.dart';
import '../../../../components/viewers/json_viewer.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../models/log/log_entry.dart';
import '../../../../models/network/network_entry.dart';
import '../../../../models/state/state_change.dart';
import '../../../../models/storage/storage_entry.dart';
import '../../../../server/providers/server_providers.dart';
import '../../provider/all_events_provider.dart';

class AllEventsPage extends ConsumerStatefulWidget {
  const AllEventsPage({super.key});

  @override
  ConsumerState<AllEventsPage> createState() => _AllEventsPageState();
}

class _AllEventsPageState extends ConsumerState<AllEventsPage> {
  final _scrollController = ScrollController();
  UnifiedEvent? _selectedEvent;
  bool _autoScroll = true;
  int _maxVisible = _pageSize;
  bool _loadingMore = false;
  int _previousCount = 0;

  static const _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_autoScroll &&
        !_loadingMore &&
        _scrollController.hasClients &&
        _scrollController.position.pixels < 50) {
      _loadMore();
    }
  }

  void _loadMore() {
    final totalCount = ref.read(filteredAllEventsProvider).length;
    if (_maxVisible >= totalCount) return;

    _loadingMore = true;
    final oldMaxExtent = _scrollController.position.maxScrollExtent;

    setState(() {
      _maxVisible = (_maxVisible + _pageSize).clamp(0, totalCount);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final newMaxExtent = _scrollController.position.maxScrollExtent;
        _scrollController
            .jumpTo(_scrollController.position.pixels + (newMaxExtent - oldMaxExtent));
      }
      _loadingMore = false;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _toggleAutoScroll() {
    setState(() {
      _autoScroll = !_autoScroll;
      if (_autoScroll) {
        _maxVisible = _pageSize;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(filteredAllEventsProvider);
    final devices = ref.watch(connectedDevicesProvider);
    final server = ref.watch(wsServerProvider);
    final theme = Theme.of(context);

    // Slice visible items
    final startIndex = (allEvents.length - _maxVisible).clamp(0, allEvents.length);
    final visibleEvents = allEvents.sublist(startIndex);
    final hasMore = startIndex > 0;

    // Auto-scroll on new items
    if (_autoScroll && allEvents.length > _previousCount && allEvents.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    _previousCount = allEvents.length;

    // Clear selection if selected event is no longer in visible list
    if (_selectedEvent != null &&
        !allEvents.any((e) => e.id == _selectedEvent!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedEvent = null);
      });
    }

    return Column(
      children: [
        _Toolbar(
          eventCount: allEvents.length,
          visibleCount: visibleEvents.length,
          deviceCount: devices.length,
          serverRunning: server.isRunning,
          port: server.isRunning ? server.port : 9090,
          autoScroll: _autoScroll,
          onToggleAutoScroll: _toggleAutoScroll,
        ),
        const Divider(height: 1),
        _StatsBar(events: allEvents),
        const Divider(height: 1),
        Expanded(
          child: visibleEvents.isEmpty
              ? EmptyState(
                  icon: LucideIcons.layoutDashboard,
                  title: devices.isEmpty
                      ? 'No devices connected'
                      : 'No events yet',
                  subtitle: devices.isEmpty
                      ? 'Start your app with DevConnect SDK to see events'
                      : 'Events will appear here in real-time',
                )
              : Row(
                  children: [
                    // Event list
                    Expanded(
                      flex: _selectedEvent != null ? 4 : 1,
                      child: Column(
                        children: [
                          if (hasMore && !_autoScroll)
                            GestureDetector(
                              onTap: _loadMore,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  color: ColorTokens.primary.withValues(alpha: 0.05),
                                  child: Center(
                                    child: Text(
                                      '${allEvents.length - visibleEvents.length} older events — tap to load more',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: ColorTokens.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: visibleEvents.length,
                              itemBuilder: (context, index) {
                                final event = visibleEvents[index];
                                final isSelected =
                                    _selectedEvent?.id == event.id;
                                return _EventTile(
                                  event: event,
                                  isSelected: isSelected,
                                  onTap: () {
                                    setState(() {
                                      _selectedEvent =
                                          isSelected ? null : event;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Detail panel
                    if (_selectedEvent != null) ...[
                      VerticalDivider(
                          width: 1, color: theme.dividerColor),
                      Expanded(
                        flex: 5,
                        child: _EventDetailPanel(
                          event: _selectedEvent!,
                          onClose: () =>
                              setState(() => _selectedEvent = null),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Toolbar
// ──────────────────────────────────────────────

class _Toolbar extends ConsumerWidget {
  final int eventCount;
  final int visibleCount;
  final int deviceCount;
  final bool serverRunning;
  final int port;
  final bool autoScroll;
  final VoidCallback onToggleAutoScroll;

  const _Toolbar({
    required this.eventCount,
    required this.visibleCount,
    required this.deviceCount,
    required this.serverRunning,
    required this.port,
    required this.autoScroll,
    required this.onToggleAutoScroll,
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
          Text('All Events',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          // Event count chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: ColorTokens.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              visibleCount < eventCount
                  ? '$visibleCount / $eventCount'
                  : '$eventCount',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorTokens.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Server status
          _StatusPill(
            color: serverRunning ? ColorTokens.success : ColorTokens.error,
            label: serverRunning ? 'Port $port' : 'Stopped',
          ),
          const SizedBox(width: 8),
          _StatusPill(
            color: ColorTokens.info,
            label: '$deviceCount device${deviceCount != 1 ? 's' : ''}',
          ),
          const Spacer(),
          // Type filter chips
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
          _TypeFilterChip(
            label: 'AUTO',
            icon: LucideIcons.arrowDownToLine,
            color: ColorTokens.primary,
            isActive: autoScroll,
            onTap: onToggleAutoScroll,
          ),
          const SizedBox(width: 8),
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

class _StatusPill extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.4)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: isActive ? color : Colors.grey),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isActive ? color : Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Stats Bar (now uses filtered events)
// ──────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final List<UnifiedEvent> events;

  const _StatsBar({required this.events});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final logCount = events.where((e) => e.type == EventType.log).length;
    final netCount = events.where((e) => e.type == EventType.network).length;
    final stateCount = events.where((e) => e.type == EventType.state).length;
    final storeCount = events.where((e) => e.type == EventType.storage).length;
    final errorCount = events.where((e) => e.level == 'error').length;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      child: Row(
        children: [
          _StatChip('Logs', logCount, ColorTokens.logInfo, LucideIcons.terminal),
          const SizedBox(width: 12),
          _StatChip('API', netCount, ColorTokens.success, LucideIcons.globe),
          const SizedBox(width: 12),
          _StatChip(
              'State', stateCount, ColorTokens.secondary, LucideIcons.layers),
          const SizedBox(width: 12),
          _StatChip(
              'Storage', storeCount, ColorTokens.warning, LucideIcons.database),
          if (errorCount > 0) ...[
            const SizedBox(width: 12),
            _StatChip('Errors', errorCount, ColorTokens.error,
                LucideIcons.triangleAlert),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatChip(this.label, this.count, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Event Tile (redesigned)
// ──────────────────────────────────────────────

class _EventTile extends ConsumerWidget {
  final UnifiedEvent event;
  final bool isSelected;
  final VoidCallback onTap;

  const _EventTile({
    required this.event,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final time = DateFormat('HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(event.timestamp),
    );

    final typeInfo = _getTypeInfo(event);
    final devices = ref.watch(connectedDevicesProvider);
    final device =
        devices.where((d) => d.deviceId == event.deviceId).firstOrNull;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? ColorTokens.primary.withValues(alpha: 0.06)
                : isDark
                    ? Colors.transparent
                    : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              left: BorderSide(
                color: isSelected ? ColorTokens.primary : typeInfo.color,
                width: isSelected ? 3 : 2,
              ),
            ),
          ),
          child: Row(
            children: [
              // Timestamp
              SizedBox(
                width: 88,
                child: Text(
                  time,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    color: Colors.grey[500],
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              // Type badge
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: typeInfo.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(typeInfo.icon, size: 10, color: typeInfo.color),
                    const SizedBox(width: 3),
                    Text(
                      typeInfo.label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: typeInfo.color,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Platform badge
              if (device != null) ...[
                PlatformBadge(platform: device.platform),
                const SizedBox(width: 8),
              ],
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
              const SizedBox(width: 10),
              // Subtitle
              Text(
                event.subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                  fontFamily: 'JetBrains Mono',
                ),
              ),
              // Chevron indicator
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.chevronRight,
                    size: 12, color: ColorTokens.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _TypeInfo _getTypeInfo(UnifiedEvent event) {
    switch (event.type) {
      case EventType.log:
        return _TypeInfo(
          color: _logLevelColor(event.level),
          icon: LucideIcons.terminal,
          label: event.level.toUpperCase(),
        );
      case EventType.network:
        return _TypeInfo(
          color: ColorTokens.success,
          icon: LucideIcons.globe,
          label: 'API',
        );
      case EventType.state:
        return _TypeInfo(
          color: ColorTokens.secondary,
          icon: LucideIcons.layers,
          label: 'STATE',
        );
      case EventType.storage:
        return _TypeInfo(
          color: ColorTokens.warning,
          icon: LucideIcons.database,
          label: 'STORE',
        );
    }
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

class _TypeInfo {
  final Color color;
  final IconData icon;
  final String label;

  _TypeInfo({required this.color, required this.icon, required this.label});
}

// ──────────────────────────────────────────────
// Detail Panel (routes to correct detail view)
// ──────────────────────────────────────────────

class _EventDetailPanel extends StatelessWidget {
  final UnifiedEvent event;
  final VoidCallback onClose;

  const _EventDetailPanel({required this.event, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      child: Column(
        children: [
          // Detail header
          _DetailHeader(event: event, onClose: onClose),
          const Divider(height: 1),
          // Detail content based on type
          Expanded(child: _buildDetailContent()),
        ],
      ),
    );
  }

  Widget _buildDetailContent() {
    final rawData = event.rawData;

    switch (event.type) {
      case EventType.log:
        if (rawData is LogEntry) {
          return _LogDetailContent(entry: rawData);
        }
        return _FallbackDetail(event: event);

      case EventType.network:
        if (rawData is NetworkEntry) {
          return _NetworkDetailContent(entry: rawData);
        }
        return _FallbackDetail(event: event);

      case EventType.state:
        if (rawData is StateChange) {
          return _StateDetailContent(entry: rawData);
        }
        return _FallbackDetail(event: event);

      case EventType.storage:
        if (rawData is StorageEntry) {
          return _StorageDetailContent(entry: rawData);
        }
        return _FallbackDetail(event: event);
    }
  }
}

class _DetailHeader extends ConsumerWidget {
  final UnifiedEvent event;
  final VoidCallback onClose;

  const _DetailHeader({required this.event, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time = DateFormat('HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(event.timestamp),
    );

    final devices = ref.watch(connectedDevicesProvider);
    final device =
        devices.where((d) => d.deviceId == event.deviceId).firstOrNull;

    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    switch (event.type) {
      case EventType.log:
        typeColor = ColorTokens.logInfo;
        typeIcon = LucideIcons.terminal;
        typeLabel = 'Log Detail';
        break;
      case EventType.network:
        typeColor = ColorTokens.success;
        typeIcon = LucideIcons.globe;
        typeLabel = 'Network Detail';
        break;
      case EventType.state:
        typeColor = ColorTokens.secondary;
        typeIcon = LucideIcons.layers;
        typeLabel = 'State Detail';
        break;
      case EventType.storage:
        typeColor = ColorTokens.warning;
        typeIcon = LucideIcons.database;
        typeLabel = 'Storage Detail';
        break;
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
      ),
      child: Row(
        children: [
          Icon(typeIcon, size: 14, color: typeColor),
          const SizedBox(width: 8),
          Text(
            typeLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: typeColor,
            ),
          ),
          const SizedBox(width: 10),
          if (device != null) ...[
            PlatformBadge(platform: device.platform),
            const SizedBox(width: 8),
          ],
          Text(
            time,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey.withValues(alpha: 0.1),
                ),
                child: Icon(LucideIcons.x, size: 14, color: Colors.grey[500]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Log Detail
// ──────────────────────────────────────────────

class _LogDetailContent extends StatelessWidget {
  final LogEntry entry;

  const _LogDetailContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level + Tag + Copy
          Row(
            children: [
              LogLevelBadge(level: entry.level.name),
              if (entry.tag != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.tag!,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              _CopyButton(
                tooltip: 'Copy message',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: entry.message));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Message copied'),
                        duration: Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Message
          _SectionTitle('Message'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF161B22)
                  : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.05)),
            ),
            child: SelectableText(
              entry.message,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                color: isDark ? const Color(0xFFE6EDF3) : Colors.black87,
                height: 1.6,
              ),
            ),
          ),
          // Metadata
          if (entry.metadata != null && entry.metadata!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle('Metadata'),
            const SizedBox(height: 6),
            JsonViewer(data: entry.metadata, initiallyExpanded: true),
          ],
          // Stack trace
          if (entry.stackTrace != null) ...[
            const SizedBox(height: 16),
            _SectionTitle('Stack Trace'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorTokens.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ColorTokens.error.withValues(alpha: 0.15)),
              ),
              child: SelectableText(
                entry.stackTrace!,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: ColorTokens.error.withValues(alpha: 0.9),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Network Detail
// ──────────────────────────────────────────────

class _NetworkDetailContent extends StatelessWidget {
  final NetworkEntry entry;

  const _NetworkDetailContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // URL bar + actions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HttpMethodBadge(method: entry.method),
                    const SizedBox(width: 8),
                    if (entry.isComplete) ...[
                      StatusBadge(statusCode: entry.statusCode),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        entry.url,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          color:
                              isDark ? const Color(0xFFE6EDF3) : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _CopyButton(
                      tooltip: 'Copy URL',
                      icon: LucideIcons.link,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: entry.url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('URL copied'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    _CopyButton(
                      tooltip: 'Copy cURL',
                      icon: LucideIcons.terminal,
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: _buildCurl(entry)));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('cURL copied'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                    _CopyButton(
                      tooltip: 'Copy Response',
                      icon: LucideIcons.download,
                      onTap: () {
                        final body = entry.responseBody;
                        final text = body is String
                            ? body
                            : (body != null
                                ? const JsonEncoder.withIndent('  ')
                                    .convert(body)
                                : '');
                        Clipboard.setData(ClipboardData(text: text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Response copied'),
                              duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  ],
                ),
                if (entry.duration != null) ...[
                  const SizedBox(height: 8),
                  _TimingBar(duration: entry.duration!),
                ],
              ],
            ),
          ),
          // Tabs
          TabBar(
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            indicatorColor: ColorTokens.primary,
            tabs: const [
              Tab(text: 'Headers'),
              Tab(text: 'Request'),
              Tab(text: 'Response'),
              Tab(text: 'Timing'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _HeadersView(entry: entry),
                _BodyView(body: entry.requestBody, label: 'Request Body'),
                _BodyView(body: entry.responseBody, label: 'Response Body'),
                _TimingView(entry: entry),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildCurl(NetworkEntry entry) {
    final buf = StringBuffer("curl -X ${entry.method} '${entry.url}'");
    entry.requestHeaders.forEach((k, v) {
      buf.write(" \\\n  -H '$k: $v'");
    });
    if (entry.requestBody != null) {
      final body = entry.requestBody is String
          ? entry.requestBody as String
          : const JsonEncoder().convert(entry.requestBody);
      buf.write(" \\\n  -d '$body'");
    }
    return buf.toString();
  }
}

class _TimingBar extends StatelessWidget {
  final int duration;

  const _TimingBar({required this.duration});

  @override
  Widget build(BuildContext context) {
    final maxWidth = 250.0;
    final ratio = (duration / 2000).clamp(0.0, 1.0);

    Color barColor;
    if (duration < 200) {
      barColor = ColorTokens.success;
    } else if (duration < 500) {
      barColor = ColorTokens.warning;
    } else {
      barColor = ColorTokens.error;
    }

    return Row(
      children: [
        SizedBox(
          width: maxWidth,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: barColor.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${duration}ms',
          style: TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: barColor,
          ),
        ),
      ],
    );
  }
}

class _HeadersView extends StatelessWidget {
  final NetworkEntry entry;

  const _HeadersView({required this.entry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Request Headers'),
          const SizedBox(height: 8),
          _HeaderTable(headers: entry.requestHeaders),
          const SizedBox(height: 20),
          _SectionTitle('Response Headers'),
          const SizedBox(height: 8),
          _HeaderTable(headers: entry.responseHeaders),
        ],
      ),
    );
  }
}

class _HeaderTable extends StatelessWidget {
  final Map<String, String> headers;

  const _HeaderTable({required this.headers});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (headers.isEmpty) {
      return Text(
        'No headers',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: headers.entries.toList().asMap().entries.map((entry) {
          final e = entry.value;
          final isLast = entry.key == headers.length - 1;
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                  ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    e.key,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ColorTokens.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BodyView extends StatelessWidget {
  final dynamic body;
  final String label;

  const _BodyView({required this.body, required this.label});

  @override
  Widget build(BuildContext context) {
    if (body == null) {
      return EmptyState(
        icon: LucideIcons.fileText,
        title: 'No $label',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(label),
          const SizedBox(height: 8),
          if (body is Map || body is List)
            JsonViewer(data: body, initiallyExpanded: true)
          else
            JsonPrettyViewer(data: body),
        ],
      ),
    );
  }
}

class _TimingView extends StatelessWidget {
  final NetworkEntry entry;

  const _TimingView({required this.entry});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            'Start Time',
            DateFormat('HH:mm:ss.SSS').format(
              DateTime.fromMillisecondsSinceEpoch(entry.startTime),
            ),
          ),
          if (entry.endTime != null)
            _InfoRow(
              'End Time',
              DateFormat('HH:mm:ss.SSS').format(
                DateTime.fromMillisecondsSinceEpoch(entry.endTime!),
              ),
            ),
          if (entry.duration != null) _InfoRow('Duration', '${entry.duration}ms'),
          if (entry.error != null) ...[
            const SizedBox(height: 12),
            _SectionTitle('Error'),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorTokens.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: ColorTokens.error.withValues(alpha: 0.15)),
              ),
              child: Text(
                entry.error!,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: ColorTokens.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// State Detail
// ──────────────────────────────────────────────

class _StateDetailContent extends StatelessWidget {
  final StateChange entry;

  const _StateDetailContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ColorTokens.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.stateManagerType,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ColorTokens.secondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.actionName,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _CopyButton(
                  tooltip: 'Copy action',
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: entry.actionName));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Action copied'),
                          duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ],
            ),
          ),
          TabBar(
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            indicatorColor: ColorTokens.secondary,
            tabs: const [
              Tab(text: 'Diff'),
              Tab(text: 'Previous'),
              Tab(text: 'Next'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                // Diff
                entry.diff.isEmpty
                    ? const EmptyState(
                        icon: LucideIcons.gitCompare,
                        title: 'No diff',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: entry.diff.length,
                        itemBuilder: (context, index) {
                          final d = entry.diff[index];
                          return _DiffRow(diff: d);
                        },
                      ),
                // Previous state
                entry.previousState.isEmpty
                    ? const EmptyState(
                        icon: LucideIcons.layers,
                        title: 'No previous state',
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: JsonViewer(
                            data: entry.previousState,
                            initiallyExpanded: true),
                      ),
                // Next state
                entry.nextState.isEmpty
                    ? const EmptyState(
                        icon: LucideIcons.layers,
                        title: 'No next state',
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: JsonViewer(
                            data: entry.nextState,
                            initiallyExpanded: true),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  final StateDiffEntry diff;

  const _DiffRow({required this.diff});

  @override
  Widget build(BuildContext context) {
    Color opColor;
    IconData opIcon;
    switch (diff.operation) {
      case 'add':
        opColor = ColorTokens.success;
        opIcon = LucideIcons.plus;
        break;
      case 'remove':
        opColor = ColorTokens.error;
        opIcon = LucideIcons.minus;
        break;
      default:
        opColor = ColorTokens.warning;
        opIcon = LucideIcons.penLine;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: opColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: opColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(opIcon, size: 12, color: opColor),
              const SizedBox(width: 6),
              Text(
                diff.path,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: opColor,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: opColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  diff.operation.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: opColor,
                  ),
                ),
              ),
            ],
          ),
          if (diff.oldValue != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('- ',
                    style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: ColorTokens.error)),
                Expanded(
                  child: Text(
                    '${diff.oldValue}',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: ColorTokens.error.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (diff.newValue != null) ...[
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('+ ',
                    style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: ColorTokens.success)),
                Expanded(
                  child: Text(
                    '${diff.newValue}',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: ColorTokens.success.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Storage Detail
// ──────────────────────────────────────────────

class _StorageDetailContent extends StatelessWidget {
  final StorageEntry entry;

  const _StorageDetailContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color opColor;
    IconData opIcon;
    switch (entry.operation.toLowerCase()) {
      case 'write':
        opColor = ColorTokens.success;
        opIcon = LucideIcons.pencil;
        break;
      case 'read':
        opColor = ColorTokens.info;
        opIcon = LucideIcons.eye;
        break;
      case 'delete':
        opColor = ColorTokens.error;
        opIcon = LucideIcons.trash2;
        break;
      case 'clear':
        opColor = ColorTokens.error;
        opIcon = LucideIcons.eraser;
        break;
      default:
        opColor = ColorTokens.warning;
        opIcon = LucideIcons.database;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Operation + Type
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: opColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(opIcon, size: 12, color: opColor),
                    const SizedBox(width: 4),
                    Text(
                      entry.operation.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: opColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ColorTokens.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.storageType.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ColorTokens.warning,
                  ),
                ),
              ),
              const Spacer(),
              _CopyButton(
                tooltip: 'Copy key',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: entry.key));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Key copied'),
                        duration: Duration(seconds: 1)),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Key
          _SectionTitle('Key'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF161B22)
                  : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              entry.key,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
          // Value
          if (entry.value != null) ...[
            const SizedBox(height: 16),
            _SectionTitle('Value'),
            const SizedBox(height: 6),
            if (entry.value is Map || entry.value is List)
              JsonViewer(data: entry.value, initiallyExpanded: true)
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF161B22)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  '${entry.value}',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.5,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Fallback Detail (when rawData type doesn't match)
// ──────────────────────────────────────────────

class _FallbackDetail extends StatelessWidget {
  final UnifiedEvent event;

  const _FallbackDetail({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Title'),
          const SizedBox(height: 6),
          SelectableText(
            event.title,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _SectionTitle('Details'),
          const SizedBox(height: 6),
          SelectableText(
            event.subtitle,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              color: Colors.grey[400],
            ),
          ),
          if (event.rawData != null) ...[
            const SizedBox(height: 16),
            _SectionTitle('Raw Data'),
            const SizedBox(height: 6),
            if (event.rawData is Map || event.rawData is List)
              JsonViewer(data: event.rawData, initiallyExpanded: true)
            else
              SelectableText(
                '${event.rawData}',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Shared Widgets
// ──────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final IconData icon;

  const _CopyButton({
    required this.tooltip,
    required this.onTap,
    this.icon = LucideIcons.copy,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey.withValues(alpha: 0.08),
            ),
            child: Icon(icon, size: 13, color: Colors.grey[500]),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
