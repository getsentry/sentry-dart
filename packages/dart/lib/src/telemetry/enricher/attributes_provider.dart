import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Computes attributes for telemetry enrichment.
@internal
abstract class TelemetryAttributesProvider {
  /// Computes attributes to be added to telemetry.
  ///
  /// Return a [Future] only if async work is required.
  FutureOr<Map<String, SentryAttribute>> attributes(Object telemetryItem);
}

/// Fully caches the result of any [TelemetryAttributesProvider].
///
/// The first call to [attributes] delegates to the wrapped provider
/// and caches the result. Subsequent calls return the cached value.
final class CachedAttributesProvider implements TelemetryAttributesProvider {
  final TelemetryAttributesProvider _provider;
  FutureOr<Map<String, SentryAttribute>>? _cached;

  CachedAttributesProvider(this._provider);

  @override
  FutureOr<Map<String, SentryAttribute>> attributes(Object telemetryItem) {
    if (_cached != null) return _cached!;

    final result = _provider.attributes(telemetryItem);
    if (result is Future<Map<String, SentryAttribute>>) {
      return result.then((value) => _cached = value);
    }
    return _cached = result;
  }
}

/// Caches the result of a provider based on a cache key function.
///
/// Unlike [CachedAttributesProvider] which caches forever, this checks
/// the cache key function on each call. If the key changes, the cache
/// is invalidated and attributes are recomputed.
///
/// This is ideal for providers with both static and dynamic state (e.g.,
/// user attributes that can change at runtime).
final class CacheKeyedAttributesProvider
    implements TelemetryAttributesProvider {
  final TelemetryAttributesProvider _provider;
  final Object? Function() _cacheKeyCallback;
  Object? _cachedKey;
  FutureOr<Map<String, SentryAttribute>>? _cached;

  CacheKeyedAttributesProvider(this._provider, this._cacheKeyCallback);

  @override
  FutureOr<Map<String, SentryAttribute>> attributes(Object telemetryItem) {
    final currentKey = _cacheKeyCallback();

    // Cache hit: key hasn't changed
    if (_cached != null && _cachedKey == currentKey) {
      return _cached!;
    }

    // Cache miss: recompute and update cache
    _cachedKey = currentKey;
    final result = _provider.attributes(telemetryItem);
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

  /// Returns a cache-keyed version of this provider.
  ///
  /// The [cacheKeyCallback] function is called on each request. When the returned
  /// key changes, the cache is invalidated and attributes are recomputed.
  ///
  /// Example:
  /// ```dart
  /// provider.cachedByKey(() => (userId: scope.user?.id, env: options.environment))
  /// ```
  TelemetryAttributesProvider cachedByKey(
          Object? Function() cacheKeyCallback) =>
      CacheKeyedAttributesProvider(this, cacheKeyCallback);
}
