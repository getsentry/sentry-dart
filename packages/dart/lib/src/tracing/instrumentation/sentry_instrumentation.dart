import 'package:meta/meta.dart';

import '../../hub.dart';
import '../../hub_adapter.dart';
import '../../protocol.dart';
import 'instrumentation_span.dart';
import 'span_factory.dart';

/// Helper for instrumenting operations with Sentry spans.
@internal
class SentryInstrumentation {
  final Hub _hub;
  final String _origin;
  final InstrumentationSpanFactory _factory;

  SentryInstrumentation(
    Hub? hub,
    this._origin, {
    InstrumentationSpanFactory? factory,
  })  : _hub = hub ?? HubAdapter(),
        _factory = factory ?? LegacyInstrumentationSpanFactory();

  InstrumentationSpan? getSpan() => _factory.getSpan(_hub);

  InstrumentationSpan? createChildSpan({
    required String operation,
    String? description,
    InstrumentationSpan? parent,
    DateTime? startTimestamp,
  }) {
    final parentSpan = parent ?? getSpan();
    return _factory.createChildSpan(
      parentSpan,
      operation,
      description: description,
      startTimestamp: startTimestamp,
    );
  }

  /// Wraps an async operation in a span with automatic status/error handling.
  Future<T> asyncWrapInSpan<T>({
    required String operation,
    required String description,
    required Future<T> Function() execute,
    Map<String, dynamic>? data,
    InstrumentationSpan? parent,
  }) async {
    final span = createChildSpan(
      operation: operation,
      description: description,
      parent: parent,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;
    data?.forEach((key, value) => span.setData(key, value));

    try {
      final result = await execute();
      span.status = SpanStatus.ok();
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span.finish();
    }
  }

  /// Wraps a sync operation in a span with automatic status/error handling.
  T syncWrapInSpan<T>({
    required String operation,
    required String description,
    required T Function() execute,
    Map<String, dynamic>? data,
    InstrumentationSpan? parent,
  }) {
    final span = createChildSpan(
      operation: operation,
      description: description,
      parent: parent,
    );

    if (span == null) {
      return execute();
    }

    span.origin = _origin;
    span.setData('sync', true);
    data?.forEach((key, value) => span.setData(key, value));

    try {
      final result = execute();
      span.status = SpanStatus.ok();
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      span.finish();
    }
  }
}
