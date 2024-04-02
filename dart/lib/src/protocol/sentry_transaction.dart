import 'package:meta/meta.dart';

import '../protocol.dart';
import '../sentry_tracer.dart';
import '../utils.dart';
import '../sentry_measurement.dart';

@immutable
class SentryTransaction extends SentryEvent {
  late final DateTime startTimestamp;
  static const String _type = 'transaction';
  late final List<SentrySpan> spans;
  @internal
  final SentryTracer tracer;
  late final Map<String, SentryMeasurement> measurements;
  late final Map<String, List<MetricSummary>>? metricSummaries;
  late final SentryTransactionInfo? transactionInfo;

  SentryTransaction(
    this.tracer, {
    super.eventId,
    DateTime? timestamp,
    super.platform,
    super.serverName,
    super.release,
    super.dist,
    super.environment,
    String? transaction,
    dynamic throwable,
    Map<String, String>? tags,
    @Deprecated(
        'Additional Data is deprecated in favor of structured [Contexts] and should be avoided when possible')
    Map<String, dynamic>? extra,
    super.user,
    super.contexts,
    super.breadcrumbs,
    super.sdk,
    super.request,
    String? type,
    Map<String, SentryMeasurement>? measurements,
    Map<String, List<MetricSummary>>? metricSummaries,
    SentryTransactionInfo? transactionInfo,
  }) : super(
          timestamp: timestamp ?? tracer.endTimestamp,
          transaction: transaction ?? tracer.name,
          throwable: throwable ?? tracer.throwable,
          tags: tags ?? tracer.tags,
          // ignore: deprecated_member_use_from_same_package
          extra: extra ?? tracer.data,
          type: _type,
        ) {
    startTimestamp = tracer.startTimestamp;

    final spanContext = tracer.context;
    spans = tracer.children;
    this.measurements = measurements ?? {};
    this.metricSummaries =
        metricSummaries ?? tracer.localMetricsAggregator?.getSummaries();

    contexts.trace = spanContext.toTraceContext(
      sampled: tracer.samplingDecision?.sampled,
      status: tracer.status,
    );

    this.transactionInfo = transactionInfo ??
        SentryTransactionInfo(tracer.transactionNameSource.name);
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();

    if (spans.isNotEmpty) {
      json['spans'] = spans.map((e) => e.toJson()).toList(growable: false);
    }
    json['start_timestamp'] =
        formatDateAsIso8601WithMillisPrecision(startTimestamp);

    if (measurements.isNotEmpty) {
      final map = <String, dynamic>{};
      for (final item in measurements.entries) {
        map[item.key] = item.value.toJson();
      }
      json['measurements'] = map;
    }

    final transactionInfo = this.transactionInfo;
    if (transactionInfo != null) {
      json['transaction_info'] = transactionInfo.toJson();
    }

    final metricSummariesMap = metricSummaries?.entries ?? Iterable.empty();
    if (metricSummariesMap.isNotEmpty) {
      final map = <String, dynamic>{};
      for (final entry in metricSummariesMap) {
        final summary = entry.value.map((e) => e.toJson());
        map[entry.key] = summary.toList(growable: false);
      }
      json['_metrics_summary'] = map;
    }

    return json;
  }

  bool get finished => timestamp != null;

  bool get sampled => contexts.trace?.sampled == true;

  @override
  SentryTransaction copyWith({
    SentryId? eventId,
    DateTime? timestamp,
    String? platform,
    String? logger,
    String? serverName,
    String? release,
    String? dist,
    String? environment,
    Map<String, String>? modules,
    SentryMessage? message,
    String? transaction,
    dynamic throwable,
    SentryLevel? level,
    String? culprit,
    Map<String, String>? tags,
    @Deprecated(
        'Additional Data is deprecated in favor of structured [Contexts] and should be avoided when possible')
    Map<String, dynamic>? extra,
    List<String>? fingerprint,
    SentryUser? user,
    Contexts? contexts,
    List<Breadcrumb>? breadcrumbs,
    SdkVersion? sdk,
    SentryRequest? request,
    DebugMeta? debugMeta,
    List<SentryException>? exceptions,
    List<SentryThread>? threads,
    String? type,
    Map<String, SentryMeasurement>? measurements,
    Map<String, List<MetricSummary>>? metricSummaries,
    SentryTransactionInfo? transactionInfo,
  }) =>
      SentryTransaction(
        tracer,
        eventId: eventId ?? this.eventId,
        timestamp: timestamp ?? this.timestamp,
        platform: platform ?? this.platform,
        serverName: serverName ?? this.serverName,
        release: release ?? this.release,
        dist: dist ?? this.dist,
        environment: environment ?? this.environment,
        transaction: transaction ?? this.transaction,
        throwable: throwable ?? this.throwable,
        tags: (tags != null ? Map.from(tags) : null) ?? this.tags,
        // ignore: deprecated_member_use_from_same_package
        extra: (extra != null ? Map.from(extra) : null) ?? this.extra,
        user: user ?? this.user,
        contexts: contexts ?? this.contexts,
        breadcrumbs: (breadcrumbs != null ? List.from(breadcrumbs) : null) ??
            this.breadcrumbs,
        sdk: sdk ?? this.sdk,
        request: request ?? this.request,
        type: type ?? this.type,
        measurements: (measurements != null ? Map.from(measurements) : null) ??
            this.measurements,
        metricSummaries:
            (metricSummaries != null ? Map.from(metricSummaries) : null) ??
                this.metricSummaries,
        transactionInfo: transactionInfo ?? this.transactionInfo,
      );
}
