package com.devconnect.interceptors

import com.devconnect.DevConnect

/**
 * Napier KMP logger integration - an Antilog that sends logs to DevConnect.
 *
 * Napier (https://github.com/AAkira/Napier) is a popular KMP logging library.
 * This Antilog forwards all Napier log messages to the DevConnect desktop app.
 *
 * Usage:
 * ```kotlin
 * import io.github.aakira.napier.Napier
 * import com.devconnect.interceptors.DevConnectNapierAntilog
 *
 * // In Application.onCreate():
 * Napier.base(DevConnectNapierAntilog())
 *
 * // Now all Napier logs are captured:
 * Napier.i("User logged in")
 * Napier.e("Network failed", throwable)
 * ```
 *
 * Since Napier is not a hard dependency, this class uses duck-typing.
 * You need to extend Napier's Antilog in your project:
 *
 * ```kotlin
 * import io.github.aakira.napier.Antilog
 * import io.github.aakira.napier.LogLevel
 *
 * class DevConnectAntilog : Antilog() {
 *     private val helper = DevConnectNapierAntilog()
 *
 *     override fun performLog(
 *         priority: LogLevel,
 *         tag: String?,
 *         throwable: Throwable?,
 *         message: String?
 *     ) {
 *         helper.performLog(priority.name, tag, throwable, message)
 *         // Also log to Android logcat
 *         android.util.Log.println(priority.ordinal + 2, tag ?: "Napier", message ?: "")
 *     }
 * }
 * ```
 */
class DevConnectNapierAntilog {

    private companion object {
        const val TAG = "NapierAntilog"
    }

    /**
     * Handle a Napier log call and forward to DevConnect.
     *
     * @param priority The log level name (VERBOSE, DEBUG, INFO, WARNING, ERROR, ASSERT)
     * @param tag Optional log tag
     * @param throwable Optional throwable for error logs
     * @param message The log message
     */
    fun performLog(priority: String, tag: String?, throwable: Throwable?, message: String?) {
        val level = mapPriorityToLevel(priority)
        val logMessage = buildString {
            message?.let { append(it) }
            if (throwable != null) {
                if (isNotEmpty()) append("\n")
                append(throwable.message ?: throwable.toString())
            }
        }

        if (logMessage.isNotEmpty()) {
            DevConnect.sendLog(
                level = level,
                message = logMessage,
                tag = tag ?: "Napier",
                stackTrace = throwable?.stackTraceToString()
            )
        }
    }

    /**
     * Handle a Napier log call using the LogLevel enum directly via reflection.
     *
     * This avoids requiring Napier as a compile-time dependency:
     * ```kotlin
     * override fun performLog(priority: LogLevel, tag: String?, throwable: Throwable?, message: String?) {
     *     antilog.performLogWithLevel(priority, tag, throwable, message)
     * }
     * ```
     */
    fun performLogWithLevel(priority: Any, tag: String?, throwable: Throwable?, message: String?) {
        val priorityName = try {
            priority.javaClass.getMethod("name").invoke(priority) as? String ?: "DEBUG"
        } catch (_: Exception) {
            "DEBUG"
        }
        performLog(priorityName, tag, throwable, message)
    }

    private fun mapPriorityToLevel(priority: String): String {
        return when (priority.uppercase()) {
            "VERBOSE", "DEBUG" -> "debug"
            "INFO" -> "info"
            "WARNING", "WARN" -> "warn"
            "ERROR", "ASSERT" -> "error"
            else -> "debug"
        }
    }
}

/**
 * Helper object with static utility methods for Napier integration.
 *
 * ```kotlin
 * // Quick-check if Napier is on the classpath:
 * if (DevConnectNapierHelper.isNapierAvailable()) {
 *     Napier.base(DevConnectAntilog())
 * }
 * ```
 */
object DevConnectNapierHelper {

    /**
     * Check if Napier is available on the classpath.
     */
    fun isNapierAvailable(): Boolean {
        return try {
            Class.forName("io.github.aakira.napier.Napier")
            true
        } catch (_: ClassNotFoundException) {
            false
        }
    }

    /**
     * Try to install a DevConnect antilog into Napier via reflection.
     *
     * Returns true if successful, false if Napier is not available.
     */
    fun tryInstall(): Boolean {
        if (!isNapierAvailable()) return false

        try {
            DevConnect.sendLog(
                "info",
                "DevConnect Napier antilog ready. Use DevConnectAntilog with Napier.base().",
                "NapierAntilog"
            )
            return true
        } catch (e: Exception) {
            DevConnect.sendLog(
                "warn",
                "Failed to set up Napier integration: ${e.message}",
                "NapierAntilog",
                e.stackTraceToString()
            )
            return false
        }
    }
}
