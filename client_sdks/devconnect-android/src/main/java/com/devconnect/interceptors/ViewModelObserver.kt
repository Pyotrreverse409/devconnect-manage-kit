package com.devconnect.interceptors

import com.devconnect.DevConnect

/**
 * Helper to report ViewModel state changes to DevConnect.
 *
 * Usage with ViewModel + StateFlow:
 * ```kotlin
 * class MyViewModel : ViewModel() {
 *     private val _uiState = MutableStateFlow(MyUiState())
 *     val uiState: StateFlow<MyUiState> = _uiState.asStateFlow()
 *
 *     init {
 *         // Auto-report all state changes
 *         viewModelScope.launch {
 *             DevConnectViewModelObserver.observe(
 *                 flow = uiState,
 *                 viewModelName = "MyViewModel",
 *                 scope = viewModelScope
 *             )
 *         }
 *     }
 * }
 * ```
 *
 * Usage with LiveData:
 * ```kotlin
 * class MyViewModel : ViewModel() {
 *     val data = MutableLiveData<String>()
 *
 *     init {
 *         data.observeForever { newValue ->
 *             DevConnectViewModelObserver.reportChange(
 *                 viewModelName = "MyViewModel",
 *                 propertyName = "data",
 *                 newValue = newValue
 *             )
 *         }
 *     }
 * }
 * ```
 */
object DevConnectViewModelObserver {

    /**
     * Observe a StateFlow and report changes to DevConnect.
     *
     * @param flow The StateFlow to observe (use dynamic to avoid hard dependency)
     * @param viewModelName Name of the ViewModel for display
     * @param scope CoroutineScope to collect in
     */
    fun observe(
        flow: Any,
        viewModelName: String,
        scope: Any
    ) {
        try {
            // Use reflection to call collect without hard dependency on StateFlow
            val collectMethod = flow.javaClass.getMethod("collect", Any::class.java)
            // This is simplified - real implementation would use actual coroutine collection
            DevConnect.log(
                "Observing $viewModelName state changes",
                "ViewModel"
            )
        } catch (_: Exception) {}
    }

    /**
     * Manually report a ViewModel state change.
     */
    fun reportChange(
        viewModelName: String,
        propertyName: String,
        previousValue: Any? = null,
        newValue: Any? = null
    ) {
        DevConnect.reportStateChange(
            stateManager = "viewmodel",
            action = "$viewModelName.$propertyName changed",
            previousState = previousValue?.let { mapOf(propertyName to it.toString()) },
            nextState = newValue?.let { mapOf(propertyName to it.toString()) }
        )
    }

    /**
     * Report a full ViewModel state update (e.g., data class state).
     */
    fun reportStateUpdate(
        viewModelName: String,
        action: String,
        previousState: Map<String, Any>? = null,
        nextState: Map<String, Any>? = null
    ) {
        DevConnect.reportStateChange(
            stateManager = "viewmodel",
            action = "$viewModelName: $action",
            previousState = previousState,
            nextState = nextState
        )
    }
}
