import '../devconnect_client.dart';

/// Reports storage operations to DevConnect.
///
/// Usage:
/// ```dart
/// final storage = DevConnectStorage(storageType: 'shared_preferences');
/// storage.reportWrite('user_token', 'abc123');
/// storage.reportRead('user_token', 'abc123');
/// storage.reportDelete('user_token');
/// ```
class DevConnectStorage {
  final String storageType;

  const DevConnectStorage({this.storageType = 'shared_preferences'});

  void reportRead(String key, dynamic value) {
    DevConnectClient.instance.reportStorageOperation(
      storageType: storageType,
      key: key,
      value: value,
      operation: 'read',
    );
  }

  void reportWrite(String key, dynamic value) {
    DevConnectClient.instance.reportStorageOperation(
      storageType: storageType,
      key: key,
      value: value,
      operation: 'write',
    );
  }

  void reportDelete(String key) {
    DevConnectClient.instance.reportStorageOperation(
      storageType: storageType,
      key: key,
      operation: 'delete',
    );
  }

  void reportClear() {
    DevConnectClient.instance.reportStorageOperation(
      storageType: storageType,
      key: '*',
      operation: 'clear',
    );
  }
}
