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
  final SentryTracer _tracer;
  late final Map<String, SentryMeasurement> measurements;
  late final SentryTransactionInfo? transactionInfo;

  SentryTransaction(
    this._tracer, {
    SentryId? eventId,
    DateTime? timestamp,
    String? platform,
    String? serverName,
    String? release,
    String? dist,
    String? environment,
    String? transaction,
    dynamic throwable,
    Map<String, String>? tags,
    @Deprecated('Additional Data is deprecated in favor of structured [Contexts] and should be avoided when possible')
        Map<String, dynamic>? extra,
    SentryUser? user,
    Contexts? contexts,
    List<Breadcrumb>? breadcrumbs,
    SdkVersion? sdk,
    SentryRequest? request,
    String? type,
    Map<String, SentryMeasurement>? measurements,
    SentryTransactionInfo? transactionInfo,
  }) : super(
          eventId: eventId,
          timestamp: timestamp ?? _tracer.endTimestamp,
          platform: platform,
          serverName: serverName,
          release: release,
          dist: dist,
          environment: environment,
          transaction: transaction ?? _tracer.name,
          throwable: throwable ?? _tracer.throwable,
          tags: tags ?? _tracer.tags,
          // ignore: deprecated_member_use_from_same_package
          extra: extra ?? _tracer.data,
          user: user,
          contexts: contexts,
          breadcrumbs: breadcrumbs,
          sdk: sdk,
          request: request,
          type: _type,
        ) {
    startTimestamp = _tracer.startTimestamp;

    final spanContext = _tracer.context;
    spans = _tracer.children;
    this.measurements = measurements ?? {};

    this.contexts.trace = spanContext.toTraceContext(
      sampled: _tracer.samplingDecision?.sampled,
      status: _tracer.status,
    );

    this.transactionInfo = transactionInfo ??
        SentryTransactionInfo(_tracer.transactionNameSource.toStringValue());
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
    @Deprecated('Additional Data is deprecated in favor of structured [Contexts] and should be avoided when possible')
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
    SentryTransactionInfo? transactionInfo,
  }) =>
      SentryTransaction(
        _tracer,
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
        transactionInfo: transactionInfo ?? this.transactionInfo,
      );
}
