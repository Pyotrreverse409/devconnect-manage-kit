/**
 * DevConnect React Native SDK
 *
 * Auto-intercepts fetch, XMLHttpRequest, axios, Redux, MobX, AsyncStorage, Firebase.
 *
 * ## Quick Start (1 line):
 * ```typescript
 * import { DevConnect } from 'devconnect-react-native';
 *
 * // In App.tsx or index.js
 * DevConnect.init({ appName: 'MyApp' });
 * // That's it! fetch, XMLHttpRequest, and AsyncStorage are now auto-intercepted.
 * ```
 *
 * ## With Redux:
 * ```typescript
 * import { devConnectReduxMiddleware } from 'devconnect-react-native';
 * const store = createStore(rootReducer, applyMiddleware(devConnectReduxMiddleware));
 * ```
 *
 * ## With Axios:
 * ```typescript
 * import { setupAxiosInterceptor } from 'devconnect-react-native';
 * setupAxiosInterceptor(axiosInstance);
 * ```
 */

export { DevConnect } from './client';
export { devConnectReduxMiddleware } from './interceptors/reduxMiddleware';
export { setupMobxSpy } from './interceptors/mobxSpy';
export { setupAxiosInterceptor } from './interceptors/axiosInterceptor';
export { DevConnectAsyncStorage } from './interceptors/asyncStoragePlugin';
export { DevConnectLogger } from './reporters/logReporter';
export { DevConnectStorage } from './reporters/storageReporter';

// Logging library integrations
export {
  devConnectTransport,       // react-native-logs
  patchLoglevel,             // loglevel
  winstonDevConnectTransport,// winston
  pinoDevConnectTransport,   // pino
  bunyanDevConnectStream,    // bunyan
  wrapLogger,                // any custom logger
} from './interceptors/logLibraryPlugins';
