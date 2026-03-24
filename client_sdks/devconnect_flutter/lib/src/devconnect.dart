import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import 'devconnect_client.dart';
import 'interceptors/dio_interceptor.dart';
import 'interceptors/getx_interceptor.dart';
import 'interceptors/http_client_interceptor.dart';
import 'interceptors/log_interceptor.dart';
import 'interceptors/loggy_interceptor.dart';
import 'interceptors/navigation_observer.dart';
import 'reporters/drift_reporter.dart';
import 'reporters/isar_reporter.dart';
import 'reporters/log_reporter.dart';
import 'reporters/mmkv_reporter.dart';
import 'reporters/secure_storage_reporter.dart';
import 'reporters/signals_observer.dart';
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
    String? host,
    int port = 9090,
    bool auto_ = true,
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
      auto_: auto_,
    );

    // Intercept ALL HTTP traffic globally
    HttpOverrides.global = DevConnectHttpOverrides();

    // Run app in zone that captures print() and debugPrint()
    runZoned(runApp);
  }

  /// Initialize DevConnect and connect to desktop app.
  ///
  /// [host] - Desktop IP. Leave null for auto-detect.
  /// [auto_] - Auto-detect host if [host] is null (default: true).
  static Future<void> init({
    required String appName,
    String appVersion = '1.0.0',
    String? host,
    int port = 9090,
    String platform = 'flutter',
    bool auto_ = true,
    bool enabled = true,
  }) async {
    if (!enabled || _initialized) return;
    _initialized = true;

    await DevConnectClient.init(
      host: host,
      port: port,
      appName: appName,
      appVersion: appVersion,
      auto_: auto_,
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

  // ---- GetX / GetConnect ----

  /// GetConnect request modifier that captures outgoing HTTP requests.
  ///
  /// ```dart
  /// httpClient.addRequestModifier(DevConnect.getConnectModifier());
  /// ```
  static dynamic Function(dynamic) getConnectModifier() {
    return DevConnectGetConnectInterceptor().requestModifier();
  }

  /// GetConnect response modifier that captures HTTP responses.
  ///
  /// ```dart
  /// httpClient.addResponseModifier(DevConnect.getConnectResponseModifier());
  /// ```
  static dynamic Function(dynamic, dynamic) getConnectResponseModifier() {
    return DevConnectGetConnectInterceptor().responseModifier();
  }

  /// Returns a GetConnect interceptor instance for full control.
  ///
  /// ```dart
  /// final interceptor = DevConnect.getConnectInterceptor();
  /// httpClient.addRequestModifier(interceptor.requestModifier());
  /// httpClient.addResponseModifier(interceptor.responseModifier());
  /// ```
  static DevConnectGetConnectInterceptor getConnectInterceptor() {
    return DevConnectGetConnectInterceptor();
  }

  // ---- Storage ----

  static DevConnectStorage sharedPreferencesReporter() {
    return const DevConnectStorage(storageType: 'shared_preferences');
  }

  static DevConnectStorage hiveReporter() {
    return const DevConnectStorage(storageType: 'hive');
  }

  /// Reporter for flutter_secure_storage read/write/delete operations.
  ///
  /// Values are masked by default for security.
  ///
  /// ```dart
  /// final reporter = DevConnect.secureStorageReporter();
  /// reporter.reportWrite('token', value: 'abc123');
  /// reporter.reportRead('token', value: token);
  /// reporter.reportDelete('token');
  /// ```
  static DevConnectSecureStorageReporter secureStorageReporter({
    bool maskValues = true,
  }) {
    return DevConnectSecureStorageReporter(maskValues: maskValues);
  }

  /// Reporter for MMKV key-value storage operations.
  ///
  /// ```dart
  /// final reporter = DevConnect.mmkvReporter();
  /// reporter.reportWrite('username', value: 'john');
  /// reporter.reportRead('username', value: username);
  /// reporter.reportDelete('username');
  /// ```
  static DevConnectMmkvReporter mmkvReporter({String? mmkvId}) {
    return DevConnectMmkvReporter(mmkvId: mmkvId);
  }

  // ---- Database ----

  /// Reporter for Drift (moor) database queries.
  ///
  /// ```dart
  /// final reporter = DevConnect.driftReporter();
  /// reporter.reportQuery(sql: 'SELECT * FROM users', duration: elapsed);
  /// ```
  static DevConnectDriftReporter driftReporter() {
    return DevConnectDriftReporter();
  }

  /// Wraps a Drift QueryExecutor to automatically report all SQL queries.
  ///
  /// ```dart
  /// @DriftDatabase(tables: [Todos])
  /// class AppDatabase extends _$AppDatabase {
  ///   AppDatabase(QueryExecutor e) : super(DevConnect.driftQueryExecutor(e));
  /// }
  /// ```
  static DevConnectDriftExecutor driftQueryExecutor(dynamic innerExecutor) {
    return DevConnectDriftExecutor(innerExecutor);
  }

  /// Reporter for Isar database operations.
  ///
  /// ```dart
  /// final reporter = DevConnect.isarReporter();
  /// reporter.reportPut('users', id, data: user.toJson());
  /// reporter.reportQuery('users', filter: 'where().findAll()', resultCount: 10);
  /// reporter.reportDelete('users', 42);
  /// ```
  static DevConnectIsarReporter isarReporter() {
    return DevConnectIsarReporter();
  }

  // ---- State Management ----

  /// Observer for signals / flutter_signals that reports signal value changes.
  ///
  /// ```dart
  /// final observer = DevConnect.signalsObserver();
  /// observer.reportChange('counter', newValue: counter.value);
  /// // Or auto-observe:
  /// observer.observe('counter', counter);
  /// ```
  static DevConnectSignalsObserver signalsObserver() {
    return DevConnectSignalsObserver();
  }

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

  // ---- Loggy ----

  /// Returns a LoggyPrinter-compatible printer that sends logs to DevConnect.
  ///
  /// ```dart
  /// Loggy.initLoggy(
  ///   logPrinter: DevConnect.loggyPrinter(),
  /// );
  /// ```
  ///
  /// Chain with another printer:
  /// ```dart
  /// Loggy.initLoggy(
  ///   logPrinter: DevConnect.loggyPrinter(innerPrinter: const PrettyPrinter()),
  /// );
  /// ```
  static DevConnectLoggyPrinter loggyPrinter({dynamic innerPrinter}) {
    return DevConnectLoggyPrinter(innerPrinter: innerPrinter);
  }
}
