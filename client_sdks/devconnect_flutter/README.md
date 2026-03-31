# DevConnect Manage Kit — Flutter SDK

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../../LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.0-02569B?logo=flutter)](https://flutter.dev)

Debug your Flutter app with [DevConnect Manage Tool](https://github.com/ridelinktechs/devconnect-manage-kit) — network, state, logs, storage, database, performance — all in one desktop tool.

## Install

```yaml
# pubspec.yaml
dependencies:
  devconnect_manage_kit:
    git:
      url: https://github.com/ridelinktechs/devconnect-manage-kit.git
      path: client_sdks/devconnect_flutter
```

## Quick Start

```dart
import 'package:devconnect_manage_kit/devconnect_manage_kit.dart';

void main() async {
  await DevConnect.initAndRunApp(
    appName: 'MyApp',
    runApp: () => runApp(const MyApp()),
  );
  // Done. Network + logs auto-captured.
}
```

## Config

```dart
await DevConnect.initAndRunApp(
  appName: 'MyApp',
  runApp: () => runApp(const MyApp()),
  appVersion: '1.0.0',
  host: null,                  // null = auto-detect
  port: 9090,                  // default: 9090
  enabled: true,               // false = disable (production)
  autoInterceptHttp: true,     // auto-capture all HTTP
  autoInterceptLogs: true,     // auto-capture print/debugPrint
);
```

## Features

### Network

Auto-captured via `HttpOverrides`: http, Dio, Chopper, Retrofit, GraphQL, Firebase, OAuth2, gRPC-web, Image.network.

```dart
// Dio (optional, for extra detail)
dio.interceptors.add(DevConnect.dioInterceptor());
```

### Logs

Auto-captured via Zone: print, debugPrint, logger, talker, logging, fimber, simple_logger.

```dart
DevConnect.log('User logged in');
DevConnect.debug('Token refreshed', tag: 'Auth');
DevConnect.warn('Rate limit approaching');
DevConnect.error('Payment failed', stackTrace: StackTrace.current.toString());
```

### State

Supports: Riverpod, BLoC, Provider/ChangeNotifier, GetX, MobX, Signals.

```dart
// Riverpod
class DevConnectObserver extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderBase p, Object? prev, Object? next, ProviderContainer c) {
    DevConnect.reportStateChange(
      stateManager: 'riverpod',
      action: '${p.name ?? p.runtimeType} updated',
      previousState: {'value': prev.toString()},
      nextState: {'value': next.toString()},
    );
  }
}
```

### Storage

```dart
final reporter = DevConnect.sharedPreferencesReporter();
reporter.reportWrite('token', 'abc123');
reporter.reportRead('token', 'abc123');
reporter.reportDelete('token');
```

### Database

```dart
final driftReporter = DevConnect.driftReporter();
driftReporter.reportQuery('SELECT * FROM users', results);
```

### Performance

```dart
DevConnect.reportPerformanceMetric(metricType: 'fps', value: 58.5, label: 'Main Thread FPS');
```

### Benchmark

```dart
DevConnect.benchmarkStart('loadHome');
await fetchUser();
DevConnect.benchmarkStep('loadHome');
await fetchPosts();
DevConnect.benchmarkStop('loadHome');
```

### Custom Commands

```dart
DevConnect.registerCommand('clearCache', (args) {
  return {'cleared': true};
});
```

## Production Safety

Disabled by default in release builds via `kDebugMode` — zero runtime overhead.

```dart
// Explicitly disable
DevConnect.init(appName: 'MyApp', enabled: false);
```

## Links

- [Main Repository](https://github.com/ridelinktechs/devconnect-manage-kit)
- [Desktop App Download](https://github.com/ridelinktechs/devconnect-manage-kit/releases)
- [Full Documentation](https://github.com/ridelinktechs/devconnect-manage-kit#flutter-sdk)

## License

MIT
