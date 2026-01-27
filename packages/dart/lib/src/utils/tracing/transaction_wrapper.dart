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
    required String integration,
    String? origin,
    Map<String, Object>? attributes,
  });

  Future<void> commitTransaction(
      Future<void> Function() execute, String integration);

  Future<void> rollbackTransaction(
      Future<void> Function() execute, String integration);
}
