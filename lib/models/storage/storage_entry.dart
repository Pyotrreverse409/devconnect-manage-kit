import 'package:freezed_annotation/freezed_annotation.dart';

part 'storage_entry.freezed.dart';
part 'storage_entry.g.dart';

enum StorageType {
  asyncStorage,
  sharedPreferences,
  hive,
  sqlite,
  realm,
  objectbox,
  floor,
  sembast,
  sqflite,
  watermelondb,
  encryptedStorage,
  sqldelight,
  mmkv,
}

@freezed
abstract class StorageEntry with _$StorageEntry {
  const factory StorageEntry({
    required String id,
    required String deviceId,
    required StorageType storageType,
    required String key,
    dynamic value,
    required String operation,
    required int timestamp,
  }) = _StorageEntry;

  factory StorageEntry.fromJson(Map<String, dynamic> json) =>
      _$StorageEntryFromJson(json);
}

@freezed
abstract class DatabaseSchema with _$DatabaseSchema {
  const factory DatabaseSchema({
    required String name,
    required List<DatabaseTable> tables,
  }) = _DatabaseSchema;

  factory DatabaseSchema.fromJson(Map<String, dynamic> json) =>
      _$DatabaseSchemaFromJson(json);
}

@freezed
abstract class DatabaseTable with _$DatabaseTable {
  const factory DatabaseTable({
    required String name,
    required List<DatabaseColumn> columns,
    @Default(0) int rowCount,
  }) = _DatabaseTable;

  factory DatabaseTable.fromJson(Map<String, dynamic> json) =>
      _$DatabaseTableFromJson(json);
}

@freezed
abstract class DatabaseColumn with _$DatabaseColumn {
  const factory DatabaseColumn({
    required String name,
    required String type,
    @Default(false) bool isPrimaryKey,
    @Default(true) bool isNullable,
  }) = _DatabaseColumn;

  factory DatabaseColumn.fromJson(Map<String, dynamic> json) =>
      _$DatabaseColumnFromJson(json);
}
