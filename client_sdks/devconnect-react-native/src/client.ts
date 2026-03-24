/**
 * DevConnect React Native Client
 *
 * Auto-detect desktop host, intercept fetch/XHR/console.
 * Supports real iOS/Android device via subnet scanning.
 */

interface DevConnectConfig {
  appName: string;
  appVersion?: string;
  /** Desktop IP. undefined/'auto' = auto-detect. '192.168.x.x' = manual */
  host?: string;
  port?: number;
  /** Auto-detect host (default: true) */
  auto?: boolean;
  enabled?: boolean;
  autoInterceptFetch?: boolean;
  autoInterceptXHR?: boolean;
  autoInterceptConsole?: boolean;
}

interface DCMessage {
  id: string;
  type: string;
  deviceId: string;
  timestamp: number;
  payload: Record<string, any>;
  correlationId?: string;
}

function generateId(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

// ---- Auto-detect host (supports real device iOS/Android) ----

async function tryConnect(host: string, port: number, timeoutMs: number): Promise<boolean> {
  try {
    const ws = new WebSocket(`ws://${host}:${port}`);
    return await new Promise<boolean>((resolve) => {
      const timer = setTimeout(() => { try { ws.close(); } catch (_) {} resolve(false); }, timeoutMs);
      ws.onopen = () => { clearTimeout(timer); try { ws.close(); } catch (_) {} resolve(true); };
      ws.onerror = () => { clearTimeout(timer); resolve(false); };
    });
  } catch (_) { return false; }
}

async function autoDetectHost(port: number): Promise<string> {
  // 1. Try known addresses first (fast - emulator/simulator)
  const knownHosts = ['localhost', '10.0.2.2', '10.0.3.2', '127.0.0.1'];
  for (const host of knownHosts) {
    if (await tryConnect(host, port, 600)) return host;
  }

  // 2. Scan local subnets for real device (iOS/Android)
  const subnets = ['192.168.1', '192.168.0', '192.168.2', '10.0.0', '10.0.1', '172.16.0'];
  for (const subnet of subnets) {
    const batch = Array.from({ length: 20 }, (_, i) => `${subnet}.${i + 1}`);
    const results = await Promise.allSettled(
      batch.map((h) => tryConnect(h, port, 400).then((ok) => ok ? h : null))
    );
    for (const r of results) {
      if (r.status === 'fulfilled' && r.value) return r.value;
    }
  }

  return 'localhost';
}

// ---- Main Class ----

export class DevConnect {
  private static instance: DevConnect | null = null;
  private ws: WebSocket | null = null;
  private config: Required<DevConnectConfig>;
  private deviceId: string;
  private connected = false;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private messageQueue: string[] = [];
  private _reduxStore: any = null;
  private _stateRestoreHandler: ((state: any) => void) | null = null;
  private _customCommandHandlers: Map<string, (args?: any) => any> = new Map();
  private _benchmarks: Map<string, { title: string; startTime: number; steps: Array<{ title: string; timestamp: number }> }> = new Map();

  private constructor(config: DevConnectConfig & { resolvedHost: string }) {
    this.config = {
      appName: config.appName,
      appVersion: config.appVersion ?? '1.0.0',
      host: config.resolvedHost,
      port: config.port ?? 9090,
      auto: config.auto ?? true,
      enabled: config.enabled ?? __DEV__,
      autoInterceptFetch: config.autoInterceptFetch ?? true,
      autoInterceptXHR: config.autoInterceptXHR ?? true,
      autoInterceptConsole: config.autoInterceptConsole ?? true,
    };
    this.deviceId = generateId();
  }

  /**
   * Initialize DevConnect.
   *
   * ```typescript
   * // Auto-detect (emulator + real device)
   * await DevConnect.init({ appName: 'MyApp' });
   *
   * // Manual IP (real device)
   * await DevConnect.init({ appName: 'MyApp', host: '192.168.1.5' });
   *
   * // Custom port
   * await DevConnect.init({ appName: 'MyApp', port: 9999 });
   *
   * // Disable in production
   * await DevConnect.init({ appName: 'MyApp', enabled: !__DEV__ });
   * ```
   */
  static async init(config: DevConnectConfig): Promise<DevConnect> {
    if (DevConnect.instance) return DevConnect.instance;

    const port = config.port ?? 9090;
    const shouldAuto = (config.auto ?? true) && (!config.host || config.host === 'auto');
    const resolvedHost = shouldAuto
      ? await autoDetectHost(port)
      : (config.host ?? 'localhost');

    const dc = new DevConnect({ ...config, resolvedHost });
    DevConnect.instance = dc;

    if (dc.config.enabled) {
      dc.connect();
      if (dc.config.autoInterceptFetch) dc.patchFetch();
      if (dc.config.autoInterceptXHR) dc.patchXHR();
      if (dc.config.autoInterceptConsole) dc.patchConsole();
    }

    return dc;
  }

  static getInstance(): DevConnect {
    if (!DevConnect.instance) {
      throw new Error('DevConnect not initialized. Call DevConnect.init() first.');
    }
    return DevConnect.instance;
  }

  // ---- WebSocket ----

  private connect(): void {
    try {
      this.ws = new WebSocket(`ws://${this.config.host}:${this.config.port}`);

      this.ws.onopen = () => {
        this.connected = true;
        this.messageQueue.forEach((msg) => this.ws?.send(msg));
        this.messageQueue = [];
      };

      this.ws.onmessage = (event: WebSocketMessageEvent) => {
        try {
          const msg = JSON.parse(event.data as string);
          if (msg.type === 'server:hello') {
            this.sendHandshake();
          } else if (msg.type === 'server:redux:dispatch') {
            // Desktop dispatching a Redux action into the app
            if (this._reduxStore && msg.payload?.action) {
              this._reduxStore.dispatch(msg.payload.action);
            }
          } else if (msg.type === 'server:state:restore') {
            // Desktop restoring a state snapshot
            if (this._stateRestoreHandler && msg.payload?.state) {
              this._stateRestoreHandler(msg.payload.state);
            }
          } else if (msg.type === 'server:custom:command') {
            // Desktop sending a custom command
            const cmd = msg.payload?.command;
            const handler = this._customCommandHandlers.get(cmd);
            if (handler) {
              const result = handler(msg.payload?.args);
              this.send('client:custom:command_result', {
                command: cmd,
                result,
              }, msg.correlationId);
            }
          }
        } catch (_) {}
      };

      this.ws.onclose = () => { this.connected = false; this.scheduleReconnect(); };
      this.ws.onerror = () => { this.connected = false; this.scheduleReconnect(); };
    } catch (_) {
      this.scheduleReconnect();
    }
  }

  private sendHandshake(): void {
    const Platform = (global as any).Platform;
    this.send('client:handshake', {
      deviceInfo: {
        deviceId: this.deviceId,
        deviceName: Platform
          ? `${Platform.OS} ${Platform.Version ?? ''}`.trim()
          : 'React Native Device',
        platform: 'react_native',
        osVersion: Platform
          ? `${Platform.OS} ${Platform.Version ?? ''}`.trim()
          : 'unknown',
        appName: this.config.appName,
        appVersion: this.config.appVersion,
        sdkVersion: '1.0.0',
      },
    });
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = setTimeout(async () => {
      if (!this.connected) {
        if (this.config.auto) {
          this.config.host = await autoDetectHost(this.config.port);
        }
        this.connect();
      }
    }, 3000);
  }

  send(type: string, payload: Record<string, any>, correlationId?: string): void {
    const message: DCMessage = {
      id: generateId(),
      type,
      deviceId: this.deviceId,
      timestamp: Date.now(),
      payload,
      ...(correlationId ? { correlationId } : {}),
    };
    const json = JSON.stringify(message);
    if (this.connected && this.ws) {
      this.ws.send(json);
    } else if (this.messageQueue.length < 1000) {
      this.messageQueue.push(json);
    }
  }

  // ---- Fetch interceptor ----

  private patchFetch(): void {
    const originalFetch = global.fetch;
    const dc = this;

    global.fetch = async function (input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
      const requestId = generateId();
      const startTime = Date.now();
      const method = init?.method?.toUpperCase() ?? 'GET';
      const url = typeof input === 'string' ? input : input.toString();

      const reqHeaders: Record<string, string> = {};
      if (init?.headers) {
        if (init.headers instanceof Headers) {
          init.headers.forEach((v, k) => (reqHeaders[k] = v));
        } else if (typeof init.headers === 'object') {
          Object.entries(init.headers).forEach(([k, v]) => (reqHeaders[k] = String(v)));
        }
      }

      let requestBody: any;
      if (init?.body) {
        try { requestBody = JSON.parse(init.body as string); } catch (_) { requestBody = String(init.body); }
      }

      dc.send('client:network:request_start', { requestId, method, url, startTime, requestHeaders: reqHeaders, requestBody });

      try {
        const response = await originalFetch(input, init);
        const clone = response.clone();
        let responseBody: any;
        try { const text = await clone.text(); try { responseBody = JSON.parse(text); } catch (_) { responseBody = text; } } catch (_) {}
        const resHeaders: Record<string, string> = {};
        response.headers.forEach((v, k) => (resHeaders[k] = v));

        dc.send('client:network:request_complete', {
          requestId, method, url, statusCode: response.status, startTime,
          endTime: Date.now(), duration: Date.now() - startTime,
          requestHeaders: reqHeaders, responseHeaders: resHeaders, requestBody, responseBody,
        });
        return response;
      } catch (error: any) {
        dc.send('client:network:request_complete', {
          requestId, method, url, statusCode: 0, startTime,
          endTime: Date.now(), duration: Date.now() - startTime,
          requestHeaders: reqHeaders, requestBody, error: error?.message ?? String(error),
        });
        throw error;
      }
    };
  }

  // ---- XHR interceptor ----

  private patchXHR(): void {
    const dc = this;
    const OriginalXHR = global.XMLHttpRequest;

    function PatchedXHR(this: any) {
      const xhr = new OriginalXHR();
      const requestId = generateId();
      let method = 'GET', url = '', startTime = 0;
      const reqHeaders: Record<string, string> = {};
      let requestBody: any;

      const origOpen = xhr.open.bind(xhr);
      xhr.open = (m: string, u: string, ...args: any[]) => { method = m.toUpperCase(); url = u; return origOpen(m, u, ...args); };

      const origSetHeader = xhr.setRequestHeader.bind(xhr);
      xhr.setRequestHeader = (n: string, v: string) => { reqHeaders[n] = v; return origSetHeader(n, v); };

      const origSend = xhr.send.bind(xhr);
      xhr.send = (body?: any) => {
        startTime = Date.now();
        if (body) { try { requestBody = JSON.parse(body); } catch (_) { requestBody = body; } }
        dc.send('client:network:request_start', { requestId, method, url, startTime, requestHeaders: reqHeaders, requestBody });
        return origSend(body);
      };

      xhr.addEventListener('loadend', () => {
        const resHeaders: Record<string, string> = {};
        try { xhr.getAllResponseHeaders().split('\r\n').forEach((l: string) => { const i = l.indexOf(':'); if (i > 0) resHeaders[l.substring(0, i).trim()] = l.substring(i + 1).trim(); }); } catch (_) {}
        let responseBody: any;
        try { responseBody = JSON.parse(xhr.responseText); } catch (_) { responseBody = xhr.responseText; }
        dc.send('client:network:request_complete', {
          requestId, method, url, statusCode: xhr.status, startTime,
          endTime: Date.now(), duration: Date.now() - startTime,
          requestHeaders: reqHeaders, responseHeaders: resHeaders, requestBody, responseBody,
          ...(xhr.status === 0 ? { error: 'Network request failed' } : {}),
        });
      });
      return xhr;
    }
    (global as any).XMLHttpRequest = PatchedXHR;
  }

  // ---- Console interceptor ----

  private patchConsole(): void {
    const dc = this;
    const orig = {
      log: console.log.bind(console), warn: console.warn.bind(console),
      error: console.error.bind(console), debug: console.debug.bind(console),
      info: console.info.bind(console), trace: console.trace?.bind(console),
    };

    const systemPrefixes = [
      'Running "', 'BUNDLE ', 'nativeRequire ', 'Require cycle:', 'Remote debugger',
      'Debugger and device', 'Download the React DevTools', 'New NativeEventEmitter',
      'Sending `', 'ViewManager:', 'Unbalanced calls', 'componentWillReceiveProps',
      'componentWillMount', 'Each child in a list', 'VirtualizedList:', 'LogBox',
    ];

    const isSys = (args: any[]) => args.length === 0 || systemPrefixes.some((p) => String(args[0]).startsWith(p));
    const toStr = (args: any[]) => args.map((a) => typeof a === 'string' ? a : (() => { try { return JSON.stringify(a, null, 2); } catch (_) { return String(a); } })()).join(' ');
    const toMeta = (args: any[]): Record<string, any> | undefined => {
      if (args.length === 1 && typeof args[0] === 'object' && args[0] !== null) { try { return JSON.parse(JSON.stringify(args[0])); } catch (_) {} }
      return undefined;
    };

    const patch = (method: string, level: string, origFn: Function) => (...args: any[]) => {
      origFn(...args);
      if (!isSys(args)) dc.send('client:log', { level, message: toStr(args), tag: `console.${method}`, ...(toMeta(args) ? { metadata: toMeta(args) } : {}) });
    };

    console.log = patch('log', 'debug', orig.log);
    console.debug = patch('debug', 'debug', orig.debug);
    console.info = patch('info', 'info', orig.info);
    console.warn = patch('warn', 'warn', orig.warn);
    console.error = patch('error', 'error', orig.error);
    if (console.trace) console.trace = patch('trace', 'debug', orig.trace!);
  }

  // ---- Public API ----

  static log(message: string, tag?: string, metadata?: Record<string, any>): void {
    DevConnect.getInstance().send('client:log', { level: 'info', message, ...(tag ? { tag } : {}), ...(metadata ? { metadata } : {}) });
  }
  static debug(message: string, tag?: string, metadata?: Record<string, any>): void {
    DevConnect.getInstance().send('client:log', { level: 'debug', message, ...(tag ? { tag } : {}), ...(metadata ? { metadata } : {}) });
  }
  static warn(message: string, tag?: string, metadata?: Record<string, any>): void {
    DevConnect.getInstance().send('client:log', { level: 'warn', message, ...(tag ? { tag } : {}), ...(metadata ? { metadata } : {}) });
  }
  static error(message: string, tag?: string, stackTrace?: string, metadata?: Record<string, any>): void {
    DevConnect.getInstance().send('client:log', { level: 'error', message, ...(tag ? { tag } : {}), ...(stackTrace ? { stackTrace } : {}), ...(metadata ? { metadata } : {}) });
  }

  static reportStateChange(opts: { stateManager: string; action: string; previousState?: Record<string, any>; nextState?: Record<string, any>; diff?: Array<Record<string, any>> }): void {
    DevConnect.getInstance().send('client:state:change', opts);
  }

  static reportStorageOperation(opts: { storageType: string; key: string; value?: any; operation: string }): void {
    DevConnect.getInstance().send('client:storage:operation', opts);
  }

  // ---- Redux dispatch from desktop ----

  /**
   * Connect Redux store so desktop can dispatch actions into the app.
   *
   * ```typescript
   * const store = createStore(reducer);
   * DevConnect.connectReduxStore(store);
   * // Now desktop can dispatch actions into your app!
   * ```
   */
  static connectReduxStore(store: any): void {
    DevConnect.getInstance()._reduxStore = store;
    // Send initial state snapshot
    try {
      DevConnect.getInstance().send('client:state:snapshot', {
        stateManager: 'redux',
        state: JSON.parse(JSON.stringify(store.getState())),
      });
    } catch (_) {}
  }

  // ---- State snapshot + restore ----

  /**
   * Set handler for state restore from desktop.
   *
   * ```typescript
   * DevConnect.onStateRestore((state) => {
   *   store.dispatch({ type: 'RESTORE_STATE', payload: state });
   * });
   * ```
   */
  static onStateRestore(handler: (state: any) => void): void {
    DevConnect.getInstance()._stateRestoreHandler = handler;
  }

  /**
   * Send a state snapshot to desktop (for saving/restoring later).
   */
  static sendStateSnapshot(stateManager: string, state: any): void {
    try {
      DevConnect.getInstance().send('client:state:snapshot', {
        stateManager,
        state: JSON.parse(JSON.stringify(state)),
      });
    } catch (_) {}
  }

  // ---- Benchmark API ----

  /**
   * Start a benchmark timer.
   *
   * ```typescript
   * DevConnect.benchmark('loadUserData');
   * await fetchUser();
   * DevConnect.benchmarkStep('loadUserData', 'fetched user');
   * await fetchPosts();
   * DevConnect.benchmarkStop('loadUserData');
   * ```
   */
  static benchmark(title: string): void {
    const dc = DevConnect.getInstance();
    dc._benchmarks.set(title, {
      title,
      startTime: Date.now(),
      steps: [],
    });
  }

  static benchmarkStep(title: string, stepTitle: string): void {
    const dc = DevConnect.getInstance();
    const b = dc._benchmarks.get(title);
    if (b) {
      b.steps.push({ title: stepTitle, timestamp: Date.now() });
    }
  }

  static benchmarkStop(title: string): void {
    const dc = DevConnect.getInstance();
    const b = dc._benchmarks.get(title);
    if (b) {
      const endTime = Date.now();
      const steps = b.steps.map((s, i) => ({
        ...s,
        delta: i === 0 ? s.timestamp - b.startTime : s.timestamp - b.steps[i - 1].timestamp,
      }));

      dc.send('client:benchmark', {
        title: b.title,
        startTime: b.startTime,
        endTime,
        duration: endTime - b.startTime,
        steps,
      });

      dc._benchmarks.delete(title);
    }
  }

  // ---- Custom commands (desktop -> app) ----

  /**
   * Register a custom command that desktop can trigger.
   *
   * ```typescript
   * DevConnect.registerCommand('clearCache', () => {
   *   AsyncStorage.clear();
   *   return { success: true };
   * });
   *
   * DevConnect.registerCommand('setUser', (args) => {
   *   store.dispatch({ type: 'SET_USER', payload: args });
   * });
   * ```
   */
  static registerCommand(name: string, handler: (args?: any) => any): void {
    DevConnect.getInstance()._customCommandHandlers.set(name, handler);
  }
}

declare let __DEV__: boolean;
