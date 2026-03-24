package com.devconnect.reporters

import com.devconnect.DevConnect
import org.json.JSONArray
import org.json.JSONObject

/**
 * Room database query reporter for DevConnect.
 *
 * Reports Room database operations (queries, inserts, updates, deletes)
 * to the DevConnect desktop app for debugging.
 *
 * Usage:
 * ```kotlin
 * val reporter = DevConnect.roomReporter()
 *
 * // After a query
 * val users = userDao.getAllUsers()
 * reporter.reportQuery("SELECT * FROM users", users)
 *
 * // After an insert
 * val rowId = userDao.insert(user)
 * reporter.reportInsert("users", rowId)
 *
 * // After an update
 * val rowsAffected = userDao.updateUser(user)
 * reporter.reportUpdate("users", rowsAffected)
 *
 * // After a delete
 * val deletedCount = userDao.deleteUser(user)
 * reporter.reportDelete("users", deletedCount)
 * ```
 *
 * Since Room is not a hard dependency, this reporter uses manual reporting.
 * Call the appropriate method after your DAO operations.
 */
class RoomReporter {

    private companion object {
        const val STORAGE_TYPE = "room"
    }

    /**
     * Report a Room SELECT query and its results.
     *
     * @param query The SQL query string (e.g., "SELECT * FROM users WHERE active = 1")
     * @param results The query results (list, single object, or count)
     * @param tableName Optional table name (extracted from query if not provided)
     */
    fun reportQuery(query: String, results: Any? = null, tableName: String? = null) {
        val table = tableName ?: extractTableName(query) ?: "unknown"

        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = "$table:query",
            value = buildQueryValue(query, results),
            operation = "read"
        )
    }

    /**
     * Report a Room INSERT operation.
     *
     * @param tableName The table that was inserted into
     * @param rowId The ID of the inserted row (returned by @Insert)
     * @param entity Optional entity data that was inserted
     */
    fun reportInsert(tableName: String, rowId: Long, entity: Any? = null) {
        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = "$tableName:insert",
            value = buildInsertValue(rowId, entity),
            operation = "write"
        )
    }

    /**
     * Report a batch Room INSERT operation.
     *
     * @param tableName The table that was inserted into
     * @param rowIds The IDs of the inserted rows
     */
    fun reportBatchInsert(tableName: String, rowIds: List<Long>) {
        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = "$tableName:batchInsert",
            value = JSONObject().apply {
                put("rowIds", JSONArray(rowIds))
                put("count", rowIds.size)
            },
            operation = "write"
        )
    }

    /**
     * Report a Room UPDATE operation.
     *
     * @param tableName The table that was updated
     * @param rowsAffected Number of rows affected by the update
     * @param query Optional update query or description
     */
    fun reportUpdate(tableName: String, rowsAffected: Int, query: String? = null) {
        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = "$tableName:update",
            value = JSONObject().apply {
                put("rowsAffected", rowsAffected)
                query?.let { put("query", it) }
            },
            operation = "write"
        )
    }

    /**
     * Report a Room DELETE operation.
     *
     * @param tableName The table that was deleted from
     * @param rowsAffected Number of rows deleted
     * @param query Optional delete query or description
     */
    fun reportDelete(tableName: String, rowsAffected: Int, query: String? = null) {
        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = "$tableName:delete",
            value = JSONObject().apply {
                put("rowsAffected", rowsAffected)
                query?.let { put("query", it) }
            },
            operation = "delete"
        )
    }

    /**
     * Report a raw Room query execution.
     *
     * @param query The raw SQL query
     * @param args Query arguments
     * @param results Optional results
     */
    fun reportRawQuery(query: String, args: List<Any?>? = null, results: Any? = null) {
        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = "raw:query",
            value = JSONObject().apply {
                put("query", query)
                args?.let { put("args", JSONArray(it)) }
                results?.let { put("results", toJsonValue(it)) }
            },
            operation = "read"
        )
    }

    /**
     * Report a Room transaction.
     *
     * @param description Description of the transaction
     * @param operations List of operations performed in the transaction
     */
    fun reportTransaction(description: String, operations: List<String>) {
        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = "transaction",
            value = JSONObject().apply {
                put("description", description)
                put("operations", JSONArray(operations))
                put("operationCount", operations.size)
            },
            operation = "write"
        )
    }

    // ---- Internal helpers ----

    private fun buildQueryValue(query: String, results: Any?): JSONObject {
        return JSONObject().apply {
            put("query", query)
            results?.let {
                when (it) {
                    is List<*> -> {
                        put("resultCount", it.size)
                        put("results", JSONArray(it.map { item -> toJsonValue(item) }))
                    }
                    is Number -> put("result", it)
                    is String -> put("result", it)
                    else -> put("result", it.toString())
                }
            }
        }
    }

    private fun buildInsertValue(rowId: Long, entity: Any?): JSONObject {
        return JSONObject().apply {
            put("rowId", rowId)
            entity?.let { put("entity", toJsonValue(it)) }
        }
    }

    private fun toJsonValue(value: Any?): Any {
        return when (value) {
            null -> JSONObject.NULL
            is String, is Number, is Boolean -> value
            is Map<*, *> -> JSONObject(value)
            is List<*> -> JSONArray(value)
            else -> {
                // Try to convert to map via reflection (for data classes)
                try {
                    val fields = value.javaClass.declaredFields
                    val map = mutableMapOf<String, Any?>()
                    for (field in fields) {
                        try {
                            field.isAccessible = true
                            map[field.name] = field.get(value)
                        } catch (_: Exception) {}
                    }
                    if (map.isNotEmpty()) JSONObject(map as Map<*, *>) else value.toString()
                } catch (_: Exception) {
                    value.toString()
                }
            }
        }
    }

    private fun extractTableName(query: String): String? {
        val normalized = query.trim().uppercase()
        val patterns = listOf(
            Regex("""FROM\s+(\w+)""", RegexOption.IGNORE_CASE),
            Regex("""INTO\s+(\w+)""", RegexOption.IGNORE_CASE),
            Regex("""UPDATE\s+(\w+)""", RegexOption.IGNORE_CASE),
            Regex("""DELETE\s+FROM\s+(\w+)""", RegexOption.IGNORE_CASE),
        )
        for (pattern in patterns) {
            val match = pattern.find(query)
            if (match != null) {
                return match.groupValues[1].lowercase()
            }
        }
        return null
    }
}
