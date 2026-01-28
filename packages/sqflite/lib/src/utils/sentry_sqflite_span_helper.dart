// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';
import 'package:sentry/sentry.dart';

import '../../sentry_sqflite.dart';
import 'sentry_database_span_attributes.dart';

/// Helper class that combines SpanWrapper with breadcrumb handling for sqflite.
///
/// This class wraps SpanWrapper calls and adds breadcrumb creation to maintain
/// backwards compatibility with the existing sqflite tracing behavior.
@internal
class SentrySqfliteSpanHelper {
  final SpanWrapper _spanWrapper;
  final Hub _hub;
  final String? _dbName;

  static const _loggerName = 'sentry_sqflite';

  SentrySqfliteSpanHelper({
    required SpanWrapper spanWrapper,
    required Hub hub,
    String? dbName,
  })  : _spanWrapper = spanWrapper,
        _hub = hub,
        _dbName = dbName;

  /// Wraps an async operation with span tracing and breadcrumb creation.
  Future<T> wrapAsync<T>({
    required String operation,
    required String description,
    required Future<T> Function() execute,
    required String origin,
    Object? parentSpan,
  }) async {
    final breadcrumb = _createBreadcrumb(description, operation);

    try {
      final result = await _spanWrapper.wrapAsync<T>(
        operation: operation,
        description: description,
        execute: execute,
        loggerName: _loggerName,
        origin: origin,
        attributes: _createAttributes(),
        parentSpan: parentSpan,
      );
      breadcrumb.data?['status'] = 'ok';
      return result;
    } catch (e) {
      breadcrumb.data?['status'] = 'internal_error';
      breadcrumb.level = SentryLevel.warning;
      rethrow;
    } finally {
      await _hub.scope.addBreadcrumb(breadcrumb);
    }
  }

  Map<String, Object> _createAttributes() {
    final attributes = <String, Object>{
      SentryDatabase.dbSystemKey: SentryDatabase.dbSystem,
    };
    if (_dbName != null) {
      attributes[SentryDatabase.dbNameKey] = _dbName;
    }
    return attributes;
  }

  Breadcrumb _createBreadcrumb(String message, String category) {
    final breadcrumb = Breadcrumb(
      message: message,
      category: category,
      data: <String, dynamic>{},
      type: 'query',
    );
    setDatabaseAttributeOnBreadcrumb(breadcrumb, _dbName);
    return breadcrumb;
  }

  /// Wraps a transaction operation with span tracing and breadcrumb creation.
  ///
  /// The callback receives an opaque parent span handle that can be passed
  /// to child operations within the transaction.
  Future<T> wrapTransaction<T>({
    required String operation,
    required String description,
    required Future<T> Function(Object? transactionSpan) execute,
    required String origin,
    Object? parentSpan,
  }) async {
    final span = _spanWrapper.startSpan(
      operation: operation,
      description: description,
      origin: origin,
      attributes: _createAttributes(),
      parentSpan: parentSpan,
    );

    final breadcrumb = _createBreadcrumb(description, operation);

    try {
      final result = await execute(span);
      breadcrumb.data?['status'] = 'ok';
      await _spanWrapper.finishSpan(span, status: SpanStatus.ok());
      return result;
    } catch (e) {
      breadcrumb.data?['status'] = 'internal_error';
      breadcrumb.level = SentryLevel.warning;
      await _spanWrapper.finishSpan(
        span,
        status: SpanStatus.internalError(),
        throwable: e,
      );
      rethrow;
    } finally {
      await _hub.scope.addBreadcrumb(breadcrumb);
    }
  }
}
