# DevConnect

Desktop debugging & inspection tool for **Flutter**, **React Native**, and **Android Native** apps.

Like Reactotron, but better UI, multi-platform, and auto-detect everything.

---

## Desktop App

### Download

| Platform | File | Architecture |
|----------|------|-------------|
| macOS | `DevConnect-macOS-v1.0.0-universal.dmg` | arm64 + x86_64 |
| Windows | `DevConnect-Windows-v1.0.0.zip` | x64 |

Download from [Releases](https://github.com/ridelinktechs/devconnect/releases).

### Build from source

```bash
git clone https://github.com/ridelinktechs/devconnect.git
cd devconnect
flutter build macos --release   # macOS
flutter build windows --release # Windows
```

### Features

- Console/Logs - real-time log viewer, level filters, search, clear
- Network Inspector - request/response, headers, body, timing, copy cURL, copy response
- State Inspector - state change timeline, before/after diff, snapshot + restore
- Storage Viewer - SharedPreferences, AsyncStorage, Hive, MMKV, SecureStorage
- Database Viewer - SQLite, Drift, Room, Isar with query editor
- Benchmark - performance timing with steps
- Custom Commands - send commands from desktop to app
- Device Panel - connected devices with platform badge, OS version
- ADB Reverse - one-click for Android USB
- Port Config - change WebSocket port in Settings
- Auto-detect Host - SDK auto-finds desktop IP
- Dual Theme - dark / light

---

## Flutter SDK

### Install

```yaml
# pubspec.yaml
dependencies:
  devconnect_flutter:
    git:
      url: https://github.com/ridelinktechs/devconnect.git
      path: client_sdks/devconnect_flutter
```

### Init

```dart
import 'package:devconnect_flutter/devconnect_flutter.dart';

void main() async {
  // Auto-detect: captures all HTTP + logs automatically
  await DevConnect.initAndRunApp(
    appName: 'MyApp',
    runApp: () => runApp(const MyApp()),
  );
}
```

### Config

```dart
await DevConnect.initAndRunApp(
  appName: 'MyApp',
  runApp: () => runApp(const MyApp()),
  appVersion: '1.0.0',
  host: null,              // null = auto-detect, '192.168.1.100' = manual
  port: 9090,              // default: 9090
  enabled: true,           // false = disable (production)
);
```

### Manual Setup

```dart
void main() async {
  await DevConnect.init(appName: 'MyApp');
  HttpOverrides.global = DevConnect.httpOverrides(); // intercept all HTTP
  DevConnect.runZoned(() => runApp(const MyApp()));   // capture logs
}
```

### Network

Auto-captured via `HttpOverrides`: http, Dio, Chopper, Retrofit, GraphQL, Firebase, OAuth2, gRPC-web, Image.network.

```dart
// Dio (optional, for extra detail)
dio.interceptors.add(DevConnect.dioInterceptor());

// GetX GetConnect
final connect = GetConnect();
connect.httpClient.addRequestModifier(DevConnect.getConnectModifier());
connect.httpClient.addResponseModifier(DevConnect.getConnectResponseModifier());
```

### Logs

Auto-captured via Zone: print, debugPrint, logger, talker, logging, fimber, simple_logger.

```dart
// Manual
DevConnect.log('User logged in');
DevConnect.debug('Token refreshed', tag: 'Auth');
DevConnect.warn('Rate limit approaching');
DevConnect.error('Payment failed', stackTrace: StackTrace.current.toString());

// Tagged logger
final logger = DevConnect.logger('AuthService');
logger.info('Login success');

// Loggy
final printer = DevConnect.loggyPrinter();
```

### State

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

```dart
// Signals
final observer = DevConnect.signalsObserver();
observer.observe(mySignal, 'counterSignal');
```

### Storage

```dart
// SharedPreferences
final reporter = DevConnect.sharedPreferencesReporter();
reporter.reportWrite('token', 'abc123');
reporter.reportRead('token', 'abc123');
reporter.reportDelete('token');

// Hive
final hiveReporter = DevConnect.hiveReporter();
hiveReporter.reportWrite('settings', {'darkMode': true});

// flutter_secure_storage
final secureReporter = DevConnect.secureStorageReporter();
secureReporter.reportWrite('token', 'secret');
secureReporter.reportRead('token', '***');

// MMKV
final mmkvReporter = DevConnect.mmkvReporter();
mmkvReporter.reportWrite('key', 'value');
mmkvReporter.reportRead('key', 'value');
```

### Database

```dart
// Drift
final driftReporter = DevConnect.driftReporter();
driftReporter.reportQuery('SELECT * FROM users', results);

// Drift auto-intercept
final executor = DevConnect.driftQueryExecutor(innerExecutor);

// Isar
final isarReporter = DevConnect.isarReporter();
isarReporter.reportQuery('User', results);
isarReporter.reportPut('User', {'name': 'John'});
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

### Navigation

```dart
MaterialApp(navigatorObservers: [DevConnect.navigationObserver()])
GoRouter(observers: [DevConnect.navigationObserver()])
```

---

## React Native SDK

### Install

```bash
yarn add devconnect-react-native
# or from GitHub
yarn add github:ridelinktechs/devconnect#main
```

### Init

```typescript
import { DevConnect } from 'devconnect-react-native';

await DevConnect.init({ appName: 'MyApp' });
// Auto-captures: fetch, XHR, console.log/warn/error
```

### Config

```typescript
await DevConnect.init({
  appName: 'MyApp',
  appVersion: '1.0.0',
  host: undefined,            // undefined = auto-detect, '192.168.1.100' = manual
  port: 9090,                 // default: 9090
  enabled: __DEV__,           // false in production
  autoInterceptFetch: true,
  autoInterceptXHR: true,
  autoInterceptConsole: true,
});
```

### Network

Auto-captured: fetch, XHR, axios, got, ky, superagent, apisauce, Apollo, urql, TanStack Query, SWR, RTK Query, ofetch, wretch, redaxios, Firebase, OAuth2.

```typescript
// Axios (optional, for extra tagging)
import { setupAxiosInterceptor } from 'devconnect-react-native';
setupAxiosInterceptor(axios);
```

### Logs

Auto-captured: console.log, console.debug, console.info, console.warn, console.error, console.trace. Also auto-captures: consola, debug, tslog, signale (they use console internally).

```typescript
// Manual
DevConnect.log('User logged in');
DevConnect.debug('Debug info', 'Auth');
DevConnect.warn('Warning');
DevConnect.error('Error', 'Tag', stackTrace);

// react-native-logs
import { devConnectTransport } from 'devconnect-react-native';
const log = logger.createLogger({ transport: [consoleTransport, devConnectTransport] });

// loglevel
import { patchLoglevel } from 'devconnect-react-native';
patchLoglevel(log);

// pino
import { pinoDevConnectTransport } from 'devconnect-react-native';
const logger = pino({}, pinoDevConnectTransport());

// winston
import { winstonDevConnectTransport } from 'devconnect-react-native';

// bunyan
import { bunyanDevConnectStream } from 'devconnect-react-native';

// Any custom logger
import { wrapLogger } from 'devconnect-react-native';
const wrapped = wrapLogger(myLogger, 'myLoggerName');
```

### State

```typescript
// Redux / Redux Toolkit
import { devConnectReduxMiddleware } from 'devconnect-react-native';
const store = configureStore({
  reducer: rootReducer,
  middleware: (getDefault) => getDefault().concat(devConnectReduxMiddleware),
});

// Dispatch from desktop
DevConnect.connectReduxStore(store);

// MobX
import { setupMobxSpy } from 'devconnect-react-native';
setupMobxSpy(spy);

// Zustand
import { devConnectMiddleware } from 'devconnect-react-native';
const useStore = create(devConnectMiddleware((set) => ({
  count: 0,
  increment: () => set((s) => ({ count: s.count + 1 })),
}), 'MyStore'));

// Jotai
import { devConnectAtomEffect } from 'devconnect-react-native';

// Valtio
import { watchValtio } from 'devconnect-react-native';
const state = proxy({ count: 0 });
watchValtio(state, 'MyState');

// XState
import { devConnectXStateInspector } from 'devconnect-react-native';
const service = interpret(machine).onTransition(devConnectXStateInspector('MyMachine'));
```

### Storage

```typescript
// AsyncStorage
import { DevConnectAsyncStorage } from 'devconnect-react-native';
DevConnectAsyncStorage.patchInPlace(AsyncStorage);

// MMKV
import { DevConnectMMKV } from 'devconnect-react-native';
DevConnectMMKV.wrap(storage);
```

### Benchmark

```typescript
DevConnect.benchmark('loadUserData');
await fetchUser();
DevConnect.benchmarkStep('loadUserData', 'fetched user');
await fetchPosts();
DevConnect.benchmarkStop('loadUserData');
```

### Custom Commands

```typescript
DevConnect.registerCommand('clearCache', () => {
  AsyncStorage.clear();
  return { success: true };
});
```

### State Snapshot + Restore

```typescript
DevConnect.sendStateSnapshot('redux', store.getState());
DevConnect.onStateRestore((state) => {
  store.dispatch({ type: 'RESTORE_STATE', payload: state });
});
```

---

## Android Native SDK

### Install

```gradle
// JitPack
dependencies {
    implementation("com.github.ridelinktechs.devconnect:devconnect-android:v1.0.0")
}

// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        maven { url = uri("https://jitpack.io") }
    }
}
```

### Init

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        DevConnect.init(
            context = this,
            appName = "MyApp",
        )
    }
}
```

### Config

```kotlin
DevConnect.init(
    context = this,
    appName = "MyApp",
    appVersion = "1.0.0",
    host = null,                 // null = auto-detect, "192.168.1.100" = manual
    port = 9090,                 // default: 9090
    enabled = BuildConfig.DEBUG, // false in release
)
```

### Network

```kotlin
// OkHttp (captures Retrofit, Firebase, OAuth2, Glide, Coil)
val client = OkHttpClient.Builder()
    .addInterceptor(DevConnect.okHttpInterceptor())
    .build()

// Ktor
val client = HttpClient {
    install(DevConnect.ktorPlugin())
}

// Volley
val stack = object : HurlStack() {
    override fun createConnection(url: URL): HttpURLConnection {
        return DevConnectHttpURLConnection.wrap(super.createConnection(url))
    }
}
```

### Logs

```kotlin
// Drop-in replacement for android.util.Log
import com.devconnect.interceptors.DCLog as Log
Log.d("MyTag", "Hello")
Log.e("MyTag", "Error", exception)

// Timber
Timber.plant(DevConnectTree())

// Intercept println()
DevConnectLogInterceptor.interceptSystemOut()

// Kermit (KMP)
Logger.addLogWriter(DevConnect.kermitWriter())

// Napier (KMP)
Napier.base(DevConnect.napierAntilog())

// Manual
DevConnect.sendLog("info", "User logged in", tag = "Auth")
```

### State

```kotlin
// ViewModel (manual)
DevConnectViewModelObserver.reportStateUpdate(
    viewModelName = "MyViewModel",
    action = "updateName",
    previousState = mapOf("name" to prev),
    nextState = mapOf("name" to next),
)

// StateFlow (auto-observe)
DevConnect.stateObserver().observe(scope, stateFlow, "UserState")

// LiveData (auto-observe)
DevConnect.stateObserver().observe(lifecycleOwner, liveData, "UserState")
```

### Storage

```kotlin
// SharedPreferences
val reporter = DevConnect.sharedPrefsReporter()
reporter.reportWrite("token", "abc123")
reporter.reportRead("token", "abc123")
reporter.reportDelete("token")

// DataStore
val dsReporter = DevConnect.dataStoreReporter()
dsReporter.reportWrite("darkMode", true)
dsReporter.reportRead("darkMode", true)

// MMKV
val mmkvReporter = DevConnect.mmkvReporter()
mmkvReporter.reportWrite("key", "value")
mmkvReporter.reportRead("key", "value")
```

### Database

```kotlin
// Room
val roomReporter = DevConnect.roomReporter()
roomReporter.reportQuery("SELECT * FROM users", results)
roomReporter.reportInsert("users", rowId)
```

### Benchmark

```kotlin
DevConnect.benchmarkStart("loadHome")
fetchUser()
DevConnect.benchmarkStep("loadHome")
fetchPosts()
DevConnect.benchmarkStop("loadHome")
```

### Custom Commands

```kotlin
DevConnect.registerCommand("clearCache") { args ->
    mapOf("cleared" to true)
}
```

---

## Real Device Connection

### Auto-detect (default)

SDK tries these addresses in order:
1. `localhost` (iOS simulator, macOS)
2. `10.0.2.2` (Android emulator)
3. `10.0.3.2` (Genymotion)
4. Scan local network subnet

### Manual IP

Check your desktop IP in **Settings** page (click to copy), then:

```dart
await DevConnect.init(appName: 'MyApp', host: '192.168.1.5');
```

### Android USB

In desktop **Settings > Android Device (USB)**, click **"Run ADB Reverse"**.

Or manually: `adb reverse tcp:9090 tcp:9090`

---

## Architecture

- **Desktop**: Flutter Desktop (macOS/Windows) + Riverpod + go_router + Freezed
- **Protocol**: JSON over WebSocket (default port 9090)
- **SDKs**: Flutter (pub.dev / git), React Native (npm / git), Android (Maven / JitPack / AAR)

## License

MIT
