import '../sentry.dart';
import 'utils.dart';

class SentryTransaction extends SentryEvent {
  late final DateTime _startTimestamp;
  // move to SentryEvent
  static const String _type = 'transaction';
  final List<ISentrySpan> _spans;

  SentryTransaction(ISentrySpan trace, this._spans, String name)
      : super(
          timestamp: trace.timestamp,
          transaction: name,
        ) {
    _startTimestamp = trace.startTimestamp;
    contexts.trace = trace.context;
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    json['type'] = _type;

    if (_spans.isNotEmpty) {
      json['spans'] = _spans.map((e) => e.toJson()).toList(growable: false);
    }
    json['start_timestamp'] =
        formatDateAsIso8601WithMillisPrecision(_startTimestamp);

    return json;
  }

  bool get finished => timestamp != null;

  bool get sampled => contexts.trace?.sampled == true;
}
