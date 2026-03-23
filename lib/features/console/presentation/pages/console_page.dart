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
import '../../../../server/providers/server_providers.dart';
import '../../provider/console_providers.dart';

class ConsolePage extends ConsumerStatefulWidget {
  const ConsolePage({super.key});

  @override
  ConsumerState<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends ConsumerState<ConsolePage> {
  final _scrollController = ScrollController();
  bool _autoScroll = true;
  LogEntry? _selectedEntry;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(filteredConsoleEntriesProvider);
    final theme = Theme.of(context);

    // Auto scroll to bottom
    if (_autoScroll && entries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Column(
      children: [
        // Toolbar
        _buildToolbar(context, entries.length),
        const Divider(height: 1),
        // Content
        Expanded(
          child: entries.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.terminal,
                  title: 'No logs yet',
                  subtitle:
                      'Connect a device and start logging to see entries here',
                )
              : Row(
                  children: [
                    // Log list
                    Expanded(
                      flex: _selectedEntry != null ? 3 : 1,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final isSelected = _selectedEntry?.id == entry.id;
                          return _LogEntryTile(
                            entry: entry,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() {
                                _selectedEntry = isSelected ? null : entry;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    // Detail panel
                    if (_selectedEntry != null) ...[
                      VerticalDivider(width: 1, color: theme.dividerColor),
                      Expanded(
                        flex: 2,
                        child: _LogDetailPanel(entry: _selectedEntry!),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, int count) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeFilters = ref.watch(consoleFilterProvider);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.terminal, size: 16, color: ColorTokens.primary),
          const SizedBox(width: 8),
          Text(
            'Console',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(width: 8),
          Text(
            '$count entries',
            style: theme.textTheme.bodySmall,
          ),
          const Spacer(),
          // Level filters
          ...LogLevel.values.map((level) {
            final isActive = activeFilters.contains(level);
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _FilterChip(
                label: level.name.toUpperCase(),
                isActive: isActive,
                color: _levelColor(level),
                onTap: () {
                  final current = ref.read(consoleFilterProvider);
                  if (isActive) {
                    ref.read(consoleFilterProvider.notifier).state =
                        current.difference({level});
                  } else {
                    ref.read(consoleFilterProvider.notifier).state = {
                      ...current,
                      level,
                    };
                  }
                },
              ),
            );
          }),
          const SizedBox(width: 8),
          SizedBox(
            width: 200,
            child: SearchField(
              hintText: 'Filter logs...',
              onChanged: (value) {
                ref.read(consoleSearchProvider.notifier).state = value;
              },
            ),
          ),
          const SizedBox(width: 8),
          // Auto scroll toggle
          _ToolbarButton(
            icon: LucideIcons.arrowDownToLine,
            isActive: _autoScroll,
            tooltip: 'Auto-scroll',
            onTap: () => setState(() => _autoScroll = !_autoScroll),
          ),
          const SizedBox(width: 4),
          _ToolbarButton(
            icon: LucideIcons.trash2,
            tooltip: 'Clear',
            onTap: () => ref.read(consoleEntriesProvider.notifier).clear(),
          ),
        ],
      ),
    );
  }

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return ColorTokens.logDebug;
      case LogLevel.info:
        return ColorTokens.logInfo;
      case LogLevel.warn:
        return ColorTokens.logWarn;
      case LogLevel.error:
        return ColorTokens.logError;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? color.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.2),
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
    );
  }
}

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

class _LogEntryTile extends ConsumerWidget {
  final LogEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _LogEntryTile({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final time = DateFormat('HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(entry.timestamp),
    );

    // Lookup platform from connected devices
    final devices = ref.watch(connectedDevicesProvider);
    final device =
        devices.where((d) => d.deviceId == entry.deviceId).firstOrNull;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? ColorTokens.primary.withValues(alpha: 0.08)
                : null,
            border: Border(
              bottom: BorderSide(
                color: theme.dividerColor.withValues(alpha: 0.3),
                width: 0.5,
              ),
              left: isSelected
                  ? const BorderSide(color: ColorTokens.primary, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(width: 6),
              // Platform tag
              if (device != null)
                PlatformBadge(platform: device.platform),
              if (device != null) const SizedBox(width: 6),
              LogLevelBadge(level: entry.level.name),
              const SizedBox(width: 8),
              if (entry.tag != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    entry.tag!,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  entry.message,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1F2328),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogDetailPanel extends StatelessWidget {
  final LogEntry entry;

  const _LogDetailPanel({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final time = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(entry.timestamp),
    );

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LogLevelBadge(level: entry.level.name),
                const SizedBox(width: 8),
                Text(time, style: theme.textTheme.bodySmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: entry.message));
                  },
                  tooltip: 'Copy message',
                  splashRadius: 14,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (entry.tag != null) ...[
              Text('Tag', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(entry.tag!, style: theme.textTheme.labelLarge),
              const SizedBox(height: 12),
            ],
            Text('Message', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            SelectableText(
              entry.message,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.5,
              ),
            ),
            if (entry.metadata != null && entry.metadata!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Metadata', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              JsonViewer(data: entry.metadata),
            ],
            if (entry.stackTrace != null) ...[
              const SizedBox(height: 16),
              Text('Stack Trace', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF161B22)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  entry.stackTrace!,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    color: ColorTokens.logError.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
