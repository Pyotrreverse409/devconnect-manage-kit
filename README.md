# DevConnect

Desktop debugging & inspection tool for **Flutter**, **React Native**, and **Android Native** apps.

Like Reactotron, but with better UI, dual theme support, and multi-platform coverage.

```
┌─────────────────────────────────────────────┐
│              DevConnect Desktop              │
│  ┌─────────┐ ┌───────────────────────────┐  │
│  │ Sidebar │ │     Feature Panels        │  │
│  │         │ │  Network | State | Logs   │  │
│  │         │ │  Storage | Database       │  │
│  └─────────┘ └───────────────────────────┘  │
│  ┌─────────────────────────────────────────┐│
│  │     WebSocket Server (port 9090)        ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
        ▲            ▲            ▲
   ┌────┴───┐  ┌─────┴────┐  ┌───┴──────┐
   │Flutter │  │React     │  │Android   │
   │  App   │  │Native App│  │Native App│
   └────────┘  └──────────┘  └──────────┘
```

---

## 1. Desktop App - Download & Open

### macOS (Apple Silicon + Intel)

Download **`DevConnect-macOS-v1.0.0-universal.dmg`** from [Releases](https://github.com/ridelinktechs/devconnect/releases).

Open DMG, drag `DevConnect.app` to Applications. Done.

> Supports both **arm64** (M1/M2/M3/M4) and **x86_64** (Intel) - universal binary.

### Windows

Download **`DevConnect-Windows-v1.0.0.zip`** from [Releases](https://github.com/ridelinktechs/devconnect/releases).

Extract and run `DevConnect.exe`. Done.

### Build from source

```bash
git clone https://github.com/ridelinktechs/devconnect.git
cd devconnect

# macOS
./scripts/build_macos.sh
# -> dist/macos/DevConnect.app
# -> dist/macos/DevConnect-macOS-v1.0.0-universal.dmg

# Windows
./scripts/build_windows.sh
# -> dist/windows/devconnect.exe
```

### Features

- **Console/Logs** - Real-time log viewer with level filters, search, auto-scroll
- **Network Inspector** - Request/response viewer with headers, body, timing
- **State Inspector** - State change timeline with before/after diff
- **Storage Viewer** - SharedPreferences, AsyncStorage, Hive browser
- **Database Viewer** - SQLite browser with SQL query editor
- **Dual Theme** - Dark / Light mode
- **Multi-device** - Connect multiple apps simultaneously

---

## 2. Flutter SDK

### Install

```bash
# From pub.dev (after published)
flutter pub add devconnect_flutter
```

Or from GitHub:

```yaml
# pubspec.yaml
dependencies:
  devconnect_flutter:
    git:
      url: https://github.com/ridelinktechs/devconnect.git
      path: client_sdks/devconnect_flutter
```

### Quick Start

```dart
import 'package:devconnect_flutter/devconnect_flutter.dart';

void main() async {
  await DevConnect.initAndRunApp(
    appName: 'MyApp',
    runApp: () => runApp(const MyApp()),
  );
}
```

Done. This single call auto-captures:
- ALL `print()` / `debugPrint()` calls
- ALL HTTP traffic (http, Dio, Chopper, GraphQL, Firebase, OAuth2...)
- Filters out framework/system logs

### Manual Setup (more control)

```dart
import 'dart:io';
import 'package:devconnect_flutter/devconnect_flutter.dart';

void main() async {
  // 1. Connect to DevConnect desktop
  await DevConnect.init(appName: 'MyApp');

  // 2. Intercept ALL HTTP globally
  HttpOverrides.global = DevConnect.httpOverrides();

  // 3. Capture logs + run app
  DevConnect.runZoned(() => runApp(const MyApp()));
}
```

### Network - Auto-captured HTTP Libraries

`HttpOverrides.global = DevConnect.httpOverrides()` captures everything:

| Library | Auto? |
|---------|-------|
| `http` package | Auto |
| `Dio` | Auto |
| `Chopper` | Auto |
| `Retrofit` (chopper/dio) | Auto |
| `graphql_flutter` / `ferry` / `artemis` | Auto |
| Firebase REST API | Auto |
| OAuth2 (`oauth2`, `flutter_appauth`) | Auto |
| `Image.network()` | Auto |
| gRPC-web | Auto |

Optional Dio-specific interceptor:

```dart
final dio = Dio();
dio.interceptors.add(DevConnect.dioInterceptor());
```

### Logs - Auto-detected Libraries

All these use `print()` internally, so Zone interception catches them:

| Library | Tag in DevConnect |
|---------|-------------------|
| `print()` | `print` |
| `debugPrint()` | `debugPrint` |
| `logger` package | `logger` |
| `talker` package | `talker` |
| `logging` (dart:logging) | logger name |
| `fimber` / `fimber_io` | tag name |
| `simple_logger` | class name |

Manual logging:

```dart
DevConnect.log('User logged in');
DevConnect.debug('Token refreshed', tag: 'Auth');
DevConnect.warn('Rate limit approaching');
DevConnect.error('Payment failed', stackTrace: StackTrace.current.toString());

// Tagged logger
final logger = DevConnect.logger('AuthService');
logger.info('Login success');
logger.error('Token expired');
```

### State Management

```dart
// Riverpod
class DevConnectObserver extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderBase provider, Object? prev, Object? next, ProviderContainer container) {
    DevConnect.reportStateChange(
      stateManager: 'riverpod',
      action: '${provider.name ?? provider.runtimeType} updated',
      previousState: {'value': prev.toString()},
      nextState: {'value': next.toString()},
    );
  }
}

ProviderScope(observers: [DevConnectObserver()], child: MyApp())
```

```dart
// BLoC
class DevConnectBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    DevConnect.reportStateChange(
      stateManager: 'bloc',
      action: '${bloc.runtimeType} changed',
      previousState: {'state': change.currentState.toString()},
      nextState: {'state': change.nextState.toString()},
    );
  }
}

Bloc.observer = DevConnectBlocObserver();
```

### Storage

```dart
final reporter = DevConnect.sharedPreferencesReporter();
reporter.reportWrite('token', 'abc123');
reporter.reportRead('token', 'abc123');
reporter.reportDelete('token');

// Hive
final hiveReporter = DevConnect.hiveReporter();
hiveReporter.reportWrite('settings', {'darkMode': true});
```

### Navigation

```dart
MaterialApp(navigatorObservers: [DevConnect.navigationObserver()])

// GoRouter
GoRouter(observers: [DevConnect.navigationObserver()])
```

---

## 3. React Native SDK

### Install

```bash
# From npm (after published)
yarn add devconnect-react-native
# or
npm install devconnect-react-native
```

Or from GitHub:

```bash
yarn add github:ridelinktechs/devconnect#main
```

### Quick Start

```typescript
import { DevConnect } from 'devconnect-react-native';

// In App.tsx or index.js - before anything else
DevConnect.init({ appName: 'MyApp' });
```

Done. This single call auto-captures:
- ALL `console.log/debug/info/warn/error/trace` calls
- ALL `fetch()` requests
- ALL `XMLHttpRequest` requests
- Filters out RN system logs

### Network - Auto-captured HTTP Libraries

| Library | Auto? |
|---------|-------|
| `fetch()` | Auto |
| `XMLHttpRequest` | Auto |
| `axios` | Auto (uses XHR/fetch) |
| `got` / `ky` / `superagent` | Auto (uses fetch) |
| `apisauce` | Auto (wraps axios) |
| `@tanstack/react-query` | Auto (uses fetch/axios) |
| `Apollo GraphQL` / `urql` | Auto (uses fetch) |
| Firebase REST | Auto |
| OAuth2 token requests | Auto |

Optional axios-specific interceptor (adds Firebase/OAuth2 tagging):

```typescript
import axios from 'axios';
import { setupAxiosInterceptor } from 'devconnect-react-native';

setupAxiosInterceptor(axios);
```

### Logs - All Logging Libraries

`console.*` is auto-patched on init. For third-party libraries:

```typescript
// react-native-logs
import { logger, consoleTransport } from 'react-native-logs';
import { devConnectTransport } from 'devconnect-react-native';

const log = logger.createLogger({
  transport: [consoleTransport, devConnectTransport],
});
```

```typescript
// loglevel
import log from 'loglevel';
import { patchLoglevel } from 'devconnect-react-native';
patchLoglevel(log);
```

```typescript
// pino
import pino from 'pino';
import { pinoDevConnectTransport } from 'devconnect-react-native';
const logger = pino({}, pinoDevConnectTransport());
```

```typescript
// winston
import winston from 'winston';
import { winstonDevConnectTransport } from 'devconnect-react-native';
const logger = winston.createLogger({ transports: [winstonDevConnectTransport] });
```

```typescript
// bunyan
import bunyan from 'bunyan';
import { bunyanDevConnectStream } from 'devconnect-react-native';
const logger = bunyan.createLogger({ name: 'myapp', streams: [{ stream: bunyanDevConnectStream() }] });
```

```typescript
// ANY custom logger
import { wrapLogger } from 'devconnect-react-native';
const wrapped = wrapLogger(myLogger, 'myLoggerName');
```

| Library | Integration | Tag |
|---------|------------|-----|
| `console.log/warn/error` | Auto | `console.log`, `console.warn`... |
| `react-native-logs` | `devConnectTransport` | `rn-logs` |
| `loglevel` | `patchLoglevel(log)` | `loglevel` |
| `pino` | `pinoDevConnectTransport()` | `pino` |
| `winston` | `winstonDevConnectTransport` | `winston` |
| `bunyan` | `bunyanDevConnectStream()` | `bunyan` |
| Any custom | `wrapLogger(logger, name)` | custom |

### State Management

```typescript
// Redux / Redux Toolkit
import { devConnectReduxMiddleware } from 'devconnect-react-native';

// Classic Redux
const store = createStore(rootReducer, applyMiddleware(devConnectReduxMiddleware));

// Redux Toolkit
const store = configureStore({
  reducer: rootReducer,
  middleware: (getDefault) => getDefault().concat(devConnectReduxMiddleware),
});
```

```typescript
// MobX
import { spy } from 'mobx';
import { setupMobxSpy } from 'devconnect-react-native';
setupMobxSpy(spy);
```

### AsyncStorage

```typescript
import AsyncStorage from '@react-native-async-storage/async-storage';
import { DevConnectAsyncStorage } from 'devconnect-react-native';

// Patch in-place (recommended)
DevConnectAsyncStorage.patchInPlace(AsyncStorage);

// Or wrap
const Storage = DevConnectAsyncStorage.wrap(AsyncStorage);
```

---

## 4. Android Native SDK

### Install

```gradle
// app/build.gradle.kts
dependencies {
    // From Maven Central (after published)
    implementation("com.ridelink:devconnect-android:1.0.0")
}
```

Or from JitPack (GitHub):

```gradle
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        maven { url = uri("https://jitpack.io") }
    }
}

// app/build.gradle.kts
dependencies {
    implementation("com.github.ridelinktechs.devconnect:devconnect-android:v1.0.0")
}
```

Or AAR file: download from [Releases](https://github.com/ridelinktechs/devconnect/releases):

```gradle
dependencies {
    implementation(files("libs/devconnect-android-1.0.0.aar"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
```

### Quick Start

```kotlin
// Application.kt
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        DevConnect.init(
            context = this,
            appName = "MyApp",
            host = "10.0.2.2", // emulator -> host (use your PC IP for real device)
        )
    }
}
```

### Network - All HTTP Libraries

```kotlin
// OkHttp (also captures Retrofit, Firebase, OAuth2, Glide, Coil)
val client = OkHttpClient.Builder()
    .addInterceptor(DevConnect.okHttpInterceptor())
    .build()

// Retrofit uses the same OkHttp client
val retrofit = Retrofit.Builder()
    .client(client)
    .baseUrl("https://api.example.com/")
    .build()
```

| Library | How |
|---------|-----|
| OkHttp | `DevConnect.okHttpInterceptor()` |
| Retrofit | Via OkHttp client |
| Ktor (OkHttp engine) | Via OkHttp client |
| Fuel | Via OkHttp client |
| Firebase | Via OkHttp client |
| OAuth2 | Via OkHttp client |
| Glide / Coil | Via OkHttp client |
| Volley | `DevConnectHttpURLConnection` wrapper |
| `HttpURLConnection` | `DevConnectHttpURLConnection.open(url)` |

For Volley:

```kotlin
val stack = object : HurlStack() {
    override fun createConnection(url: URL): HttpURLConnection {
        return DevConnectHttpURLConnection.wrap(super.createConnection(url))
    }
}
val queue = Volley.newRequestQueue(context, stack)
```

### Logs - All Logging Methods

```kotlin
// Option 1: Drop-in replacement for android.util.Log
import com.devconnect.interceptors.DCLog as Log

Log.d("MyTag", "Hello")       // -> DevConnect + logcat
Log.e("MyTag", "Error", exception)
```

```kotlin
// Option 2: Timber
class DevConnectTree : Timber.Tree() {
    override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
        DevConnectTimberHelper.log(priority, tag, message, t)
    }
}

// In Application.onCreate()
Timber.plant(Timber.DebugTree())
Timber.plant(DevConnectTree())
```

```kotlin
// Option 3: Intercept println()
DevConnectLogInterceptor.interceptSystemOut()
```

| Method | How | Tag |
|--------|-----|-----|
| `Log.d/i/w/e()` | `import DCLog as Log` | Your tag |
| `Timber.d/e()` | `DevConnectTree` | Timber tag |
| `println()` | `interceptSystemOut()` | `println` |

### State Management

```kotlin
// ViewModel
fun updateName(name: String) {
    val prev = _state.value
    _state.value = prev.copy(name = name)
    DevConnectViewModelObserver.reportStateUpdate(
        viewModelName = "MyViewModel",
        action = "updateName",
        previousState = mapOf("name" to prev.name),
        nextState = mapOf("name" to name),
    )
}
```

### SharedPreferences

```kotlin
val reporter = DevConnect.sharedPrefsReporter()
reporter.reportWrite("token", "abc123")
reporter.reportRead("token", "abc123")
reporter.reportDelete("token")
```

---

## Architecture

- **Desktop**: Flutter Desktop (macOS/Windows) + Riverpod + go_router + Freezed
- **Protocol**: JSON over WebSocket (port 9090)
- **Client SDKs**: Flutter (pub.dev / git), React Native (npm / git), Android (Maven / JitPack / AAR)

## License

MIT
