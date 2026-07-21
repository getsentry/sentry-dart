import 'package:meta/meta.dart';

import '../protocol.dart';
import '../sentry_measurement.dart';
import '../sentry_tracer.dart';
import '../utils.dart';

class SentryTransaction extends SentryEvent {
  late final DateTime startTimestamp;
  static const String _type = 'transaction';
  late final List<SentrySpan> spans;
  @internal
  final SentryTracer tracer;
  late final Map<String, SentryMeasurement> measurements;
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

    final data = extra ?? tracer.data;
    contexts.trace = spanContext.toTraceContext(
      sampled: tracer.samplingDecision?.sampled,
      status: tracer.status,
      data: data.isEmpty ? null : data,
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

    return json;
  }

  bool get finished => timestamp != null;

  bool get sampled => contexts.trace?.sampled == true;
}
