import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../components/feedback/empty_state.dart';
import '../../../../components/inputs/scroll_direction_button.dart';
import '../../../../components/inputs/search_field.dart';
import '../../../../components/viewers/json_viewer.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../models/state/state_change.dart';
import '../../provider/state_providers.dart';

class StateInspectorPage extends ConsumerStatefulWidget {
  const StateInspectorPage({super.key});

  @override
  ConsumerState<StateInspectorPage> createState() =>
      _StateInspectorPageState();
}

class _StateInspectorPageState extends ConsumerState<StateInspectorPage> {
  static const _pageSize = 50;

  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  int _maxVisible = 50;
  bool _loadingMore = false;
  int _previousCount = 0;

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
      if (pos.pixels < 50) _loadMore();
    } else {
      if (pos.pixels > pos.maxScrollExtent - 50) _loadMore();
    }
  }

  void _loadMore() {
    final entries = ref.read(filteredStateChangesProvider);
    if (_maxVisible >= entries.length) return;

    _loadingMore = true;
    final scrollDir = ref.read(scrollDirectionProvider);
    final oldMaxExtent = _scrollController.position.maxScrollExtent;

    setState(() {
      _maxVisible = (_maxVisible + _pageSize).clamp(0, entries.length);
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && scrollDir == ScrollDirection.bottom) {
        final newMaxExtent = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(
          _scrollController.offset + (newMaxExtent - oldMaxExtent),
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
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToTarget();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(filteredStateChangesProvider);
    final selected = ref.watch(selectedStateChangeProvider);
    final theme = Theme.of(context);

    // Reset pagination when scroll direction changes
    final scrollDir = ref.watch(scrollDirectionProvider);
    ref.listen<ScrollDirection>(scrollDirectionProvider, (prev, next) {
      if (prev != next) {
        setState(() => _maxVisible = _pageSize);
        SchedulerBinding.instance
            .addPostFrameCallback((_) => _scrollToTarget());
      }
    });

    // Slice visible items based on scroll direction
    final List<StateChange> visibleEntries;
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

    // Auto-scroll when new items arrive and autoScroll is on
    if (_autoScroll && entries.length > _previousCount && entries.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _scrollToTarget();
      });
    }
    _previousCount = entries.length;

    return Column(
      children: [
        _Toolbar(
          totalCount: entries.length,
          visibleCount: visibleEntries.length,
          autoScroll: _autoScroll,
          onToggleAutoScroll: _toggleAutoScroll,
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? const EmptyState(
                  icon: LucideIcons.layers,
                  title: 'No state changes',
                  subtitle:
                      'Redux, BLoC, Riverpod, and MobX state changes appear here',
                )
              : Row(
                  children: [
                    // Timeline
                    Expanded(
                      flex: selected != null ? 2 : 1,
                      child: Column(
                        children: [
                          if (hasMore && scrollDir == ScrollDirection.bottom)
                            GestureDetector(
                              onTap: _loadMore,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  color: ColorTokens.primary
                                      .withValues(alpha: 0.05),
                                  child: Center(
                                    child: Text(
                                      '${entries.length - visibleEntries.length} older changes — tap to load more',
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
                              itemCount: visibleEntries.length,
                              itemExtent: 52,
                              itemBuilder: (context, index) {
                                final entry = visibleEntries[index];
                                final isSelected = selected?.id == entry.id;
                                return _StateChangeTile(
                                  key: ValueKey(entry.id),
                                  entry: entry,
                                  isSelected: isSelected,
                                  onTap: () {
                                    ref
                                        .read(selectedStateChangeProvider
                                            .notifier)
                                        .state = isSelected ? null : entry;
                                  },
                                );
                              },
                            ),
                          ),
                          if (hasMore && scrollDir == ScrollDirection.top)
                            GestureDetector(
                              onTap: _loadMore,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  color: ColorTokens.primary
                                      .withValues(alpha: 0.05),
                                  child: Center(
                                    child: Text(
                                      '${entries.length - visibleEntries.length} older changes — tap to load more',
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
                        ],
                      ),
                    ),
                    if (selected != null) ...[
                      VerticalDivider(width: 1, color: theme.dividerColor),
                      Expanded(
                        child: _StateDetailPanel(entry: selected),
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
  final int totalCount;
  final int visibleCount;
  final bool autoScroll;
  final VoidCallback onToggleAutoScroll;

  const _Toolbar({
    required this.totalCount,
    required this.visibleCount,
    required this.autoScroll,
    required this.onToggleAutoScroll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final countText = visibleCount != totalCount
        ? '$visibleCount / $totalCount changes'
        : '$totalCount changes';

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
      ),
      child: Row(
        children: [
          Icon(LucideIcons.layers, size: 16, color: ColorTokens.primary),
          const SizedBox(width: 8),
          Text('State Inspector', style: theme.textTheme.titleMedium),
          const SizedBox(width: 8),
          Text(countText, style: theme.textTheme.bodySmall),
          const Spacer(),
          GestureDetector(
            onTap: onToggleAutoScroll,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: autoScroll
                      ? ColorTokens.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: autoScroll
                        ? ColorTokens.primary.withValues(alpha: 0.4)
                        : Colors.grey.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.arrowDownToLine,
                        size: 11,
                        color:
                            autoScroll ? ColorTokens.primary : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'AUTO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color:
                            autoScroll ? ColorTokens.primary : Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          const ScrollDirectionButton(),
          const SizedBox(width: 8),
          SizedBox(
            width: 200,
            child: SearchField(
              hintText: 'Filter actions...',
              onChanged: (v) =>
                  ref.read(stateSearchProvider.notifier).state = v,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => ref.read(stateChangesProvider.notifier).clear(),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child:
                  Icon(LucideIcons.trash2, size: 14, color: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateChangeTile extends StatelessWidget {
  final StateChange entry;
  final bool isSelected;
  final VoidCallback onTap;

  const _StateChangeTile({
    super.key,
    required this.entry,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final time = DateFormat('HH:mm:ss.SSS').format(
      DateTime.fromMillisecondsSinceEpoch(entry.timestamp),
    );

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: ColorTokens.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      entry.stateManagerType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.secondary,
                      ),
                    ),
                  ),
                  const Spacer(),
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
              const SizedBox(height: 4),
              Text(
                entry.actionName,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (entry.diff.isNotEmpty)
                Text(
                  '${entry.diff.length} change${entry.diff.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateDetailPanel extends StatelessWidget {
  final StateChange entry;

  const _StateDetailPanel({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(LucideIcons.gitCommitHorizontal,
                          size: 16, color: ColorTokens.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.actionName,
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [
                    Tab(text: 'Diff'),
                    Tab(text: 'Before'),
                    Tab(text: 'After'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Diff tab
                _DiffView(diff: entry.diff),
                // Before tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: JsonViewer(
                    data: entry.previousState,
                    initiallyExpanded: true,
                  ),
                ),
                // After tab
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: JsonViewer(
                    data: entry.nextState,
                    initiallyExpanded: true,
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

class _DiffView extends StatelessWidget {
  final List<StateDiffEntry> diff;

  const _DiffView({required this.diff});

  @override
  Widget build(BuildContext context) {
    if (diff.isEmpty) {
      return const EmptyState(
        icon: LucideIcons.equal,
        title: 'No changes detected',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: diff.length,
      itemBuilder: (context, index) {
        final d = diff[index];
        Color opColor;
        IconData opIcon;
        switch (d.operation) {
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
            opIcon = LucideIcons.arrowRight;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: opColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: opColor.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(opIcon, size: 12, color: opColor),
                  const SizedBox(width: 6),
                  Text(
                    d.path,
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: opColor,
                    ),
                  ),
                ],
              ),
              if (d.oldValue != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '- ',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: ColorTokens.error,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${d.oldValue}',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          color: ColorTokens.error.withValues(alpha: 0.8),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (d.newValue != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '+ ',
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        color: ColorTokens.success,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${d.newValue}',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 11,
                          color: ColorTokens.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
