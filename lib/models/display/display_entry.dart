import 'package:freezed_annotation/freezed_annotation.dart';

part 'display_entry.freezed.dart';
part 'display_entry.g.dart';

@freezed
abstract class DisplayEntry with _$DisplayEntry {
  const factory DisplayEntry({
    required String id,
    required String deviceId,
    required String name,
    required int timestamp,
    dynamic value,
    String? preview,
    String? image,
    Map<String, dynamic>? metadata,
  }) = _DisplayEntry;

  factory DisplayEntry.fromJson(Map<String, dynamic> json) =>
      _$DisplayEntryFromJson(json);
}

@freezed
abstract class AsyncOperationEntry with _$AsyncOperationEntry {
  const factory AsyncOperationEntry({
    required String id,
    required String deviceId,
    required AsyncOperationType operationType,
    required String description,
    required AsyncOperationStatus status,
    required int timestamp,
    int? duration,
    String? sagaName,
    String? error,
    dynamic result,
    Map<String, dynamic>? metadata,
  }) = _AsyncOperationEntry;

  factory AsyncOperationEntry.fromJson(Map<String, dynamic> json) =>
      _$AsyncOperationEntryFromJson(json);
}

enum AsyncOperationType {
  sagaTake,
  sagaPut,
  sagaCall,
  sagaFork,
  sagaAll,
  sagaRace,
  sagaSelect,
  sagaDelay,
  asyncTask,
  backgroundJob,
  custom,
}

enum AsyncOperationStatus {
  start,
  resolve,
  reject,
}
