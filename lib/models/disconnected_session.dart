import 'device_info.dart';
import 'log/log_entry.dart';
import 'network/network_entry.dart';
import 'state/state_change.dart';
import 'storage/storage_entry.dart';

class DisconnectedSession {
  final DeviceInfo deviceInfo;
  final DateTime disconnectedAt;
  final List<LogEntry> logs;
  final List<NetworkEntry> networkEntries;
  final List<StateChange> stateChanges;
  final List<StorageEntry> storageEntries;
  final String? clientIp;

  DisconnectedSession({
    required this.deviceInfo,
    required this.disconnectedAt,
    required this.logs,
    required this.networkEntries,
    required this.stateChanges,
    required this.storageEntries,
    this.clientIp,
  });

  int get totalEvents =>
      logs.length + networkEntries.length + stateChanges.length + storageEntries.length;
}
