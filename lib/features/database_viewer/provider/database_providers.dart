import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/storage/storage_entry.dart';

final databaseSchemaProvider =
    StateNotifierProvider<DatabaseSchemaNotifier, List<DatabaseSchema>>((ref) {
  return DatabaseSchemaNotifier();
});

final selectedTableProvider = StateProvider<String?>((ref) => null);

final queryResultProvider =
    StateNotifierProvider<QueryResultNotifier, QueryResult?>((ref) {
  return QueryResultNotifier();
});

class DatabaseSchemaNotifier extends StateNotifier<List<DatabaseSchema>> {
  DatabaseSchemaNotifier() : super([]);

  void setSchemas(List<DatabaseSchema> schemas) => state = schemas;
  void clear() => state = [];
}

class QueryResult {
  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final String? error;
  final int executionTimeMs;

  QueryResult({
    required this.columns,
    required this.rows,
    this.error,
    this.executionTimeMs = 0,
  });
}

class QueryResultNotifier extends StateNotifier<QueryResult?> {
  QueryResultNotifier() : super(null);

  void setResult(QueryResult result) => state = result;
  void clear() => state = null;
}
