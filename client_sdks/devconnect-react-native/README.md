# DevConnect Manage Kit — React Native SDK

[![npm](https://img.shields.io/npm/v/devconnect-manage-kit)](https://www.npmjs.com/package/devconnect-manage-kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](../../LICENSE)
[![React Native](https://img.shields.io/badge/React%20Native-%3E%3D0.60-61DAFB?logo=react)](https://reactnative.dev)

Debug your React Native app with [DevConnect Manage Tool](https://github.com/ridelinktechs/devconnect-manage-kit) — network, state, logs, storage, performance — all in one desktop tool.

## Install

```bash
yarn add devconnect-manage-kit
# or
npm install devconnect-manage-kit
```

## Quick Start

```typescript
import { DevConnect } from 'devconnect-manage-kit';

await DevConnect.init({ appName: 'MyApp' });
// Done. fetch + XHR + console auto-captured.
```

## Config

```typescript
await DevConnect.init({
  appName: 'MyApp',
  appVersion: '1.0.0',
  host: undefined,            // undefined = auto-detect
  port: 9090,                 // default: 9090
  enabled: __DEV__,           // false in production
  autoInterceptFetch: true,
  autoInterceptXHR: true,
  autoInterceptConsole: true,
});
```

## Features

### Network

Auto-captured: fetch, XHR, axios, got, ky, superagent, apisauce, Apollo, urql, TanStack Query, SWR, RTK Query.

```typescript
// Axios (optional, for extra tagging)
import { setupAxiosInterceptor } from 'devconnect-manage-kit';
setupAxiosInterceptor(axios);
```

### Logs

Auto-captured: console.log, console.debug, console.info, console.warn, console.error, console.trace.

```typescript
DevConnect.log('User logged in');
DevConnect.debug('Debug info', 'Auth');
DevConnect.warn('Warning');
DevConnect.error('Error', 'Tag', stackTrace);
```

### State

Supports: Redux, Redux Toolkit, MobX, Zustand, Jotai, Valtio, XState.

```typescript
// Redux Toolkit
import { configureStore } from '@reduxjs/toolkit';
import { devConnectReduxMiddleware } from 'devconnect-manage-kit';

const store = configureStore({
  reducer: rootReducer,
  middleware: (getDefault) =>
    __DEV__ ? getDefault().concat(devConnectReduxMiddleware) : getDefault(),
});
```

```typescript
// Zustand
import { devConnectMiddleware } from 'devconnect-manage-kit';

const useStore = create(
  devConnectMiddleware(
    (set) => ({ count: 0, increment: () => set((s) => ({ count: s.count + 1 })) }),
    'CounterStore'
  )
);
```

### Storage

```typescript
// AsyncStorage
import { DevConnectAsyncStorage } from 'devconnect-manage-kit';
DevConnectAsyncStorage.patchInPlace(AsyncStorage);

// MMKV
import { DevConnectMMKV } from 'devconnect-manage-kit';
DevConnectMMKV.wrap(storage);
```

### Performance

```typescript
DevConnect.reportPerformanceMetric({ metricType: 'fps', value: 58.5, label: 'JS Thread FPS' });
```

### Benchmark

```typescript
DevConnect.benchmark('loadUserData');
await fetchUser();
DevConnect.benchmarkStep('loadUserData', 'fetched user');
await fetchPosts();
DevConnect.benchmarkStop('loadUserData');
```

### Custom Commands

```typescript
DevConnect.registerCommand('clearCache', () => {
  AsyncStorage.clear();
  return { success: true };
});
```

## Production Safety

Disabled by default when `__DEV__` is false — zero runtime overhead. Metro bundler strips `__DEV__` blocks in production.

```typescript
// Explicitly disable
DevConnect.init({ appName: 'MyApp', enabled: false });
```

## Links

- [Main Repository](https://github.com/ridelinktechs/devconnect-manage-kit)
- [Desktop App Download](https://github.com/ridelinktechs/devconnect-manage-kit/releases)
- [Full Documentation](https://github.com/ridelinktechs/devconnect-manage-kit#react-native-sdk)

## License

MIT
