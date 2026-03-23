import 'package:freezed_annotation/freezed_annotation.dart';

part 'state_change.freezed.dart';
part 'state_change.g.dart';

@freezed
abstract class StateChange with _$StateChange {
  const factory StateChange({
    required String id,
    required String deviceId,
    required String stateManagerType,
    required String actionName,
    @Default({}) Map<String, dynamic> previousState,
    @Default({}) Map<String, dynamic> nextState,
    @Default([]) List<StateDiffEntry> diff,
    required int timestamp,
  }) = _StateChange;

  factory StateChange.fromJson(Map<String, dynamic> json) =>
      _$StateChangeFromJson(json);
}

@freezed
abstract class StateDiffEntry with _$StateDiffEntry {
  const factory StateDiffEntry({
    required String path,
    required String operation,
    dynamic oldValue,
    dynamic newValue,
  }) = _StateDiffEntry;

  factory StateDiffEntry.fromJson(Map<String, dynamic> json) =>
      _$StateDiffEntryFromJson(json);
}
