import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/display/display_entry.dart';
import '../../../server/providers/server_providers.dart';

// ---- Display Entries ----

final displayEntriesProvider =
    StateNotifierProvider<DisplayEntriesNotifier, List<DisplayEntry>>((ref) {
  final handler = ref.watch(wsMessageHandlerProvider);
  final notifier = DisplayEntriesNotifier();
  final sub = handler.onDisplay.listen(notifier.add);
  ref.onDispose(() => sub.cancel());
  return notifier;
});

class DisplayEntriesNotifier extends StateNotifier<List<DisplayEntry>> {
  DisplayEntriesNotifier() : super([]);

  void add(DisplayEntry entry) {
    if (state.length >= 5000) {
      state = [...state.sublist(state.length - 4000), entry];
    } else {
      state = [...state, entry];
    }
  }

  void clear() => state = [];
}

// ---- Async Operation Entries ----

final asyncOperationEntriesProvider =
    StateNotifierProvider<AsyncOpEntriesNotifier, List<AsyncOperationEntry>>(
        (ref) {
  final handler = ref.watch(wsMessageHandlerProvider);
  final notifier = AsyncOpEntriesNotifier();
  final sub = handler.onAsyncOperation.listen(notifier.add);
  ref.onDispose(() => sub.cancel());
  return notifier;
});

class AsyncOpEntriesNotifier extends StateNotifier<List<AsyncOperationEntry>> {
  AsyncOpEntriesNotifier() : super([]);

  void add(AsyncOperationEntry entry) {
    if (state.length >= 5000) {
      state = [...state.sublist(state.length - 4000), entry];
    } else {
      state = [...state, entry];
    }
  }

  void clear() => state = [];
}
