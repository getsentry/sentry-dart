import 'package:meta/meta.dart';

/// Wrapper for database transaction instrumentation for integrations such as Drift, Hive, etc.
///
/// This interface provides a unified, implementation-agnostic way to wrap
/// database transactions with spans. It does not expose any transaction types,
/// allowing integration packages to instrument code without coupling to a specific
/// tracing implementation.
@internal
abstract class TransactionWrapper {
  Object? get currentSpan;

  int get transactionStackSize;

  T beginTransaction<T>({
    required String operation,
    required String description,
    required T Function() execute,
    String? origin,
    Map<String, Object>? attributes,
  });

  Future<bool> commitTransaction(Future<void> Function() execute);

  Future<bool> rollbackTransaction(Future<void> Function() execute);
}
