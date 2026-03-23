import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/ws_constants.dart';
import '../models/device_info.dart';
import 'protocol/dc_message.dart';
import 'ws_connection.dart';

typedef MessageCallback = void Function(DCMessage message);

class WsServer {
  HttpServer? _server;
  final Map<String, WsConnection> _connections = {};
  final _uuid = const Uuid();

  final _messageController = StreamController<DCMessage>.broadcast();
  final _connectionController = StreamController<DeviceInfo>.broadcast();
  final _disconnectionController = StreamController<String>.broadcast();

  Stream<DCMessage> get onMessage => _messageController.stream;
  Stream<DeviceInfo> get onConnection => _connectionController.stream;
  Stream<String> get onDisconnection => _disconnectionController.stream;

  Map<String, WsConnection> get connections => Map.unmodifiable(_connections);
  bool get isRunning => _server != null;
  int get port => _server?.port ?? 0;

  Future<void> start({int port = AppConstants.defaultPort}) async {
    if (_server != null) return;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    for (final conn in _connections.values) {
      await conn.close();
    }
    _connections.clear();
    await _server?.close(force: true);
    _server = null;
  }

  void sendToDevice(String deviceId, DCMessage message) {
    final conn = _connections[deviceId];
    if (conn != null) {
      conn.send(message);
    }
  }

  void broadcastMessage(DCMessage message) {
    for (final conn in _connections.values) {
      conn.send(message);
    }
  }

  void _handleRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      _handleWebSocket(socket);
    } else {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'app': AppConstants.appName,
          'version': AppConstants.appVersion,
          'connections': _connections.length,
        }));
      await request.response.close();
    }
  }

  void _handleWebSocket(WebSocket socket) {
    // Send hello
    final helloMsg = DCMessage(
      id: _uuid.v4(),
      type: WsMessageTypes.serverHello,
      deviceId: 'server',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      payload: {'version': AppConstants.appVersion},
    );
    socket.add(jsonEncode(helloMsg.toJson()));

    // Listen for messages
    socket.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          final message = DCMessage.fromJson(json);

          if (message.type == WsMessageTypes.clientHandshake) {
            _handleHandshake(socket, message);
          } else {
            _messageController.add(message);
          }
        } catch (e) {
          // ignore malformed messages
        }
      },
      onDone: () {
        _handleDisconnect(socket);
      },
      onError: (error) {
        _handleDisconnect(socket);
      },
    );
  }

  void _handleHandshake(WebSocket socket, DCMessage message) {
    final deviceInfo = DeviceInfo.fromJson(
      message.payload['deviceInfo'] as Map<String, dynamic>,
    );
    final deviceId = deviceInfo.deviceId;

    final connection = WsConnection(
      socket: socket,
      deviceInfo: deviceInfo.copyWith(connectedAt: DateTime.now()),
    );
    _connections[deviceId] = connection;

    // Send handshake ack
    final ack = DCMessage(
      id: _uuid.v4(),
      type: WsMessageTypes.serverHandshakeAck,
      deviceId: 'server',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      payload: {'sessionId': _uuid.v4(), 'deviceId': deviceId},
    );
    socket.add(jsonEncode(ack.toJson()));

    _connectionController.add(connection.deviceInfo);
  }

  void _handleDisconnect(WebSocket socket) {
    String? disconnectedId;
    _connections.removeWhere((id, conn) {
      if (conn.socket == socket) {
        disconnectedId = id;
        return true;
      }
      return false;
    });
    if (disconnectedId != null) {
      _disconnectionController.add(disconnectedId!);
    }
  }

  void dispose() {
    _messageController.close();
    _connectionController.close();
    _disconnectionController.close();
    stop();
  }
}
