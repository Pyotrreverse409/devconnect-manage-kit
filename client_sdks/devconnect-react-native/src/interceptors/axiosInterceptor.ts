import { DevConnect } from '../client';

/**
 * Axios interceptor that auto-captures all requests.
 *
 * Usage:
 * ```typescript
 * import axios from 'axios';
 * import { setupAxiosInterceptor } from 'devconnect-react-native';
 *
 * // Intercept the default axios instance
 * setupAxiosInterceptor(axios);
 *
 * // Or a custom instance
 * const api = axios.create({ baseURL: 'https://api.example.com' });
 * setupAxiosInterceptor(api);
 * ```
 *
 * Captures:
 * - Request method, URL, headers, body
 * - Response status, headers, body, timing
 * - Errors with response data
 * - Firebase REST API calls
 * - OAuth2 token requests
 */
export function setupAxiosInterceptor(axiosInstance: any): void {
  let requestId = '';

  function generateId(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
  }

  // Request interceptor
  axiosInstance.interceptors.request.use(
    (config: any) => {
      requestId = generateId();
      const startTime = Date.now();

      // Attach metadata to config
      config._dcRequestId = requestId;
      config._dcStartTime = startTime;

      // Detect special request types
      const url = config.url ?? '';
      const baseURL = config.baseURL ?? '';
      const fullUrl = url.startsWith('http') ? url : `${baseURL}${url}`;
      let tag: string | undefined;

      if (fullUrl.includes('firebaseio.com') || fullUrl.includes('googleapis.com/identitytoolkit')) {
        tag = 'Firebase';
      } else if (fullUrl.includes('/oauth') || fullUrl.includes('/token') || fullUrl.includes('/authorize')) {
        tag = 'OAuth2';
      }

      // Parse request body
      let requestBody: any = undefined;
      if (config.data) {
        try {
          requestBody = typeof config.data === 'string' ? JSON.parse(config.data) : config.data;
        } catch (_) {
          requestBody = config.data;
        }
      }

      DevConnect.safeSend('client:network:request_start', {
        requestId,
        method: (config.method ?? 'GET').toUpperCase(),
        url: fullUrl,
        startTime,
        requestHeaders: config.headers ?? {},
        requestBody,
      });

      // Also log special requests
      if (tag) {
        DevConnect.log(`${tag} request: ${(config.method ?? 'GET').toUpperCase()} ${url}`, tag);
      }

      return config;
    },
    (error: any) => Promise.reject(error)
  );

  // Response interceptor
  axiosInstance.interceptors.response.use(
    (response: any) => {
      try {
        const config = response.config;
        const rid = config._dcRequestId ?? generateId();
        const startTime = config._dcStartTime ?? Date.now();
        const fullUrl = response.config?.url?.startsWith('http')
          ? response.config.url
          : `${response.config?.baseURL ?? ''}${response.config?.url ?? ''}`;

        // Response headers
        const resHeaders: Record<string, string> = {};
        if (response.headers) {
          Object.entries(response.headers).forEach(([k, v]) => {
            resHeaders[k] = String(v);
          });
        }

        DevConnect.safeSend('client:network:request_complete', {
          requestId: rid,
          method: (config.method ?? 'GET').toUpperCase(),
          url: fullUrl,
          statusCode: response.status,
          startTime,
          endTime: Date.now(),
          duration: Date.now() - startTime,
          requestHeaders: config.headers ?? {},
          responseHeaders: resHeaders,
          requestBody: config.data,
          responseBody: response.data,
        });
      } catch (_) {}

      return response;
    },
    (error: any) => {
      try {
        const config = error.config ?? {};
        const rid = config._dcRequestId ?? generateId();
        const startTime = config._dcStartTime ?? Date.now();
        const fullUrl = config.url?.startsWith('http')
          ? config.url
          : `${config.baseURL ?? ''}${config.url ?? ''}`;

        DevConnect.safeSend('client:network:request_complete', {
          requestId: rid,
          method: (config.method ?? 'GET').toUpperCase(),
          url: fullUrl,
          statusCode: error.response?.status ?? 0,
          startTime,
          endTime: Date.now(),
          duration: Date.now() - startTime,
          requestHeaders: config.headers ?? {},
          responseBody: error.response?.data,
          error: error.message ?? String(error),
        });
      } catch (_) {}

      return Promise.reject(error);
    }
  );
}
