import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../span/sentry_span_v2.dart';
import 'attributes_aggregator.dart';
import 'attributes_provider.dart';

/// Pipeline for managing telemetry attribute providers and executing enrichment.
///
/// **Providers** compute attributes from scope/options/context.
/// **Aggregators** (one per telemetry type) collect attributes from providers.
/// **Pipeline** applies attributes with correct priority (user > providers).
///
/// The pipeline owns the provider lists and aggregators reference them,
/// so when you register a new provider, it's automatically used by the aggregators.
///
/// Registration uses **prepend semantics** (`insert(0, e)`) so that:
/// - Newest registered providers appear first in the list
/// - Forward iteration executes newest (upstream/generic) first
/// - Older (downstream/specific) providers run last and can overwrite
@internal
class TelemetryEnricher {
  /// Provider list for span enrichment.
  final List<TelemetryAttributesProvider> _spanProviders = [];

  /// Provider list for log enrichment.
  final List<TelemetryAttributesProvider> _logProviders = [];

  /// The single log aggregator that uses all registered providers.
  late final TelemetryAttributesAggregator _logAttributesAggregator;

  /// The single span aggregator that uses all registered providers.
  late final TelemetryAttributesAggregator _spanAttributesAggregator;

  TelemetryEnricher._();

  factory TelemetryEnricher.create() {
    final pipeline = TelemetryEnricher._();
    pipeline._logAttributesAggregator =
        TelemetryAttributesAggregator(providers: pipeline._logProviders);
    pipeline._spanAttributesAggregator =
        TelemetryAttributesAggregator(providers: pipeline._spanProviders);
    return pipeline;
  }

  FutureOr<void> enrichLog(SentryLog log) {
    final userAttributes = log.attributes;
    final result = _logAttributesAggregator.attributes();

    if (result is Map<String, SentryAttribute>) {
      log.attributes = {...result, ...userAttributes};
    } else {
      return Future.value(result).then((aggregated) {
        log.attributes = {...aggregated, ...userAttributes};
      });
    }
  }

  FutureOr<void> enrichSpan(RecordingSentrySpanV2 span) {
    final userAttributes = span.attributes;
    final FutureOr<Map<String, SentryAttribute>> result =
        _spanAttributesAggregator.attributes();

    if (result is Map<String, SentryAttribute>) {
      span.setAttributes({...result, ...userAttributes});
    } else {
      return Future.value(result).then((aggregated) {
        span.setAttributes({...aggregated, ...userAttributes});
      });
    }
  }

  /// Registers an attribute provider for span enrichment.
  ///
  /// The provider is prepended (inserted at index 0) so newer providers
  /// execute first and older providers can overwrite their attributes.
  void registerSpanAttributesProvider(TelemetryAttributesProvider provider) {
    if (!_spanProviders.contains(provider)) {
      _spanProviders.insert(0, provider);
    }
  }

  /// Registers an attribute provider for log enrichment.
  ///
  /// The provider is prepended (inserted at index 0) so newer providers
  /// execute first and older providers can overwrite their attributes.
  void registerLogAttributesProvider(TelemetryAttributesProvider provider) {
    if (!_logProviders.contains(provider)) {
      _logProviders.insert(0, provider);
    }
  }
}
