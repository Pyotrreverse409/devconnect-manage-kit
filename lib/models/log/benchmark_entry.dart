import 'package:freezed_annotation/freezed_annotation.dart';

part 'benchmark_entry.freezed.dart';
part 'benchmark_entry.g.dart';

@freezed
abstract class BenchmarkEntry with _$BenchmarkEntry {
  const factory BenchmarkEntry({
    required String id,
    required String deviceId,
    required String title,
    required int startTime,
    int? endTime,
    int? duration,
    @Default([]) List<BenchmarkStep> steps,
  }) = _BenchmarkEntry;

  factory BenchmarkEntry.fromJson(Map<String, dynamic> json) =>
      _$BenchmarkEntryFromJson(json);
}

@freezed
abstract class BenchmarkStep with _$BenchmarkStep {
  const factory BenchmarkStep({
    required String title,
    required int timestamp,
    int? delta,
  }) = _BenchmarkStep;

  factory BenchmarkStep.fromJson(Map<String, dynamic> json) =>
      _$BenchmarkStepFromJson(json);
}
