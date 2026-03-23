/**
 * DevConnect React Native Client
 *
 * Manages WebSocket connection to DevConnect desktop app.
 * Auto-patches fetch and XMLHttpRequest on init.
 */

interface DevConnectConfig {
  appName: string;
  appVersion?: string;
  host?: string;
  port?: number;
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

export class DevConnect {
  private static instance: DevConnect | null = null;
  private ws: WebSocket | null = null;
  private config: Required<DevConnectConfig>;
  private deviceId: string;
  private connected = false;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private messageQueue: string[] = [];

  private constructor(config: DevConnectConfig) {
    this.config = {
      appName: config.appName,
      appVersion: config.appVersion ?? '1.0.0',
      host: config.host ?? 'localhost',
      port: config.port ?? 9090,
      enabled: config.enabled ?? __DEV__,
      autoInterceptFetch: config.autoInterceptFetch ?? true,
      autoInterceptXHR: config.autoInterceptXHR ?? true,
      autoInterceptConsole: config.autoInterceptConsole ?? true,
    };
    this.deviceId = generateId();
  }

  /**
   * Initialize DevConnect. Call once in App.tsx or index.js.
   *
   * ```typescript
   * DevConnect.init({ appName: 'MyApp' });
   * ```
   */
  static init(config: DevConnectConfig): DevConnect {
    if (DevConnect.instance) return DevConnect.instance;

    const dc = new DevConnect(config);
    DevConnect.instance = dc;

    if (dc.config.enabled) {
      dc.connect();

      if (dc.config.autoInterceptFetch) {
        dc.patchFetch();
      }
      if (dc.config.autoInterceptXHR) {
        dc.patchXHR();
      }
      if (dc.config.autoInterceptConsole) {
        dc.patchConsole();
      }
    }

    return dc;
  }

  static getInstance(): DevConnect {
    if (!DevConnect.instance) {
      throw new Error('DevConnect not initialized. Call DevConnect.init() first.');
    }
    return DevConnect.instance;
  }

  // ---- WebSocket Connection ----

  private connect(): void {
    try {
      const url = `ws://${this.config.host}:${this.config.port}`;
      this.ws = new WebSocket(url);

      this.ws.onopen = () => {
        this.connected = true;
        // Flush queued messages
        this.messageQueue.forEach((msg) => this.ws?.send(msg));
        this.messageQueue = [];
      };

      this.ws.onmessage = (event: WebSocketMessageEvent) => {
        try {
          const msg = JSON.parse(event.data as string);
          if (msg.type === 'server:hello') {
            this.sendHandshake();
          }
        } catch (_) {}
      };

      this.ws.onclose = () => {
        this.connected = false;
        this.scheduleReconnect();
      };

      this.ws.onerror = () => {
        this.connected = false;
        this.scheduleReconnect();
      };
    } catch (_) {
      this.scheduleReconnect();
    }
  }

  private sendHandshake(): void {
    this.send('client:handshake', {
      deviceInfo: {
        deviceId: this.deviceId,
        deviceName: 'React Native Device',
        platform: 'react_native',
        osVersion: `${(global as any).Platform?.OS ?? 'unknown'} ${(global as any).Platform?.Version ?? ''}`.trim(),
        appName: this.config.appName,
        appVersion: this.config.appVersion,
        sdkVersion: '1.0.0',
      },
    });
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer) clearTimeout(this.reconnectTimer);
    this.reconnectTimer = setTimeout(() => {
      if (!this.connected) this.connect();
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
    } else {
      // Queue messages when disconnected
      if (this.messageQueue.length < 1000) {
        this.messageQueue.push(json);
      }
    }
  }

  // ---- Auto Fetch Interceptor ----

  private patchFetch(): void {
    const originalFetch = global.fetch;
    const dc = this;

    global.fetch = async function (
      input: RequestInfo | URL,
      init?: RequestInit
    ): Promise<Response> {
      const requestId = generateId();
      const startTime = Date.now();
      const method = init?.method?.toUpperCase() ?? 'GET';
      const url = typeof input === 'string' ? input : input.toString();

      // Extract headers
      const reqHeaders: Record<string, string> = {};
      if (init?.headers) {
        if (init.headers instanceof Headers) {
          init.headers.forEach((v, k) => (reqHeaders[k] = v));
        } else if (typeof init.headers === 'object') {
          Object.entries(init.headers).forEach(([k, v]) => (reqHeaders[k] = String(v)));
        }
      }

      // Parse request body
      let requestBody: any = undefined;
      if (init?.body) {
        try {
          requestBody = JSON.parse(init.body as string);
        } catch (_) {
          requestBody = String(init.body);
        }
      }

      dc.send('client:network:request_start', {
        requestId,
        method,
        url,
        startTime,
        requestHeaders: reqHeaders,
        requestBody,
      });

      try {
        const response = await originalFetch(input, init);

        // Clone response to read body without consuming it
        const clone = response.clone();
        let responseBody: any = undefined;
        try {
          const text = await clone.text();
          try {
            responseBody = JSON.parse(text);
          } catch (_) {
            responseBody = text;
          }
        } catch (_) {}

        // Extract response headers
        const resHeaders: Record<string, string> = {};
        response.headers.forEach((v, k) => (resHeaders[k] = v));

        dc.send('client:network:request_complete', {
          requestId,
          method,
          url,
          statusCode: response.status,
          startTime,
          endTime: Date.now(),
          duration: Date.now() - startTime,
          requestHeaders: reqHeaders,
          responseHeaders: resHeaders,
          requestBody,
          responseBody,
        });

        return response;
      } catch (error: any) {
        dc.send('client:network:request_complete', {
          requestId,
          method,
          url,
          statusCode: 0,
          startTime,
          endTime: Date.now(),
          duration: Date.now() - startTime,
          requestHeaders: reqHeaders,
          requestBody,
          error: error?.message ?? String(error),
        });
        throw error;
      }
    };
  }

  // ---- Auto XMLHttpRequest Interceptor ----

  private patchXHR(): void {
    const dc = this;
    const OriginalXHR = global.XMLHttpRequest;

    function PatchedXHR(this: any) {
      const xhr = new OriginalXHR();
      const requestId = generateId();
      let method = 'GET';
      let url = '';
      let startTime = 0;
      const reqHeaders: Record<string, string> = {};
      let requestBody: any = undefined;

      const originalOpen = xhr.open.bind(xhr);
      xhr.open = function (m: string, u: string, ...args: any[]) {
        method = m.toUpperCase();
        url = u;
        return originalOpen(m, u, ...args);
      };

      const originalSetRequestHeader = xhr.setRequestHeader.bind(xhr);
      xhr.setRequestHeader = function (name: string, value: string) {
        reqHeaders[name] = value;
        return originalSetRequestHeader(name, value);
      };

      const originalSend = xhr.send.bind(xhr);
      xhr.send = function (body?: any) {
        startTime = Date.now();

        if (body) {
          try {
            requestBody = JSON.parse(body);
          } catch (_) {
            requestBody = body;
          }
        }

        dc.send('client:network:request_start', {
          requestId,
          method,
          url,
          startTime,
          requestHeaders: reqHeaders,
          requestBody,
        });

        return originalSend(body);
      };

      xhr.addEventListener('loadend', () => {
        const resHeaders: Record<string, string> = {};
        try {
          const headerStr = xhr.getAllResponseHeaders();
          headerStr.split('\r\n').forEach((line: string) => {
            const idx = line.indexOf(':');
            if (idx > 0) {
              resHeaders[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
            }
          });
        } catch (_) {}

        let responseBody: any = undefined;
        try {
          responseBody = JSON.parse(xhr.responseText);
        } catch (_) {
          responseBody = xhr.responseText;
        }

        dc.send('client:network:request_complete', {
          requestId,
          method,
          url,
          statusCode: xhr.status,
          startTime,
          endTime: Date.now(),
          duration: Date.now() - startTime,
          requestHeaders: reqHeaders,
          responseHeaders: resHeaders,
          requestBody,
          responseBody,
          ...(xhr.status === 0 ? { error: 'Network request failed' } : {}),
        });
      });

      return xhr;
    }

    (global as any).XMLHttpRequest = PatchedXHR;
  }

  // ---- Auto Console Interceptor ----
  // Captures: console.log, console.warn, console.error, console.debug,
  //           console.info, console.trace
  // Only sends developer-placed console calls to DevConnect.

  private patchConsole(): void {
    const dc = this;

    const originalConsole = {
      log: console.log.bind(console),
      warn: console.warn.bind(console),
      error: console.error.bind(console),
      debug: console.debug.bind(console),
      info: console.info.bind(console),
      trace: console.trace?.bind(console),
    };

    // Known RN/system log prefixes to filter out
    const systemPrefixes = [
      'Running "',
      'BUNDLE ',
      'nativeRequire ',
      'Require cycle:',
      'Remote debugger',
      'Debugger and device',
      'Download the React DevTools',
      'New NativeEventEmitter',
      'Sending `',
      'ViewManager:',
      'Unbalanced calls',
      'componentWillReceiveProps',
      'componentWillMount',
      'Each child in a list',
      'VirtualizedList:',
      'LogBox',
    ];

    function isSystemLog(args: any[]): boolean {
      if (args.length === 0) return true;
      const first = String(args[0]);
      return systemPrefixes.some((p) => first.startsWith(p));
    }

    function argsToString(args: any[]): string {
      return args
        .map((a) => {
          if (typeof a === 'string') return a;
          try {
            return JSON.stringify(a, null, 2);
          } catch (_) {
            return String(a);
          }
        })
        .join(' ');
    }

    function argsToMetadata(args: any[]): Record<string, any> | undefined {
      // If there's a single object arg (common pattern: console.log({user, token}))
      if (args.length === 1 && typeof args[0] === 'object' && args[0] !== null) {
        try {
          return JSON.parse(JSON.stringify(args[0]));
        } catch (_) {}
      }
      // If multiple args, store as indexed metadata
      if (args.length > 1) {
        const meta: Record<string, any> = {};
        args.forEach((a, i) => {
          if (typeof a === 'object' && a !== null) {
            try {
              meta[`arg${i}`] = JSON.parse(JSON.stringify(a));
            } catch (_) {
              meta[`arg${i}`] = String(a);
            }
          }
        });
        if (Object.keys(meta).length > 0) return meta;
      }
      return undefined;
    }

    console.log = (...args: any[]) => {
      originalConsole.log(...args);
      if (!isSystemLog(args)) {
        dc.send('client:log', {
          level: 'debug',
          message: argsToString(args),
          tag: 'console.log',
          ...(argsToMetadata(args) ? { metadata: argsToMetadata(args) } : {}),
        });
      }
    };

    console.debug = (...args: any[]) => {
      originalConsole.debug(...args);
      if (!isSystemLog(args)) {
        dc.send('client:log', {
          level: 'debug',
          message: argsToString(args),
          tag: 'console.debug',
          ...(argsToMetadata(args) ? { metadata: argsToMetadata(args) } : {}),
        });
      }
    };

    console.info = (...args: any[]) => {
      originalConsole.info(...args);
      if (!isSystemLog(args)) {
        dc.send('client:log', {
          level: 'info',
          message: argsToString(args),
          tag: 'console.info',
          ...(argsToMetadata(args) ? { metadata: argsToMetadata(args) } : {}),
        });
      }
    };

    console.warn = (...args: any[]) => {
      originalConsole.warn(...args);
      if (!isSystemLog(args)) {
        dc.send('client:log', {
          level: 'warn',
          message: argsToString(args),
          tag: 'console.warn',
          ...(argsToMetadata(args) ? { metadata: argsToMetadata(args) } : {}),
        });
      }
    };

    console.error = (...args: any[]) => {
      originalConsole.error(...args);
      if (!isSystemLog(args)) {
        dc.send('client:log', {
          level: 'error',
          message: argsToString(args),
          tag: 'console.error',
          ...(argsToMetadata(args) ? { metadata: argsToMetadata(args) } : {}),
        });
      }
    };

    if (console.trace) {
      console.trace = (...args: any[]) => {
        originalConsole.trace?.(...args);
        if (!isSystemLog(args)) {
          dc.send('client:log', {
            level: 'debug',
            message: argsToString(args),
            tag: 'console.trace',
            stackTrace: new Error().stack,
          });
        }
      };
    }
  }

  // ---- Public API ----

  static log(message: string, tag?: string, metadata?: Record<string, any>): void {
    DevConnect.getInstance().send('client:log', {
      level: 'info',
      message,
      ...(tag ? { tag } : {}),
      ...(metadata ? { metadata } : {}),
    });
  }

  static debug(message: string, tag?: string, metadata?: Record<string, any>): void {
    DevConnect.getInstance().send('client:log', {
      level: 'debug',
      message,
      ...(tag ? { tag } : {}),
      ...(metadata ? { metadata } : {}),
    });
  }

  static warn(message: string, tag?: string, metadata?: Record<string, any>): void {
    DevConnect.getInstance().send('client:log', {
      level: 'warn',
      message,
      ...(tag ? { tag } : {}),
      ...(metadata ? { metadata } : {}),
    });
  }

  static error(
    message: string,
    tag?: string,
    stackTrace?: string,
    metadata?: Record<string, any>
  ): void {
    DevConnect.getInstance().send('client:log', {
      level: 'error',
      message,
      ...(tag ? { tag } : {}),
      ...(stackTrace ? { stackTrace } : {}),
      ...(metadata ? { metadata } : {}),
    });
  }

  static reportStateChange(opts: {
    stateManager: string;
    action: string;
    previousState?: Record<string, any>;
    nextState?: Record<string, any>;
    diff?: Array<Record<string, any>>;
  }): void {
    DevConnect.getInstance().send('client:state:change', opts);
  }

  static reportStorageOperation(opts: {
    storageType: string;
    key: string;
    value?: any;
    operation: string;
  }): void {
    DevConnect.getInstance().send('client:storage:operation', opts);
  }
}

// Polyfill __DEV__ for non-RN environments
declare let __DEV__: boolean;
