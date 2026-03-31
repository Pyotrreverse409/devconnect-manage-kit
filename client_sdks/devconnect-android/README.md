# DevConnect Manage Kit — Android SDK

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../../LICENSE)
[![Android](https://img.shields.io/badge/Android-SDK%2021%2B-3DDC84?logo=android)](https://developer.android.com)

Debug your Android app with [DevConnect Manage Tool](https://github.com/ridelinktechs/devconnect-manage-kit) — network, state, logs, storage, database, performance — all in one desktop tool.

## Install

```gradle
// settings.gradle.kts
dependencyResolutionManagement {
    repositories {
        maven { url = uri("https://jitpack.io") }
    }
}

// app/build.gradle.kts
dependencies {
    implementation("com.github.ridelinktechs.devconnect-manage-kit:devconnect-manage-android:v1.0.0")
}
```

## Quick Start

```kotlin
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        DevConnect.init(
            context = this,
            appName = "MyApp",
            enabled = BuildConfig.DEBUG,
        )
    }
}
```

## Config

```kotlin
DevConnect.init(
    context = this,
    appName = "MyApp",
    appVersion = "1.0.0",
    host = null,                    // null = auto-detect, "192.168.1.5" = manual
    port = 9090,                    // default: 9090
    enabled = BuildConfig.DEBUG,    // false in release
    autoInterceptLogs = true,       // true = auto-capture println()
)
```

Disable auto-intercept if you want manual control:

```kotlin
DevConnect.init(
    context = this,
    appName = "MyApp",
    autoInterceptLogs = false,      // disable auto — use DevConnect.sendLog() manually
)
```

## Features

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
```

### Logs

```kotlin
// Drop-in replacement for android.util.Log
import com.devconnect.interceptors.DCLog as Log

Log.d("MyTag", "Hello")       // -> Logcat + DevConnect
Log.e("MyTag", "Error", exception)

// Timber
class DevConnectTree : Timber.Tree() {
    override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
        DevConnectTimberHelper.log(priority, tag, message, t)
    }
}
Timber.plant(DevConnectTree())

// Kermit (KMP)
Logger.addLogWriter(DevConnect.kermitWriter())

// Napier (KMP)
Napier.base(DevConnect.napierAntilog())
```

### State

```kotlin
// ViewModel + StateFlow
val observer = DevConnect.stateObserver()
observer.observe(lifecycleScope, viewModel.state, "UserState")

// LiveData
observer.observe(viewLifecycleOwner, viewModel.userLiveData, "UserLiveData")
```

### Storage

Supports: SharedPreferences, DataStore, MMKV, Realm, ObjectBox, SQLDelight.

Each library has 2 options: **auto** (wrap once, everything reported) or **manual** (you control what gets reported). Choose per library.

#### SharedPreferences

```kotlin
// Option 1: Auto — wrap once, all get/put/remove auto-reported
val prefs = DevConnectSharedPrefs.wrap(
    context.getSharedPreferences("my_prefs", Context.MODE_PRIVATE)
)
prefs.edit().putString("token", "abc").apply()  // auto-reported
prefs.getString("token", null)                   // auto-reported

// Option 2: Manual — report only what you want
val sp = DevConnect.sharedPrefsReporter()
prefs.edit().putString("token", "abc").apply()
sp.reportWrite("token", "abc")                   // only this gets reported
```

#### MMKV

```kotlin
// Option 1: Auto
val mmkv = com.devconnect.wrappers.DevConnectMMKV.wrap(MMKV.defaultMMKV())
mmkv.encode("token", "abc")   // auto-reported
mmkv.decodeString("token")     // auto-reported

// Option 2: Manual
val reporter = DevConnect.mmkvReporter()
mmkv.encode("token", "abc")
reporter.reportWrite("token", "abc")
```

#### DataStore, Realm, ObjectBox, SQLDelight (manual only)

```kotlin
// DataStore
val ds = DevConnect.dataStoreReporter()
ds.reportWrite("darkMode", true)
ds.reportRead("darkMode", true)

// Realm
val realm = DevConnect.realmReporter()
realm.reportWrite("User", mapOf("name" to "John"))
realm.reportQuery("User", results)
realm.reportDelete("User", mapOf("id" to 1))

// ObjectBox
val obx = DevConnect.objectBoxReporter()
obx.reportWrite("User", mapOf("name" to "John"))
obx.reportQuery("User", results)

// SQLDelight
val sdl = DevConnect.sqlDelightReporter()
sdl.reportQuery("SELECT * FROM users", results)
sdl.reportExecute("INSERT INTO users (name) VALUES (?)", mapOf("name" to "John"))
```

### Database

Supports: Room, SQLDelight.

```kotlin
// Room
val room = DevConnect.roomReporter()
room.reportQuery("SELECT * FROM users", results)
room.reportInsert("users", rowId)

// SQLDelight
val sdl = DevConnect.sqlDelightReporter()
sdl.reportQuery("SELECT * FROM users", results)
sdl.reportExecute("INSERT INTO users (name) VALUES (?)", mapOf("name" to "John"))
```

### Performance

```kotlin
DevConnect.reportPerformanceMetric(metricType = "fps", value = 58.5, label = "Main Thread FPS")
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

## Production Safety

Disabled when `enabled = false` — zero runtime overhead. Use `BuildConfig.DEBUG` to auto-disable in release.

```kotlin
DevConnect.init(context = this, appName = "MyApp", enabled = BuildConfig.DEBUG)
```

## Links

- [Main Repository](https://github.com/ridelinktechs/devconnect-manage-kit)
- [Desktop App Download](https://github.com/ridelinktechs/devconnect-manage-kit/releases)
- [Full Documentation](https://github.com/ridelinktechs/devconnect-manage-kit#android-native-sdk)

## License

MIT - by [ridelinktechs](https://github.com/ridelinktechs)
