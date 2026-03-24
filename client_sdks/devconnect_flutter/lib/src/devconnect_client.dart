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
  String _host;
  final int _port;
  final String _appName;
  final String _appVersion;
  final String _deviceName;
  final String _platform;
  final bool _auto;
  final _uuid = const Uuid();
  late final String _deviceId;
  bool _connected = false;
  Timer? _reconnectTimer;

  OnConnected? onConnected;
  OnDisconnected? onDisconnected;

  /// Called when desktop dispatches a Redux/BLoC action into the app
  void Function(Map<String, dynamic> action)? onReduxDispatch;
  /// Called when desktop restores a state snapshot
  void Function(Map<String, dynamic> state)? onStateRestore;
  /// Custom command handlers: command name -> handler
  final Map<String, dynamic Function(Map<String, dynamic>?)> _commandHandlers = {};
  /// Active benchmarks
  final Map<String, List<int>> _benchmarks = {}; // title -> [startTime, ...stepTimes]

  bool get isConnected => _connected;
  String get host => _host;
  int get port => _port;

  DevConnectClient._({
    required String host,
    required int port,
    required String appName,
    required String appVersion,
    required String deviceName,
    String platform = 'flutter',
    bool auto_ = true,
  })  : _host = host,
        _port = port,
        _appName = appName,
        _appVersion = appVersion,
        _deviceName = deviceName,
        _platform = platform,
        _auto = auto_ {
    _deviceId = _uuid.v4();
  }

  /// Initialize DevConnect client.
  ///
  /// [host] - Desktop app IP. Leave null or 'auto' for auto-detection.
  /// [port] - WebSocket port (default 9090).
  /// [auto_] - If true (default), auto-detect host when [host] is null/'auto'.
  ///
  /// Auto-detection order:
  /// 1. Android emulator -> 10.0.2.2
  /// 2. iOS simulator -> localhost
  /// 3. Real device -> tries localhost, then common gateway IPs
  static Future<DevConnectClient> init({
    String? host,
    int port = 9090,
    required String appName,
    String appVersion = '1.0.0',
    String? deviceName,
    String platform = 'flutter',
    bool auto_ = true,
  }) async {
    final resolvedHost = host == null || host == 'auto'
        ? await _autoDetectHost(port)
        : host;

    _instance = DevConnectClient._(
      host: resolvedHost,
      port: port,
      appName: appName,
      appVersion: appVersion,
      deviceName: deviceName ?? Platform.localHostname,
      platform: platform,
      auto_: auto_,
    );
    await _instance!.connect();
    return _instance!;
  }

  /// Auto-detect the DevConnect desktop host IP.
  ///
  /// Tries multiple addresses in order and connects to the first one that responds.
  static Future<String> _autoDetectHost(int port) async {
    // Candidate hosts to try
    final candidates = <String>[
      'localhost',       // iOS simulator, macOS, same machine
      '10.0.2.2',       // Android emulator (standard AVD)
      '10.0.3.2',       // Genymotion emulator
      '127.0.0.1',      // Loopback
    ];

    // On Android, try emulator address first
    if (Platform.isAndroid) {
      candidates.insert(0, '10.0.2.2');
    }

    // Try each candidate with a short timeout
    for (final host in candidates) {
      try {
        final socket = await WebSocket.connect(
          'ws://$host:$port',
        ).timeout(const Duration(milliseconds: 800));
        await socket.close();
        return host;
      } catch (_) {
        continue;
      }
    }

    // If nothing found, try to discover via network interfaces
    final gatewayHost = await _tryGatewayHost(port);
    if (gatewayHost != null) return gatewayHost;

    // Fallback
    return Platform.isAndroid ? '10.0.2.2' : 'localhost';
  }

  /// Try to find desktop app on the local network gateway IP.
  static Future<String?> _tryGatewayHost(int port) async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface_ in interfaces) {
        for (final addr in interface_.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            // Try the gateway (x.x.x.1) - common router/host pattern
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              final gatewayIp = '${parts[0]}.${parts[1]}.${parts[2]}.1';
              try {
                final socket = await WebSocket.connect(
                  'ws://$gatewayIp:$port',
                ).timeout(const Duration(milliseconds: 500));
                await socket.close();
                return gatewayIp;
              } catch (_) {}

              // Also try the host IP (for real device on same network)
              // Common pattern: device is x.x.x.Y, desktop is x.x.x.Z
              // We can't know Z, but gateway is a good guess
            }
          }
        }
      }
    } catch (_) {}
    return null;
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
            } else if (type == 'server:redux:dispatch') {
              final action = msg['payload']?['action'] as Map<String, dynamic>?;
              if (action != null) onReduxDispatch?.call(action);
            } else if (type == 'server:state:restore') {
              final state = msg['payload']?['state'] as Map<String, dynamic>?;
              if (state != null) onStateRestore?.call(state);
            } else if (type == 'server:custom:command') {
              final cmd = msg['payload']?['command'] as String?;
              final args = msg['payload']?['args'] as Map<String, dynamic>?;
              if (cmd != null && _commandHandlers.containsKey(cmd)) {
                final result = _commandHandlers[cmd]!(args);
                _send('client:custom:command_result', {
                  'command': cmd,
                  'result': result,
                }, correlationId: msg['correlationId'] as String?);
              }
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
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (!_connected) {
        // If auto mode, re-detect host on reconnect
        if (_auto) {
          _host = await _autoDetectHost(_port);
        }
        connect();
      }
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

  // ---- State snapshot ----

  void sendStateSnapshot({
    required String stateManager,
    required Map<String, dynamic> state,
  }) {
    _send('client:state:snapshot', {
      'stateManager': stateManager,
      'state': state,
    });
  }

  // ---- Benchmark API ----

  void benchmarkStart(String title) {
    _benchmarks[title] = [DateTime.now().millisecondsSinceEpoch];
  }

  void benchmarkStep(String title) {
    _benchmarks[title]?.add(DateTime.now().millisecondsSinceEpoch);
  }

  void benchmarkStop(String title) {
    final times = _benchmarks.remove(title);
    if (times == null || times.isEmpty) return;

    final startTime = times.first;
    final endTime = DateTime.now().millisecondsSinceEpoch;
    final steps = <Map<String, dynamic>>[];
    for (int i = 1; i < times.length; i++) {
      steps.add({
        'title': 'step $i',
        'timestamp': times[i],
        'delta': times[i] - times[i - 1],
      });
    }

    _send('client:benchmark', {
      'title': title,
      'startTime': startTime,
      'endTime': endTime,
      'duration': endTime - startTime,
      'steps': steps,
    });
  }

  // ---- Custom commands ----

  void registerCommand(
      String name, dynamic Function(Map<String, dynamic>?) handler) {
    _commandHandlers[name] = handler;
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _connected = false;
    await _socket?.close();
    _socket = null;
  }
}
