import 'dart:async';

import 'package:meta/meta.dart';

import '../../../sentry.dart';
import '../span/sentry_span_v2.dart';
import 'attributes_aggregator.dart';

/// Pipeline for systematic telemetry attribute enrichment.
///
/// This enricher manages **global, systematic attribute providers** that apply
/// to all telemetry items. It is NOT the source of truth for ALL enrichment
/// in the SDK.
@internal
final class GlobalTelemetryEnricher {
  final Hub _hub;
  final _providers = <TelemetryAttributesProvider>[];

  late final _aggregator = TelemetryAttributesAggregator(_providers);

  GlobalTelemetryEnricher({Hub? hub}) : _hub = hub ?? HubAdapter();

  TelemetryAttributesProviderContext get _context =>
      TelemetryAttributesProviderContext(
          options: _hub.options, scope: _hub.scope);

  FutureOr<void> enrichLog(SentryLog log) {
    // Scope is also set by the SDK user so it should be merged first
    final attributes = log.attributes..addAllIfAbsent(_hub.scope.attributes);

    final result = _aggregator.build(log, _context);
    if (result is Map<String, SentryAttribute>) {
      attributes.addAllIfAbsent(result);
      log.attributes = attributes;
    } else {
      return Future.value(result).then((aggregated) {
        attributes.addAllIfAbsent(aggregated);
        log.attributes = attributes;
      });
    }
  }

  FutureOr<void> enrichSpan(RecordingSentrySpanV2 span) {
    // Scope is also set by the SDK user so it should be merged first
    final attributes = span.attributes..addAllIfAbsent(_hub.scope.attributes);

    final result = _aggregator.build(span, _context);
    if (result is Map<String, SentryAttribute>) {
      attributes.addAllIfAbsent(result);
      span.setAttributes(attributes);
    } else {
      return Future.value(result).then((aggregated) {
        attributes.addAllIfAbsent(aggregated);
        span.setAttributes(attributes);
      });
    }
  }

  void registerAttributesProvider(TelemetryAttributesProvider provider) {
    if (_providers.contains(provider)) {
      return;
    }
    _providers.add(provider);
  }
}

extension _AddAllAbsentX<K, V> on Map<K, V> {
  void addAllIfAbsent(Map<K, V> other) {
    for (final e in other.entries) {
      putIfAbsent(e.key, () => e.value);
    }
  }
}
