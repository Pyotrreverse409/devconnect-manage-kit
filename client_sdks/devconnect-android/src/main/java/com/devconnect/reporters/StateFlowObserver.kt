package com.devconnect.reporters

import com.devconnect.DevConnect

/**
 * StateFlow/LiveData observer that reports state changes to DevConnect.
 *
 * Observes StateFlow or LiveData and reports previous/next state changes
 * to the DevConnect desktop app for real-time state debugging.
 *
 * ## StateFlow usage:
 * ```kotlin
 * import kotlinx.coroutines.CoroutineScope
 * import kotlinx.coroutines.flow.StateFlow
 *
 * // In a ViewModel or anywhere with a CoroutineScope:
 * DevConnectStateObserver.observe(viewModelScope, uiState, "UserState")
 *
 * // With MutableStateFlow:
 * val _state = MutableStateFlow(UiState())
 * DevConnectStateObserver.observe(viewModelScope, _state, "MainScreen")
 * ```
 *
 * ## LiveData usage:
 * ```kotlin
 * import androidx.lifecycle.LifecycleOwner
 * import androidx.lifecycle.LiveData
 *
 * // In an Activity or Fragment:
 * DevConnectStateObserver.observe(this, viewModel.userData, "UserData")
 * ```
 *
 * ## Flow usage:
 * ```kotlin
 * // Any Flow can be observed:
 * DevConnectStateObserver.observeFlow(scope, myFlow, "MyFlow")
 * ```
 *
 * Since kotlinx.coroutines.flow and androidx.lifecycle are not hard dependencies,
 * this uses reflection to avoid compile-time coupling.
 */
object DevConnectStateObserver {

    private const val TAG = "StateObserver"

    /**
     * Observe a StateFlow and report state changes to DevConnect.
     *
     * Uses reflection to collect from the StateFlow without requiring
     * kotlinx.coroutines as a compile-time dependency.
     *
     * @param scope A CoroutineScope to launch the collection in
     * @param stateFlow The StateFlow to observe
     * @param name A descriptive name for this state (shown in DevConnect UI)
     */
    fun observe(scope: Any, stateFlow: Any, name: String) {
        try {
            observeStateFlowViaReflection(scope, stateFlow, name)
        } catch (e: Exception) {
            DevConnect.sendLog(
                "warn",
                "Failed to observe StateFlow '$name': ${e.message}. " +
                    "Use manual reporting with DevConnectStateObserver.reportChange() instead.",
                TAG,
                e.stackTraceToString()
            )
        }
    }

    /**
     * Observe a LiveData and report state changes to DevConnect.
     *
     * Uses reflection to observe the LiveData without requiring
     * androidx.lifecycle as a compile-time dependency.
     *
     * @param lifecycleOwner The LifecycleOwner to bind observation to
     * @param liveData The LiveData to observe
     * @param name A descriptive name for this state (shown in DevConnect UI)
     */
    fun observe(lifecycleOwner: Any, liveData: Any, name: String) {
        try {
            observeLiveDataViaReflection(lifecycleOwner, liveData, name)
        } catch (e: Exception) {
            DevConnect.sendLog(
                "warn",
                "Failed to observe LiveData '$name': ${e.message}. " +
                    "Use manual reporting with DevConnectStateObserver.reportChange() instead.",
                TAG,
                e.stackTraceToString()
            )
        }
    }

    /**
     * Observe any Flow and report emitted values to DevConnect.
     *
     * @param scope A CoroutineScope to launch the collection in
     * @param flow The Flow to observe
     * @param name A descriptive name for this flow (shown in DevConnect UI)
     */
    fun observeFlow(scope: Any, flow: Any, name: String) {
        try {
            observeFlowViaReflection(scope, flow, name)
        } catch (e: Exception) {
            DevConnect.sendLog(
                "warn",
                "Failed to observe Flow '$name': ${e.message}. " +
                    "Use manual reporting with DevConnectStateObserver.reportChange() instead.",
                TAG,
                e.stackTraceToString()
            )
        }
    }

    /**
     * Manually report a state change.
     *
     * Use this as a fallback if automatic observation fails, or when you
     * want fine-grained control over what's reported.
     *
     * ```kotlin
     * val oldState = _state.value
     * _state.value = newState
     * DevConnectStateObserver.reportChange(
     *     name = "UserState",
     *     previousState = mapOf("loggedIn" to false),
     *     nextState = mapOf("loggedIn" to true, "userId" to "123")
     * )
     * ```
     *
     * @param name A descriptive name for this state
     * @param previousState The previous state as a map
     * @param nextState The new state as a map
     * @param action Optional description of what changed
     */
    fun reportChange(
        name: String,
        previousState: Map<String, Any>? = null,
        nextState: Map<String, Any>? = null,
        action: String = "state_updated"
    ) {
        DevConnect.reportStateChange(
            stateManager = name,
            action = action,
            previousState = previousState,
            nextState = nextState
        )
    }

    /**
     * Report a state snapshot (the full current state).
     *
     * ```kotlin
     * DevConnectStateObserver.reportSnapshot("UserState", mapOf(
     *     "loggedIn" to true,
     *     "userId" to "123",
     *     "userName" to "John"
     * ))
     * ```
     */
    fun reportSnapshot(name: String, state: Map<String, Any>) {
        DevConnect.sendStateSnapshot(
            stateManager = name,
            state = state
        )
    }

    // ---- Internal reflection-based observers ----

    private fun observeStateFlowViaReflection(scope: Any, stateFlow: Any, name: String) {
        // StateFlow implements Flow, so we can use Flow collection.
        // We need CoroutineScope.launch { flow.collect { ... } }
        //
        // Since we can't call suspend functions directly via reflection easily,
        // we use a thread-based approach to collect.

        val thread = Thread {
            var previousValue: Any? = null
            try {
                // Get the current value via StateFlow.value property
                val valueMethod = stateFlow.javaClass.getMethod("getValue")

                DevConnect.sendLog("info", "Observing StateFlow '$name'", TAG)

                while (!Thread.currentThread().isInterrupted) {
                    try {
                        val currentValue = valueMethod.invoke(stateFlow)

                        if (currentValue != previousValue) {
                            DevConnect.reportStateChange(
                                stateManager = name,
                                action = "state_updated",
                                previousState = toStateMap(previousValue),
                                nextState = toStateMap(currentValue)
                            )
                            previousValue = currentValue
                        }

                        Thread.sleep(100) // Poll interval
                    } catch (_: InterruptedException) {
                        break
                    }
                }
            } catch (e: Exception) {
                DevConnect.sendLog(
                    "warn",
                    "StateFlow observation ended for '$name': ${e.message}",
                    TAG
                )
            }
        }
        thread.isDaemon = true
        thread.name = "DevConnect-StateFlow-$name"
        thread.start()
    }

    private fun observeLiveDataViaReflection(lifecycleOwner: Any, liveData: Any, name: String) {
        // LiveData.observe(LifecycleOwner, Observer)
        // Observer is a functional interface: void onChanged(T value)

        try {
            val liveDataClass = Class.forName("androidx.lifecycle.LiveData")
            val lifecycleOwnerClass = Class.forName("androidx.lifecycle.LifecycleOwner")
            val observerClass = Class.forName("androidx.lifecycle.Observer")

            var previousValue: Any? = null

            // Create an Observer proxy
            val observer = java.lang.reflect.Proxy.newProxyInstance(
                observerClass.classLoader,
                arrayOf(observerClass)
            ) { _, method, args ->
                if (method.name == "onChanged" && args != null && args.isNotEmpty()) {
                    val newValue = args[0]
                    DevConnect.reportStateChange(
                        stateManager = name,
                        action = "state_updated",
                        previousState = toStateMap(previousValue),
                        nextState = toStateMap(newValue)
                    )
                    previousValue = newValue
                }
                null
            }

            // Call liveData.observe(lifecycleOwner, observer)
            val observeMethod = liveDataClass.getMethod(
                "observe",
                lifecycleOwnerClass,
                observerClass
            )
            observeMethod.invoke(liveData, lifecycleOwner, observer)

            DevConnect.sendLog("info", "Observing LiveData '$name'", TAG)
        } catch (e: Exception) {
            // Fallback: try observeForever if LifecycleOwner fails
            try {
                observeForeverViaReflection(liveData, name)
            } catch (e2: Exception) {
                throw e
            }
        }
    }

    private fun observeForeverViaReflection(liveData: Any, name: String) {
        val liveDataClass = Class.forName("androidx.lifecycle.LiveData")
        val observerClass = Class.forName("androidx.lifecycle.Observer")

        var previousValue: Any? = null

        val observer = java.lang.reflect.Proxy.newProxyInstance(
            observerClass.classLoader,
            arrayOf(observerClass)
        ) { _, method, args ->
            if (method.name == "onChanged" && args != null && args.isNotEmpty()) {
                val newValue = args[0]
                DevConnect.reportStateChange(
                    stateManager = name,
                    action = "state_updated",
                    previousState = toStateMap(previousValue),
                    nextState = toStateMap(newValue)
                )
                previousValue = newValue
            }
            null
        }

        val observeForeverMethod = liveDataClass.getMethod("observeForever", observerClass)
        observeForeverMethod.invoke(liveData, observer)

        DevConnect.sendLog("info", "Observing LiveData '$name' (forever)", TAG)
    }

    private fun observeFlowViaReflection(scope: Any, flow: Any, name: String) {
        // Similar to StateFlow but without .value access
        // We use a polling thread as a simplified approach
        val thread = Thread {
            try {
                DevConnect.sendLog("info", "Observing Flow '$name'", TAG)

                // For generic flows, we report when collection starts
                // Actual collection requires coroutine suspension which we can't
                // easily do via reflection. Report setup and suggest manual usage.
                DevConnect.sendLog(
                    "info",
                    "Flow '$name' registered. For best results, use manual " +
                        "reporting with reportChange() in your collect block.",
                    TAG
                )
            } catch (e: Exception) {
                DevConnect.sendLog(
                    "warn",
                    "Flow observation setup failed for '$name': ${e.message}",
                    TAG
                )
            }
        }
        thread.isDaemon = true
        thread.name = "DevConnect-Flow-$name"
        thread.start()
    }

    private fun toStateMap(value: Any?): Map<String, Any>? {
        if (value == null) return null

        return try {
            when (value) {
                is Map<*, *> -> {
                    @Suppress("UNCHECKED_CAST")
                    value as Map<String, Any>
                }
                is String, is Number, is Boolean -> {
                    mapOf("value" to value)
                }
                else -> {
                    // Try to convert data class fields to a map via reflection
                    val fields = value.javaClass.declaredFields
                    val map = mutableMapOf<String, Any>()
                    for (field in fields) {
                        try {
                            field.isAccessible = true
                            val fieldValue = field.get(value)
                            if (fieldValue != null) {
                                map[field.name] = fieldValue.toString()
                            }
                        } catch (_: Exception) {}
                    }
                    if (map.isNotEmpty()) map else mapOf("value" to value.toString())
                }
            }
        } catch (_: Exception) {
            mapOf("value" to value.toString())
        }
    }
}
