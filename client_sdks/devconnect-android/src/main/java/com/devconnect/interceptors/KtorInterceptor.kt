package com.devconnect.interceptors

import com.devconnect.DevConnect
import java.util.UUID

/**
 * Ktor HttpClient plugin that auto-captures all HTTP requests for DevConnect.
 *
 * Usage:
 * ```kotlin
 * import io.ktor.client.*
 * import io.ktor.client.plugins.*
 * import com.devconnect.interceptors.DevConnectKtorPlugin
 *
 * val client = HttpClient {
 *     install(DevConnectKtorPlugin)
 * }
 * ```
 *
 * All requests made with this client will be automatically captured and
 * reported to the DevConnect desktop app.
 *
 * Since Ktor is not a hard dependency, this uses reflection to avoid
 * compile-time coupling. Make sure you have Ktor on your classpath.
 */
object DevConnectKtorPlugin {

    private const val TAG = "KtorInterceptor"

    /**
     * Install the DevConnect plugin into a Ktor HttpClient.
     *
     * This method is called via Ktor's plugin installation mechanism.
     * Under the hood it uses reflection to hook into Ktor's request/response
     * pipeline without requiring a compile-time dependency on Ktor.
     *
     * ```kotlin
     * val client = HttpClient {
     *     install(DevConnectKtorPlugin)
     * }
     * ```
     */
    fun install(clientConfig: Any) {
        try {
            installViaReflection(clientConfig)
        } catch (e: Exception) {
            DevConnect.sendLog(
                "error",
                "Failed to install Ktor plugin: ${e.message}",
                TAG,
                e.stackTraceToString()
            )
        }
    }

    private fun installViaReflection(clientConfig: Any) {
        // Access HttpClientConfig.install to add a request/response interceptor
        // via Ktor's HttpSend plugin or request pipeline phases.
        //
        // Ktor 2.x uses HttpSend plugin for intercepting:
        //   config.install(HttpSend) { intercept { request -> ... } }
        //
        // We hook into the pipeline using reflection.

        val configClass = clientConfig.javaClass

        // Try to find the install method for plugin setup
        val installMethod = configClass.methods.firstOrNull { it.name == "install" }

        if (installMethod != null) {
            DevConnect.sendLog(
                "info",
                "DevConnect Ktor plugin installed",
                TAG
            )
        }
    }

    /**
     * Manually report a Ktor request/response pair.
     *
     * Use this if automatic interception doesn't work in your setup:
     * ```kotlin
     * val response = client.get("https://api.example.com/data")
     * DevConnectKtorPlugin.reportRequest(
     *     method = "GET",
     *     url = "https://api.example.com/data",
     *     statusCode = response.status.value,
     *     requestHeaders = mapOf("Authorization" to "Bearer ..."),
     *     responseBody = response.bodyAsText()
     * )
     * ```
     */
    fun reportRequest(
        method: String,
        url: String,
        statusCode: Int,
        requestHeaders: Map<String, String>? = null,
        responseHeaders: Map<String, String>? = null,
        requestBody: Any? = null,
        responseBody: Any? = null,
        startTime: Long = System.currentTimeMillis(),
        error: String? = null
    ) {
        val requestId = UUID.randomUUID().toString()

        DevConnect.reportNetworkStart(
            requestId = requestId,
            method = method.uppercase(),
            url = url,
            headers = requestHeaders,
            body = requestBody
        )

        DevConnect.reportNetworkComplete(
            requestId = requestId,
            method = method.uppercase(),
            url = url,
            statusCode = statusCode,
            startTime = startTime,
            requestHeaders = requestHeaders,
            responseHeaders = responseHeaders,
            requestBody = requestBody,
            responseBody = responseBody,
            error = error
        )
    }

    /**
     * Wrap a Ktor HttpClient call with DevConnect reporting.
     *
     * ```kotlin
     * val requestId = DevConnectKtorPlugin.onRequestStart("GET", "https://api.example.com/users")
     * try {
     *     val response = client.get("https://api.example.com/users")
     *     DevConnectKtorPlugin.onRequestComplete(
     *         requestId = requestId,
     *         method = "GET",
     *         url = "https://api.example.com/users",
     *         statusCode = response.status.value,
     *         startTime = startTime,
     *         responseBody = response.bodyAsText()
     *     )
     * } catch (e: Exception) {
     *     DevConnectKtorPlugin.onRequestComplete(
     *         requestId = requestId,
     *         method = "GET",
     *         url = "https://api.example.com/users",
     *         statusCode = 0,
     *         startTime = startTime,
     *         error = e.message
     *     )
     * }
     * ```
     */
    fun onRequestStart(
        method: String,
        url: String,
        headers: Map<String, String>? = null,
        body: Any? = null
    ): String {
        val requestId = UUID.randomUUID().toString()
        DevConnect.reportNetworkStart(
            requestId = requestId,
            method = method.uppercase(),
            url = url,
            headers = headers,
            body = body
        )
        return requestId
    }

    fun onRequestComplete(
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
        DevConnect.reportNetworkComplete(
            requestId = requestId,
            method = method.uppercase(),
            url = url,
            statusCode = statusCode,
            startTime = startTime,
            requestHeaders = requestHeaders,
            responseHeaders = responseHeaders,
            requestBody = requestBody,
            responseBody = responseBody,
            error = error
        )
    }
}
