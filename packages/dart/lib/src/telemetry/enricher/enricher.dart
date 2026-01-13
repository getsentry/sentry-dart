import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../span/sentry_span_v2.dart';
import 'attributes_aggregator.dart';

/// Pipeline for systematic telemetry attribute enrichment.
///
/// This enricher manages **global, systematic attribute providers** that apply
/// to all telemetry items of a given type. It is NOT the source of truth for
/// ALL enrichment in the SDK.
@internal
class GlobalTelemetryEnricher {
  final List<TelemetryAttributesProvider> _spanProviders = [];
  final List<TelemetryAttributesProvider> _logProviders = [];
  late final TelemetryAttributesAggregator _logAttributesAggregator;
  late final TelemetryAttributesAggregator _spanAttributesAggregator;

  GlobalTelemetryEnricher({
    TelemetryAttributesAggregator? spanAttributesAggregator,
    TelemetryAttributesAggregator? logAttributesAggregator,
  }) {
    _logAttributesAggregator = logAttributesAggregator ??
        TelemetryAttributesAggregator(providers: _logProviders);
    _spanAttributesAggregator = spanAttributesAggregator ??
        TelemetryAttributesAggregator(providers: _spanProviders);
  }

  FutureOr<void> enrichLog(SentryLog log) {
    final userAttributes = log.attributes;
    final result = _logAttributesAggregator.attributes(log);

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
        _spanAttributesAggregator.attributes(span);

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
