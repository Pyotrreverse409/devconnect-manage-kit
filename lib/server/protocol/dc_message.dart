import 'package:freezed_annotation/freezed_annotation.dart';

part 'dc_message.freezed.dart';
part 'dc_message.g.dart';

@freezed
abstract class DCMessage with _$DCMessage {
  const factory DCMessage({
    required String id,
    required String type,
    required String deviceId,
    required int timestamp,
    required Map<String, dynamic> payload,
    String? correlationId,
  }) = _DCMessage;

  factory DCMessage.fromJson(Map<String, dynamic> json) =>
      _$DCMessageFromJson(json);
}
