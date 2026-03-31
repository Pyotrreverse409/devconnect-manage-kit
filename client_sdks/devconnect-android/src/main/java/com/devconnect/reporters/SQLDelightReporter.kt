package com.devconnect.reporters

import com.devconnect.DevConnect

/**
 * SQLDelight reporter for DevConnect.
 *
 * ```kotlin
 * val reporter = DevConnect.sqlDelightReporter()
 * reporter.reportQuery("SELECT * FROM users", users)
 * reporter.reportExecute("INSERT INTO users (name) VALUES (?)", mapOf("name" to "John"))
 * ```
 */
class SQLDelightReporter {

    private companion object {
        const val STORAGE_TYPE = "sqldelight"
    }

    fun reportQuery(sql: String, results: List<Map<String, Any?>>) {
        DevConnect.sendStorage(
            storageType = STORAGE_TYPE,
            key = sql,
            value = results,
            operation = "read",
        )
    }

    fun reportExecute(sql: String, params: Map<String, Any?>? = null) {
        val op = sql.trim().uppercase()
        val operation = if (op.startsWith("DELETE")) "delete" else "write"
        DevConnect.sendStorage(
            storageType = STORAGE_TYPE,
            key = sql,
            value = params,
            operation = operation,
        )
    }
}
