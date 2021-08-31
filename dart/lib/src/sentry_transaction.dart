import '../sentry.dart';

class SentryTransaction extends SentryEvent {
  late final DateTime startTimestamp;
  // move to SentryEvent
  final String type = 'transaction';
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

    return json;
  }
}
