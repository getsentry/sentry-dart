import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Computes attributes for telemetry enrichment.
///
/// Providers are the source of attributes - they compute values from
/// scope, options, or other context. Providers are registered with
/// the pipeline and automatically used by aggregators.
@internal
abstract class TelemetryAttributesProvider {
  /// Computes attributes to be added to telemetry.
  ///
  /// Return a [Future] only if async work is required.
  FutureOr<Map<String, SentryAttribute>> attributes();
}

/// Caches the result of any [TelemetryAttributesProvider].
///
/// The first call to [attributes] delegates to the wrapped provider
/// and caches the result. Subsequent calls return the cached value.
final class CachedAttributesProvider implements TelemetryAttributesProvider {
  final TelemetryAttributesProvider _provider;
  FutureOr<Map<String, SentryAttribute>>? _cached;

  CachedAttributesProvider(this._provider);

  @override
  FutureOr<Map<String, SentryAttribute>> attributes() {
    if (_cached != null) return _cached!;

    final result = _provider.attributes();
    if (result is Future<Map<String, SentryAttribute>>) {
      return result.then((value) => _cached = value);
    }
    return _cached = result;
  }
}

@internal
extension CachedAttributesProviderExtension on TelemetryAttributesProvider {
  /// Returns a cached version of this provider.
  ///
  /// The provider's [attributes] method will only be called once,
  /// and subsequent calls will return the cached result.
  TelemetryAttributesProvider cached() => CachedAttributesProvider(this);
}
