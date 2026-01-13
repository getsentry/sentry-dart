import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';

/// Aggregates attributes from multiple providers.
///
/// References the providers list owned by the pipeline, so newly registered
/// providers are automatically used on subsequent aggregation calls.
@internal
final class TelemetryAttributesAggregator {
  final List<TelemetryAttributesProvider> _providers;

  TelemetryAttributesAggregator({
    required List<TelemetryAttributesProvider> providers,
  }) : _providers = providers;

  /// Collects and merges attributes from all registered providers.
  ///
  /// Iterates through providers in order, collecting their attributes into
  /// a single map. Later providers can overwrite attributes from earlier ones.
  ///
  /// Returns synchronously if all providers are synchronous. Switches to async
  /// mode when encountering the first async provider. Provider errors are
  /// logged but don't stop aggregation.
  FutureOr<Map<String, SentryAttribute>> attributes(Object telemetryItem) {
    final aggregated = <String, SentryAttribute>{};

    for (int i = 0; i < _providers.length; i++) {
      try {
        final result = _providers[i].attributes(telemetryItem);

        if (result is Future<Map<String, SentryAttribute>>) {
          // Hit async provider - switch to async mode for remaining providers
          return _aggregateAsyncFrom(telemetryItem, aggregated, result, i + 1);
        } else {
          aggregated.addAll(result);
        }
      } catch (error, stackTrace) {
        internalLogger.error(
          'Provider "${_providers[i]}" failed: $error',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return aggregated;
  }

  Future<Map<String, SentryAttribute>> _aggregateAsyncFrom(
    Object telemetryItem,
    Map<String, SentryAttribute> aggregated,
    Future<Map<String, SentryAttribute>> currentAsyncResult,
    int nextIndex,
  ) async {
    try {
      final attributes = await currentAsyncResult;
      aggregated.addAll(attributes);
    } catch (error, stackTrace) {
      internalLogger.error(
        'Provider failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
    }

    for (int i = nextIndex; i < _providers.length; i++) {
      try {
        final attributes = await _providers[i].attributes(telemetryItem);
        aggregated.addAll(attributes);
      } catch (error, stackTrace) {
        internalLogger.error(
          'Provider "${_providers[i]}" failed: $error',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return aggregated;
  }
}
