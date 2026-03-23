import { DevConnect } from '../client';

/**
 * AsyncStorage wrapper that auto-reports all storage operations.
 *
 * Usage:
 * ```typescript
 * import AsyncStorage from '@react-native-async-storage/async-storage';
 * import { DevConnectAsyncStorage } from 'devconnect-react-native';
 *
 * // Wrap AsyncStorage globally
 * const Storage = DevConnectAsyncStorage.wrap(AsyncStorage);
 *
 * // Use Storage instead of AsyncStorage
 * await Storage.setItem('token', 'abc123');
 * const token = await Storage.getItem('token');
 * ```
 *
 * Or patch in-place:
 * ```typescript
 * DevConnectAsyncStorage.patchInPlace(AsyncStorage);
 * // Now AsyncStorage itself is intercepted
 * ```
 */
export class DevConnectAsyncStorage {
  /**
   * Returns a wrapped version of AsyncStorage that reports operations.
   */
  static wrap(asyncStorage: any): any {
    return {
      getItem: async (key: string, ...args: any[]) => {
        const value = await asyncStorage.getItem(key, ...args);
        DevConnect.reportStorageOperation({
          storageType: 'async_storage',
          key,
          value,
          operation: 'read',
        });
        return value;
      },

      setItem: async (key: string, value: string, ...args: any[]) => {
        await asyncStorage.setItem(key, value, ...args);
        DevConnect.reportStorageOperation({
          storageType: 'async_storage',
          key,
          value,
          operation: 'write',
        });
      },

      removeItem: async (key: string, ...args: any[]) => {
        await asyncStorage.removeItem(key, ...args);
        DevConnect.reportStorageOperation({
          storageType: 'async_storage',
          key,
          operation: 'delete',
        });
      },

      mergeItem: async (key: string, value: string, ...args: any[]) => {
        await asyncStorage.mergeItem(key, value, ...args);
        DevConnect.reportStorageOperation({
          storageType: 'async_storage',
          key,
          value,
          operation: 'write',
        });
      },

      clear: async (...args: any[]) => {
        await asyncStorage.clear(...args);
        DevConnect.reportStorageOperation({
          storageType: 'async_storage',
          key: '*',
          operation: 'clear',
        });
      },

      getAllKeys: async (...args: any[]) => {
        const keys = await asyncStorage.getAllKeys(...args);
        DevConnect.log(`AsyncStorage.getAllKeys: ${keys?.length ?? 0} keys`, 'Storage');
        return keys;
      },

      multiGet: async (keys: string[], ...args: any[]) => {
        const result = await asyncStorage.multiGet(keys, ...args);
        result?.forEach(([key, value]: [string, string | null]) => {
          DevConnect.reportStorageOperation({
            storageType: 'async_storage',
            key,
            value,
            operation: 'read',
          });
        });
        return result;
      },

      multiSet: async (keyValuePairs: [string, string][], ...args: any[]) => {
        await asyncStorage.multiSet(keyValuePairs, ...args);
        keyValuePairs.forEach(([key, value]) => {
          DevConnect.reportStorageOperation({
            storageType: 'async_storage',
            key,
            value,
            operation: 'write',
          });
        });
      },

      multiRemove: async (keys: string[], ...args: any[]) => {
        await asyncStorage.multiRemove(keys, ...args);
        keys.forEach((key) => {
          DevConnect.reportStorageOperation({
            storageType: 'async_storage',
            key,
            operation: 'delete',
          });
        });
      },

      multiMerge: async (keyValuePairs: [string, string][], ...args: any[]) => {
        await asyncStorage.multiMerge(keyValuePairs, ...args);
        keyValuePairs.forEach(([key, value]) => {
          DevConnect.reportStorageOperation({
            storageType: 'async_storage',
            key,
            value,
            operation: 'write',
          });
        });
      },
    };
  }

  /**
   * Monkey-patches AsyncStorage in-place so all calls are auto-intercepted.
   */
  static patchInPlace(asyncStorage: any): void {
    const original = {
      getItem: asyncStorage.getItem.bind(asyncStorage),
      setItem: asyncStorage.setItem.bind(asyncStorage),
      removeItem: asyncStorage.removeItem.bind(asyncStorage),
      clear: asyncStorage.clear.bind(asyncStorage),
    };

    asyncStorage.getItem = async (key: string, ...args: any[]) => {
      const value = await original.getItem(key, ...args);
      DevConnect.reportStorageOperation({
        storageType: 'async_storage', key, value, operation: 'read',
      });
      return value;
    };

    asyncStorage.setItem = async (key: string, value: string, ...args: any[]) => {
      await original.setItem(key, value, ...args);
      DevConnect.reportStorageOperation({
        storageType: 'async_storage', key, value, operation: 'write',
      });
    };

    asyncStorage.removeItem = async (key: string, ...args: any[]) => {
      await original.removeItem(key, ...args);
      DevConnect.reportStorageOperation({
        storageType: 'async_storage', key, operation: 'delete',
      });
    };

    asyncStorage.clear = async (...args: any[]) => {
      await original.clear(...args);
      DevConnect.reportStorageOperation({
        storageType: 'async_storage', key: '*', operation: 'clear',
      });
    };
  }
}
