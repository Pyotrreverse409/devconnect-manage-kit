package com.devconnect.interceptors

import com.devconnect.DevConnect

/**
 * Drop-in replacement for android.util.Log that sends logs to DevConnect.
 *
 * ## Option 1: Replace Log calls in your code
 * ```kotlin
 * // Before:
 * import android.util.Log
 * Log.d("MyTag", "Hello")
 *
 * // After:
 * import com.devconnect.interceptors.DCLog as Log
 * Log.d("MyTag", "Hello")  // Same API, now captured by DevConnect!
 * ```
 *
 * ## Option 2: Use with Timber (recommended)
 * ```kotlin
 * // In Application.onCreate():
 * Timber.plant(DevConnect.timberTree())
 *
 * // All Timber.d(), Timber.e(), etc. are now auto-captured!
 * ```
 *
 * ## Option 3: Global print interception
 * ```kotlin
 * // Captures System.out.println() and println()
 * DevConnectLogInterceptor.interceptSystemOut()
 * ```
 */
object DCLog {
    fun v(tag: String, msg: String): Int {
        DevConnect.sendLog("debug", msg, tag)
        return android.util.Log.v(tag, msg)
    }

    fun v(tag: String, msg: String, tr: Throwable): Int {
        DevConnect.sendLog("debug", "$msg\n${tr.stackTraceToString()}", tag, tr.stackTraceToString())
        return android.util.Log.v(tag, msg, tr)
    }

    fun d(tag: String, msg: String): Int {
        DevConnect.sendLog("debug", msg, tag)
        return android.util.Log.d(tag, msg)
    }

    fun d(tag: String, msg: String, tr: Throwable): Int {
        DevConnect.sendLog("debug", "$msg\n${tr.stackTraceToString()}", tag, tr.stackTraceToString())
        return android.util.Log.d(tag, msg, tr)
    }

    fun i(tag: String, msg: String): Int {
        DevConnect.sendLog("info", msg, tag)
        return android.util.Log.i(tag, msg)
    }

    fun i(tag: String, msg: String, tr: Throwable): Int {
        DevConnect.sendLog("info", "$msg\n${tr.stackTraceToString()}", tag, tr.stackTraceToString())
        return android.util.Log.i(tag, msg, tr)
    }

    fun w(tag: String, msg: String): Int {
        DevConnect.sendLog("warn", msg, tag)
        return android.util.Log.w(tag, msg)
    }

    fun w(tag: String, msg: String, tr: Throwable): Int {
        DevConnect.sendLog("warn", "$msg\n${tr.stackTraceToString()}", tag, tr.stackTraceToString())
        return android.util.Log.w(tag, msg, tr)
    }

    fun w(tag: String, tr: Throwable): Int {
        DevConnect.sendLog("warn", tr.message ?: tr.toString(), tag, tr.stackTraceToString())
        return android.util.Log.w(tag, tr)
    }

    fun e(tag: String, msg: String): Int {
        DevConnect.sendLog("error", msg, tag)
        return android.util.Log.e(tag, msg)
    }

    fun e(tag: String, msg: String, tr: Throwable): Int {
        DevConnect.sendLog("error", "$msg\n${tr.stackTraceToString()}", tag, tr.stackTraceToString())
        return android.util.Log.e(tag, msg, tr)
    }

    fun wtf(tag: String, msg: String): Int {
        DevConnect.sendLog("error", "[WTF] $msg", tag)
        return android.util.Log.wtf(tag, msg)
    }

    fun wtf(tag: String, msg: String, tr: Throwable): Int {
        DevConnect.sendLog("error", "[WTF] $msg\n${tr.stackTraceToString()}", tag, tr.stackTraceToString())
        return android.util.Log.wtf(tag, msg, tr)
    }
}

/**
 * Timber.Tree implementation that sends logs to DevConnect.
 *
 * ```kotlin
 * // In Application.onCreate():
 * if (BuildConfig.DEBUG) {
 *     Timber.plant(DevConnectTimberTree())
 *     Timber.plant(Timber.DebugTree()) // keep console output too
 * }
 * ```
 *
 * This captures ALL Timber.d(), Timber.i(), Timber.w(), Timber.e() calls
 * from anywhere in your app automatically.
 *
 * Since Timber is duck-typed here (no hard dependency), you need to extend
 * Timber.Tree in your own code:
 *
 * ```kotlin
 * import timber.log.Timber
 *
 * class DevConnectTree : Timber.Tree() {
 *     override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
 *         val level = when (priority) {
 *             android.util.Log.VERBOSE, android.util.Log.DEBUG -> "debug"
 *             android.util.Log.INFO -> "info"
 *             android.util.Log.WARN -> "warn"
 *             android.util.Log.ERROR, android.util.Log.ASSERT -> "error"
 *             else -> "debug"
 *         }
 *         DevConnect.sendLog(level, message, tag ?: "Timber", t?.stackTraceToString())
 *     }
 * }
 * ```
 */
object DevConnectTimberHelper {
    /**
     * Call from your Timber.Tree.log() override:
     *
     * ```kotlin
     * override fun log(priority: Int, tag: String?, message: String, t: Throwable?) {
     *     DevConnectTimberHelper.log(priority, tag, message, t)
     * }
     * ```
     */
    fun log(priority: Int, tag: String?, message: String, throwable: Throwable?) {
        val level = when (priority) {
            android.util.Log.VERBOSE, android.util.Log.DEBUG -> "debug"
            android.util.Log.INFO -> "info"
            android.util.Log.WARN -> "warn"
            android.util.Log.ERROR, android.util.Log.ASSERT -> "error"
            else -> "debug"
        }
        DevConnect.sendLog(level, message, tag ?: "Timber", throwable?.stackTraceToString())
    }
}

/**
 * Intercepts System.out.println() and System.err.println() calls.
 *
 * ```kotlin
 * // In Application.onCreate():
 * DevConnectLogInterceptor.interceptSystemOut()
 *
 * // Now println("hello") is captured!
 * ```
 */
object DevConnectLogInterceptor {
    private var intercepted = false

    fun interceptSystemOut() {
        if (intercepted) return
        intercepted = true

        val originalOut = System.out
        val originalErr = System.err

        System.setOut(object : java.io.PrintStream(originalOut) {
            override fun println(x: String?) {
                super.println(x)
                x?.let {
                    if (!isSystemLog(it)) {
                        DevConnect.sendLog("debug", it, "println")
                    }
                }
            }

            override fun println(x: Any?) {
                super.println(x)
                x?.let {
                    val msg = it.toString()
                    if (!isSystemLog(msg)) {
                        DevConnect.sendLog("debug", msg, "println")
                    }
                }
            }
        })

        System.setErr(object : java.io.PrintStream(originalErr) {
            override fun println(x: String?) {
                super.println(x)
                x?.let {
                    if (!isSystemLog(it)) {
                        DevConnect.sendLog("error", it, "System.err")
                    }
                }
            }

            override fun println(x: Any?) {
                super.println(x)
                x?.let {
                    val msg = it.toString()
                    if (!isSystemLog(msg)) {
                        DevConnect.sendLog("error", msg, "System.err")
                    }
                }
            }
        })
    }

    private fun isSystemLog(message: String): Boolean {
        val systemPrefixes = listOf(
            "D/",
            "I/",
            "V/",
            "W/",
            "E/",
            "--------- beginning of",
            "GC_",
            "dalvikvm",
            "art",
            "zygote",
            "System.err",
            "at java.",
            "at android.",
            "at com.android.",
            "at dalvik.",
            "Caused by:",
            "\tat ",
        )
        return systemPrefixes.any { message.trimStart().startsWith(it) }
    }
}
