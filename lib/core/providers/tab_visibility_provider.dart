import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keys matching sidebar route paths (without leading /)
enum TabKey { console, network, state, storage, database, history }

class TabVisibilityNotifier extends StateNotifier<Set<TabKey>> {
  TabVisibilityNotifier() : super(TabKey.values.toSet());

  void toggle(TabKey tab) {
    if (state.contains(tab)) {
      state = {...state}..remove(tab);
    } else {
      state = {...state, tab};
    }
  }

  void enable(TabKey tab) => state = {...state, tab};
  void disable(TabKey tab) => state = {...state}..remove(tab);

  bool isEnabled(TabKey tab) => state.contains(tab);
}

final tabVisibilityProvider =
    StateNotifierProvider<TabVisibilityNotifier, Set<TabKey>>(
  (ref) => TabVisibilityNotifier(),
);

/// Helper to check if a route path is enabled
bool isTabEnabled(Set<TabKey> enabledTabs, String routePath) {
  final key = routePath.replaceAll('/', '');
  for (final tab in TabKey.values) {
    if (tab.name == key) return enabledTabs.contains(tab);
  }
  // All, Settings — always enabled
  return true;
}
