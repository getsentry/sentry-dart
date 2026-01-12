import 'package:meta/meta.dart';

import 'enricher.dart';

/// Registry for managing telemetry attribute providers and enrichers.
///
/// **Providers** compute attributes from scope/options/context.
/// **Enrichers** (one per telemetry type) apply attributes to telemetry.
///
/// The enrichers hold a reference to the providers list, so when you
/// register a new provider, it's automatically used by the enrichers.
///
/// Registration uses **prepend semantics** (`insert(0, e)`) so that:
/// - Newest registered providers appear first in the list
/// - Forward iteration executes newest (upstream/generic) first
/// - Older (downstream/specific) providers run last and can overwrite
@internal
class TelemetryEnricherRegistry {
  final List<TelemetryAttributesProvider> _attributeProviders = [];

  /// The single log enricher that uses all registered providers.
  late final LogEnricher _logEnricher;

  /// The single span enricher that uses all registered providers.
  late final SpanEnricher _spanEnricher;

  TelemetryEnricherRegistry(
      {LogEnricher? logEnricher, SpanEnricher? spanEnricher}) {
    _logEnricher = logEnricher ?? LogEnricher(providers: _attributeProviders);
    _spanEnricher =
        spanEnricher ?? SpanEnricher(providers: _attributeProviders);
  }

  /// The log enricher that uses all registered providers.
  LogEnricher get logEnricher => _logEnricher;

  /// The span enricher that uses all registered providers.
  SpanEnricher get spanEnricher => _spanEnricher;

  /// Read-only view of registered attribute providers.
  ///
  /// Iteration order: newest-first (last registered appears at index 0).
  List<TelemetryAttributesProvider> get attributeProviders =>
      List.unmodifiable(_attributeProviders);

  /// Registers a [TelemetryAttributesProvider].
  ///
  /// The provider is prepended (inserted at index 0).
  ///
  /// Example: SentryFlutter.init:
  /// - Flutter registers provider first
  /// - Dart registers providers second
  /// - -> the Dart providers will execute first (less specific)
  /// - -> the Flutter set providers will execute later and overwrite the generic ones if overlapping
  ///
  /// The enrichers automatically pick up new providers since they hold
  /// a reference to the same providers list.
  ///
  /// Skip if provider already exists.
  void registerProvider(TelemetryAttributesProvider provider) {
    if (_attributeProviders.contains(provider)) {
      return;
    }
    _attributeProviders.insert(0, provider);
  }

  /// Removes a [TelemetryAttributesProvider] by name.
  ///
  /// Returns `true` if a provider was removed, `false` otherwise.
  bool removeProviderByName(String name) {
    final initialLength = _attributeProviders.length;
    _attributeProviders.removeWhere((p) => p.name == name);
    return _attributeProviders.length < initialLength;
  }

  /// Removes a specific [TelemetryAttributesProvider] instance.
  ///
  /// Returns `true` if the provider was found and removed.
  bool removeProvider(TelemetryAttributesProvider provider) =>
      _attributeProviders.remove(provider);

  /// Clears all providers.
  void clearProviders() => _attributeProviders.clear();
}
