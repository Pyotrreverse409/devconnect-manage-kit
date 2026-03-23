import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

typedef OnConnected = void Function();
typedef OnDisconnected = void Function();

class DevConnectClient {
  static DevConnectClient? _instance;
  static DevConnectClient get instance => _instance!;

  WebSocket? _socket;
  final String _host;
  final int _port;
  final String _appName;
  final String _appVersion;
  final String _deviceName;
  final String _platform;
  final _uuid = const Uuid();
  late final String _deviceId;
  bool _connected = false;
  Timer? _reconnectTimer;

  OnConnected? onConnected;
  OnDisconnected? onDisconnected;

  bool get isConnected => _connected;

  DevConnectClient._({
    required String host,
    required int port,
    required String appName,
    required String appVersion,
    required String deviceName,
    String platform = 'flutter',
  })  : _host = host,
        _port = port,
        _appName = appName,
        _appVersion = appVersion,
        _deviceName = deviceName,
        _platform = platform {
    _deviceId = _uuid.v4();
  }

  static Future<DevConnectClient> init({
    String host = 'localhost',
    int port = 9090,
    required String appName,
    String appVersion = '1.0.0',
    String? deviceName,
    String platform = 'flutter',
  }) async {
    _instance = DevConnectClient._(
      host: host,
      port: port,
      appName: appName,
      appVersion: appVersion,
      deviceName: deviceName ?? Platform.localHostname,
      platform: platform,
    );
    await _instance!.connect();
    return _instance!;
  }

  Future<void> connect() async {
    try {
      _socket = await WebSocket.connect('ws://$_host:$_port');
      _connected = true;

      _socket!.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            final type = msg['type'] as String?;

            if (type == 'server:hello') {
              _sendHandshake();
            } else if (type == 'server:handshake_ack') {
              onConnected?.call();
            }
          } catch (_) {}
        },
        onDone: () {
          _connected = false;
          onDisconnected?.call();
          _scheduleReconnect();
        },
        onError: (_) {
          _connected = false;
          _scheduleReconnect();
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _sendHandshake() {
    _send('client:handshake', {
      'deviceInfo': {
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'platform': _platform,
        'osVersion': Platform.operatingSystemVersion,
        'appName': _appName,
        'appVersion': _appVersion,
        'sdkVersion': '1.0.0',
      },
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_connected) connect();
    });
  }

  void _send(String type, Map<String, dynamic> payload,
      {String? correlationId}) {
    if (_socket == null || !_connected) return;

    final message = {
      'id': _uuid.v4(),
      'type': type,
      'deviceId': _deviceId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'payload': payload,
      if (correlationId != null) 'correlationId': correlationId,
    };

    _socket!.add(jsonEncode(message));
  }

  // --- Public API ---

  /// Internal method used by log interceptor.
  void sendLog({
    required String level,
    required String message,
    String? tag,
    String? stackTrace,
    Map<String, dynamic>? metadata,
  }) {
    _send('client:log', {
      'level': level,
      'message': message,
      if (tag != null) 'tag': tag,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (metadata != null) 'metadata': metadata,
    });
  }

  void log(String message, {String? tag, Map<String, dynamic>? metadata}) {
    _send('client:log', {
      'level': 'info',
      'message': message,
      if (tag != null) 'tag': tag,
      if (metadata != null) 'metadata': metadata,
    });
  }

  void debug(String message, {String? tag, Map<String, dynamic>? metadata}) {
    _send('client:log', {
      'level': 'debug',
      'message': message,
      if (tag != null) 'tag': tag,
      if (metadata != null) 'metadata': metadata,
    });
  }

  void warn(String message, {String? tag, Map<String, dynamic>? metadata}) {
    _send('client:log', {
      'level': 'warn',
      'message': message,
      if (tag != null) 'tag': tag,
      if (metadata != null) 'metadata': metadata,
    });
  }

  void error(String message,
      {String? tag, String? stackTrace, Map<String, dynamic>? metadata}) {
    _send('client:log', {
      'level': 'error',
      'message': message,
      if (tag != null) 'tag': tag,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (metadata != null) 'metadata': metadata,
    });
  }

  void reportNetworkStart({
    required String requestId,
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
  }) {
    _send('client:network:request_start', {
      'requestId': requestId,
      'method': method,
      'url': url,
      'startTime': DateTime.now().millisecondsSinceEpoch,
      if (headers != null) 'requestHeaders': headers,
      if (body != null) 'requestBody': body,
    });
  }

  void reportNetworkComplete({
    required String requestId,
    required String method,
    required String url,
    required int statusCode,
    required int startTime,
    Map<String, String>? requestHeaders,
    Map<String, String>? responseHeaders,
    dynamic requestBody,
    dynamic responseBody,
    String? error,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _send('client:network:request_complete', {
      'requestId': requestId,
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'startTime': startTime,
      'endTime': now,
      'duration': now - startTime,
      if (requestHeaders != null) 'requestHeaders': requestHeaders,
      if (responseHeaders != null) 'responseHeaders': responseHeaders,
      if (requestBody != null) 'requestBody': requestBody,
      if (responseBody != null) 'responseBody': responseBody,
      if (error != null) 'error': error,
    });
  }

  void reportStateChange({
    required String stateManager,
    required String action,
    Map<String, dynamic>? previousState,
    Map<String, dynamic>? nextState,
    List<Map<String, dynamic>>? diff,
  }) {
    _send('client:state:change', {
      'stateManager': stateManager,
      'action': action,
      if (previousState != null) 'previousState': previousState,
      if (nextState != null) 'nextState': nextState,
      if (diff != null) 'diff': diff,
    });
  }

  void reportStorageOperation({
    required String storageType,
    required String key,
    dynamic value,
    required String operation,
  }) {
    _send('client:storage:operation', {
      'storageType': storageType,
      'key': key,
      if (value != null) 'value': value,
      'operation': operation,
    });
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _connected = false;
    await _socket?.close();
    _socket = null;
  }
}
