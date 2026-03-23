import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/device_info.dart';
import '../ws_message_handler.dart';
import '../ws_server.dart';

final wsServerProvider = Provider<WsServer>((ref) {
  final server = WsServer();
  ref.onDispose(() => server.dispose());
  return server;
});

final wsMessageHandlerProvider = Provider<WsMessageHandler>((ref) {
  final server = ref.watch(wsServerProvider);
  final handler = WsMessageHandler(server: server);
  ref.onDispose(() => handler.dispose());
  return handler;
});

final connectedDevicesProvider =
    StateNotifierProvider<ConnectedDevicesNotifier, List<DeviceInfo>>((ref) {
  final handler = ref.watch(wsMessageHandlerProvider);
  return ConnectedDevicesNotifier(handler);
});

/// null = show all devices, non-null = filter by this deviceId
final selectedDeviceProvider =
    StateNotifierProvider<SelectedDeviceNotifier, String?>((ref) {
  // Auto-select first device when it connects
  final devices = ref.watch(connectedDevicesProvider);
  final notifier = SelectedDeviceNotifier();
  if (devices.length == 1) {
    notifier.select(devices.first.deviceId);
  }
  return notifier;
});

class ConnectedDevicesNotifier extends StateNotifier<List<DeviceInfo>> {
  ConnectedDevicesNotifier(WsMessageHandler handler) : super([]) {
    handler.onDeviceConnected.listen((device) {
      state = [...state, device];
    });
    handler.onDeviceDisconnected.listen((deviceId) {
      state = state.where((d) => d.deviceId != deviceId).toList();
    });
  }
}

class SelectedDeviceNotifier extends StateNotifier<String?> {
  SelectedDeviceNotifier() : super(null);

  void select(String? deviceId) => state = deviceId;
}
