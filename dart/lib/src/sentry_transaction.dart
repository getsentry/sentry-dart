import '../sentry.dart';
import 'utils.dart';

class SentryTransaction extends SentryEvent {
  late final DateTime startTimestamp;
  // move to SentryEvent
  static const String type = 'transaction';
  final List<ISentrySpan> spans;

  SentryTransaction(ISentrySpan trace, this.spans, String name)
      : super(
          timestamp: trace.timestamp,
          transaction: name,
        ) {
    startTimestamp = trace.startTimestamp;
    contexts.trace = trace.context;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['type'] = type;
    json['spans'] = spans.map((e) => e.context.toJson()).toList(growable: false);
    json['start_timestamp'] =
        formatDateAsIso8601WithMillisPrecision(startTimestamp);

    return json;
  }
}
