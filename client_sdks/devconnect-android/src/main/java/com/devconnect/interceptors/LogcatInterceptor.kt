package com.devconnect.interceptors

import com.devconnect.DevConnect

/**
 * Square Logcat integration - captures logs from logcat {} calls.
 *
 * Integrates with Square's Logcat library (https://github.com/square/logcat).
 *
 * Usage:
 * ```kotlin
 * // In Application.onCreate():
 * DevConnectLogcatInterceptor.install()
 *
 * // Now all logcat {} calls are captured by DevConnect:
 * logcat { "User logged in" }
 * logcat(LogPriority.WARN) { "Token expiring soon" }
 * ```
 *
 * This works by installing a custom LogcatLogger that forwards logs to
 * DevConnect while also printing to the standard Android logcat.
 *
 * Since Square Logcat is not a hard dependency, this uses reflection to
 * avoid compile-time coupling. Make sure you have `com.squareup.logcat:logcat`
 * on your classpath.
 */
object DevConnectLogcatInterceptor {

    private const val TAG = "LogcatInterceptor"
    private var installed = false

    /**
     * Install the DevConnect logcat interceptor.
     *
     * This patches Square Logcat's logger to forward all log messages
     * to DevConnect in addition to the standard Android logcat output.
     *
     * ```kotlin
     * DevConnectLogcatInterceptor.install()
     * ```
     *
     * Safe to call multiple times - subsequent calls are no-ops.
     */
    fun install() {
        if (installed) return
        installed = true

        try {
            installViaReflection()
        } catch (e: Exception) {
            DevConnect.sendLog(
                "warn",
                "Failed to install Logcat interceptor: ${e.message}. " +
                    "Make sure com.squareup.logcat:logcat is on your classpath.",
                TAG,
                e.stackTraceToString()
            )
        }
    }

    private fun installViaReflection() {
        // Square Logcat uses LogcatLogger.install() to set up logging.
        // We wrap the logger to also forward to DevConnect.
        //
        // LogcatLogger has a companion object with:
        //   fun install(logger: LogcatLogger)
        //
        // The default AndroidLogcatLogger implements:
        //   fun log(priority: LogPriority, tag: String, message: String)

        val logcatLoggerClass = Class.forName("logcat.LogcatLogger")
        val companionField = logcatLoggerClass.getDeclaredField("Companion")
        companionField.isAccessible = true
        val companion = companionField.get(null)

        // Create a proxy that intercepts log calls
        val androidLoggerClass = try {
            Class.forName("logcat.AndroidLogcatLogger")
        } catch (_: Exception) {
            null
        }

        // Use a dynamic proxy to intercept the log method
        val logcatLoggerInterfaces = arrayOf(logcatLoggerClass)

        val proxy = java.lang.reflect.Proxy.newProxyInstance(
            logcatLoggerClass.classLoader,
            logcatLoggerInterfaces
        ) { _, method, args ->
            if (method.name == "log" && args != null && args.size >= 3) {
                val priority = args[0] // LogPriority enum
                val tag = args[1] as? String ?: "Logcat"
                val message = args[2] as? String ?: ""

                // Forward to DevConnect
                val level = mapPriorityToLevel(priority)
                DevConnect.sendLog(level, message, tag)

                // Also call Android's Log
                logToAndroid(level, tag, message)
            }
            null
        }

        // Install our proxy as the logger
        val installMethod = companion.javaClass.methods.firstOrNull { it.name == "install" }
        installMethod?.invoke(companion, proxy)

        DevConnect.sendLog("info", "DevConnect Logcat interceptor installed", TAG)
    }

    /**
     * Manually forward a log message captured from logcat {} to DevConnect.
     *
     * Use this as a fallback if reflection-based installation fails:
     * ```kotlin
     * // In your custom LogcatLogger:
     * class MyLogger : LogcatLogger {
     *     override fun log(priority: LogPriority, tag: String, message: String) {
     *         Log.println(priority.priorityInt, tag, message)
     *         DevConnectLogcatInterceptor.forwardLog(priority.name, tag, message)
     *     }
     * }
     * ```
     */
    fun forwardLog(priority: String, tag: String, message: String) {
        val level = when (priority.uppercase()) {
            "VERBOSE", "DEBUG" -> "debug"
            "INFO" -> "info"
            "WARN" -> "warn"
            "ERROR", "ASSERT" -> "error"
            else -> "debug"
        }
        DevConnect.sendLog(level, message, tag)
    }

    private fun mapPriorityToLevel(priority: Any?): String {
        val name = try {
            // LogPriority is an enum, get its name
            priority?.javaClass?.getMethod("name")?.invoke(priority) as? String
        } catch (_: Exception) {
            null
        }

        return when (name?.uppercase()) {
            "VERBOSE", "DEBUG" -> "debug"
            "INFO" -> "info"
            "WARN" -> "warn"
            "ERROR", "ASSERT" -> "error"
            else -> "debug"
        }
    }

    private fun logToAndroid(level: String, tag: String, message: String) {
        try {
            when (level) {
                "debug" -> android.util.Log.d(tag, message)
                "info" -> android.util.Log.i(tag, message)
                "warn" -> android.util.Log.w(tag, message)
                "error" -> android.util.Log.e(tag, message)
                else -> android.util.Log.d(tag, message)
            }
        } catch (_: Exception) {}
    }
}
