import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'devconnect_client.dart';
import 'interceptors/dio_interceptor.dart';
import 'interceptors/http_client_interceptor.dart';
import 'interceptors/log_interceptor.dart';
import 'interceptors/navigation_observer.dart';
import 'reporters/log_reporter.dart';
import 'reporters/storage_reporter.dart';

/// DevConnect Flutter SDK - Main entry point.
///
/// ## Minimal setup (captures ALL HTTP + ALL developer logs):
/// ```dart
/// void main() {
///   DevConnect.runApp(
///     appName: 'MyApp',
///     app: const MyApp(),
///   );
/// }
/// ```
///
/// ## Or manual setup:
/// ```dart
/// void main() async {
///   await DevConnect.init(appName: 'MyApp');
///   HttpOverrides.global = DevConnect.httpOverrides();
///   DevConnect.runZoned(() => runApp(const MyApp()));
/// }
/// ```
class DevConnect {
  DevConnect._();

  static DevConnectClient get client => DevConnectClient.instance;
  static bool _initialized = false;

  /// One-line setup: init + intercept ALL HTTP + capture ALL developer logs.
  ///
  /// ```dart
  /// void main() {
  ///   DevConnect.runApp(
  ///     appName: 'MyApp',
  ///     app: const MyApp(),
  ///   );
  /// }
  /// ```
  ///
  /// This single call:
  /// - Connects to DevConnect desktop
  /// - Intercepts ALL HTTP (http, Dio, Chopper, GraphQL, Firebase, OAuth2...)
  /// - Captures print(), debugPrint(), log() from dart:developer
  /// - Does NOT capture framework/system logs, only YOUR code's print statements
  /// One-line setup that wraps your runApp call.
  ///
  /// ```dart
  /// void main() async {
  ///   await DevConnect.initAndRunApp(
  ///     appName: 'MyApp',
  ///     runApp: () => runApp(const MyApp()),
  ///   );
  /// }
  /// ```
  ///
  /// This single call:
  /// - Connects to DevConnect desktop
  /// - Intercepts ALL HTTP (http, Dio, Chopper, GraphQL, Firebase, OAuth2...)
  /// - Captures print(), debugPrint(), log() from dart:developer
  /// - Does NOT capture framework/system logs, only YOUR code's print statements
  static Future<void> initAndRunApp({
    required String appName,
    required void Function() runApp,
    String appVersion = '1.0.0',
    String host = 'localhost',
    int port = 9090,
    bool enabled = true,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    if (!enabled) {
      runApp();
      return;
    }

    await init(
      appName: appName,
      appVersion: appVersion,
      host: host,
      port: port,
    );

    // Intercept ALL HTTP traffic globally
    HttpOverrides.global = DevConnectHttpOverrides();

    // Run app in zone that captures print() and debugPrint()
    runZoned(runApp);
  }

  /// Initialize DevConnect and connect to desktop app.
  static Future<void> init({
    required String appName,
    String appVersion = '1.0.0',
    String host = 'localhost',
    int port = 9090,
    String platform = 'flutter',
    bool enabled = true,
  }) async {
    if (!enabled || _initialized) return;
    _initialized = true;

    await DevConnectClient.init(
      host: host,
      port: port,
      appName: appName,
      appVersion: appVersion,
      deviceName: Platform.localHostname,
      platform: platform,
    );
  }

  /// Run a callback in a Zone that captures print() and debugPrint().
  ///
  /// Only captures developer-placed print statements, NOT framework logs.
  ///
  /// ```dart
  /// DevConnect.runZoned(() {
  ///   runApp(const MyApp());
  /// });
  /// ```
  static R runZoned<R>(R Function() body) {
    return DevConnectLogInterceptor.runZoned(body);
  }

  // ---- HTTP Interceptors ----

  /// Global HttpOverrides - intercepts ALL HTTP in the entire app.
  ///
  /// Captures: http package, Dio, Chopper, Retrofit, GraphQL (graphql_flutter,
  /// ferry, artemis), Firebase REST, OAuth2, image loading, gRPC-web, and ANY
  /// library that uses dart:io HttpClient under the hood.
  ///
  /// ```dart
  /// HttpOverrides.global = DevConnect.httpOverrides();
  /// ```
  static DevConnectHttpOverrides httpOverrides() {
    return DevConnectHttpOverrides();
  }

  /// Dio-specific interceptor for granular control.
  ///
  /// Use this if you want to intercept only specific Dio instances
  /// instead of all HTTP globally.
  ///
  /// ```dart
  /// dio.interceptors.add(DevConnect.dioInterceptor());
  /// ```
  static DevConnectDioInterceptor dioInterceptor() {
    return DevConnectDioInterceptor();
  }

  // ---- Navigation ----

  static DevConnectNavigationObserver navigationObserver() {
    return DevConnectNavigationObserver();
  }

  // ---- Logging ----

  static DevConnectLogger logger([String? tag]) {
    return DevConnectLogger(tag: tag);
  }

  static void log(String message,
          {String? tag, Map<String, dynamic>? metadata}) =>
      client.log(message, tag: tag, metadata: metadata);

  static void debug(String message,
          {String? tag, Map<String, dynamic>? metadata}) =>
      client.debug(message, tag: tag, metadata: metadata);

  static void warn(String message,
          {String? tag, Map<String, dynamic>? metadata}) =>
      client.warn(message, tag: tag, metadata: metadata);

  static void error(String message,
          {String? tag,
          String? stackTrace,
          Map<String, dynamic>? metadata}) =>
      client.error(message,
          tag: tag, stackTrace: stackTrace, metadata: metadata);

  // ---- Storage ----

  static DevConnectStorage sharedPreferencesReporter() {
    return const DevConnectStorage(storageType: 'shared_preferences');
  }

  static DevConnectStorage hiveReporter() {
    return const DevConnectStorage(storageType: 'hive');
  }

  // ---- State Management ----

  static void reportStateChange({
    required String stateManager,
    required String action,
    Map<String, dynamic>? previousState,
    Map<String, dynamic>? nextState,
    List<Map<String, dynamic>>? diff,
  }) {
    client.reportStateChange(
      stateManager: stateManager,
      action: action,
      previousState: previousState,
      nextState: nextState,
      diff: diff,
    );
  }
}
