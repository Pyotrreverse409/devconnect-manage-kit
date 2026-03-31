package com.devconnect.reporters

import com.devconnect.DevConnect

/**
 * ObjectBox database reporter for DevConnect.
 *
 * ```kotlin
 * val reporter = DevConnect.objectBoxReporter()
 * reporter.reportQuery("User", users.map { mapOf("name" to it.name) })
 * reporter.reportWrite("User", mapOf("name" to user.name))
 * reporter.reportDelete("User", mapOf("id" to user.id))
 * ```
 */
class ObjectBoxReporter {

    private companion object {
        const val STORAGE_TYPE = "objectbox"
    }

    fun reportQuery(entityName: String, results: List<Map<String, Any?>>) {
        DevConnect.sendStorage(
            storageType = STORAGE_TYPE,
            key = entityName,
            value = results,
            operation = "read",
        )
    }

    fun reportWrite(entityName: String, data: Map<String, Any?>) {
        DevConnect.sendStorage(
            storageType = STORAGE_TYPE,
            key = entityName,
            value = data,
            operation = "write",
        )
    }

    fun reportDelete(entityName: String, data: Map<String, Any?>? = null) {
        DevConnect.sendStorage(
            storageType = STORAGE_TYPE,
            key = entityName,
            value = data,
            operation = "delete",
        )
    }
}
