import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../../utils/internal_logger.dart';
import '../span/sentry_span_v2.dart';

/// Computes attributes for telemetry enrichment.
///
/// Providers are the source of attributes - they compute values from
/// scope, options, or other context. Providers are registered with
/// the registry and automatically used by enrichers.
@internal
abstract class TelemetryAttributesProvider {
  /// A unique name identifying this provider.
  String get name;

  /// Computes attributes to be added to telemetry.
  ///
  /// Return a [Future] only if async work is required.
  FutureOr<Map<String, SentryAttribute>> provide();
}

/// Applies enrichment to telemetry items.
///
/// Enrichers run providers and apply the collected attributes to telemetry.
/// Each enricher type decides its own merge semantics.
@internal
abstract class TelemetryEnricher<T> {
  /// Enriches the telemetry item by running providers and applying attributes.
  FutureOr<void> enrich(T telemetry);
}

/// Function type for applying attributes to telemetry.
typedef AttributesApplier<T> = void Function(
  T telemetry,
  Map<String, SentryAttribute> attrs,
);

/// Generic enricher that runs providers and applies attributes via a callback.
///
/// Holds a reference to the providers list, so newly registered providers
/// are automatically used on subsequent enrichment calls.
@internal
final class AttributesEnricher<T> implements TelemetryEnricher<T> {
  /// Reference to the providers list (not a copy).
  final List<TelemetryAttributesProvider> _providers;
  final AttributesApplier<T> _apply;

  const AttributesEnricher({
    required List<TelemetryAttributesProvider> providers,
    required AttributesApplier<T> apply,
  })  : _providers = providers,
        _apply = apply;

  @override
  FutureOr<void> enrich(T telemetry) {
    List<Future<void>>? pending;

    for (final provider in _providers) {
      try {
        final result = provider.provide();

        if (result is Future<Map<String, SentryAttribute>>) {
          pending ??= <Future<void>>[];
          pending.add(
            result
                .then((attrs) => _apply(telemetry, attrs))
                .catchError((Object error, StackTrace stackTrace) {
              internalLogger.error(
                'Provider "${provider.name}" failed: $error',
                error: error,
                stackTrace: stackTrace,
              );
            }),
          );
        } else {
          _apply(telemetry, result);
        }
      } catch (error, stackTrace) {
        internalLogger.error(
          'Provider "${provider.name}" failed: $error',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    if (pending != null && pending.isNotEmpty) {
      return Future.wait(pending).then((_) {});
    }
  }
}
