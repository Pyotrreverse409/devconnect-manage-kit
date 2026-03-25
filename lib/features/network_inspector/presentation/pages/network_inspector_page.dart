import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../components/feedback/empty_state.dart';
import '../../../../components/inputs/scroll_direction_button.dart';
import '../../../../components/inputs/search_field.dart';
import '../../../../components/misc/status_badge.dart';
import '../../../../components/viewers/json_viewer.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../models/network/network_entry.dart';
import '../../../../server/providers/server_providers.dart';
import '../../provider/network_providers.dart';

// ---------------------------------------------------------------------------
// Root page
// ---------------------------------------------------------------------------

class NetworkInspectorPage extends ConsumerStatefulWidget {
  const NetworkInspectorPage({super.key});

  @override
  ConsumerState<NetworkInspectorPage> createState() =>
      _NetworkInspectorPageState();
}

class _NetworkInspectorPageState extends ConsumerState<NetworkInspectorPage> {
  static const _pageSize = 50;

  final _scrollController = ScrollController();
  bool _autoScroll = true;
  int _maxVisible = _pageSize;
  bool _loadingMore = false;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_loadingMore || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final scrollDir = ref.read(scrollDirectionProvider);
    if (scrollDir == ScrollDirection.bottom) {
      if (pos.pixels < 50) _loadMore();
    } else {
      if (pos.pixels > pos.maxScrollExtent - 50) _loadMore();
    }
  }

  void _loadMore() {
    final entries = ref.read(filteredNetworkEntriesProvider);
    if (_maxVisible >= entries.length) return;

    _loadingMore = true;
    final scrollDir = ref.read(scrollDirectionProvider);
    final oldMaxExtent = _scrollController.position.maxScrollExtent;

    setState(() {
      _maxVisible = (_maxVisible + _pageSize).clamp(0, entries.length);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && scrollDir == ScrollDirection.bottom) {
        final newMaxExtent = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(
          _scrollController.position.pixels + (newMaxExtent - oldMaxExtent),
        );
      }
      _loadingMore = false;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(filteredNetworkEntriesProvider);
    final selected = ref.watch(selectedNetworkEntryProvider);
    final theme = Theme.of(context);

    // Compute visible window for pagination
    final scrollDir = ref.watch(scrollDirectionProvider);
    ref.listen<ScrollDirection>(scrollDirectionProvider, (prev, next) {
      if (prev != next) {
        setState(() => _maxVisible = _pageSize);
      }
    });

    final List<NetworkEntry> visibleEntries;
    final bool hasMore;
    if (scrollDir == ScrollDirection.bottom) {
      final startIndex =
          (entries.length - _maxVisible).clamp(0, entries.length);
      visibleEntries = entries.sublist(startIndex);
      hasMore = startIndex > 0;
    } else {
      final reversed = entries.reversed.toList();
      visibleEntries = reversed.take(_maxVisible).toList();
      hasMore = entries.length > _maxVisible;
    }
    if (_autoScroll && entries.length > _previousCount && entries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final target = scrollDir == ScrollDirection.top
              ? 0.0
              : _scrollController.position.maxScrollExtent;
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _previousCount = entries.length;

    return Column(
      children: [
        _Toolbar(
          count: entries.length,
          visibleCount:
              visibleEntries.length != entries.length
                  ? visibleEntries.length
                  : null,
          autoScroll: _autoScroll,
          onToggleAutoScroll: () {
            setState(() {
              _autoScroll = !_autoScroll;
              if (_autoScroll) {
                _maxVisible = _pageSize;
              }
            });
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.globe,
                  title: 'No network requests',
                  subtitle: 'API calls will appear here in real-time',
                )
              : Row(
                  children: [
                    // Request list
                    Expanded(
                      flex: selected != null ? 2 : 1,
                      child: Column(
                        children: [
                          if (hasMore && scrollDir == ScrollDirection.bottom)
                            _LoadMoreBanner(
                              count: entries.length - visibleEntries.length,
                              onTap: _loadMore,
                            ),
                          Expanded(
                            child: ListView.builder(
                              controller: _scrollController,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              itemCount: visibleEntries.length,
                              itemExtent: 56,
                              itemBuilder: (context, index) {
                                final entry = visibleEntries[index];
                                final isSelected =
                                    selected?.id == entry.id;
                                return _RequestCard(
                                  key: ValueKey(entry.id),
                                  entry: entry,
                                  isSelected: isSelected,
                                  onTap: () {
                                    ref
                                        .read(selectedNetworkEntryProvider
                                            .notifier)
                                        .state =
                                        isSelected ? null : entry;
                                  },
                                );
                              },
                            ),
                          ),
                          if (hasMore && scrollDir == ScrollDirection.top)
                            _LoadMoreBanner(
                              count: entries.length - visibleEntries.length,
                              onTap: _loadMore,
                            ),
                        ],
                      ),
                    ),
                    if (selected != null) ...[
                      VerticalDivider(width: 1, color: theme.dividerColor),
                      Expanded(
                        flex: 3,
                        child: _RequestDetailPanel(
                          entry: selected,
                          onClose: () {
                            ref
                                .read(selectedNetworkEntryProvider.notifier)
                                .state = null;
                          },
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
          color: ColorTokens.primary.withValues(alpha: 0.05),
          child: Center(
            child: Text(
              '$count older requests — tap to load more',
              style: TextStyle(
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

// ---------------------------------------------------------------------------
// Toolbar
// ---------------------------------------------------------------------------

class _Toolbar extends ConsumerWidget {
  final int count;
  final int? visibleCount;
  final bool autoScroll;
  final VoidCallback onToggleAutoScroll;

  const _Toolbar({
    required this.count,
    this.visibleCount,
    required this.autoScroll,
    required this.onToggleAutoScroll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final methodFilter = ref.watch(networkMethodFilterProvider);
    final sourceFilter = ref.watch(networkSourceFilterProvider);
    final methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
      ),
      child: Row(
        children: [
          // Title + count pill
          Icon(LucideIcons.globe, size: 16, color: ColorTokens.primary),
          const SizedBox(width: 8),
          Text('Network', style: theme.textTheme.titleMedium),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ColorTokens.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              visibleCount != null ? '$visibleCount / $count' : '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorTokens.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Method filter chips
          ...methods.map((m) {
            final isActive = methodFilter == m;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () {
                  ref.read(networkMethodFilterProvider.notifier).state =
                      isActive ? null : m;
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? ColorTokens.httpMethodColor(m)
                              .withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isActive
                            ? ColorTokens.httpMethodColor(m)
                                .withValues(alpha: 0.5)
                            : Colors.grey.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? ColorTokens.httpMethodColor(m)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),

          const SizedBox(width: 8),

          // Source filter chips
          ..._buildSourceChips(ref, sourceFilter),

          const Spacer(),

          // Search field
          SizedBox(
            width: 200,
            child: SearchField(
              hintText: 'Filter URLs...',
              onChanged: (v) =>
                  ref.read(networkSearchProvider.notifier).state = v,
            ),
          ),
          const SizedBox(width: 8),

          // Auto-scroll toggle
          _ToolbarButton(
            icon: LucideIcons.arrowDownToLine,
            isActive: autoScroll,
            tooltip: 'Auto-scroll',
            onTap: onToggleAutoScroll,
          ),
          const SizedBox(width: 4),
          // Scroll direction toggle
          const ScrollDirectionButton(),
          const SizedBox(width: 4),

          // Clear button
          _ToolbarButton(
            icon: LucideIcons.trash2,
            tooltip: 'Clear',
            onTap: () => ref.read(networkEntriesProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSourceChips(WidgetRef ref, Set<String> sourceFilter) {
    const sources = [
      ('App', 'app', ColorTokens.primary),
      ('Library', 'library', ColorTokens.warning),
    ];

    return [
      ...sources.map((s) {
        final (label, key, color) = s;
        final isActive = sourceFilter.contains(key);
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: GestureDetector(
            onTap: () {
              final current = ref.read(networkSourceFilterProvider);
              if (isActive) {
                ref.read(networkSourceFilterProvider.notifier).state =
                    current.difference({key});
              } else {
                ref.read(networkSourceFilterProvider.notifier).state = {
                  ...current,
                  key,
                };
              }
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isActive
                        ? color.withValues(alpha: 0.4)
                        : Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isActive ? color : Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
      // System chip (grey)
      Padding(
        padding: const EdgeInsets.only(right: 4),
        child: GestureDetector(
          onTap: () {
            final current = ref.read(networkSourceFilterProvider);
            final isActive = current.contains('system');
            if (isActive) {
              ref.read(networkSourceFilterProvider.notifier).state =
                  current.difference({'system'});
            } else {
              ref.read(networkSourceFilterProvider.notifier).state = {
                ...current,
                'system',
              };
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Builder(builder: (context) {
              final isActive = sourceFilter.contains('system');
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.grey.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isActive
                        ? Colors.grey.withValues(alpha: 0.4)
                        : Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'System',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isActive ? Colors.grey[600] : Colors.grey,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Toolbar button (same style as console page)
// ---------------------------------------------------------------------------

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    this.isActive = false,
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive
                  ? ColorTokens.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 14,
              color: isActive ? ColorTokens.primary : Colors.grey[500],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Request card tile
// ---------------------------------------------------------------------------

class _RequestCard extends ConsumerWidget {
  final NetworkEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _RequestCard({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final time = DateFormat('HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(entry.startTime),
    );

    final devices = ref.watch(connectedDevicesProvider);
    final device =
        devices.where((d) => d.deviceId == entry.deviceId).firstOrNull;

    // Parse URL
    Uri? uri;
    try {
      uri = Uri.parse(entry.url);
    } catch (_) {}
    final displayUrl = uri?.path ?? entry.url;
    final host = uri?.host ?? '';

    // Left bar color based on status code
    final Color leftBarColor;
    if (!entry.isComplete) {
      leftBarColor = ColorTokens.info;
    } else if (entry.statusCode < 300) {
      leftBarColor = ColorTokens.success;
    } else if (entry.statusCode < 500) {
      leftBarColor = ColorTokens.warning;
    } else {
      leftBarColor = ColorTokens.error;
    }

    // Source badge color
    Color sourceColor;
    String sourceLabel;
    switch (entry.source) {
      case 'library':
        sourceColor = ColorTokens.warning;
        sourceLabel = 'LIB';
        break;
      case 'system':
        sourceColor = Colors.grey;
        sourceLabel = 'SYS';
        break;
      default:
        sourceColor = ColorTokens.primary;
        sourceLabel = 'APP';
    }

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? ColorTokens.primary.withValues(alpha: 0.08)
                  : isDark
                      ? const Color(0xFF161B22)
                      : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? ColorTokens.primary.withValues(alpha: 0.4)
                    : isDark
                        ? const Color(0xFF30363D)
                        : const Color(0xFFE1E4E8),
                width: 1,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Left color bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: leftBarColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          // Badges column
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (device != null) ...[
                                    PlatformBadge(platform: device.platform),
                                    const SizedBox(width: 4),
                                  ],
                                  HttpMethodBadge(method: entry.method),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  // Source badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color:
                                          sourceColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      sourceLabel,
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: sourceColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Status badge
                                  if (entry.isComplete)
                                    StatusBadge(statusCode: entry.statusCode)
                                  else
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: ColorTokens.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(width: 12),

                          // URL + host
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  displayUrl,
                                  style: TextStyle(
                                    fontFamily: 'JetBrains Mono',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? const Color(0xFFE6EDF3)
                                        : const Color(0xFF1F2328),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (host.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    host,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Duration + timestamp
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (entry.duration != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _durationColor(entry.duration!)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${entry.duration}ms',
                                    style: TextStyle(
                                      fontFamily: 'JetBrains Mono',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _durationColor(entry.duration!),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                time,
                                style: TextStyle(
                                  fontFamily: 'JetBrains Mono',
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _durationColor(int ms) {
    if (ms < 200) return ColorTokens.success;
    if (ms < 500) return ColorTokens.warning;
    return ColorTokens.error;
  }
}

// ---------------------------------------------------------------------------
// Request detail panel
// ---------------------------------------------------------------------------

class _RequestDetailPanel extends StatelessWidget {
  final NetworkEntry entry;
  final VoidCallback onClose;

  const _RequestDetailPanel({
    required this.entry,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          // ---- Header bar ----
          Container(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Method + status + URL + close
                Padding(
                  padding:
                      const EdgeInsets.only(left: 12, right: 4, top: 8, bottom: 4),
                  child: Row(
                    children: [
                      HttpMethodBadge(method: entry.method),
                      const SizedBox(width: 6),
                      if (entry.isComplete) ...[
                        StatusBadge(statusCode: entry.statusCode),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          entry.url,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Close button
                      _HeaderIconButton(
                        icon: LucideIcons.x,
                        tooltip: 'Close',
                        onPressed: onClose,
                      ),
                    ],
                  ),
                ),

                // Timing bar
                if (entry.duration != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _TimingBar(duration: entry.duration!),
                  ),

                const SizedBox(height: 6),

                // Copy actions row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _CopyActionChip(
                        icon: LucideIcons.link,
                        label: 'Copy URL',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: entry.url));
                          _showCopied(context, 'URL copied');
                        },
                      ),
                      const SizedBox(width: 6),
                      _CopyActionChip(
                        icon: LucideIcons.terminal,
                        label: 'Copy cURL',
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: _buildCurl(entry)));
                          _showCopied(context, 'cURL copied');
                        },
                      ),
                      const SizedBox(width: 6),
                      _CopyActionChip(
                        icon: LucideIcons.upload,
                        label: 'Copy Request',
                        onTap: () {
                          final body = entry.requestBody;
                          final text = body is String
                              ? body
                              : (body != null
                                  ? const JsonEncoder.withIndent('  ')
                                      .convert(body)
                                  : '');
                          Clipboard.setData(ClipboardData(text: text));
                          _showCopied(context, 'Request copied');
                        },
                      ),
                      const SizedBox(width: 6),
                      _CopyActionChip(
                        icon: LucideIcons.download,
                        label: 'Copy Response',
                        onTap: () {
                          final body = entry.responseBody;
                          final text = body is String
                              ? body
                              : (body != null
                                  ? const JsonEncoder.withIndent('  ')
                                      .convert(body)
                                  : '');
                          Clipboard.setData(ClipboardData(text: text));
                          _showCopied(context, 'Response copied');
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Tabs
                TabBar(
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  indicatorColor: ColorTokens.primary,
                  labelColor:
                      isDark ? Colors.white : Colors.black87,
                  unselectedLabelColor: Colors.grey[500],
                  tabs: const [
                    Tab(text: 'Headers'),
                    Tab(text: 'Request'),
                    Tab(text: 'Response'),
                    Tab(text: 'Timing'),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ---- Tab views ----
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
              child: TabBarView(
                children: [
                  _HeadersTab(entry: entry),
                  _BodyTab(body: entry.requestBody, label: 'Request Body'),
                  _BodyTab(body: entry.responseBody, label: 'Response Body'),
                  _TimingTab(entry: entry),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCopied(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 180,
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

// ---------------------------------------------------------------------------
// Copy action chip (small button used in detail header)
// ---------------------------------------------------------------------------

class _CopyActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CopyActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF21262D)
                : const Color(0xFFEEF0F2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF30363D)
                  : const Color(0xFFD0D7DE),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header icon button (close, etc.)
// ---------------------------------------------------------------------------

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 14, color: Colors.grey[500]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timing bar
// ---------------------------------------------------------------------------

class _TimingBar extends StatelessWidget {
  final int duration;

  const _TimingBar({required this.duration});

  @override
  Widget build(BuildContext context) {
    const maxWidth = 300.0;
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
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: barColor.withValues(alpha: 0.1),
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
            fontWeight: FontWeight.w600,
            color: barColor,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Headers tab
// ---------------------------------------------------------------------------

class _HeadersTab extends StatelessWidget {
  final NetworkEntry entry;

  const _HeadersTab({required this.entry});

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

// ---------------------------------------------------------------------------
// Body tab (request / response)
// ---------------------------------------------------------------------------

class _BodyTab extends StatefulWidget {
  final dynamic body;
  final String label;

  const _BodyTab({required this.body, required this.label});

  @override
  State<_BodyTab> createState() => _BodyTabState();
}

class _BodyTabState extends State<_BodyTab> {
  bool _jsonMode = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.body == null) {
      return EmptyState(
        icon: LucideIcons.fileText,
        title: 'No ${widget.label}',
      );
    }

    // Try to parse string body as JSON
    dynamic parsedBody = widget.body;
    if (parsedBody is String) {
      try {
        parsedBody = jsonDecode(parsedBody);
      } catch (_) {
        // Not valid JSON, keep as string
      }
    }

    final canToggle = parsedBody is Map || parsedBody is List;

    return Column(
      children: [
        // Toggle bar
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
              Text(widget.label, style: theme.textTheme.titleSmall),
              const Spacer(),
              if (canToggle) ...[
                GestureDetector(
                  onTap: () => setState(() => _jsonMode = false),
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
                  onTap: () => setState(() => _jsonMode = true),
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
              const SizedBox(width: 8),
              // Copy body button
              GestureDetector(
                onTap: () {
                  final text = parsedBody is String
                      ? parsedBody
                      : const JsonEncoder.withIndent('  ')
                          .convert(parsedBody);
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.label} copied'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                      width: 180,
                    ),
                  );
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Icon(LucideIcons.copy,
                      size: 14, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ),
        // Body content
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

// ---------------------------------------------------------------------------
// Timing tab
// ---------------------------------------------------------------------------

class _TimingTab extends StatelessWidget {
  final NetworkEntry entry;

  const _TimingTab({required this.entry});

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
          // Timeline card
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
          if (entry.error != null) ...[
            const SizedBox(height: 16),
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
                entry.error!,
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
      child: Column(children: children),
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
    const startAngle = 2.356;
    const sweepTotal = 4.712;

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
