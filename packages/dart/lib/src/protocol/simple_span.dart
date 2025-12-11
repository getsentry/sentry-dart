import '../../sentry.dart';

class SimpleSpan implements Span {
  final SpanId _spanId;
  final Hub _hub;
  @override
  final Span? parentSpan;
  final Map<String, SentryAttribute> _attributes = {};
  final DateTime _startTimestamp;
  late final SentryId _traceId;

  String _name;
  SpanV2Status _status = SpanV2Status.ok;
  DateTime? _endTimestamp;
  bool _isFinished = false;
  String? _segmentKey;

  SimpleSpan({
    required String name,
    this.parentSpan,
    Hub? hub,
  })  : _spanId = SpanId.newId(),
        _startTimestamp = DateTime.now().toUtc(),
        _hub = hub ?? HubAdapter(),
        _name = name {
    _traceId = parentSpan?.traceId ?? _hub.scope.propagationContext.traceId;
  }

  @override
  Span get segmentSpan => parentSpan?.segmentSpan ?? this;

  @override
  SentryId get traceId => _traceId;

  @override
  SpanId get spanId => _spanId;

  @override
  String get name => _name;

  @override
  set name(String value) => _name = value;

  @override
  SpanV2Status get status => _status;

  @override
  set status(SpanV2Status value) => _status = value;

  @override
  DateTime? get endTimestamp => _endTimestamp;

  @override
  Map<String, SentryAttribute> get attributes => Map.unmodifiable(_attributes);

  @override
  bool get isFinished => _isFinished;

  @override
  String get segmentKey => _segmentKey ??= '$traceId-${segmentSpan.spanId}';

  @override
  void setAttribute(String key, SentryAttribute value) {
    _attributes[key] = value;
  }

  @override
  void setAttributes(Map<String, SentryAttribute> attributes) {
    _attributes.addAll(attributes);
  }

  @override
  void end({DateTime? endTimestamp}) {
    if (_isFinished) {
      return;
    }
    _endTimestamp = (endTimestamp ?? DateTime.now()).toUtc();
    _isFinished = true;
    _hub.captureSpan(this);
  }

  @override
  Map<String, dynamic> toJson() {
    double toUnixSeconds(DateTime timestamp) =>
        timestamp.microsecondsSinceEpoch / 1000000;

    return {
      'trace_id': _hub.scope.propagationContext.traceId.toString(),
      'span_id': spanId.toString(),
      'name': name,
      'status': status.name,
      'end_timestamp':
          endTimestamp == null ? null : toUnixSeconds(endTimestamp!),
      'start_timestamp': toUnixSeconds(_startTimestamp),
      if (parentSpan == null) 'is_segment': true,
      if (attributes.isNotEmpty)
        'attributes':
            attributes.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}
