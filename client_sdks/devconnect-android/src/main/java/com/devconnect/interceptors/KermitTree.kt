package com.devconnect.interceptors

import com.devconnect.DevConnect

/**
 * Kermit KMP logger integration - a LogWriter that sends logs to DevConnect.
 *
 * Kermit (https://github.com/touchlab/Kermit) is a popular KMP logging library.
 * This LogWriter forwards all Kermit log messages to the DevConnect desktop app.
 *
 * Usage:
 * ```kotlin
 * import co.touchlab.kermit.Logger
 * import com.devconnect.interceptors.DevConnectKermitWriter
 *
 * // Add the DevConnect writer alongside the default platform logger:
 * Logger.addLogWriter(DevConnectKermitWriter())
 *
 * // Or set it as the only writer:
 * Logger.setLogWriters(DevConnectKermitWriter())
 *
 * // Now all Kermit logs are captured:
 * Logger.i { "User logged in" }
 * Logger.e(throwable) { "Network request failed" }
 * ```
 *
 * Since Kermit is not a hard dependency, this class uses duck-typing.
 * You need to extend Kermit's LogWriter in your project:
 *
 * ```kotlin
 * import co.touchlab.kermit.LogWriter
 * import co.touchlab.kermit.Severity
 *
 * class DevConnectKermitLogWriter : LogWriter() {
 *     private val helper = DevConnectKermitWriter()
 *
 *     override fun log(severity: Severity, message: String, tag: String, throwable: Throwable?) {
 *         helper.log(severity.name, message, tag, throwable)
 *     }
 * }
 * ```
 */
class DevConnectKermitWriter {

    private companion object {
        const val TAG = "KermitWriter"
    }

    /**
     * Log a message from Kermit to DevConnect.
     *
     * @param severity The Kermit severity name (Verbose, Debug, Info, Warn, Error, Assert)
     * @param message The log message
     * @param tag The log tag
     * @param throwable Optional throwable for error logs
     */
    fun log(severity: String, message: String, tag: String, throwable: Throwable? = null) {
        val level = mapSeverityToLevel(severity)
        DevConnect.sendLog(
            level = level,
            message = message,
            tag = tag,
            stackTrace = throwable?.stackTraceToString()
        )
    }

    /**
     * Log a message using the Kermit Severity enum directly via reflection.
     *
     * This avoids requiring Kermit as a compile-time dependency:
     * ```kotlin
     * override fun log(severity: Severity, message: String, tag: String, throwable: Throwable?) {
     *     writer.logWithSeverity(severity, message, tag, throwable)
     * }
     * ```
     */
    fun logWithSeverity(severity: Any, message: String, tag: String, throwable: Throwable? = null) {
        val severityName = try {
            severity.javaClass.getMethod("name").invoke(severity) as? String ?: "Debug"
        } catch (_: Exception) {
            "Debug"
        }
        log(severityName, message, tag, throwable)
    }

    private fun mapSeverityToLevel(severity: String): String {
        return when (severity.uppercase()) {
            "VERBOSE", "DEBUG" -> "debug"
            "INFO" -> "info"
            "WARN" -> "warn"
            "ERROR", "ASSERT" -> "error"
            else -> "debug"
        }
    }
}

/**
 * Helper object with static utility methods for Kermit integration.
 *
 * ```kotlin
 * // Quick-check if Kermit is on the classpath:
 * if (DevConnectKermitHelper.isKermitAvailable()) {
 *     Logger.addLogWriter(DevConnectKermitLogWriter())
 * }
 * ```
 */
object DevConnectKermitHelper {

    /**
     * Check if Kermit is available on the classpath.
     */
    fun isKermitAvailable(): Boolean {
        return try {
            Class.forName("co.touchlab.kermit.Logger")
            true
        } catch (_: ClassNotFoundException) {
            false
        }
    }

    /**
     * Try to install a DevConnect log writer into Kermit via reflection.
     *
     * Returns true if successful, false if Kermit is not available.
     */
    fun tryInstall(): Boolean {
        if (!isKermitAvailable()) return false

        try {
            DevConnect.sendLog(
                "info",
                "DevConnect Kermit writer ready. Add DevConnectKermitLogWriter to your Logger.",
                "KermitWriter"
            )
            return true
        } catch (e: Exception) {
            DevConnect.sendLog(
                "warn",
                "Failed to set up Kermit integration: ${e.message}",
                "KermitWriter",
                e.stackTraceToString()
            )
            return false
        }
    }
}
