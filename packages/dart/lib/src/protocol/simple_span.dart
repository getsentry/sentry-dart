import '../../sentry.dart';

class SimpleSpan implements Span {
  final Hub _hub;
  final Map<String, SentryAttribute> _attributes = {};
  final DateTime _startTimestamp;
  final SpanId _spanId = SpanId.newId();

  @override
  final Span? parentSpan;

  String _name;
  SpanV2Status _status = SpanV2Status.ok;
  DateTime? _endTimestamp;
  bool _isFinished = false;

  SimpleSpan({
    required String name,
    this.parentSpan,
    DateTime? startTimestamp,
    Hub? hub,
  })  : _hub = hub ?? HubAdapter(),
        _name = name,
        _startTimestamp = startTimestamp ?? DateTime.now().toUtc();

  @override
  DateTime? get endTimestamp => _endTimestamp;

  @override
  Map<String, SentryAttribute> get attributes => Map.unmodifiable(_attributes);

  @override
  String get name => _name;

  @override
  set name(String value) {
    _name = value;
  }

  @override
  SpanV2Status get status => _status;

  @override
  set status(SpanV2Status value) {
    _status = value;
  }

  @override
  void end({DateTime? endTimestamp}) {
    _endTimestamp = endTimestamp ?? DateTime.now().toUtc();
    _hub.captureSpan(this);
    _isFinished = true;
  }

  @override
  void setAttribute(String key, SentryAttribute value) {
    _attributes[key] = value;
  }

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {
    _attributes.addAll(attributes);
  }

  @override
  SpanId? get parentSpanId => parentSpan?.spanId;

  @override
  SpanId get spanId => _spanId;

  @override
  bool get isFinished => _isFinished;

  @override
  Map<String, dynamic> toJson() {
    return {
      'trace_id': _hub.scope.propagationContext.traceId,
      'span_id': _spanId.toString(),
      if (parentSpanId != null) 'parent_span_id': parentSpanId!.toString(),
      'is_segment': parentSpan == null,
      'name': name,
      'status': status.name,
      'start_timestamp': _startTimestamp.microsecondsSinceEpoch / 1000000.0,
      'end_timestamp': _endTimestamp!.microsecondsSinceEpoch / 1000000.0,
      if (attributes.isNotEmpty)
        'attributes':
            attributes.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}
