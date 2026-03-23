import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../components/feedback/empty_state.dart';
import '../../../../components/inputs/search_field.dart';
import '../../../../components/viewers/json_viewer.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../models/storage/storage_entry.dart';
import '../../provider/storage_providers.dart';

class StorageViewerPage extends ConsumerWidget {
  const StorageViewerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(filteredStorageEntriesProvider);
    final selected = ref.watch(selectedStorageEntryProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        _Toolbar(count: entries.length),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.database,
                  title: 'No storage data',
                  subtitle:
                      'SharedPreferences, AsyncStorage, and Hive entries appear here',
                )
              : Row(
                  children: [
                    // Key list
                    SizedBox(
                      width: selected != null ? 320 : 400,
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final isSelected = selected?.id == entry.id;
                          return _StorageEntryTile(
                            entry: entry,
                            isSelected: isSelected,
                            onTap: () {
                              ref
                                  .read(selectedStorageEntryProvider.notifier)
                                  .state = isSelected ? null : entry;
                            },
                          );
                        },
                      ),
                    ),
                    if (selected != null) ...[
                      VerticalDivider(width: 1, color: theme.dividerColor),
                      Expanded(
                        child: _StorageDetailPanel(entry: selected),
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

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.database, size: 16, color: ColorTokens.primary),
          const SizedBox(width: 8),
          Text('Storage', style: theme.textTheme.titleMedium),
          const SizedBox(width: 8),
          Text('$count keys', style: theme.textTheme.bodySmall),
          const Spacer(),
          SizedBox(
            width: 200,
            child: SearchField(
              hintText: 'Filter keys...',
              onChanged: (v) =>
                  ref.read(storageSearchProvider.notifier).state = v,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref.read(storageEntriesProvider.notifier).clear(),
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

class _StorageEntryTile extends StatelessWidget {
  final StorageEntry entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _StorageEntryTile({
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color typeColor;
    String typeLabel;
    switch (entry.storageType) {
      case StorageType.asyncStorage:
        typeColor = const Color(0xFF61DAFB);
        typeLabel = 'AS';
        break;
      case StorageType.sharedPreferences:
        typeColor = const Color(0xFF3DDC84);
        typeLabel = 'SP';
        break;
      case StorageType.hive:
        typeColor = const Color(0xFFFFC107);
        typeLabel = 'HV';
        break;
      case StorageType.sqlite:
        typeColor = const Color(0xFF003B57);
        typeLabel = 'SQL';
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              Container(
                width: 28,
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Center(
                  child: Text(
                    typeLabel,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: typeColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _valuePreview(entry.value),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: _opColor(entry.operation).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  entry.operation.toUpperCase(),
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: _opColor(entry.operation),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _valuePreview(dynamic value) {
    if (value == null) return 'null';
    final str = value.toString();
    return str.length > 50 ? '${str.substring(0, 50)}...' : str;
  }

  Color _opColor(String op) {
    switch (op.toLowerCase()) {
      case 'write':
        return ColorTokens.success;
      case 'delete':
      case 'clear':
        return ColorTokens.error;
      default:
        return ColorTokens.info;
    }
  }
}

class _StorageDetailPanel extends StatelessWidget {
  final StorageEntry entry;

  const _StorageDetailPanel({required this.entry});

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
                Text('Key', style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 14),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: entry.value?.toString() ?? ''),
                    );
                  },
                  tooltip: 'Copy value',
                  splashRadius: 14,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              entry.key,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorTokens.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text('Value', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            if (entry.value is Map || entry.value is List)
              JsonViewer(data: entry.value, initiallyExpanded: true)
            else
              JsonPrettyViewer(data: entry.value),
            const SizedBox(height: 16),
            Text('Metadata', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            _MetaRow('Type', entry.storageType.name),
            _MetaRow('Operation', entry.operation),
            _MetaRow('Timestamp', time),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 12),
          ),
        ],
      ),
    );
  }
}
