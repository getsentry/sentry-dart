import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';

/// Base interface for attribute providers used in telemetry enrichment.
///
/// Providers compute attributes that are added to telemetry items (spans, logs).
/// Each provider can filter which items it supports via [supports].
@internal
abstract interface class TelemetryAttributesProvider {
  /// Returns true if this provider should contribute attributes for [item].
  bool supports(Object item);

  /// Computes attributes for the given [item].
  ///
  /// Return a [Future] only if async work is required.
  FutureOr<Map<String, SentryAttribute>> call(
      Object item, TelemetryAttributesProviderContext context);
}

@immutable
final class TelemetryAttributesProviderContext {
  final SentryOptions options;
  final Scope scope;

  TelemetryAttributesProviderContext({
    required this.options,
    required this.scope,
  });
}

/// Fully caches the result of any [TelemetryAttributesProvider].
///
/// The first call to [call] delegates to the wrapped provider
/// and caches the result. Subsequent calls return the cached value.
@internal
final class CachedTelemetryAttributesProvider
    implements TelemetryAttributesProvider {
  final TelemetryAttributesProvider _provider;
  FutureOr<Map<String, SentryAttribute>>? _cached;

  CachedTelemetryAttributesProvider(this._provider);

  @override
  bool supports(Object item) => _provider.supports(item);

  @override
  FutureOr<Map<String, SentryAttribute>> call(
      Object item, TelemetryAttributesProviderContext context) {
    if (_cached != null) return _cached!;

    final result = _provider(item, context);
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
@internal
final class CacheKeyedTelemetryAttributesProvider
    implements TelemetryAttributesProvider {
  final TelemetryAttributesProvider _provider;
  final Object? Function() _cacheKeyCallback;

  Object? _cachedKey;
  FutureOr<Map<String, SentryAttribute>>? _cached;

  CacheKeyedTelemetryAttributesProvider(this._provider, this._cacheKeyCallback);

  @override
  bool supports(Object item) => _provider.supports(item);

  @override
  FutureOr<Map<String, SentryAttribute>> call(
      Object item, TelemetryAttributesProviderContext context) {
    final currentKey = _cacheKeyCallback();

    // Cache hit: key hasn't changed
    if (_cached != null && _cachedKey == currentKey) {
      return _cached!;
    }

    // Cache miss: recompute and update cache
    _cachedKey = currentKey;
    final result = _provider(item, context);
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
  /// The provider's [call] method will only be called once,
  /// and subsequent calls will return the cached result.
  TelemetryAttributesProvider cached() =>
      CachedTelemetryAttributesProvider(this);

  /// Returns a cache-keyed version of this provider.
  ///
  /// The [cacheKeyCallback] function is called on each request. When the returned
  /// key changes, the cache is invalidated and attributes are recomputed.
  ///
  /// Example:
  /// ```dart
  /// provider.cachedByKey(() => (userId: scope.user?.id, env: options.environment))
  TelemetryAttributesProvider cachedByKey(
          Object? Function() cacheKeyCallback) =>
      CacheKeyedTelemetryAttributesProvider(this, cacheKeyCallback);
}
