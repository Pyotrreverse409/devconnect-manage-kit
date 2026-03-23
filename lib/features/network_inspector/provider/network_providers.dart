import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/network/network_entry.dart';
import '../../../server/providers/server_providers.dart';
import '../../../server/ws_message_handler.dart';

final networkEntriesProvider =
    StateNotifierProvider<NetworkNotifier, List<NetworkEntry>>((ref) {
  final handler = ref.watch(wsMessageHandlerProvider);
  return NetworkNotifier(handler);
});

final networkSearchProvider = StateProvider<String>((ref) => '');
final networkMethodFilterProvider = StateProvider<String?>((ref) => null);

final filteredNetworkEntriesProvider = Provider<List<NetworkEntry>>((ref) {
  final entries = ref.watch(networkEntriesProvider);
  final search = ref.watch(networkSearchProvider).toLowerCase();
  final methodFilter = ref.watch(networkMethodFilterProvider);
  final selectedDevice = ref.watch(selectedDeviceProvider);

  return entries.where((e) {
    if (selectedDevice != null && e.deviceId != selectedDevice) return false;
    if (methodFilter != null && e.method.toUpperCase() != methodFilter) {
      return false;
    }
    if (search.isNotEmpty) {
      return e.url.toLowerCase().contains(search);
    }
    return true;
  }).toList();
});

final selectedNetworkEntryProvider = StateProvider<NetworkEntry?>((ref) => null);

class NetworkNotifier extends StateNotifier<List<NetworkEntry>> {
  NetworkNotifier(WsMessageHandler wsMessageHandler) : super([]) {
    wsMessageHandler.onNetwork.listen((entry) {
      // Update existing or add new
      final index = state.indexWhere((e) => e.id == entry.id);
      if (index >= 0) {
        final updated = List<NetworkEntry>.from(state);
        updated[index] = entry;
        state = updated;
      } else {
        if (state.length > 5000) {
          state = [...state.skip(500), entry];
        } else {
          state = [...state, entry];
        }
      }
    });
  }

  void clear() => state = [];
}
