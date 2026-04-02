package com.devconnect.reporters

import com.devconnect.DevConnect
import org.json.JSONObject

/**
 * Realm database reporter for DevConnect.
 *
 * Reports Realm database operations (queries, writes, deletes)
 * to the DevConnect desktop app for debugging.
 *
 * Usage:
 * ```kotlin
 * val reporter = DevConnect.realmReporter()
 *
 * // After a query
 * val results = realm.query<User>().find()
 * reporter.reportQuery("User", results.map { mapOf("name" to it.name) })
 *
 * // After a write
 * realm.writeBlocking { copyToRealm(user) }
 * reporter.reportWrite("User", mapOf("name" to user.name))
 *
 * // After a delete
 * realm.writeBlocking { delete(user) }
 * reporter.reportDelete("User", mapOf("id" to user.id))
 * ```
 *
 * Since Realm is not a hard dependency, this reporter uses manual reporting.
 */
class RealmReporter {

    private companion object {
        const val STORAGE_TYPE = "realm"
    }

    /**
     * Report a Realm query and its results.
     */
    fun reportQuery(className: String, results: List<Map<String, Any?>>) {
        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = className,
            value = results,
            operation = "read",
        )
    }

    /**
     * Report a Realm write (create/update) operation.
     */
    fun reportWrite(className: String, data: Map<String, Any?>) {
        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = className,
            value = data,
            operation = "write",
        )
    }

    /**
     * Report a Realm delete operation.
     */
    fun reportDelete(className: String, data: Map<String, Any?>? = null) {
        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = className,
            value = data,
            operation = "delete",
        )
    }

    /**
     * Report a Realm batch write (transaction).
     */
    fun reportTransaction(description: String, affectedObjects: Int) {
        DevConnect.reportStorageOperation(
            storageType = STORAGE_TYPE,
            key = description,
            value = mapOf("affectedObjects" to affectedObjects),
            operation = "write",
        )
    }
}
