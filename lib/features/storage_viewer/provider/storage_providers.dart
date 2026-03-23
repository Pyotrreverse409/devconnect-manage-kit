import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/storage/storage_entry.dart';
import '../../../server/providers/server_providers.dart';
import '../../../server/ws_message_handler.dart';

final storageEntriesProvider =
    StateNotifierProvider<StorageNotifier, List<StorageEntry>>((ref) {
  final handler = ref.watch(wsMessageHandlerProvider);
  return StorageNotifier(handler);
});

final storageSearchProvider = StateProvider<String>((ref) => '');

final filteredStorageEntriesProvider = Provider<List<StorageEntry>>((ref) {
  final entries = ref.watch(storageEntriesProvider);
  final search = ref.watch(storageSearchProvider).toLowerCase();
  final selectedDevice = ref.watch(selectedDeviceProvider);

  return entries.where((e) {
    if (selectedDevice != null && e.deviceId != selectedDevice) return false;
    if (search.isNotEmpty) {
      return e.key.toLowerCase().contains(search) ||
          (e.value?.toString().toLowerCase().contains(search) ?? false);
    }
    return true;
  }).toList();
});

final selectedStorageEntryProvider =
    StateProvider<StorageEntry?>((ref) => null);

class StorageNotifier extends StateNotifier<List<StorageEntry>> {
  StorageNotifier(WsMessageHandler wsMessageHandler) : super([]) {
    wsMessageHandler.onStorage.listen((entry) {
      // Update existing key or add new
      final index = state.indexWhere(
          (e) => e.key == entry.key && e.storageType == entry.storageType);
      if (index >= 0) {
        final updated = List<StorageEntry>.from(state);
        updated[index] = entry;
        state = updated;
      } else {
        state = [...state, entry];
      }
    });
  }

  void clear() => state = [];
}
