package com.devconnect

import com.devconnect.client.WebSocketClient
import com.devconnect.interceptors.OkHttpInterceptor
import com.devconnect.reporters.LogReporter
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
     * @param host DevConnect desktop IP (default: 10.0.2.2 for emulator, localhost for device)
     * @param port WebSocket port (default: 9090)
     * @param enabled Set false to disable in production
     */
    fun init(
        context: Any,
        appName: String,
        appVersion: String = "1.0.0",
        host: String = "10.0.2.2", // Android emulator -> host machine
        port: Int = 9090,
        enabled: Boolean = true
    ) {
        this.enabled = enabled
        if (!enabled) return

        client = WebSocketClient(
            host = host,
            port = port,
            deviceId = deviceId,
            appName = appName,
            appVersion = appVersion
        )
        client?.connect()
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

    // ---- Logging ----

    fun logger(tag: String? = null): LogReporter = LogReporter(tag)

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
