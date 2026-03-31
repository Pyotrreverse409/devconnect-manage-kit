package com.devconnect.wrappers

import com.devconnect.DevConnect

/**
 * Auto-reporting wrapper for MMKV (Android).
 *
 * ```kotlin
 * val mmkv = DevConnectMMKV.wrap(MMKV.defaultMMKV())
 * mmkv.encode("token", "abc")  // auto-reports write
 * mmkv.decodeString("token")    // auto-reports read
 * mmkv.removeValueForKey("token") // auto-reports delete
 * ```
 *
 * Uses dynamic dispatch since MMKV is not a compile-time dependency.
 */
class DevConnectMMKV private constructor(
    private val inner: Any,
    private val label: String,
) {
    companion object {
        fun wrap(mmkv: Any, label: String = "mmkv"): DevConnectMMKV {
            return DevConnectMMKV(mmkv, label)
        }
    }

    fun encode(key: String, value: Any?): Boolean {
        val method = inner.javaClass.getMethod("encode", String::class.java, value?.javaClass ?: Any::class.java)
        val result = method.invoke(inner, key, value) as Boolean
        report("write", key, value)
        return result
    }

    fun decodeString(key: String, defaultValue: String? = null): String? {
        val method = inner.javaClass.getMethod("decodeString", String::class.java, String::class.java)
        val value = method.invoke(inner, key, defaultValue) as? String
        report("read", key, value)
        return value
    }

    fun decodeInt(key: String, defaultValue: Int = 0): Int {
        val method = inner.javaClass.getMethod("decodeInt", String::class.java, Int::class.java)
        val value = method.invoke(inner, key, defaultValue) as Int
        report("read", key, value)
        return value
    }

    fun decodeBool(key: String, defaultValue: Boolean = false): Boolean {
        val method = inner.javaClass.getMethod("decodeBool", String::class.java, Boolean::class.java)
        val value = method.invoke(inner, key, defaultValue) as Boolean
        report("read", key, value)
        return value
    }

    fun removeValueForKey(key: String) {
        val method = inner.javaClass.getMethod("removeValueForKey", String::class.java)
        method.invoke(inner, key)
        report("delete", key, null)
    }

    fun clearAll() {
        val method = inner.javaClass.getMethod("clearAll")
        method.invoke(inner)
        report("clear", "*", null)
    }

    private fun report(operation: String, key: String, value: Any?) {
        DevConnect.sendStorage(
            storageType = "mmkv",
            key = "$label:$key",
            value = value,
            operation = operation,
        )
    }
}
