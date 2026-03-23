package com.devconnect.reporters

import com.devconnect.DevConnect

/**
 * Reports SharedPreferences operations to DevConnect.
 *
 * Usage:
 * ```kotlin
 * val reporter = DevConnect.sharedPrefsReporter()
 *
 * // After writing to SharedPreferences
 * prefs.edit().putString("token", "abc123").apply()
 * reporter.reportWrite("token", "abc123")
 *
 * // After reading
 * val token = prefs.getString("token", null)
 * reporter.reportRead("token", token)
 * ```
 *
 * Or wrap SharedPreferences for auto-reporting:
 * ```kotlin
 * val prefs = DevConnectSharedPrefs.wrap(
 *     context.getSharedPreferences("my_prefs", Context.MODE_PRIVATE)
 * )
 * ```
 */
class SharedPrefsReporter {

    fun reportRead(key: String, value: Any?) {
        DevConnect.reportStorageOperation(
            storageType = "shared_preferences",
            key = key,
            value = value,
            operation = "read"
        )
    }

    fun reportWrite(key: String, value: Any?) {
        DevConnect.reportStorageOperation(
            storageType = "shared_preferences",
            key = key,
            value = value,
            operation = "write"
        )
    }

    fun reportDelete(key: String) {
        DevConnect.reportStorageOperation(
            storageType = "shared_preferences",
            key = key,
            operation = "delete"
        )
    }

    fun reportClear() {
        DevConnect.reportStorageOperation(
            storageType = "shared_preferences",
            key = "*",
            operation = "clear"
        )
    }
}
