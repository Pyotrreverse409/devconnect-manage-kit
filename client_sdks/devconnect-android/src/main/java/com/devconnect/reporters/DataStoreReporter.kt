package com.devconnect.reporters

import com.devconnect.DevConnect

/**
 * Reports AndroidX DataStore (Preferences) operations to DevConnect.
 *
 * Usage:
 * ```kotlin
 * val reporter = DevConnect.dataStoreReporter()
 *
 * // After writing to DataStore
 * dataStore.edit { prefs ->
 *     prefs[DARK_MODE_KEY] = true
 *     reporter.reportWrite("darkMode", true)
 * }
 *
 * // After reading from DataStore
 * dataStore.data.collect { prefs ->
 *     val darkMode = prefs[DARK_MODE_KEY] ?: false
 *     reporter.reportRead("darkMode", darkMode)
 * }
 * ```
 *
 * For Proto DataStore:
 * ```kotlin
 * val reporter = DevConnect.dataStoreReporter()
 *
 * // Report Proto DataStore operations
 * reporter.reportWrite("userSettings", mapOf(
 *     "theme" to "dark",
 *     "fontSize" to 14
 * ))
 * ```
 *
 * Since AndroidX DataStore is not a hard dependency, this reporter uses manual
 * reporting. Call reportRead/reportWrite after your DataStore operations.
 */
class DataStoreReporter {

    /**
     * Report a DataStore read operation.
     *
     * @param key The preference key name
     * @param value The value that was read
     */
    fun reportRead(key: String, value: Any?) {
        DevConnect.reportStorageOperation(
            storageType = "datastore",
            key = key,
            value = value,
            operation = "read"
        )
    }

    /**
     * Report a DataStore write operation.
     *
     * @param key The preference key name
     * @param value The value that was written
     */
    fun reportWrite(key: String, value: Any?) {
        DevConnect.reportStorageOperation(
            storageType = "datastore",
            key = key,
            value = value,
            operation = "write"
        )
    }

    /**
     * Report a DataStore key deletion.
     *
     * @param key The preference key that was removed
     */
    fun reportDelete(key: String) {
        DevConnect.reportStorageOperation(
            storageType = "datastore",
            key = key,
            operation = "delete"
        )
    }

    /**
     * Report a DataStore clear operation (all preferences removed).
     */
    fun reportClear() {
        DevConnect.reportStorageOperation(
            storageType = "datastore",
            key = "*",
            operation = "clear"
        )
    }

    /**
     * Report a batch of DataStore writes at once.
     *
     * ```kotlin
     * dataStore.edit { prefs ->
     *     prefs[THEME_KEY] = "dark"
     *     prefs[FONT_SIZE_KEY] = 14
     *     reporter.reportBatchWrite(mapOf(
     *         "theme" to "dark",
     *         "fontSize" to 14
     *     ))
     * }
     * ```
     *
     * @param entries Map of key-value pairs that were written
     */
    fun reportBatchWrite(entries: Map<String, Any?>) {
        for ((key, value) in entries) {
            reportWrite(key, value)
        }
    }

    /**
     * Report a full DataStore snapshot (all current preferences).
     *
     * ```kotlin
     * dataStore.data.collect { prefs ->
     *     val snapshot = prefs.asMap().mapKeys { it.key.name }
     *     reporter.reportSnapshot(snapshot)
     * }
     * ```
     *
     * @param entries Map of all current key-value pairs
     */
    fun reportSnapshot(entries: Map<String, Any?>) {
        for ((key, value) in entries) {
            reportRead(key, value)
        }
    }
}
