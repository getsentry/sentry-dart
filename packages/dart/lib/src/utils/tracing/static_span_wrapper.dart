// ignore_for_file: invalid_use_of_internal_member

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../internal_logger.dart';

@internal
class StaticSpanWrapper implements SpanWrapper {
  final Hub _hub;

  StaticSpanWrapper({Hub? hub}) : _hub = hub ?? HubAdapter();

  ISentrySpan? _resolveParent(Object? parentSpan) {
    if (parentSpan is ISentrySpan) {
      return parentSpan;
    }
    return _hub.getSpan();
  }

  @override
  Future<T> wrapAsync<T>({
    required String operation,
    required String description,
    required Future<T> Function() execute,
    required String integration,
    String? origin,
    Map<String, Object>? attributes,
    SpanStatus Function(T result)? deriveStatus,
    Object? parentSpan,
  }) async {
    final parent = _resolveParent(parentSpan);

    if (parent == null) {
      internalLogger.warning(
        'No active span found for $integration. The operation will not be traced for $operation $description',
      );
      return execute();
    }

    final span = parent.startChild(operation, description: description);
    _configureSpan(span, origin: origin, attributes: attributes);

    try {
      final result = await execute();
      span.status = deriveStatus?.call(result) ?? SpanStatus.ok();
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      await span.finish();
    }
  }

  @override
  T wrapSync<T>({
    required String operation,
    required String description,
    required T Function() execute,
    required String integration,
    String? origin,
    Map<String, Object>? attributes,
    SpanStatus Function(T result)? deriveStatus,
    Object? parentSpan,
  }) {
    final parent = _resolveParent(parentSpan);

    if (parent == null) {
      internalLogger.warning(
        'No active span found for $integration. The operation will not be traced for $operation $description',
      );
      return execute();
    }

    final span = parent.startChild(operation, description: description);
    _configureSpan(span, origin: origin, attributes: attributes);

    try {
      final result = execute();
      span.status = deriveStatus?.call(result) ?? SpanStatus.ok();
      return result;
    } catch (exception) {
      span.throwable = exception;
      span.status = SpanStatus.internalError();
      rethrow;
    } finally {
      span.finish();
    }
  }

  void _configureSpan(
    ISentrySpan span, {
    String? origin,
    Map<String, Object>? attributes,
  }) {
    if (origin != null) {
      span.origin = origin;
    }
    attributes?.forEach((key, value) => span.setData(key, value));
  }
}
