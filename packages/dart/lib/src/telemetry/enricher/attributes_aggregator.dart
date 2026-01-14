import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';

/// Aggregates attributes from multiple providers.
///
/// ## Provider Ordering
///
/// Providers are processed in the order they were registered. When multiple
/// providers generate attributes with the same key, **the last provider's value
/// wins**. This allows later providers to override attributes from earlier ones.
///
/// Example:
/// ```dart
/// aggregator.providers = [providerA, providerB, providerC];
/// // If all three providers return {'key': 'value'}, providerC's value is used.
/// ```
///
/// Note: This aggregator-level ordering is separate from the final attribute
/// merge in [GlobalTelemetryEnricher], where item and scope attributes take
/// precedence over all provider-generated attributes.
@internal
final class TelemetryAttributesAggregator {
  final List<TelemetryAttributesProvider> _providers;

  TelemetryAttributesAggregator(this._providers);

  /// Collects and merges attributes from all registered providers.
  ///
  /// Iterates through providers collecting their attributes into
  /// a single map.
  ///
  /// Returns synchronously if all providers are synchronous. Switches to async
  /// mode when encountering the first async provider. Provider errors are
  /// logged but don't stop aggregation.
  FutureOr<Map<String, SentryAttribute>> build(
      Object item, TelemetryAttributesProviderContext context) {
    final out = <String, SentryAttribute>{};

    for (int i = 0; i < _providers.length; i++) {
      final provider = _providers[i];
      if (!provider.supports(item)) continue;

      try {
        final result = provider(item, context);

        if (result is Future<Map<String, SentryAttribute>>) {
          // Hit async provider - switch to async mode for remaining providers
          return _buildAsyncFrom(item, out, result, i - 1, context);
        } else {
          for (final e in result.entries) {
            out[e.key] = e.value;
          }
        }
      } catch (error, stackTrace) {
        internalLogger.error(
          'Provider "$provider" failed: $error',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return out;
  }

  Future<Map<String, SentryAttribute>> _buildAsyncFrom(
      Object item,
      Map<String, SentryAttribute> out,
      Future<Map<String, SentryAttribute>> currentAsyncResult,
      int nextIndex,
      TelemetryAttributesProviderContext context) async {
    try {
      final attributes = await currentAsyncResult;
      for (final attribute in attributes.entries) {
        out[attribute.key] = attribute.value;
      }
    } catch (error, stackTrace) {
      internalLogger.error(
        'Provider failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
    }

    for (int i = nextIndex; i < _providers.length; i++) {
      final p = _providers[i];
      if (!p.supports(item)) continue;

      try {
        final attributes = await p(item, context);
        for (final attribute in attributes.entries) {
          out[attribute.key] = attribute.value;
        }
      } catch (error, stackTrace) {
        internalLogger.error(
          'Provider "$p" failed: $error',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return out;
  }
}
