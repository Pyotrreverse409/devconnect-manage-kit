package com.devconnect

import com.devconnect.client.WebSocketClient
import com.devconnect.interceptors.DevConnectKermitWriter
import com.devconnect.interceptors.DevConnectKtorPlugin
import com.devconnect.interceptors.DevConnectNapierAntilog
import com.devconnect.interceptors.OkHttpInterceptor
import com.devconnect.reporters.DataStoreReporter
import com.devconnect.reporters.LogReporter
import com.devconnect.reporters.MmkvReporter
import com.devconnect.reporters.RoomReporter
import com.devconnect.reporters.DevConnectStateObserver
import com.devconnect.reporters.SharedPrefsReporter
import org.json.JSONObject
import java.util.UUID

/**
 * DevConnect Android SDK - Main entry point.
 *
 * ## Quick Start:
 * ```kotlin
 * // In Application.onCreate()
 * DevConnect.init(
 *     context = this,
 *     appName = "MyApp",
 *     appVersion = "1.0.0"
 * )
 * ```
 *
 * ## With OkHttp (auto-intercept ALL network requests):
 * ```kotlin
 * val client = OkHttpClient.Builder()
 *     .addInterceptor(DevConnect.okHttpInterceptor())
 *     .build()
 * ```
 *
 * ## With Retrofit (uses OkHttp under the hood):
 * ```kotlin
 * val client = OkHttpClient.Builder()
 *     .addInterceptor(DevConnect.okHttpInterceptor())
 *     .build()
 *
 * val retrofit = Retrofit.Builder()
 *     .client(client)
 *     .baseUrl("https://api.example.com/")
 *     .build()
 * ```
 *
 * ## With Ktor:
 * ```kotlin
 * val client = HttpClient {
 *     install(DevConnectKtorPlugin)
 * }
 * ```
 *
 * ## With Kermit (KMP logger):
 * ```kotlin
 * Logger.addLogWriter(DevConnectKermitWriter())
 * ```
 *
 * ## With Napier (KMP logger):
 * ```kotlin
 * Napier.base(DevConnectNapierAntilog())
 * ```
 *
 * ## Firebase / OAuth2:
 * Firebase and OAuth2 use OkHttp internally on Android.
 * If you set DevConnect's interceptor on your OkHttpClient,
 * all Firebase REST and OAuth2 token calls will be captured automatically.
 */
object DevConnect {
    private var client: WebSocketClient? = null
    private var enabled = true
    private var deviceId = UUID.randomUUID().toString()

    /**
     * Initialize DevConnect.
     *
     * @param context Android Context (Application preferred)
     * @param appName Your app's name
     * @param appVersion Your app's version
     * @param host Desktop IP. null or "auto" for auto-detection.
     * @param port WebSocket port (default: 9090)
     * @param auto Auto-detect host if not specified (default: true)
     * @param enabled Set false to disable in production
     *
     * Auto-detection tries: 10.0.2.2 (emulator) -> 10.0.3.2 (Genymotion) -> localhost -> 127.0.0.1
     */
    fun init(
        context: Any,
        appName: String,
        appVersion: String = "1.0.0",
        host: String? = null,
        port: Int = 9090,
        auto: Boolean = true,
        enabled: Boolean = true
    ) {
        this.enabled = enabled
        if (!enabled) return

        val resolvedHost = if (host == null || host == "auto") {
            if (auto) autoDetectHost(port) else "10.0.2.2"
        } else {
            host
        }

        client = WebSocketClient(
            host = resolvedHost,
            port = port,
            deviceId = deviceId,
            appName = appName,
            appVersion = appVersion
        )
        client?.connect()
    }

    private fun autoDetectHost(port: Int): String {
        val candidates = listOf("10.0.2.2", "10.0.3.2", "localhost", "127.0.0.1")
        for (candidate in candidates) {
            try {
                val socket = java.net.Socket()
                socket.connect(java.net.InetSocketAddress(candidate, port), 500)
                socket.close()
                return candidate
            } catch (_: Exception) {}
        }
        return "10.0.2.2" // fallback for emulator
    }

    fun isConnected(): Boolean = client?.isConnected == true

    // ---- OkHttp Interceptor ----

    /**
     * Returns an OkHttp Interceptor that captures all HTTP requests.
     *
     * Works with OkHttp, Retrofit, Firebase, OAuth2, Glide, Coil, etc.
     *
     * ```kotlin
     * val client = OkHttpClient.Builder()
     *     .addInterceptor(DevConnect.okHttpInterceptor())
     *     .build()
     * ```
     */
    fun okHttpInterceptor(): OkHttpInterceptor = OkHttpInterceptor()

    // ---- Ktor Plugin ----

    /**
     * Returns the Ktor HttpClient plugin for capturing network requests.
     *
     * ```kotlin
     * val client = HttpClient {
     *     install(DevConnect.ktorPlugin())
     * }
     * ```
     *
     * Or use the plugin object directly:
     * ```kotlin
     * val client = HttpClient {
     *     install(DevConnectKtorPlugin)
     * }
     * ```
     */
    fun ktorPlugin(): DevConnectKtorPlugin = DevConnectKtorPlugin

    // ---- Logging ----

    fun logger(tag: String? = null): LogReporter = LogReporter(tag)

    /**
     * Returns a Kermit LogWriter that sends logs to DevConnect.
     *
     * ```kotlin
     * Logger.addLogWriter(DevConnect.kermitWriter())
     * ```
     */
    fun kermitWriter(): DevConnectKermitWriter = DevConnectKermitWriter()

    /**
     * Returns a Napier Antilog that sends logs to DevConnect.
     *
     * ```kotlin
     * Napier.base(DevConnect.napierAntilog())
     * ```
     */
    fun napierAntilog(): DevConnectNapierAntilog = DevConnectNapierAntilog()

    fun log(message: String, tag: String? = null, metadata: Map<String, Any>? = null) {
        send("client:log", buildPayload {
            put("level", "info")
            put("message", message)
            tag?.let { put("tag", it) }
            metadata?.let { put("metadata", JSONObject(it)) }
        })
    }

    fun debug(message: String, tag: String? = null, metadata: Map<String, Any>? = null) {
        send("client:log", buildPayload {
            put("level", "debug")
            put("message", message)
            tag?.let { put("tag", it) }
            metadata?.let { put("metadata", JSONObject(it)) }
        })
    }

    fun warn(message: String, tag: String? = null, metadata: Map<String, Any>? = null) {
        send("client:log", buildPayload {
            put("level", "warn")
            put("message", message)
            tag?.let { put("tag", it) }
            metadata?.let { put("metadata", JSONObject(it)) }
        })
    }

    fun error(
        message: String,
        tag: String? = null,
        stackTrace: String? = null,
        metadata: Map<String, Any>? = null
    ) {
        send("client:log", buildPayload {
            put("level", "error")
            put("message", message)
            tag?.let { put("tag", it) }
            stackTrace?.let { put("stackTrace", it) }
            metadata?.let { put("metadata", JSONObject(it)) }
        })
    }

    // ---- State Management ----

    /**
     * Get the StateFlow/LiveData observer for reporting state changes.
     *
     * ```kotlin
     * // StateFlow
     * DevConnect.stateObserver().observe(scope, stateFlow, "UserState")
     *
     * // LiveData
     * DevConnect.stateObserver().observe(lifecycleOwner, liveData, "UserState")
     * ```
     */
    fun stateObserver(): DevConnectStateObserver = DevConnectStateObserver

    fun reportStateChange(
        stateManager: String,
        action: String,
        previousState: Map<String, Any>? = null,
        nextState: Map<String, Any>? = null
    ) {
        send("client:state:change", buildPayload {
            put("stateManager", stateManager)
            put("action", action)
            previousState?.let { put("previousState", JSONObject(it)) }
            nextState?.let { put("nextState", JSONObject(it)) }
        })
    }

    // ---- Storage ----

    /**
     * Get a SharedPreferences reporter.
     *
     * ```kotlin
     * val prefsReporter = DevConnect.sharedPrefsReporter()
     * prefsReporter.reportWrite("user_token", "abc123")
     * ```
     */
    fun sharedPrefsReporter(): SharedPrefsReporter = SharedPrefsReporter()

    /**
     * Get a DataStore (Preferences) reporter.
     *
     * ```kotlin
     * val reporter = DevConnect.dataStoreReporter()
     * reporter.reportWrite("darkMode", true)
     * reporter.reportRead("darkMode", true)
     * ```
     */
    fun dataStoreReporter(): DataStoreReporter = DataStoreReporter()

    /**
     * Get a Room database reporter.
     *
     * ```kotlin
     * val reporter = DevConnect.roomReporter()
     * reporter.reportQuery("SELECT * FROM users", results)
     * reporter.reportInsert("users", rowId)
     * ```
     */
    fun roomReporter(): RoomReporter = RoomReporter()

    /**
     * Get an MMKV storage reporter.
     *
     * ```kotlin
     * val reporter = DevConnect.mmkvReporter()
     * reporter.reportWrite("token", "abc123")
     * reporter.reportRead("token", "abc123")
     * reporter.reportDelete("token")
     * ```
     */
    fun mmkvReporter(): MmkvReporter = MmkvReporter()

    fun reportStorageOperation(
        storageType: String,
        key: String,
        value: Any? = null,
        operation: String
    ) {
        send("client:storage:operation", buildPayload {
            put("storageType", storageType)
            put("key", key)
            value?.let { put("value", it) }
            put("operation", operation)
        })
    }

    // ---- Network (internal) ----

    fun reportNetworkStart(
        requestId: String,
        method: String,
        url: String,
        headers: Map<String, String>? = null,
        body: Any? = null
    ) {
        send("client:network:request_start", buildPayload {
            put("requestId", requestId)
            put("method", method)
            put("url", url)
            put("startTime", System.currentTimeMillis())
            headers?.let { put("requestHeaders", JSONObject(it as Map<*, *>)) }
            body?.let { put("requestBody", it) }
        })
    }

    fun reportNetworkComplete(
        requestId: String,
        method: String,
        url: String,
        statusCode: Int,
        startTime: Long,
        requestHeaders: Map<String, String>? = null,
        responseHeaders: Map<String, String>? = null,
        requestBody: Any? = null,
        responseBody: Any? = null,
        error: String? = null
    ) {
        val now = System.currentTimeMillis()
        send("client:network:request_complete", buildPayload {
            put("requestId", requestId)
            put("method", method)
            put("url", url)
            put("statusCode", statusCode)
            put("startTime", startTime)
            put("endTime", now)
            put("duration", now - startTime)
            requestHeaders?.let { put("requestHeaders", JSONObject(it as Map<*, *>)) }
            responseHeaders?.let { put("responseHeaders", JSONObject(it as Map<*, *>)) }
            requestBody?.let { put("requestBody", it) }
            responseBody?.let { put("responseBody", it) }
            error?.let { put("error", it) }
        })
    }

    // ---- Benchmark API ----

    private val benchmarks = mutableMapOf<String, MutableList<Long>>()

    fun benchmarkStart(title: String) {
        benchmarks[title] = mutableListOf(System.currentTimeMillis())
    }

    fun benchmarkStep(title: String) {
        benchmarks[title]?.add(System.currentTimeMillis())
    }

    fun benchmarkStop(title: String) {
        val times = benchmarks.remove(title) ?: return
        val startTime = times.first()
        val endTime = System.currentTimeMillis()

        send("client:benchmark", buildPayload {
            put("title", title)
            put("startTime", startTime)
            put("endTime", endTime)
            put("duration", endTime - startTime)
        })
    }

    // ---- State snapshot ----

    fun sendStateSnapshot(stateManager: String, state: Map<String, Any>) {
        send("client:state:snapshot", buildPayload {
            put("stateManager", stateManager)
            put("state", JSONObject(state))
        })
    }

    // ---- Custom commands ----

    private val commandHandlers = mutableMapOf<String, (Map<String, Any>?) -> Any?>()

    fun registerCommand(name: String, handler: (Map<String, Any>?) -> Any?) {
        commandHandlers[name] = handler
    }

    // ---- Log (internal, used by DCLog/Timber/LogInterceptor) ----

    fun sendLog(
        level: String,
        message: String,
        tag: String? = null,
        stackTrace: String? = null,
        metadata: Map<String, Any>? = null
    ) {
        send("client:log", buildPayload {
            put("level", level)
            put("message", message)
            tag?.let { put("tag", it) }
            stackTrace?.let { put("stackTrace", it) }
            metadata?.let { put("metadata", JSONObject(it)) }
        })
    }

    // ---- Internal ----

    internal fun send(type: String, payload: JSONObject) {
        if (!enabled) return

        val message = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("type", type)
            put("deviceId", deviceId)
            put("timestamp", System.currentTimeMillis())
            put("payload", payload)
        }

        client?.send(message.toString())
    }

    private fun buildPayload(block: JSONObject.() -> Unit): JSONObject {
        return JSONObject().apply(block)
    }
}
