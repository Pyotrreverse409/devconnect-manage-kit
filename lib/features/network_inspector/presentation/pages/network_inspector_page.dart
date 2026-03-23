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
import '../../../../models/network/network_entry.dart';
import '../../../../server/providers/server_providers.dart';
import '../../provider/network_providers.dart';

class NetworkInspectorPage extends ConsumerWidget {
  const NetworkInspectorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(filteredNetworkEntriesProvider);
    final selected = ref.watch(selectedNetworkEntryProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        _Toolbar(count: entries.length),
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
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[entries.length - 1 - index];
                          final isSelected = selected?.id == entry.id;
                          return _RequestTile(
                            entry: entry,
                            isSelected: isSelected,
                            onTap: () {
                              ref
                                  .read(selectedNetworkEntryProvider.notifier)
                                  .state = isSelected ? null : entry;
                            },
                          );
                        },
                      ),
                    ),
                    if (selected != null) ...[
                      VerticalDivider(width: 1, color: theme.dividerColor),
                      Expanded(
                        flex: 3,
                        child: _RequestDetailPanel(entry: selected),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Toolbar extends ConsumerWidget {
  final int count;
  const _Toolbar({required this.count});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final methodFilter = ref.watch(networkMethodFilterProvider);
    final methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.globe, size: 16, color: ColorTokens.primary),
          const SizedBox(width: 8),
          Text('Network', style: theme.textTheme.titleMedium),
          const SizedBox(width: 8),
          Text('$count requests', style: theme.textTheme.bodySmall),
          const Spacer(),
          ...methods.map((m) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () {
                    ref.read(networkMethodFilterProvider.notifier).state =
                        methodFilter == m ? null : m;
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: HttpMethodBadge(method: m),
                  ),
                ),
              )),
          const SizedBox(width: 8),
          SizedBox(
            width: 200,
            child: SearchField(
              hintText: 'Filter URLs...',
              onChanged: (v) =>
                  ref.read(networkSearchProvider.notifier).state = v,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref.read(networkEntriesProvider.notifier).clear(),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Icon(LucideIcons.trash2, size: 14, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestTile extends ConsumerWidget {
  final NetworkEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _RequestTile({
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

    // Parse URL to show path only
    Uri? uri;
    try {
      uri = Uri.parse(entry.url);
    } catch (_) {}
    final displayUrl = uri?.path ?? entry.url;
    final host = uri?.host ?? '';

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            children: [
              // Platform tag
              if (device != null) ...[
                PlatformBadge(platform: device.platform),
                const SizedBox(width: 6),
              ],
              HttpMethodBadge(method: entry.method),
              const SizedBox(width: 8),
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayUrl,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFFE6EDF3)
                            : const Color(0xFF1F2328),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (host.isNotEmpty)
                      Text(
                        host,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (entry.duration != null)
                Text(
                  '${entry.duration}ms',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 11,
                    color: _durationColor(entry.duration!),
                  ),
                ),
              const SizedBox(width: 8),
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

class _RequestDetailPanel extends StatelessWidget {
  final NetworkEntry entry;

  const _RequestDetailPanel({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // URL bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      HttpMethodBadge(method: entry.method),
                      const SizedBox(width: 8),
                      StatusBadge(statusCode: entry.statusCode),
                      const SizedBox(width: 8),
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
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: entry.url));
                        },
                        splashRadius: 14,
                        tooltip: 'Copy URL',
                      ),
                    ],
                  ),
                ),
                // Timing bar
                if (entry.duration != null)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    child: _TimingBar(duration: entry.duration!),
                  ),
                const SizedBox(height: 8),
                // Tabs
                TabBar(
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
          Expanded(
            child: TabBarView(
              children: [
                _HeadersTab(entry: entry),
                _BodyTab(body: entry.requestBody, label: 'Request Body'),
                _BodyTab(body: entry.responseBody, label: 'Response Body'),
                _TimingTab(entry: entry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimingBar extends StatelessWidget {
  final int duration;

  const _TimingBar({required this.duration});

  @override
  Widget build(BuildContext context) {
    final maxWidth = 300.0;
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

class _HeadersTab extends StatelessWidget {
  final NetworkEntry entry;

  const _HeadersTab({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Request Headers', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _HeaderTable(headers: entry.requestHeaders),
          const SizedBox(height: 20),
          Text('Response Headers', style: theme.textTheme.titleSmall),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (headers.isEmpty) {
      return Text(
        'No headers',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: headers.entries.map((e) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 180,
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

class _BodyTab extends StatelessWidget {
  final dynamic body;
  final String label;

  const _BodyTab({required this.body, required this.label});

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
          Text(label, style: Theme.of(context).textTheme.titleSmall),
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

class _TimingTab extends StatelessWidget {
  final NetworkEntry entry;

  const _TimingTab({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow('Start Time', DateFormat('HH:mm:ss.SSS').format(
            DateTime.fromMillisecondsSinceEpoch(entry.startTime),
          )),
          if (entry.endTime != null)
            _InfoRow('End Time', DateFormat('HH:mm:ss.SSS').format(
              DateTime.fromMillisecondsSinceEpoch(entry.endTime!),
            )),
          if (entry.duration != null)
            _InfoRow('Duration', '${entry.duration}ms'),
          if (entry.error != null) ...[
            const SizedBox(height: 12),
            Text('Error', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorTokens.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ColorTokens.error.withValues(alpha: 0.3)),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
