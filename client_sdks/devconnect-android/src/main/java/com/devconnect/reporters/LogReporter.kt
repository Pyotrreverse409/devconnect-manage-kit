package com.devconnect.reporters

import com.devconnect.DevConnect

/**
 * Tagged logger for DevConnect.
 *
 * ```kotlin
 * val logger = DevConnect.logger("AuthService")
 * logger.info("User logged in")
 * logger.error("Login failed", stackTrace = Log.getStackTraceString(e))
 * ```
 */
class LogReporter(private val tag: String? = null) {

    fun debug(message: String, metadata: Map<String, Any>? = null) {
        DevConnect.debug(message, tag, metadata)
    }

    fun info(message: String, metadata: Map<String, Any>? = null) {
        DevConnect.log(message, tag, metadata)
    }

    fun warn(message: String, metadata: Map<String, Any>? = null) {
        DevConnect.warn(message, tag, metadata)
    }

    fun error(
        message: String,
        stackTrace: String? = null,
        metadata: Map<String, Any>? = null
    ) {
        DevConnect.error(message, tag, stackTrace, metadata)
    }

    /**
     * Log an exception with full stack trace.
     */
    fun exception(e: Throwable, message: String? = null) {
        DevConnect.error(
            message = message ?: e.message ?: e.toString(),
            tag = tag,
            stackTrace = e.stackTraceToString()
        )
    }
}
