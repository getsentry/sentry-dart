import '../sentry.dart';

class SentryTransaction extends SentryEvent {
  late final DateTime startTimestamp;
  // move to SentryEvent
  final String type = 'transaction';
  final ISentrySpan trace;
  final List<ISentrySpan> spans;

  SentryTransaction(this.trace, this.spans, String name)
      : super(
          timestamp: trace.timestamp,
          transaction: name,
        ) {
    startTimestamp = trace.startTimestamp;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();

    return json;
  }
}
