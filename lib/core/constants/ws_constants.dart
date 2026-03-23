class WsMessageTypes {
  // Server -> Client
  static const String serverHello = 'server:hello';
  static const String serverHandshakeAck = 'server:handshake_ack';
  static const String serverPing = 'server:ping';
  static const String serverStorageRequestAll = 'server:storage:request_all';
  static const String serverStorageWrite = 'server:storage:write';
  static const String serverStorageDelete = 'server:storage:delete';
  static const String serverDatabaseQuery = 'server:database:query';
  static const String serverDatabaseRequestSchema =
      'server:database:request_schema';

  // Client -> Server
  static const String clientHandshake = 'client:handshake';
  static const String clientPong = 'client:pong';
  static const String clientNetworkRequestStart =
      'client:network:request_start';
  static const String clientNetworkRequestComplete =
      'client:network:request_complete';
  static const String clientStateChange = 'client:state:change';
  static const String clientLog = 'client:log';
  static const String clientStorageOperation = 'client:storage:operation';
  static const String clientStorageAllData = 'client:storage:all_data';
  static const String clientDatabaseQueryResult =
      'client:database:query_result';
  static const String clientDatabaseSchema = 'client:database:schema';
  static const String clientBenchmark = 'client:benchmark';
  static const String clientCustom = 'client:custom';
}
