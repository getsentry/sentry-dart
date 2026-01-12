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

  FutureOr<Map<String, SentryAttribute>> aggregate() {
    final aggregated = <String, SentryAttribute>{};
    List<Future<void>>? pending;

    for (final provider in _providers) {
      try {
        final result = provider.provide();

        if (result is Future<Map<String, SentryAttribute>>) {
          pending ??= <Future<void>>[];
          pending.add(
            result.then((attrs) {
              aggregated.addAll(attrs);
            }).catchError((Object error, StackTrace stackTrace) {
              internalLogger.error(
                'Provider "$provider" failed: $error',
                error: error,
                stackTrace: stackTrace,
              );
            }),
          );
        } else {
          aggregated.addAll(result);
        }
      } catch (error, stackTrace) {
        internalLogger.error(
          'Provider "$provider" failed: $error',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (pending != null && pending.isNotEmpty) {
      return Future.wait(pending).then((_) => aggregated);
    }

    return aggregated;
  }
}
