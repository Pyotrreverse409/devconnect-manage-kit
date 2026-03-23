import 'package:freezed_annotation/freezed_annotation.dart';

part 'log_entry.freezed.dart';
part 'log_entry.g.dart';

enum LogLevel { debug, info, warn, error }

@freezed
abstract class LogEntry with _$LogEntry {
  const factory LogEntry({
    required String id,
    required String deviceId,
    required LogLevel level,
    required String message,
    required int timestamp,
    Map<String, dynamic>? metadata,
    String? stackTrace,
    String? tag,
  }) = _LogEntry;

  factory LogEntry.fromJson(Map<String, dynamic> json) =>
      _$LogEntryFromJson(json);
}
