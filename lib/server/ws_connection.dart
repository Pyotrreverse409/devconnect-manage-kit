import 'dart:convert';
import 'dart:io';

import '../models/device_info.dart';
import 'protocol/dc_message.dart';

class WsConnection {
  final WebSocket socket;
  final DeviceInfo deviceInfo;

  WsConnection({required this.socket, required this.deviceInfo});

  void send(DCMessage message) {
    if (socket.readyState == WebSocket.open) {
      socket.add(jsonEncode(message.toJson()));
    }
  }

  Future<void> close() async {
    await socket.close();
  }
}
