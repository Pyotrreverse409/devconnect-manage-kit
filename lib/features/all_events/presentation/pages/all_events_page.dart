import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' hide ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../components/feedback/empty_state.dart';
import '../../../../components/inputs/scroll_direction_button.dart';
import '../../../../components/inputs/search_field.dart';
import '../../../../components/misc/status_badge.dart';
import '../../../../components/viewers/json_viewer.dart';
import '../../../../core/providers/tab_visibility_provider.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../models/log/log_entry.dart';
import '../../../../models/network/network_entry.dart';
import '../../../../models/state/state_change.dart';
import '../../../../models/storage/storage_entry.dart';
import '../../../../server/providers/server_providers.dart';
import '../../../console/provider/console_providers.dart';
import '../../../network_inspector/provider/network_providers.dart';
import '../../../state_inspector/provider/state_providers.dart';
import '../../../storage_viewer/provider/storage_providers.dart';
import '../../provider/all_events_provider.dart';

// ═══════════════════════════════════════════════
// All Events Page
// ═══════════════════════════════════════════════

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

  static const _pageSize = 80;

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
    if (_loadingMore || !_scrollController.hasClients) return;

    final pos = _scrollController.position;
    final scrollDir = ref.read(scrollDirectionProvider);

    if (scrollDir == ScrollDirection.bottom) {
      // Bottom mode: newest at bottom → scroll UP to load older items
      if (pos.pixels < 50) _loadMore();
    } else {
      // Top mode: newest at top → scroll DOWN to load older items
      if (pos.pixels > pos.maxScrollExtent - 50) _loadMore();
    }
  }

  void _loadMore() {
    final totalCount = ref.read(filteredAllEventsProvider).length;
    if (_maxVisible >= totalCount) return;

    _loadingMore = true;
    final scrollDir = ref.read(scrollDirectionProvider);
    final oldMaxExtent = _scrollController.position.maxScrollExtent;

    setState(() {
      _maxVisible = (_maxVisible + _pageSize).clamp(0, totalCount);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && scrollDir == ScrollDirection.bottom) {
        // Keep scroll position stable when prepending items at the top
        final newMaxExtent = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(
          _scrollController.position.pixels + (newMaxExtent - oldMaxExtent),
        );
      }
      _loadingMore = false;
    });
  }

  void _scrollToTarget() {
    if (_scrollController.hasClients) {
      final scrollDir = ref.read(scrollDirectionProvider);
      final target = scrollDir == ScrollDirection.top
          ? 0.0
          : _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        target,
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
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToTarget());
      }
    });
  }

  void _clearAll() {
    ref.read(consoleEntriesProvider.notifier).clear();
    ref.read(networkEntriesProvider.notifier).clear();
    ref.read(stateChangesProvider.notifier).clear();
    ref.read(storageEntriesProvider.notifier).clear();
    setState(() {
      _selectedEvent = null;
      _maxVisible = _pageSize;
      _previousCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(filteredAllEventsProvider);
    final devices = ref.watch(connectedDevicesProvider);
    final server = ref.watch(wsServerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Reset pagination when scroll direction changes
    final scrollDir = ref.watch(scrollDirectionProvider);
    ref.listen<ScrollDirection>(scrollDirectionProvider, (prev, next) {
      if (prev != next) {
        setState(() => _maxVisible = _pageSize);
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToTarget());
      }
    });

    // Slice visible items based on scroll direction
    final List<UnifiedEvent> visibleEvents;
    final bool hasMore;

    if (scrollDir == ScrollDirection.bottom) {
      // Bottom mode: oldest first, show last _maxVisible items
      final startIndex =
          (allEvents.length - _maxVisible).clamp(0, allEvents.length);
      visibleEvents = allEvents.sublist(startIndex);
      hasMore = startIndex > 0;
    } else {
      // Top mode: newest first, reverse and show first _maxVisible items
      final reversed = allEvents.reversed.toList();
      visibleEvents = reversed.take(_maxVisible).toList();
      hasMore = allEvents.length > _maxVisible;
    }

    // Auto-scroll on new items
    if (_autoScroll &&
        allEvents.length > _previousCount &&
        allEvents.isNotEmpty) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToTarget());
    }
    _previousCount = allEvents.length;

    // Clear selection if event removed
    if (_selectedEvent != null &&
        !allEvents.any((e) => e.id == _selectedEvent!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedEvent = null);
      });
    }

    return Column(
      children: [
        // ── Header ──
        _Header(
          eventCount: allEvents.length,
          deviceCount: devices.length,
          serverRunning: server.isRunning,
          port: server.isRunning ? server.port : 9090,
          autoScroll: _autoScroll,
          onToggleAutoScroll: _toggleAutoScroll,
          onClear: _clearAll,
        ),
        // ── Stats + Filters ──
        _FilterBar(events: allEvents),
        // ── Content ──
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
                    // ── Event List ──
                    Expanded(
                      flex: _selectedEvent != null ? 4 : 1,
                      child: Column(
                        children: [
                          if (hasMore && scrollDir == ScrollDirection.bottom)
                            _LoadMoreBanner(
                              count: allEvents.length -
                                  visibleEvents.length,
                              onTap: _loadMore,
                            ),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: visibleEvents.length,
                              itemExtent: 44,
                              itemBuilder: (context, index) {
                                final event = visibleEvents[index];
                                final isSelected =
                                    _selectedEvent?.id == event.id;
                                final device = devices
                                    .where(
                                        (d) => d.deviceId == event.deviceId)
                                    .firstOrNull;
                                return _EventRow(
                                  key: ValueKey(event.id),
                                  event: event,
                                  isSelected: isSelected,
                                  showDetail: _selectedEvent != null,
                                  platform: device?.platform,
                                  onTap: () {
                                    setState(() {
                                      _selectedEvent =
                                          isSelected ? null : event;
                                    });
                                  },
                                  onCopyTitle: () =>
                                      _copy(context, event.title),
                                );
                              },
                            ),
                          ),
                          if (hasMore && scrollDir == ScrollDirection.top)
                            _LoadMoreBanner(
                              count: allEvents.length -
                                  visibleEvents.length,
                              onTap: _loadMore,
                            ),
                        ],
                      ),
                    ),
                    // ── Detail Panel ──
                    if (_selectedEvent != null) ...[
                      VerticalDivider(
                        width: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.08),
                      ),
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

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied'),
        duration: Duration(milliseconds: 800),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Header
// ═══════════════════════════════════════════════

class _Header extends ConsumerWidget {
  final int eventCount;
  final int deviceCount;
  final bool serverRunning;
  final int port;
  final bool autoScroll;
  final VoidCallback onToggleAutoScroll;
  final VoidCallback onClear;

  const _Header({
    required this.eventCount,
    required this.deviceCount,
    required this.serverRunning,
    required this.port,
    required this.autoScroll,
    required this.onToggleAutoScroll,
    required this.onClear,
  });

  List<Widget> _buildDeviceChips(WidgetRef ref) {
    final devices = ref.watch(connectedDevicesProvider);
    if (devices.isEmpty) return [];
    return devices.map((d) {
      final label = d.deviceName != d.osVersion
          ? '${d.deviceName} · ${d.osVersion}'
          : d.osVersion;
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _StatusPill(
          color: const Color(0xFF8B5CF6),
          label: '${d.appName} — $label',
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;
          return Row(
            children: [
              // Title
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF8B7EF0)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.activity, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                'All Events',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 10),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ColorTokens.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$eventCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.primary,
                  ),
                ),
              ),
              if (!isNarrow) ...[
                const SizedBox(width: 12),
                // Status pills
                _StatusPill(
                  color: serverRunning ? ColorTokens.success : ColorTokens.error,
                  label: serverRunning ? 'Port $port' : 'Stopped',
                ),
                const SizedBox(width: 8),
                _StatusPill(
                  color: deviceCount > 0 ? ColorTokens.info : Colors.grey,
                  label: '$deviceCount device${deviceCount != 1 ? 's' : ''}',
                ),
                // Show connected device info
                ..._buildDeviceChips(ref),
              ],

              const Spacer(),

              // Auto-scroll toggle
              _ToolbarButton(
                icon: LucideIcons.arrowDownToLine,
                label: 'AUTO',
                isActive: autoScroll,
                color: ColorTokens.primary,
                onTap: onToggleAutoScroll,
              ),
              const SizedBox(width: 6),
              const ScrollDirectionButton(),
              const SizedBox(width: 8),
              // Search
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isNarrow ? 140 : 220,
                ),
                child: SearchField(
                  hintText: 'Search events...',
                  onChanged: (v) =>
                      ref.read(allEventsSearchProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 8),
              // Clear all
              GestureDetector(
                onTap: onClear,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    message: 'Clear all events',
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: Colors.grey.withValues(alpha: 0.08),
                      ),
                      child: Icon(LucideIcons.trash2,
                          size: 16, color: Colors.grey[500]),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Filter Bar
// ═══════════════════════════════════════════════

class _FilterBar extends ConsumerWidget {
  final List<UnifiedEvent> events;

  const _FilterBar({required this.events});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeFilters = ref.watch(allEventsFilterProvider);
    final enabledTabs = ref.watch(tabVisibilityProvider);

    final logCount = events.where((e) => e.type == EventType.log).length;
    final netCount = events.where((e) => e.type == EventType.network).length;
    final stateCount = events.where((e) => e.type == EventType.state).length;
    final storeCount = events.where((e) => e.type == EventType.storage).length;
    final errorCount = events.where((e) => e.level == 'error').length;

    // Only show filter chips for enabled tabs
    final chips = <Widget>[];
    if (enabledTabs.contains(TabKey.console)) {
      chips.add(_FilterChip(
        label: 'LOG',
        count: logCount,
        icon: LucideIcons.terminal,
        color: ColorTokens.logInfo,
        isActive: activeFilters.contains(EventType.log),
        onTap: () => _toggle(ref, EventType.log),
      ));
    }
    if (enabledTabs.contains(TabKey.network)) {
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 8));
      chips.add(_FilterChip(
        label: 'API',
        count: netCount,
        icon: LucideIcons.globe,
        color: ColorTokens.success,
        isActive: activeFilters.contains(EventType.network),
        onTap: () => _toggle(ref, EventType.network),
      ));
    }
    if (enabledTabs.contains(TabKey.state)) {
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 8));
      chips.add(_FilterChip(
        label: 'STATE',
        count: stateCount,
        icon: LucideIcons.layers,
        color: ColorTokens.secondary,
        isActive: activeFilters.contains(EventType.state),
        onTap: () => _toggle(ref, EventType.state),
      ));
    }
    if (enabledTabs.contains(TabKey.storage)) {
      if (chips.isNotEmpty) chips.add(const SizedBox(width: 8));
      chips.add(_FilterChip(
        label: 'STORE',
        count: storeCount,
        icon: LucideIcons.database,
        color: ColorTokens.warning,
        isActive: activeFilters.contains(EventType.storage),
        onTap: () => _toggle(ref, EventType.storage),
      ));
    }

    final visibleFilterCount =
        activeFilters.where((t) {
          final tabKey = _eventToTab(t);
          return tabKey == null || enabledTabs.contains(tabKey);
        }).length;
    final totalVisible = enabledTabs.length.clamp(0, EventType.values.length);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          ...chips,
          if (errorCount > 0) ...[
            const SizedBox(width: 10),
            Container(
              width: 1,
              height: 18,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
            const SizedBox(width: 10),
            _FilterChip(
              label: 'ERRORS',
              count: errorCount,
              icon: LucideIcons.triangleAlert,
              color: ColorTokens.error,
              isActive: true,
              onTap: () {},
            ),
          ],
          const Spacer(),
          Text(
            '$visibleFilterCount/$totalVisible filters',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  TabKey? _eventToTab(EventType type) {
    switch (type) {
      case EventType.log:
        return TabKey.console;
      case EventType.network:
        return TabKey.network;
      case EventType.state:
        return TabKey.state;
      case EventType.storage:
        return TabKey.storage;
    }
  }

  void _toggle(WidgetRef ref, EventType type) {
    final current = ref.read(allEventsFilterProvider);
    if (current.contains(type)) {
      ref.read(allEventsFilterProvider.notifier).state =
          current.difference({type});
    } else {
      ref.read(allEventsFilterProvider.notifier).state = {...current, type};
    }
  }
}

// ═══════════════════════════════════════════════
// Event Row (optimized: fixed height, minimal rebuild)
// ═══════════════════════════════════════════════

class _EventRow extends StatelessWidget {
  final UnifiedEvent event;
  final bool isSelected;
  final bool showDetail;
  final String? platform;
  final VoidCallback onTap;
  final VoidCallback onCopyTitle;

  const _EventRow({
    super.key,
    required this.event,
    required this.isSelected,
    required this.showDetail,
    this.platform,
    required this.onTap,
    required this.onCopyTitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time = DateFormat('HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(event.timestamp),
    );

    final typeInfo = _typeInfo(event);

    final bgColor = isSelected
        ? ColorTokens.primary.withValues(alpha: 0.08)
        : isDark
            ? Colors.transparent
            : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.04),
              ),
              left: BorderSide(
                color: isSelected ? ColorTokens.primary : typeInfo.color,
                width: isSelected ? 3 : 2,
              ),
            ),
          ),
          child: Row(
            children: [
              // Time
              SizedBox(
                width: 84,
                child: Text(
                  time,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    color: Colors.grey[500],
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              // Type badge
              Container(
                width: 56,
                height: 22,
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
              if (platform != null) ...[
                PlatformBadge(platform: platform!),
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
              const SizedBox(width: 8),
              // Subtitle
              if (!showDetail)
                Text(
                  event.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                    fontFamily: 'JetBrains Mono',
                  ),
                ),
              // Copy button (only visible on hover would be ideal,
              // but for desktop quick-access is better)
              const SizedBox(width: 4),
              _MiniIconButton(
                icon: LucideIcons.copy,
                tooltip: 'Copy',
                onTap: onCopyTitle,
              ),
              if (isSelected) ...[
                const SizedBox(width: 2),
                Icon(LucideIcons.chevronRight,
                    size: 12, color: ColorTokens.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static _TypeInfo _typeInfo(UnifiedEvent event) {
    switch (event.type) {
      case EventType.log:
        return _TypeInfo(
          color: _logColor(event.level),
          icon: LucideIcons.terminal,
          label: event.level.toUpperCase(),
        );
      case EventType.network:
        return _TypeInfo(
          color: event.level == 'error'
              ? ColorTokens.error
              : ColorTokens.success,
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

  static Color _logColor(String level) {
    switch (level) {
      case 'debug':
        return ColorTokens.logDebug;
      case 'warn':
        return ColorTokens.logWarn;
      case 'error':
        return ColorTokens.logError;
      default:
        return ColorTokens.logInfo;
    }
  }
}

// ═══════════════════════════════════════════════
// Small UI Components
// ═══════════════════════════════════════════════

class _TypeInfo {
  final Color color;
  final IconData icon;
  final String label;
  _TypeInfo({required this.color, required this.icon, required this.label});
}

class _StatusPill extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableButton(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14, color: isActive ? color : Colors.grey[500]),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? color : Colors.grey[500],
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

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableButton(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? color.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 13,
                  color: isActive ? color : Colors.grey[600]),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? color : Colors.grey[600],
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isActive
                      ? color.withValues(alpha: 0.7)
                      : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
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
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey.withValues(alpha: 0.06),
            ),
            child: Icon(icon, size: 11, color: Colors.grey[500]),
          ),
        ),
      ),
    );
  }
}

class _LoadMoreBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _LoadMoreBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: ColorTokens.primary.withValues(alpha: 0.04),
          child: Center(
            child: Text(
              '$count older events — click to load more',
              style: const TextStyle(
                fontSize: 10,
                color: ColorTokens.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Detail Panel
// ═══════════════════════════════════════════════

class _EventDetailPanel extends StatefulWidget {
  final UnifiedEvent event;
  final VoidCallback onClose;

  const _EventDetailPanel({required this.event, required this.onClose});

  @override
  State<_EventDetailPanel> createState() => _EventDetailPanelState();
}

class _EventDetailPanelState extends State<_EventDetailPanel> {
  int _currentTabIndex = 0;
  bool _currentJsonMode = false;

  Future<void> _captureAndSave(Widget screenshotWidget) async {
    try {
      // Show capture flash animation
      _showCaptureFlash();

      final overlayKey = GlobalKey();
      final theme = Theme.of(context);

      late OverlayEntry overlayEntry;
      overlayEntry = OverlayEntry(
        builder: (_) => Positioned(
          left: -10000,
          top: 0,
          child: RepaintBoundary(
            key: overlayKey,
            child: Theme(
              data: theme,
              child: Material(
                child: SizedBox(
                  width: 600,
                  child: screenshotWidget,
                ),
              ),
            ),
          ),
        ),
      );

      Overlay.of(context).insert(overlayEntry);
      await Future.delayed(const Duration(milliseconds: 300));

      final boundary = overlayKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        overlayEntry.remove();
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      overlayEntry.remove();

      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

      final fileName =
          'devconnect_${DateTime.now().millisecondsSinceEpoch}.png';
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'PNG Image', extensions: ['png']),
        ],
      );

      if (location == null) return;

      final file = File(location.path);
      await file.writeAsBytes(pngBytes);

      if (mounted) _showSavedToast(file.path);
    } catch (e) {
      if (mounted) _showErrorToast('$e');
    }
  }

  void _showCaptureFlash() {
    final overlay = Overlay.of(context);
    late OverlayEntry flashEntry;
    flashEntry = OverlayEntry(
      builder: (_) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.35, end: 0.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        onEnd: () {
          if (flashEntry.mounted) flashEntry.remove();
        },
        builder: (context, value, _) => IgnorePointer(
          child: Container(
            color: Colors.white.withValues(alpha: value),
          ),
        ),
      ),
    );
    overlay.insert(flashEntry);
  }

  void _showSavedToast(String path) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 32,
        left: 0,
        right: 0,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Transform.scale(
                  scale: 0.92 + 0.08 * value,
                  child: child,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF131A24)
                      : const Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    // Ambient shadow
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                    // Subtle glow
                    if (isDark)
                      BoxShadow(
                        color: ColorTokens.success.withValues(alpha: 0.08),
                        blurRadius: 40,
                        spreadRadius: -4,
                      ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top accent bar
                    Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ColorTokens.success.withValues(alpha: 0.0),
                            ColorTokens.success,
                            ColorTokens.success.withValues(alpha: 0.0),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          // Success icon with glow
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  ColorTokens.success.withValues(alpha: 0.2),
                                  ColorTokens.success.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: ColorTokens.success
                                    .withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              LucideIcons.checkCheck,
                              size: 18,
                              color: ColorTokens.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Text content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Screenshot saved',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? const Color(0xFFE6EDF3)
                                        : const Color(0xFF1E293B),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  path.split('/').last,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'JetBrains Mono',
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Show in Finder button
                          _PressableButton(
                            onTap: () {
                              entry.remove();
                              Process.run('open', ['-R', path]);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [
                                          const Color(0xFF1A2332),
                                          const Color(0xFF1E2A3A),
                                        ]
                                      : [
                                          const Color(0xFFF0F4F8),
                                          const Color(0xFFE8EDF2),
                                        ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.1)
                                      : Colors.black.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.folderOpen,
                                    size: 13,
                                    color: isDark
                                        ? const Color(0xFFE6EDF3)
                                        : const Color(0xFF374151),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Reveal',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? const Color(0xFFE6EDF3)
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Close button
                          _PressableButton(
                            onTap: () => entry.remove(),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.04),
                              ),
                              child: Icon(LucideIcons.x,
                                  size: 13,
                                  color: isDark
                                      ? Colors.grey[600]
                                      : Colors.grey[400]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Screenshot failed: $message'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _takeFullScreenshot() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    await _captureAndSave(_buildScreenshotWidget(theme, isDark));
  }

  Future<void> _takeTabScreenshot() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    await _captureAndSave(
        _buildTabScreenshotWidget(theme, isDark, _currentTabIndex));
  }

  /// Builds the full detail widget for screenshot (no scroll constraints).
  Widget _buildScreenshotWidget(ThemeData theme, bool isDark) {
    final event = widget.event;
    final time = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(event.timestamp),
    );

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
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                Text(
                  time,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildScreenshotContent(isDark),
        ],
      ),
    );
  }

  /// Content for screenshot — no SingleChildScrollView, no Expanded.
  /// Tabbed views are rendered as stacked sections.
  Widget _buildScreenshotContent(bool isDark) {
    switch (widget.event.type) {
      case EventType.log:
        if (widget.event.rawData is LogEntry) {
          return _logScreenshot(widget.event.rawData as LogEntry, isDark);
        }
        return _fallbackScreenshot(widget.event, isDark);
      case EventType.network:
        if (widget.event.rawData is NetworkEntry) {
          return _networkScreenshot(
              widget.event.rawData as NetworkEntry, isDark);
        }
        return _fallbackScreenshot(widget.event, isDark);
      case EventType.state:
        if (widget.event.rawData is StateChange) {
          return _stateScreenshot(
              widget.event.rawData as StateChange, isDark);
        }
        return _fallbackScreenshot(widget.event, isDark);
      case EventType.storage:
        if (widget.event.rawData is StorageEntry) {
          return _storageScreenshot(
              widget.event.rawData as StorageEntry, isDark);
        }
        return _fallbackScreenshot(widget.event, isDark);
    }
  }

  Widget _logScreenshot(LogEntry entry, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            LogLevelBadge(level: entry.level.name),
            if (entry.tag != null) ...[
              const SizedBox(width: 8),
              _TagChip(entry.tag!),
            ],
          ]),
          const SizedBox(height: 16),
          const _SectionLabel('Message'),
          const SizedBox(height: 6),
          _CodeBlock(text: entry.message, isDark: isDark),
          if (entry.metadata != null && entry.metadata!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Metadata'),
            const SizedBox(height: 6),
            JsonViewer(data: entry.metadata, initiallyExpanded: true),
          ],
          if (entry.stackTrace != null) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Stack Trace'),
            const SizedBox(height: 6),
            _ErrorBlock(text: entry.stackTrace!, isDark: isDark),
          ],
        ],
      ),
    );
  }

  Widget _networkScreenshot(NetworkEntry entry, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // URL bar
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
          child: Row(
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
                ),
              ),
            ],
          ),
        ),
        // Timing summary
        if (entry.duration != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _TimingBar(duration: entry.duration!),
          ),
        const Divider(height: 1),
        // Headers
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('REQUEST HEADERS'),
              const SizedBox(height: 8),
              _HeaderTable(headers: entry.requestHeaders),
              const SizedBox(height: 20),
              const _SectionLabel('RESPONSE HEADERS'),
              const SizedBox(height: 8),
              _HeaderTable(headers: entry.responseHeaders),
            ],
          ),
        ),
        const Divider(height: 1),
        // Request body
        if (entry.requestBody != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('REQUEST BODY'),
                const SizedBox(height: 8),
                if (entry.requestBody is Map || entry.requestBody is List)
                  JsonViewer(
                      data: entry.requestBody, initiallyExpanded: true)
                else
                  JsonPrettyViewer(data: entry.requestBody),
              ],
            ),
          ),
        if (entry.requestBody != null) const Divider(height: 1),
        // Response body
        if (entry.responseBody != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('RESPONSE BODY'),
                const SizedBox(height: 8),
                if (entry.responseBody is Map ||
                    entry.responseBody is List)
                  JsonViewer(
                      data: entry.responseBody, initiallyExpanded: true)
                else
                  JsonPrettyViewer(data: entry.responseBody),
              ],
            ),
          ),
        if (entry.responseBody != null) const Divider(height: 1),
        // Timing details
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('TIMING'),
              const SizedBox(height: 8),
              _InfoRow(
                'Start Time',
                DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(
                  DateTime.fromMillisecondsSinceEpoch(entry.startTime),
                ),
              ),
              if (entry.endTime != null)
                _InfoRow(
                  'End Time',
                  DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(
                    DateTime.fromMillisecondsSinceEpoch(entry.endTime!),
                  ),
                ),
              if (entry.duration != null)
                _InfoRow('Duration', '${entry.duration}ms'),
              if (entry.error != null) ...[
                const SizedBox(height: 12),
                const _SectionLabel('Error'),
                const SizedBox(height: 6),
                _ErrorBlock(text: entry.error!, isDark: isDark),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _stateScreenshot(StateChange entry, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              _TagChip(entry.stateManagerType,
                  color: ColorTokens.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.actionName,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Diff
        if (entry.diff.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('DIFF'),
                const SizedBox(height: 8),
                ...entry.diff.map((d) => _DiffRow(diff: d)),
              ],
            ),
          ),
        if (entry.diff.isNotEmpty) const Divider(height: 1),
        // Previous state
        if (entry.previousState.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('PREVIOUS STATE'),
                const SizedBox(height: 8),
                JsonViewer(
                    data: entry.previousState, initiallyExpanded: true),
              ],
            ),
          ),
        if (entry.previousState.isNotEmpty) const Divider(height: 1),
        // Next state
        if (entry.nextState.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('NEXT STATE'),
                const SizedBox(height: 8),
                JsonViewer(
                    data: entry.nextState, initiallyExpanded: true),
              ],
            ),
          ),
      ],
    );
  }

  Widget _storageScreenshot(StorageEntry entry, bool isDark) {
    Color opColor;
    switch (entry.operation.toLowerCase()) {
      case 'write':
        opColor = ColorTokens.success;
        break;
      case 'read':
        opColor = ColorTokens.info;
        break;
      case 'delete':
      case 'clear':
        opColor = ColorTokens.error;
        break;
      default:
        opColor = ColorTokens.warning;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _TagChip(entry.operation.toUpperCase(), color: opColor),
            const SizedBox(width: 8),
            _TagChip(entry.storageType.name, color: ColorTokens.warning),
          ]),
          const SizedBox(height: 16),
          const _SectionLabel('Key'),
          const SizedBox(height: 6),
          _CodeBlock(text: entry.key, isDark: isDark),
          if (entry.value != null) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Value'),
            const SizedBox(height: 6),
            if (entry.value is Map || entry.value is List)
              JsonViewer(data: entry.value, initiallyExpanded: true)
            else
              _CodeBlock(text: '${entry.value}', isDark: isDark),
          ],
        ],
      ),
    );
  }

  Widget _fallbackScreenshot(UnifiedEvent event, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Title'),
          const SizedBox(height: 6),
          _CodeBlock(text: event.title, isDark: isDark),
          const SizedBox(height: 16),
          const _SectionLabel('Details'),
          const SizedBox(height: 6),
          _CodeBlock(text: event.subtitle, isDark: isDark),
          if (event.rawData != null) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Raw Data'),
            const SizedBox(height: 6),
            if (event.rawData is Map || event.rawData is List)
              JsonViewer(data: event.rawData, initiallyExpanded: true)
            else
              _CodeBlock(text: '${event.rawData}', isDark: isDark),
          ],
        ],
      ),
    );
  }

  /// Builds a tab-only screenshot: header + URL bar (for network) + current tab content only.
  Widget _buildTabScreenshotWidget(
      ThemeData theme, bool isDark, int tabIndex) {
    final event = widget.event;
    final time = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(event.timestamp),
    );

    final (typeColor, typeIcon, typeLabel) =
        _DetailHeader._staticTypeDetails(event.type);

    final header = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
      ),
      child: Row(
        children: [
          Icon(typeIcon, size: 14, color: typeColor),
          const SizedBox(width: 8),
          Text(typeLabel,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: typeColor)),
          const SizedBox(width: 10),
          Text(time,
              style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 10,
                  color: Colors.grey[500])),
        ],
      ),
    );

    Widget tabContent;
    if (event.type == EventType.network && event.rawData is NetworkEntry) {
      final entry = event.rawData as NetworkEntry;
      // URL bar always shown
      final urlBar = Container(
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
        child: Row(
          children: [
            HttpMethodBadge(method: entry.method),
            const SizedBox(width: 8),
            if (entry.isComplete) ...[
              StatusBadge(statusCode: entry.statusCode),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(entry.url,
                  style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFFE6EDF3)
                          : Colors.black87)),
            ),
          ],
        ),
      );
      if (entry.duration != null) {
        // Timing bar under URL
      }

      final tabNames = ['Headers', 'Request', 'Response', 'Timing'];
      final tabLabel = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _SectionLabel(tabNames[tabIndex]),
      );

      Widget body;
      switch (tabIndex) {
        case 0: // Headers
          body = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Request Headers'),
                const SizedBox(height: 8),
                _HeaderTable(headers: entry.requestHeaders),
                const SizedBox(height: 20),
                const _SectionLabel('Response Headers'),
                const SizedBox(height: 8),
                _HeaderTable(headers: entry.responseHeaders),
              ],
            ),
          );
          break;
        case 1: // Request
          body = _buildBodyScreenshot(
              entry.requestBody, 'Request Body', isDark);
          break;
        case 2: // Response
          body = _buildBodyScreenshot(
              entry.responseBody, 'Response Body', isDark);
          break;
        case 3: // Timing
        default:
          body = Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  'Start Time',
                  DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(
                    DateTime.fromMillisecondsSinceEpoch(entry.startTime),
                  ),
                ),
                if (entry.endTime != null)
                  _InfoRow(
                    'End Time',
                    DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(
                      DateTime.fromMillisecondsSinceEpoch(entry.endTime!),
                    ),
                  ),
                if (entry.duration != null)
                  _InfoRow('Duration', '${entry.duration}ms'),
                if (entry.error != null) ...[
                  const SizedBox(height: 12),
                  const _SectionLabel('Error'),
                  const SizedBox(height: 6),
                  _ErrorBlock(text: entry.error!, isDark: isDark),
                ],
              ],
            ),
          );
          break;
      }

      tabContent = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [urlBar, tabLabel, body],
      );
    } else if (event.type == EventType.state &&
        event.rawData is StateChange) {
      final entry = event.rawData as StateChange;
      final tabNames = ['Diff', 'Previous', 'Next'];
      Widget body;
      switch (tabIndex) {
        case 0:
          body = entry.diff.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No diff'))
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        entry.diff.map((d) => _DiffRow(diff: d)).toList(),
                  ),
                );
          break;
        case 1:
          body = _buildBodyScreenshot(
              entry.previousState.isEmpty ? null : entry.previousState,
              'Previous State',
              isDark);
          break;
        case 2:
        default:
          body = _buildBodyScreenshot(
              entry.nextState.isEmpty ? null : entry.nextState,
              'Next State',
              isDark);
          break;
      }
      tabContent = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _SectionLabel(tabNames[tabIndex]),
          ),
          body,
        ],
      );
    } else {
      // Log / Storage / Fallback — no tabs, just use full content
      tabContent = _buildScreenshotContent(isDark);
    }

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const Divider(height: 1),
          tabContent,
        ],
      ),
    );
  }

  Widget _buildBodyScreenshot(dynamic body, String label, bool isDark) {
    if (body == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No $label',
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      );
    }
    dynamic parsed = body;
    if (parsed is String) {
      try {
        parsed = jsonDecode(parsed);
      } catch (_) {}
    }
    final useJson = _currentJsonMode;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label),
          const SizedBox(height: 8),
          if (useJson || !(parsed is Map || parsed is List))
            JsonPrettyViewer(data: parsed)
          else
            JsonViewer(data: parsed, initiallyExpanded: true),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      child: Column(
        children: [
          _DetailHeader(
            event: widget.event,
            onClose: widget.onClose,
            onFullScreenshot: _takeFullScreenshot,
            onTabScreenshot: _takeTabScreenshot,
            hasMultipleTabs: widget.event.type == EventType.network ||
                widget.event.type == EventType.state,
          ),
          const Divider(height: 1),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.event.type) {
      case EventType.log:
        if (widget.event.rawData is LogEntry) {
          return _LogDetail(entry: widget.event.rawData as LogEntry);
        }
        return _FallbackDetail(event: widget.event);
      case EventType.network:
        if (widget.event.rawData is NetworkEntry) {
          return _NetworkDetail(
            entry: widget.event.rawData as NetworkEntry,
            onTabChanged: (i) => _currentTabIndex = i,
            onJsonModeChanged: (v) => _currentJsonMode = v,
          );
        }
        return _FallbackDetail(event: widget.event);
      case EventType.state:
        if (widget.event.rawData is StateChange) {
          return _StateDetail(
            entry: widget.event.rawData as StateChange,
            onTabChanged: (i) => _currentTabIndex = i,
            onJsonModeChanged: (v) => _currentJsonMode = v,
          );
        }
        return _FallbackDetail(event: widget.event);
      case EventType.storage:
        if (widget.event.rawData is StorageEntry) {
          return _StorageDetail(entry: widget.event.rawData as StorageEntry);
        }
        return _FallbackDetail(event: widget.event);
    }
  }
}

class _DetailHeader extends ConsumerWidget {
  final UnifiedEvent event;
  final VoidCallback onClose;
  final VoidCallback onFullScreenshot;
  final VoidCallback? onTabScreenshot;
  final bool hasMultipleTabs;

  const _DetailHeader({
    required this.event,
    required this.onClose,
    required this.onFullScreenshot,
    this.onTabScreenshot,
    this.hasMultipleTabs = false,
  });

  static (Color, IconData, String) _staticTypeDetails(EventType type) {
    switch (type) {
      case EventType.log:
        return (ColorTokens.logInfo, LucideIcons.terminal, 'Log Detail');
      case EventType.network:
        return (ColorTokens.success, LucideIcons.globe, 'Network Detail');
      case EventType.state:
        return (
          ColorTokens.secondary,
          LucideIcons.layers,
          'State Detail'
        );
      case EventType.storage:
        return (
          ColorTokens.warning,
          LucideIcons.database,
          'Storage Detail'
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(event.timestamp),
    );

    final devices = ref.watch(connectedDevicesProvider);
    final device =
        devices.where((d) => d.deviceId == event.deviceId).firstOrNull;

    final (typeColor, typeIcon, typeLabel) = _staticTypeDetails(event.type);

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
          // Screenshot buttons
          Tooltip(
            message: 'Capture full detail panel as image',
            waitDuration: const Duration(milliseconds: 400),
            child: _ActionButton(
              icon: LucideIcons.camera,
              label: 'Full',
              onTap: onFullScreenshot,
            ),
          ),
          if (hasMultipleTabs && onTabScreenshot != null) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'Capture current tab only',
              waitDuration: const Duration(milliseconds: 400),
              child: _ActionButton(
                icon: LucideIcons.scanLine,
                label: 'Tab',
                onTap: onTabScreenshot!,
              ),
            ),
          ],
          const SizedBox(width: 6),
          _PressableButton(
            onTap: onClose,
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
        ],
      ),
    );
  }
}

class _PressableButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PressableButton({required this.onTap, required this.child});

  @override
  State<_PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<_PressableButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedOpacity(
            opacity: _pressed ? 0.7 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _PressableButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: Colors.grey.withValues(alpha: 0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Log Detail
// ═══════════════════════════════════════════════

class _LogDetail extends StatelessWidget {
  final LogEntry entry;

  const _LogDetail({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LogLevelBadge(level: entry.level.name),
              if (entry.tag != null) ...[
                const SizedBox(width: 8),
                _TagChip(entry.tag!),
              ],
              const Spacer(),
              _CopyButton(
                tooltip: 'Copy message',
                onTap: () => _copyText(context, entry.message, 'Message'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel('Message'),
          const SizedBox(height: 6),
          _CodeBlock(text: entry.message, isDark: isDark),
          if (entry.metadata != null && entry.metadata!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InlineJsonView(data: entry.metadata, label: 'Metadata'),
          ],
          if (entry.stackTrace != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                _SectionLabel('Stack Trace'),
                const Spacer(),
                _CopyButton(
                  tooltip: 'Copy stack trace',
                  onTap: () =>
                      _copyText(context, entry.stackTrace!, 'Stack trace'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _ErrorBlock(text: entry.stackTrace!, isDark: isDark),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Network Detail
// ═══════════════════════════════════════════════

class _NetworkDetail extends StatefulWidget {
  final NetworkEntry entry;
  final ValueChanged<int>? onTabChanged;
  final ValueChanged<bool>? onJsonModeChanged;

  const _NetworkDetail({
    required this.entry,
    this.onTabChanged,
    this.onJsonModeChanged,
  });

  @override
  State<_NetworkDetail> createState() => _NetworkDetailState();
}

class _NetworkDetailState extends State<_NetworkDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        widget.onTabChanged?.call(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  NetworkEntry get entry => widget.entry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
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
                          color: isDark
                              ? const Color(0xFFE6EDF3)
                              : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Action buttons row
                Row(
                  children: [
                    if (entry.duration != null) ...[
                      _TimingBar(duration: entry.duration!),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    _CopyButton(
                      tooltip: 'Copy URL',
                      icon: LucideIcons.link,
                      onTap: () =>
                          _copyText(context, entry.url, 'URL'),
                    ),
                    const SizedBox(width: 4),
                    _CopyButton(
                      tooltip: 'Copy as cURL',
                      icon: LucideIcons.terminal,
                      onTap: () => _copyText(
                          context, _buildCurl(entry), 'cURL'),
                    ),
                    const SizedBox(width: 4),
                    _CopyButton(
                      tooltip: 'Copy request',
                      icon: LucideIcons.upload,
                      onTap: () {
                        final body = entry.requestBody;
                        final text = body is String
                            ? body
                            : (body != null
                                ? const JsonEncoder.withIndent('  ')
                                    .convert(body)
                                : '');
                        _copyText(context, text, 'Request');
                      },
                    ),
                    const SizedBox(width: 4),
                    _CopyButton(
                      tooltip: 'Copy response',
                      icon: LucideIcons.download,
                      onTap: () {
                        final body = entry.responseBody;
                        final text = body is String
                            ? body
                            : (body != null
                                ? const JsonEncoder.withIndent('  ')
                                    .convert(body)
                                : '');
                        _copyText(context, text, 'Response');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
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
              controller: _tabController,
              children: [
                _HeadersView(entry: entry),
                _BodyView(
                  body: entry.requestBody,
                  label: 'Request Body',
                  onJsonModeChanged: widget.onJsonModeChanged,
                ),
                _BodyView(
                  body: entry.responseBody,
                  label: 'Response Body',
                  onJsonModeChanged: widget.onJsonModeChanged,
                ),
                _TimingView(entry: entry),
              ],
            ),
          ),
        ],
      );
  }

  String _buildCurl(NetworkEntry e) {
    final buf = StringBuffer("curl -X ${e.method} '${e.url}'");
    e.requestHeaders.forEach((k, v) {
      buf.write(" \\\n  -H '$k: $v'");
    });
    if (e.requestBody != null) {
      final body = e.requestBody is String
          ? e.requestBody as String
          : const JsonEncoder().convert(e.requestBody);
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
    final maxWidth = 200.0;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderSection(
            icon: LucideIcons.arrowUpRight,
            iconColor: ColorTokens.primary,
            title: 'Request Headers',
            count: entry.requestHeaders.length,
            headers: entry.requestHeaders,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _HeaderSection(
            icon: LucideIcons.arrowDownLeft,
            iconColor: ColorTokens.success,
            title: 'Response Headers',
            count: entry.responseHeaders.length,
            headers: entry.responseHeaders,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int count;
  final Map<String, String> headers;
  final bool isDark;

  const _HeaderSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.headers,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2128) : const Color(0xFFF6F8FA),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 13, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Header rows
          if (headers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No headers',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            )
          else
            ...headers.entries.toList().asMap().entries.map((entry) {
              final e = entry.value;
              final isLast = entry.key == headers.length - 1;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      width: 180,
                      child: SelectableText(
                        e.key,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF9CDCFE)
                              : const Color(0xFF0451A5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(
                        e.value,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          color: isDark
                              ? const Color(0xFFCE9178)
                              : const Color(0xFFA31515),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
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
      return Text('No headers',
          style: TextStyle(color: Colors.grey[500], fontSize: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: headers.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 170,
                child: Text(
                  e.key,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF9CDCFE)
                        : const Color(0xFF0451A5),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    color: isDark
                        ? const Color(0xFFCE9178)
                        : const Color(0xFFA31515),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BodyView extends StatefulWidget {
  final dynamic body;
  final String label;
  final ValueChanged<bool>? onJsonModeChanged;

  const _BodyView({
    required this.body,
    required this.label,
    this.onJsonModeChanged,
  });

  @override
  State<_BodyView> createState() => _BodyViewState();
}

class _BodyViewState extends State<_BodyView> {
  bool _jsonMode = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.body == null) {
      return EmptyState(icon: LucideIcons.fileText, title: 'No ${widget.label}');
    }

    // Try to parse string body as JSON
    dynamic parsedBody = widget.body;
    if (parsedBody is String) {
      try {
        parsedBody = jsonDecode(parsedBody);
      } catch (_) {}
    }

    final canToggle = parsedBody is Map || parsedBody is List;

    return Column(
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
          ),
          child: Row(
            children: [
              _SectionLabel(widget.label),
              const Spacer(),
              if (canToggle) ...[
                GestureDetector(
                  onTap: () {
                    setState(() => _jsonMode = false);
                    widget.onJsonModeChanged?.call(false);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: !_jsonMode
                            ? ColorTokens.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(5),
                          bottomLeft: Radius.circular(5),
                        ),
                        border: Border.all(
                          color: !_jsonMode
                              ? ColorTokens.primary.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'Tree',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: !_jsonMode
                              ? ColorTokens.primary
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _jsonMode = true);
                    widget.onJsonModeChanged?.call(true);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _jsonMode
                            ? ColorTokens.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                        border: Border.all(
                          color: _jsonMode
                              ? ColorTokens.primary.withValues(alpha: 0.3)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'JSON',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _jsonMode
                              ? ColorTokens.primary
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _jsonMode || !(parsedBody is Map || parsedBody is List)
                ? JsonPrettyViewer(data: parsedBody)
                : JsonViewer(data: parsedBody, initiallyExpanded: true),
          ),
        ),
      ],
    );
  }
}

/// Inline Tree/JSON toggle for use inside ScrollView (non-tabbed contexts).
class _InlineJsonView extends StatefulWidget {
  final dynamic data;
  final String label;

  const _InlineJsonView({required this.data, required this.label});

  @override
  State<_InlineJsonView> createState() => _InlineJsonViewState();
}

class _InlineJsonViewState extends State<_InlineJsonView> {
  bool _jsonMode = false;

  @override
  Widget build(BuildContext context) {
    dynamic parsed = widget.data;
    if (parsed is String) {
      try {
        parsed = jsonDecode(parsed);
      } catch (_) {}
    }

    final canToggle = parsed is Map || parsed is List;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionLabel(widget.label),
            const Spacer(),
            if (canToggle) ...[
              GestureDetector(
                onTap: () => setState(() => _jsonMode = false),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: !_jsonMode
                          ? ColorTokens.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(5),
                        bottomLeft: Radius.circular(5),
                      ),
                      border: Border.all(
                        color: !_jsonMode
                            ? ColorTokens.primary.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'Tree',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color:
                            !_jsonMode ? ColorTokens.primary : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _jsonMode = true),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _jsonMode
                          ? ColorTokens.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(5),
                        bottomRight: Radius.circular(5),
                      ),
                      border: Border.all(
                        color: _jsonMode
                            ? ColorTokens.primary.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      'JSON',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color:
                            _jsonMode ? ColorTokens.primary : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _jsonMode || !(parsed is Map || parsed is List)
            ? JsonPrettyViewer(data: parsed)
            : JsonViewer(data: parsed, initiallyExpanded: true),
      ],
    );
  }
}

class _TimingView extends StatelessWidget {
  final NetworkEntry entry;

  const _TimingView({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final duration = entry.duration;
    final startDt = DateTime.fromMillisecondsSinceEpoch(entry.startTime);
    final endDt = entry.endTime != null
        ? DateTime.fromMillisecondsSinceEpoch(entry.endTime!)
        : null;

    Color durationColor;
    String durationLabel;
    IconData durationIcon;
    if (duration == null) {
      durationColor = Colors.grey;
      durationLabel = 'Pending';
      durationIcon = LucideIcons.loader;
    } else if (duration < 200) {
      durationColor = ColorTokens.success;
      durationLabel = 'Fast';
      durationIcon = LucideIcons.zap;
    } else if (duration < 500) {
      durationColor = ColorTokens.warning;
      durationLabel = 'Normal';
      durationIcon = LucideIcons.clock;
    } else if (duration < 2000) {
      durationColor = const Color(0xFFE5853D);
      durationLabel = 'Slow';
      durationIcon = LucideIcons.triangleAlert;
    } else {
      durationColor = ColorTokens.error;
      durationLabel = 'Very Slow';
      durationIcon = LucideIcons.circleAlert;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duration hero card
          if (duration != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    durationColor.withValues(alpha: 0.12),
                    durationColor.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: durationColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: durationColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(durationIcon, size: 22, color: durationColor),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${duration}ms',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: durationColor,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        durationLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: durationColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Performance gauge
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CustomPaint(
                      painter: _GaugePainter(
                        ratio: (duration / 2000).clamp(0.0, 1.0),
                        color: durationColor,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Timeline
          _TimingInfoCard(
            isDark: isDark,
            children: [
              _TimingInfoRow(
                icon: LucideIcons.play,
                iconColor: ColorTokens.success,
                label: 'Start Time',
                value: DateFormat('HH:mm:ss.SSS').format(startDt),
                subtitle: DateFormat('yyyy-MM-dd').format(startDt),
                isDark: isDark,
              ),
              if (endDt != null) ...[
                _TimingDividerLine(isDark: isDark),
                _TimingInfoRow(
                  icon: LucideIcons.square,
                  iconColor: ColorTokens.error,
                  label: 'End Time',
                  value: DateFormat('HH:mm:ss.SSS').format(endDt),
                  subtitle: DateFormat('yyyy-MM-dd').format(endDt),
                  isDark: isDark,
                ),
              ],
            ],
          ),
          // Status info
          if (entry.statusCode > 0) ...[
            const SizedBox(height: 12),
            _TimingInfoCard(
              isDark: isDark,
              children: [
                _TimingInfoRow(
                  icon: LucideIcons.arrowUpRight,
                  iconColor: ColorTokens.primary,
                  label: 'Method',
                  value: entry.method,
                  isDark: isDark,
                ),
                _TimingDividerLine(isDark: isDark),
                _TimingInfoRow(
                  icon: LucideIcons.hash,
                  iconColor: entry.statusCode >= 400
                      ? ColorTokens.error
                      : ColorTokens.success,
                  label: 'Status',
                  value: '${entry.statusCode}',
                  isDark: isDark,
                ),
              ],
            ),
          ],
          // Error section
          if (entry.error != null) ...[
            const SizedBox(height: 16),
            const _SectionLabel('Error'),
            const SizedBox(height: 8),
            _ErrorBlock(text: entry.error!, isDark: isDark),
          ],
        ],
      ),
    );
  }
}

class _TimingInfoCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _TimingInfoCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _TimingInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;
  final bool isDark;

  const _TimingInfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimingDividerLine extends StatelessWidget {
  final bool isDark;
  const _TimingDividerLine({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 28),
      child: Divider(
        height: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double ratio;
  final Color color;
  final bool isDark;

  _GaugePainter({
    required this.ratio,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 4;
    const startAngle = 2.356; // 135 degrees
    const sweepTotal = 4.712; // 270 degrees

    // Background arc
    final bgPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweepTotal,
      false,
      bgPaint,
    );

    // Value arc
    final valuePaint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweepTotal * ratio,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.ratio != ratio || old.color != color;
}

// ═══════════════════════════════════════════════
// State Detail
// ═══════════════════════════════════════════════

class _StateDetail extends StatefulWidget {
  final StateChange entry;
  final ValueChanged<int>? onTabChanged;
  final ValueChanged<bool>? onJsonModeChanged;

  const _StateDetail({
    required this.entry,
    this.onTabChanged,
    this.onJsonModeChanged,
  });

  @override
  State<_StateDetail> createState() => _StateDetailState();
}

class _StateDetailState extends State<_StateDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        widget.onTabChanged?.call(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  StateChange get entry => widget.entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              _TagChip(entry.stateManagerType,
                  color: ColorTokens.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.actionName,
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _CopyButton(
                tooltip: 'Copy action',
                onTap: () =>
                    _copyText(context, entry.actionName, 'Action'),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
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
            controller: _tabController,
            children: [
              entry.diff.isEmpty
                  ? const EmptyState(
                      icon: LucideIcons.gitCompare, title: 'No diff')
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: entry.diff.length,
                      itemBuilder: (context, index) =>
                          _DiffRow(diff: entry.diff[index]),
                    ),
              entry.previousState.isEmpty
                  ? const EmptyState(
                      icon: LucideIcons.layers,
                      title: 'No previous state')
                  : _BodyView(
                      body: entry.previousState,
                      label: 'Previous State',
                      onJsonModeChanged: widget.onJsonModeChanged,
                    ),
              entry.nextState.isEmpty
                  ? const EmptyState(
                      icon: LucideIcons.layers,
                      title: 'No next state')
                  : _BodyView(
                      body: entry.nextState,
                      label: 'Next State',
                      onJsonModeChanged: widget.onJsonModeChanged,
                    ),
            ],
          ),
        ),
      ],
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

// ═══════════════════════════════════════════════
// Storage Detail
// ═══════════════════════════════════════════════

class _StorageDetail extends StatelessWidget {
  final StorageEntry entry;

  const _StorageDetail({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color opColor;
    switch (entry.operation.toLowerCase()) {
      case 'write':
        opColor = ColorTokens.success;
        break;
      case 'read':
        opColor = ColorTokens.info;
        break;
      case 'delete':
      case 'clear':
        opColor = ColorTokens.error;
        break;
      default:
        opColor = ColorTokens.warning;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TagChip(entry.operation.toUpperCase(), color: opColor),
              const SizedBox(width: 8),
              _TagChip(entry.storageType.name, color: ColorTokens.warning),
              const Spacer(),
              _CopyButton(
                tooltip: 'Copy key',
                onTap: () => _copyText(context, entry.key, 'Key'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionLabel('Key'),
          const SizedBox(height: 6),
          _CodeBlock(text: entry.key, isDark: isDark),
          if (entry.value != null) ...[
            const SizedBox(height: 16),
            if (entry.value is Map || entry.value is List)
              _InlineJsonView(data: entry.value, label: 'Value')
            else ...[
              Row(
                children: [
                  _SectionLabel('Value'),
                  const Spacer(),
                  _CopyButton(
                    tooltip: 'Copy value',
                    onTap: () {
                      final text = entry.value is String
                          ? entry.value as String
                          : const JsonEncoder.withIndent('  ')
                              .convert(entry.value);
                      _copyText(context, text, 'Value');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _CodeBlock(text: '${entry.value}', isDark: isDark),
            ],
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Fallback Detail
// ═══════════════════════════════════════════════

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
          _SectionLabel('Title'),
          const SizedBox(height: 6),
          _CodeBlock(text: event.title, isDark: isDark),
          const SizedBox(height: 16),
          _SectionLabel('Details'),
          const SizedBox(height: 6),
          _CodeBlock(text: event.subtitle, isDark: isDark),
          if (event.rawData != null) ...[
            const SizedBox(height: 16),
            _SectionLabel('Raw Data'),
            const SizedBox(height: 6),
            if (event.rawData is Map || event.rawData is List)
              JsonViewer(data: event.rawData, initiallyExpanded: true)
            else
              _CodeBlock(text: '${event.rawData}', isDark: isDark),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// Shared Widgets
// ═══════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

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

class _TagChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TagChip(this.label, {this.color = Colors.grey});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
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
    return _PressableButton(
      onTap: onTap,
      child: Tooltip(
        message: tooltip,
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

class _CodeBlock extends StatelessWidget {
  final String text;
  final bool isDark;

  const _CodeBlock({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
          color: isDark ? const Color(0xFFE6EDF3) : Colors.black87,
          height: 1.6,
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String text;
  final bool isDark;

  const _ErrorBlock({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColorTokens.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: ColorTokens.error.withValues(alpha: 0.15)),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          color: ColorTokens.error.withValues(alpha: 0.9),
          height: 1.5,
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

// ═══════════════════════════════════════════════
// Helper
// ═══════════════════════════════════════════════

void _copyText(BuildContext context, String text, String label) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label copied'),
      duration: const Duration(milliseconds: 800),
    ),
  );
}
