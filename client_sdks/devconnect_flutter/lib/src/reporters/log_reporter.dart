import '../devconnect_client.dart';

/// Convenience class for logging to DevConnect.
///
/// Usage:
/// ```dart
/// final logger = DevConnectLogger(tag: 'AuthService');
/// logger.info('User logged in');
/// logger.error('Login failed', stackTrace: StackTrace.current.toString());
/// ```
class DevConnectLogger {
  final String? tag;

  const DevConnectLogger({this.tag});

  void debug(String message, {Map<String, dynamic>? metadata}) {
    DevConnectClient.instance.debug(message, tag: tag, metadata: metadata);
  }

  void info(String message, {Map<String, dynamic>? metadata}) {
    DevConnectClient.instance.log(message, tag: tag, metadata: metadata);
  }

  void warn(String message, {Map<String, dynamic>? metadata}) {
    DevConnectClient.instance.warn(message, tag: tag, metadata: metadata);
  }

  void error(String message,
      {String? stackTrace, Map<String, dynamic>? metadata}) {
    DevConnectClient.instance
        .error(message, tag: tag, stackTrace: stackTrace, metadata: metadata);
  }
}
