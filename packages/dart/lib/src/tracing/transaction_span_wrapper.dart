import 'package:meta/meta.dart';

/// Abstraction for managing transaction span lifecycles in database operations.
///
/// This interface handles the begin/commit/rollback lifecycle of database
/// transactions, maintaining a stack of spans for nested transaction support.
///
/// The implementation (e.g., [LegacyTransactionSpanWrapper]) handles the actual
/// span creation and management using the configured tracing backend.
@internal
abstract class TransactionSpanWrapper {
  /// Returns the current transaction span, or null if no transaction is active.
  ///
  /// This is used to parent child operations (queries) to the current transaction.
  Object? get currentSpan;

  /// Returns the number of active transaction spans in the stack.
  int get transactionStackSize;

  /// Wraps a synchronous begin transaction operation with a span.
  ///
  /// Creates a child span under the current active span, executes [execute],
  /// and manages the span based on success or failure:
  /// - On success: adds span to stack with unknown status, returns result
  /// - On failure: finishes span with error status, does NOT add to stack, rethrows
  ///
  /// If no parent span is available, [execute] is called directly.
  ///
  /// Parameters:
  /// - [operation]: The span operation name (e.g., 'db.sql.transaction').
  /// - [description]: A description of the transaction.
  /// - [execute]: The sync function to execute within the span.
  /// - [origin]: Optional origin identifier for the span.
  /// - [attributes]: Optional attributes to attach to the span.
  ///
  /// Returns a tuple of (result, spanCreated) where spanCreated indicates
  /// if tracing is active.
  (T result, bool spanCreated) beginTransaction<T>({
    required String operation,
    required String description,
    required T Function() execute,
    String? origin,
    Map<String, Object>? attributes,
  });

  /// Commits the current transaction, finishing the span with success status.
  ///
  /// Executes [execute], marks the span as successful, finishes it,
  /// and pops it from the stack.
  ///
  /// Returns true if a transaction span was active, false otherwise.
  Future<bool> commitTransaction(Future<void> Function() execute);

  /// Rolls back the current transaction, finishing the span with aborted status.
  ///
  /// Executes [execute], marks the span as aborted, finishes it,
  /// and pops it from the stack.
  ///
  /// Returns true if a transaction span was active, false otherwise.
  Future<bool> rollbackTransaction(Future<void> Function() execute);
}
