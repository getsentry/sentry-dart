// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../../../sentry.dart';

/// A recorded transaction operation for testing purposes.
@visibleForTesting
class RecordedTransaction {
  final String operation;
  final String description;
  final String? origin;
  final Map<String, Object>? attributes;
  final TransactionState state;
  final Object? error;

  RecordedTransaction({
    required this.operation,
    required this.description,
    this.origin,
    this.attributes,
    required this.state,
    this.error,
  });

  bool get isCommitted => state == TransactionState.committed;
  bool get isRolledBack => state == TransactionState.rolledBack;
  bool get isPending => state == TransactionState.pending;
  bool get hasError => error != null;
}

@visibleForTesting
enum TransactionState { pending, committed, rolledBack, errorOnBegin }

/// A [TransactionSpanWrapper] implementation that records all operations for testing.
///
/// This allows tests to verify that the interceptor manages transactions correctly
/// without depending on concrete Sentry span implementations.
@visibleForTesting
class RecordingTransactionSpanWrapper implements TransactionSpanWrapper {
  final List<RecordedTransaction> _transactions = [];
  final Hub _hub;

  /// Simulated span stack to track nesting.
  final List<_FakeSpan> _spanStack = [];

  RecordingTransactionSpanWrapper({required Hub hub}) : _hub = hub;

  /// Returns all recorded transactions.
  List<RecordedTransaction> get transactions =>
      List.unmodifiable(_transactions);

  /// Returns the number of pending (uncommitted/unrolled) transactions.
  int get pendingCount =>
      _transactions.where((t) => t.state == TransactionState.pending).length;

  /// Returns transactions that were committed.
  List<RecordedTransaction> get committedTransactions =>
      _transactions.where((t) => t.isCommitted).toList();

  /// Returns transactions that were rolled back.
  List<RecordedTransaction> get rolledBackTransactions =>
      _transactions.where((t) => t.isRolledBack).toList();

  @override
  Object? get currentSpan => _spanStack.lastOrNull;

  @override
  int get transactionStackSize => _spanStack.length;

  @override
  (T, bool) beginTransaction<T>({
    required String operation,
    required String description,
    required T Function() execute,
    String? origin,
    Map<String, Object>? attributes,
  }) {
    final parent = currentSpan ?? _hub.getSpan();
    if (parent == null) {
      return (execute(), false);
    }

    final fakeSpan = _FakeSpan(
      operation: operation,
      description: description,
      origin: origin,
      attributes: attributes,
    );

    try {
      final result = execute();
      _spanStack.add(fakeSpan);
      _transactions.add(
        RecordedTransaction(
          operation: operation,
          description: description,
          origin: origin,
          attributes: attributes != null ? Map.from(attributes) : null,
          state: TransactionState.pending,
        ),
      );
      return (result, true);
    } catch (e) {
      _transactions.add(
        RecordedTransaction(
          operation: operation,
          description: description,
          origin: origin,
          attributes: attributes != null ? Map.from(attributes) : null,
          state: TransactionState.errorOnBegin,
          error: e,
        ),
      );
      rethrow;
    }
  }

  @override
  Future<bool> commitTransaction(Future<void> Function() execute) async {
    if (_spanStack.isEmpty) {
      return false;
    }

    final index = _findPendingTransactionIndex();
    if (index == -1) {
      return false;
    }

    try {
      await execute();
      _updateTransactionState(index, TransactionState.committed);
      return true;
    } catch (e) {
      _updateTransactionState(index, TransactionState.committed, error: e);
      rethrow;
    } finally {
      _spanStack.removeLast();
    }
  }

  @override
  Future<bool> rollbackTransaction(Future<void> Function() execute) async {
    if (_spanStack.isEmpty) {
      return false;
    }

    final index = _findPendingTransactionIndex();
    if (index == -1) {
      return false;
    }

    try {
      await execute();
      _updateTransactionState(index, TransactionState.rolledBack);
      return true;
    } catch (e) {
      _updateTransactionState(index, TransactionState.rolledBack, error: e);
      rethrow;
    } finally {
      _spanStack.removeLast();
    }
  }

  int _findPendingTransactionIndex() {
    for (var i = _transactions.length - 1; i >= 0; i--) {
      if (_transactions[i].state == TransactionState.pending) {
        return i;
      }
    }
    return -1;
  }

  void _updateTransactionState(
    int index,
    TransactionState state, {
    Object? error,
  }) {
    final old = _transactions[index];
    _transactions[index] = RecordedTransaction(
      operation: old.operation,
      description: old.description,
      origin: old.origin,
      attributes: old.attributes,
      state: state,
      error: error,
    );
  }

  /// Clears all recorded transactions.
  void clear() {
    _transactions.clear();
    _spanStack.clear();
  }
}

class _FakeSpan {
  final String operation;
  final String description;
  final String? origin;
  final Map<String, Object>? attributes;

  _FakeSpan({
    required this.operation,
    required this.description,
    this.origin,
    this.attributes,
  });
}
