import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import 'attributes_provider.dart';

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

  FutureOr<Map<String, SentryAttribute>> attributes() {
    final aggregated = <String, SentryAttribute>{};

    for (int i = 0; i < _providers.length; i++) {
      try {
        final result = _providers[i].attributes();

        if (result is Future<Map<String, SentryAttribute>>) {
          // Hit async provider - switch to async mode for remaining providers
          return _aggregateAsyncFrom(aggregated, result, i + 1);
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
        final attributes = await _providers[i].attributes();
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
